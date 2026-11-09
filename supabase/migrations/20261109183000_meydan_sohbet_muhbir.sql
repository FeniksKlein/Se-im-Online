-- =====================================================================
--  Meydan: eylem sohbeti, muhbir, ve kriz oyunları.
--  Az oyuncuya göre eşikler (yaklaşık 20–60 kişi).
--  Gizli işlerde yalnız oyun içi kullanıcı adı görünür.
--  Küfür süzgeci oyun.kufurlu ile aynıdır.
--  Canlı veritabanına bu dosya elle uygulanır.
-- =====================================================================

-- ───────────── sohbet: yalnız eylemin içindeki oyuncular ─────────────
create table if not exists public.sokak_eylem_sohbet(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 user_id uuid not null references oyun.profiller,
 metin text not null check(char_length(metin) between 1 and 400),
 zaman timestamptz not null default now()
);
create index if not exists sokak_eylem_sohbet_eylem on public.sokak_eylem_sohbet(eylem_id, id desc);
alter table public.sokak_eylem_sohbet enable row level security;
revoke all on public.sokak_eylem_sohbet from public, anon, authenticated;

create or replace function oyun.sokak_sohbet_uye(e bigint) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from oyun.sokak_eylem_destek d
  where d.eylem_id=e and d.destekci_tur='oyuncu' and d.destek_turu='katilim'
    and d.taraf='muhalefet' and d.temsilci=(select auth.uid()))
$$;
revoke all on function oyun.sokak_sohbet_uye(bigint) from public, anon;
grant execute on function oyun.sokak_sohbet_uye(bigint) to authenticated;

drop policy if exists sokak_sohbet_oku on public.sokak_eylem_sohbet;
drop policy if exists sokak_sohbet_yaz on public.sokak_eylem_sohbet;
create policy sokak_sohbet_oku on public.sokak_eylem_sohbet for select to authenticated
 using (oyun.sokak_sohbet_uye(eylem_id));
create policy sokak_sohbet_yaz on public.sokak_eylem_sohbet for insert to authenticated
 with check (user_id=(select auth.uid()) and oyun.sokak_sohbet_uye(eylem_id));
grant select, insert on public.sokak_eylem_sohbet to authenticated;

do $$ begin
 if exists (select 1 from pg_publication where pubname='supabase_realtime')
    and not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='sokak_eylem_sohbet') then
  alter publication supabase_realtime add table public.sokak_eylem_sohbet;
 end if;
end $$;

-- Sinyal anahtarı eylem:<id>. Metin taşımaz. Yalnız katılımcı görür.
do $$ begin
 if to_regclass('public.canli_sinyal') is not null then
  alter table public.canli_sinyal drop constraint if exists canli_sinyal_anahtar_bicim;
  alter table public.canli_sinyal add constraint canli_sinyal_anahtar_bicim
   check (anahtar ~ '^(sohbet|kutu|miting|secim|yayin|muzayede|kursu|eylem):[A-Za-z0-9_.:-]{1,72}$');
 end if;
end $$;

create or replace function oyun.canli_sinyal(p_anahtar text) returns void
language plpgsql security definer set search_path='' as $$
declare k text := left(btrim(coalesce(p_anahtar, '')), 80);
begin
 if to_regclass('public.canli_sinyal') is null then return; end if;
 if k !~ '^(sohbet|kutu|miting|secim|yayin|muzayede|kursu|eylem):[A-Za-z0-9_.:-]{1,72}$' then return; end if;
 if current_setting('oyun.csig_' || md5(k), true) = '1' then return; end if;
 perform set_config('oyun.csig_' || md5(k), '1', true);
 insert into public.canli_sinyal(anahtar, rev, zaman) values (k, 1, now())
  on conflict (anahtar) do update set rev = public.canli_sinyal.rev + 1, zaman = now();
end $$;

create or replace function oyun.canli_sinyal_gorur(p_anahtar text) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare p oyun.profiller; kod text; eid bigint;
begin
 if auth.uid() is null or p_anahtar is null then return false; end if;
 if p_anahtar like 'kutu:%' then return p_anahtar = 'kutu:' || (select auth.uid())::text; end if;
 if p_anahtar ~ '^(miting|secim|yayin|muzayede|kursu):' then return true; end if;
 if p_anahtar like 'eylem:%' then
  begin eid := substr(p_anahtar, 7)::bigint; exception when others then return false; end;
  return oyun.sokak_sohbet_uye(eid);
 end if;
 if p_anahtar like 'sohbet:%' then
  select * into p from oyun.profiller where id = (select auth.uid());
  if p.id is null then return false; end if;
  kod := substr(p_anahtar, 8);
  return exists (
   select 1 from unnest(array['genel','il','belediye','parti','yonetim','ittifak','meclis','grup','divan','kabine']::text[]) c
   where oyun.kanal_coz(p, c) = kod);
 end if;
 return false;
end $$;

-- ───────────── ortak kayıtlar ─────────────
create table if not exists oyun.sokak_denetim(
 id bigint generated always as identity primary key,
 eylem_id bigint, user_id uuid, tur text not null, hedef uuid,
 metin text, zaman timestamptz not null
);
alter table oyun.sokak_denetim enable row level security;
revoke all on oyun.sokak_denetim from public, anon, authenticated;

create table if not exists oyun.sokak_itibar(
 user_id uuid primary key references oyun.profiller,
 puan integer not null default 0
);
alter table oyun.sokak_itibar enable row level security;
revoke all on oyun.sokak_itibar from public, anon, authenticated;

create table if not exists oyun.sokak_meydan_etki(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 tur text not null, puan numeric not null, bitis timestamptz not null
);
alter table oyun.sokak_meydan_etki enable row level security;
revoke all on oyun.sokak_meydan_etki from public, anon, authenticated;

create table if not exists oyun.sokak_manset(
 id bigint generated always as identity primary key,
 metin text not null, bitis timestamptz not null, zaman timestamptz not null
);
alter table oyun.sokak_manset enable row level security;
revoke all on oyun.sokak_manset from public, anon, authenticated;

create or replace function oyun.sokak_meydan_puan(e bigint) returns numeric
language sql stable set search_path='' as $$
 select coalesce(sum(puan),0) from oyun.sokak_meydan_etki where eylem_id=e and bitis>oyun.simdi()
$$;

create or replace function oyun.sokak_log(e bigint, u uuid, tur text, hedef uuid, metin text) returns void
language sql set search_path='' as $$
 insert into oyun.sokak_denetim(eylem_id,user_id,tur,hedef,metin,zaman)
 values (e,u,tur,hedef,left(coalesce(metin,''),500),oyun.simdi())
$$;

create or replace function oyun.sokak_temiz(m text, n int) returns text
language plpgsql set search_path='' as $$
begin
 m := btrim(regexp_replace(coalesce(m,''), '\s+', ' ', 'g'));
 if char_length(m) < 1 or char_length(m) > n then raise exception 'Metin 1–% karakter olmalı', n; end if;
 if oyun.kufurlu(m) then raise exception 'Metinde uygunsuz bir ifade var. Hakaret ve küfür yasaktır.'; end if;
 return m;
end $$;

create or replace function oyun.sokak_katilimci(e bigint, u uuid) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_eylem_destek d where d.eylem_id=e and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet' and d.temsilci=u)
$$;

create or replace function oyun.sokak_kad_bul(k text) returns uuid
language sql stable set search_path='' as $$
 select id from oyun.profiller where lower(kad)=lower(btrim(coalesce(k,''))) and not yasakli limit 1
$$;

create or replace function oyun.sokak_manset_yaz(m text) returns void
language sql set search_path='' as $$
 insert into oyun.sokak_manset(metin,bitis,zaman) values (left(m,240), oyun.simdi()+interval '2 hours', oyun.simdi())
$$;

-- ───────────── muhbir ─────────────
create table if not exists oyun.sokak_muhbir(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 user_id uuid not null references oyun.profiller,
 kuran uuid not null references oyun.profiller,
 tur text not null check(tur in ('teklif','dikme')),
 para numeric not null default 0 check(para>=0 and para<=80000),
 makam_sozu text,
 durum text not null check(durum in ('bekliyor','kabul','ret','ifsa','aciga_cikti')),
 suphe numeric not null default 0,
 uyari_zamani timestamptz, uyari_gitti boolean not null default false,
 zaman timestamptz not null, karar_zamani timestamptz
);
create unique index if not exists sokak_muhbir_tek on oyun.sokak_muhbir(eylem_id,user_id) where durum in ('bekliyor','kabul');
create table if not exists oyun.sokak_muhbir_sizinti(
 id bigint generated always as identity primary key,
 muhbir_id bigint not null references oyun.sokak_muhbir,
 eylem_id bigint not null, metin text not null, zaman timestamptz not null, suphe numeric not null
);
create table if not exists oyun.sokak_muhbir_oy(
 eylem_id bigint not null, gun date not null, supheli uuid not null, veren uuid not null,
 zaman timestamptz not null, primary key(eylem_id,gun,veren)
);
create table if not exists oyun.sokak_oy_yok(
 user_id uuid not null, eylem_id bigint not null, bitis timestamptz not null, primary key(user_id,eylem_id)
);
alter table oyun.sokak_muhbir enable row level security;
alter table oyun.sokak_muhbir_sizinti enable row level security;
alter table oyun.sokak_muhbir_oy enable row level security;
alter table oyun.sokak_oy_yok enable row level security;
revoke all on oyun.sokak_muhbir, oyun.sokak_muhbir_sizinti, oyun.sokak_muhbir_oy, oyun.sokak_oy_yok from public, anon, authenticated;

-- ───────────── diğer meydan tabloları ─────────────
create table if not exists oyun.sokak_son_gece(
 eylem_id bigint primary key references oyun.sokak_eylem,
 bas timestamptz not null, bit timestamptz not null,
 durum text not null check(durum in ('hazir','canli','bitti')), sonuc text
);
create table if not exists oyun.sokak_belge(
 id bigint generated always as identity primary key,
 eylem_id bigint not null, tur text not null, metin text not null,
 yazan uuid not null, zaman timestamptz not null,
 sizan uuid, gazeteci uuid, yayinlandi timestamptz, sorusturma text
);
create table if not exists oyun.sokak_kirmizi_hat(
 id bigint generated always as identity primary key,
 eylem_id bigint not null, yapan uuid not null,
 teklif text not null check(teklif in ('bakanlik','yatirim','af')),
 metin text not null, durum text not null default 'bekliyor' check(durum in ('bekliyor','kabul','ret','ifsa')),
 zaman timestamptz not null
);
create table if not exists oyun.sokak_boykot(
 id bigint generated always as identity primary key,
 eylem_id bigint not null, sirket_id bigint not null, il_id integer not null,
 acan uuid not null, taraf text check(taraf in ('destekliyorum','tarafsizim','hukumetin_yanindayim')),
 zaman timestamptz not null
);
create table if not exists oyun.sokak_boykot_soz(
 boykot_id bigint not null references oyun.sokak_boykot, user_id uuid not null, zaman timestamptz not null,
 primary key(boykot_id,user_id)
);
create table if not exists oyun.sokak_musteri(
 sirket_id bigint not null, il_id integer not null, puan numeric not null default 100,
 primary key(sirket_id,il_id)
);
create table if not exists oyun.sokak_basin(
 id bigint generated always as identity primary key,
 eylem_id bigint not null, user_id uuid not null, metin text not null, zaman timestamptz not null,
 guvenilir integer not null default 0, tarafli integer not null default 0
);
create table if not exists oyun.sokak_basin_oy(
 not_id bigint not null references oyun.sokak_basin, user_id uuid not null, oy text not null,
 primary key(not_id,user_id)
);
create table if not exists oyun.sokak_basin_koruma(
 user_id uuid not null, eylem_id bigint not null, bitis timestamptz not null, primary key(user_id,eylem_id)
);
create table if not exists oyun.sokak_basin_tiraj(
 user_id uuid primary key, puan integer not null default 0
);
create table if not exists oyun.sokak_juri(
 eylem_id bigint primary key, durum text not null check(durum in ('savunma','oy','bitti')),
 bitis timestamptz not null, sonuc text
);
create table if not exists oyun.sokak_juri_uye(
 eylem_id bigint not null, user_id uuid not null, oy text, primary key(eylem_id,user_id)
);
create table if not exists oyun.sokak_juri_soz(
 id bigint generated always as identity primary key,
 eylem_id bigint not null, taraf text not null, metin text not null, zaman timestamptz not null
);
create table if not exists oyun.sokak_kabine_oy(
 id bigint generated always as identity primary key,
 eylem_id bigint, metin text not null, acilis timestamptz not null, aciklama timestamptz not null,
 evet integer not null default 0, hayir integer not null default 0, aciklandi boolean not null default false
);
create table if not exists oyun.sokak_kabine_kisi(
 oy_id bigint not null references oyun.sokak_kabine_oy, user_id uuid not null, oy text not null,
 primary key(oy_id,user_id)
);
create table if not exists oyun.sokak_sicil(
 id bigint generated always as identity primary key,
 user_id uuid not null, eylem_id bigint, tur text not null, ozet text not null, zaman timestamptz not null
);
create table if not exists oyun.sokak_hafiza(
 eylem_id bigint primary key, il_id integer, ad text, slogan text, ozet text, sonuc text,
 zaman timestamptz not null, anma date
);
create table if not exists oyun.sokak_hafiza_oy(
 eylem_id bigint not null, user_id uuid not null, ad text not null, primary key(eylem_id,user_id)
);
create table if not exists oyun.sokak_rozet(
 user_id uuid not null, eylem_id bigint not null, primary key(user_id,eylem_id)
);
create table if not exists oyun.sokak_mesale(
 id bigint generated always as identity primary key,
 kaynak_il integer not null, hedef_il integer not null, eylem_id bigint,
 varis timestamptz not null, durum text not null check(durum in ('yolda','ulasti','kirildi'))
);
create table if not exists oyun.sokak_mektup(
 id bigint generated always as identity primary key,
 eylem_id bigint not null, yazar uuid not null, metin text not null, zaman timestamptz not null,
 aciga uuid
);
create table if not exists oyun.sokak_meclis_hak(
 id integer primary key check(id=1), bitis timestamptz, neden text
);
insert into oyun.sokak_meclis_hak(id) values(1) on conflict do nothing;
create table if not exists oyun.sokak_gensoru(
 id bigint generated always as identity primary key,
 acan uuid not null, gerekce text not null, bas timestamptz not null, bit timestamptz not null,
 durum text not null default 'oylamada'
);
create table if not exists oyun.sokak_gensoru_oy(
 gensoru_id bigint not null references oyun.sokak_gensoru, user_id uuid not null, oy text not null,
 primary key(gensoru_id,user_id)
);
do $$ declare t text; begin
 foreach t in array array['sokak_son_gece','sokak_belge','sokak_kirmizi_hat','sokak_boykot','sokak_boykot_soz','sokak_musteri','sokak_basin','sokak_basin_oy','sokak_basin_koruma','sokak_basin_tiraj','sokak_juri','sokak_juri_uye','sokak_juri_soz','sokak_kabine_oy','sokak_kabine_kisi','sokak_sicil','sokak_hafiza','sokak_hafiza_oy','sokak_rozet','sokak_mesale','sokak_mektup','sokak_meclis_hak','sokak_gensoru','sokak_gensoru_oy'] loop
  execute format('alter table oyun.%I enable row level security', t);
  execute format('revoke all on oyun.%I from public, anon, authenticated', t);
 end loop;
end $$;

create or replace function oyun.sokak_sert_iz(e bigint, u uuid, tur text, metin text) returns void
language plpgsql set search_path='' as $$
declare t timestamptz:=oyun.simdi();
begin
 insert into oyun.sokak_belge(eylem_id,tur,metin,yazan,zaman) values(e,tur,left(metin,500),u,t);
 insert into oyun.sokak_kabine_oy(eylem_id,metin,acilis,aciklama) values(e,left(tur||': '||metin,400),t,t+interval '7 days');
 perform oyun.sokak_log(e,u,'sert_karar',null,tur);
end $$;

create or replace function oyun.sokak_sicil_yaz(u uuid, e bigint, tur text, ozet text) returns void
language sql set search_path='' as $$
 insert into oyun.sokak_sicil(user_id,eylem_id,tur,ozet,zaman) values(u,e,tur,left(ozet,200),oyun.simdi())
$$;

-- ───────────── sohbet RPC ─────────────
create or replace function public.sokak_sohbet_oku(p_eylem bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if not oyun.sokak_katilimci(p_eylem,u) then raise exception 'Bu sohbet yalnız eylemin içindeki oyunculara açık'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',oyun.kad(s.user_id),'metin',s.metin,'zaman',s.zaman,'ben',s.user_id=u) order by s.id)
  from (select * from public.sokak_eylem_sohbet where eylem_id=p_eylem order by id desc limit 40) s), '[]'::jsonb);
end $$;

create or replace function public.sokak_sohbet_yaz(p_eylem bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; t timestamptz:=oyun.simdi(); m text; x oyun.sokak_eylem;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into p from oyun.profiller where id=u;
 if p.susturma_bitis is not null and p.susturma_bitis>t then raise exception 'Hesabın mesaj yasağında'; end if;
 if not oyun.sokak_katilimci(p_eylem,u) then raise exception 'Bu sohbet yalnız eylemin içindeki oyunculara açık'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem;
 if x.durum<>'aktif' or x.bitis<=t then raise exception 'Eylem bitmiş'; end if;
 if exists(select 1 from oyun.sokak_gozalti g where g.eylem_id=p_eylem and g.hedef=u and g.durum='aktif' and g.bitis>t) then
  raise exception 'Gözaltındayken eylem sohbetine yazamazsın'; end if;
 m:=oyun.sokak_temiz(p_metin,400);
 if exists(select 1 from public.sokak_eylem_sohbet where eylem_id=p_eylem and user_id=u and zaman>t-interval '5 seconds') then
  raise exception 'Biraz bekle, ardından yaz'; end if;
 if (select count(*) from public.sokak_eylem_sohbet where user_id=u and zaman>t-interval '1 day')>=80 then
  raise exception 'Bugünkü eylem sohbeti sınırın doldu'; end if;
 insert into public.sokak_eylem_sohbet(eylem_id,user_id,metin,zaman) values(p_eylem,u,m,t);
 perform oyun.canli_sinyal('eylem:'||p_eylem::text);
 return jsonb_build_object('tamam',true);
end $$;

-- ───────────── işlemler ─────────────
create or replace function public.sokak_meydan_islem(p_eylem bigint, p_islem text, p_veri jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); me oyun.profiller; x oyun.sokak_eylem; t timestamptz:=oyun.simdi();
 h uuid; mtext text; para numeric; n integer; evet integer; mid bigint; hedef uuid; dogru boolean;
 yazi text; il integer; sid bigint; jid bigint; bid bigint; oid bigint; gid bigint;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into me from oyun.profiller where id=u;
 if me.yasakli then raise exception 'Hesabın kısıtlı'; end if;
 if p_eylem is not null then
  select * into x from oyun.sokak_eylem where id=p_eylem for update;
 end if;
 mtext := nullif(btrim(coalesce(p_veri->>'metin','')),'');

 if p_islem='muhbir_teklif' then
  if x.id is null or x.durum<>'aktif' then raise exception 'Aktif eylem gerekli'; end if;
  if not oyun.sokak_yonetebilir(u) then raise exception 'Teklifi Cumhurbaşkanı veya İçişleri Bakanı yapar'; end if;
  h:=oyun.sokak_kad_bul(p_veri->>'kad');
  if h is null or not oyun.sokak_katilimci(x.id,h) then raise exception 'Teklif yalnız eylemin içindeki bir oyuncuya gider'; end if;
  if h=u then raise exception 'Kendine teklif edemezsin'; end if;
  para:=coalesce((p_veri->>'para')::numeric,0);
  if para<0 or para>80000 or para<>round(para,2) then raise exception 'Para 0 ile 80.000 TL arasında olmalı'; end if;
  if mtext is not null then mtext:=oyun.sokak_temiz(mtext,120); end if;
  if exists(select 1 from oyun.sokak_muhbir where eylem_id=x.id and user_id=h and durum in ('bekliyor','kabul')) then raise exception 'Bu oyuncunun açık bir muhbir kaydı var'; end if;
  insert into oyun.sokak_muhbir(eylem_id,user_id,kuran,tur,para,makam_sozu,durum,zaman)
   values(x.id,h,u,'teklif',para,mtext,'bekliyor',t);
  perform oyun.bildir(h,'Sana gizli bir muhbir teklifi var. Yalnız sen görürsün. Halk Hareketleri ekranından kabul, ret ya da ifşa edebilirsin.');
  perform oyun.sokak_log(x.id,u,'muhbir_teklif',h,'para='||para);
  return jsonb_build_object('tamam',true);

 elsif p_islem='muhbir_yanit' then
  if x.id is null then raise exception 'Eylem gerekli'; end if;
  update oyun.sokak_muhbir set durum=case when coalesce((p_veri->>'kabul')::boolean,false) then 'kabul' when coalesce((p_veri->>'ifsa')::boolean,false) then 'ifsa' else 'ret' end,
    karar_zamani=t, uyari_zamani=case when coalesce((p_veri->>'kabul')::boolean,false) then t+interval '3 hours' end
   where eylem_id=x.id and user_id=u and durum='bekliyor' returning id, para, makam_sozu, kuran into mid, para, mtext, h;
  if mid is null then raise exception 'Bekleyen gizli teklifin yok'; end if;
  if coalesce((p_veri->>'kabul')::boolean,false) then
   if para>0 then
    n:=round(para)::int;
    perform oyun.bm_kasa_harca('icisleri',n/oyun.pazar_tl_milyar(),'gider','Muhbir anlaşması eylem #'||x.id);
    update oyun.cuzdan c set para=c.para+n where c.user_id=u;
    insert into oyun.hesap_hareket(user_id,zaman,tutar,vergi,tur,aciklama) values(u,t,n,0,'gelir','Gizli anlaşma, eylem #'||x.id);
   end if;
   perform oyun.sokak_log(x.id,u,'muhbir_kabul',h,null);
  elsif coalesce((p_veri->>'ifsa')::boolean,false) then
   perform oyun.sokak_duyur(x.id,'İFŞA: '||oyun.kad(u)||' gizli teklifi açıkladı. Teklif eden: '||oyun.kad(h)||'. Para: '||para||' TL. Vaat: '||coalesce(mtext,'yok')||'.');
   perform oyun.sokak_manset_yaz('İFŞA: gizli teklif açığa çıktı');
   perform oyun.sokak_log(x.id,u,'muhbir_ifsa',h,null);
  else
   perform oyun.sokak_log(x.id,u,'muhbir_ret',h,null);
  end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='muhbir_dik' then
  if x.id is null or x.durum<>'aktif' then raise exception 'Aktif eylem gerekli'; end if;
  if not oyun.sokak_yonetebilir(u) then raise exception 'Yalnız Cumhurbaşkanı veya İçişleri Bakanı'; end if;
  h:=oyun.sokak_kad_bul(p_veri->>'kad');
  if h is null or not oyun.sokak_katilimci(x.id,h) or not oyun.sokak_iktidar(h) then raise exception 'Dikilecek kişi hem eyleme katılmış hem iktidar saflarından olmalı'; end if;
  if exists(select 1 from oyun.sokak_muhbir where eylem_id=x.id and user_id=h and durum in ('bekliyor','kabul')) then raise exception 'Bu oyuncunun kaydı var'; end if;
  insert into oyun.sokak_muhbir(eylem_id,user_id,kuran,tur,durum,uyari_zamani,zaman,karar_zamani)
   values(x.id,h,u,'dikme','kabul',t+interval '3 hours',t,t);
  perform oyun.bildir(h,'Hükümet seni bu eylemde içeriden bilgi verecek kişi olarak işaretledi. Sohbette görünüşün değişmez.');
  perform oyun.sokak_log(x.id,u,'muhbir_dikme',h,null);
  return jsonb_build_object('tamam',true);

 elsif p_islem='muhbir_sizdir' then
  if x.id is null then raise exception 'Eylem gerekli'; end if;
  select id, suphe into mid, para from oyun.sokak_muhbir where eylem_id=x.id and user_id=u and durum='kabul' for update;
  if mid is null then raise exception 'İçeriden bilgi yalnız kabul edilmiş muhbirden gelir'; end if;
  mtext:=oyun.sokak_temiz(mtext,400);
  para:=para+18;
  update oyun.sokak_muhbir set suphe=para where id=mid;
  insert into oyun.sokak_muhbir_sizinti(muhbir_id,eylem_id,metin,zaman,suphe) values(mid,x.id,mtext,t,para);
  if para>=36 and para<54 then perform oyun.sokak_duyur(x.id,'Sızıntı şüphesi yükseldi. İsim yok.'); end if;
  if para>=72 and para<90 then perform oyun.sokak_duyur(x.id,'Bir katılımcının hareketleri sızıntıya benziyor. İsim hâlâ yok.'); end if;
  perform oyun.sokak_log(x.id,u,'sizinti',null,left(mtext,120));
  return jsonb_build_object('tamam',true,'suphe',para);

 elsif p_islem='muhbir_oy' then
  if x.id is null or x.durum<>'aktif' then raise exception 'Aktif eylem gerekli'; end if;
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'İfşa oyu yalnız katılımcıya açık'; end if;
  if exists(select 1 from oyun.sokak_oy_yok where user_id=u and eylem_id=x.id and bitis>t) then raise exception 'Yanlış ifşadan sonra bir gün oy kullanamazsın'; end if;
  h:=oyun.sokak_kad_bul(p_veri->>'kad');
  if h is null or not oyun.sokak_katilimci(x.id,h) then raise exception 'Şüpheli eylemin içinde olmalı'; end if;
  if h=u then raise exception 'Kendini ifşa oylamasına koyamazsın'; end if;
  begin
   insert into oyun.sokak_muhbir_oy(eylem_id,gun,supheli,veren,zaman)
    values(x.id,(t at time zone 'Europe/Istanbul')::date,h,u,t);
  exception when unique_violation then raise exception 'Bugünkü ifşa oyunu kullandın'; end;
  select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=x.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet';
  select count(*) into evet from oyun.sokak_muhbir_oy where eylem_id=x.id and gun=(t at time zone 'Europe/Istanbul')::date and supheli=h;
  if evet>=3 and evet*2>n then
   dogru:=exists(select 1 from oyun.sokak_muhbir where eylem_id=x.id and user_id=h and durum='kabul');
   if dogru then
    update oyun.sokak_muhbir set durum='aciga_cikti', karar_zamani=t where eylem_id=x.id and user_id=h and durum='kabul';
    delete from oyun.sokak_eylem_destek where eylem_id=x.id and destekci_tur='oyuncu' and destekci_id=h::text and destek_turu='katilim';
    insert into oyun.sokak_itibar(user_id,puan) values(h,-20) on conflict(user_id) do update set puan=oyun.sokak_itibar.puan-20;
    update oyun.ulke set memnuniyet=greatest(0,memnuniyet-2) where id=1;
    insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'muhbir',8,t+interval '12 hours');
    perform oyun.sokak_duyur(x.id,'Muhbir açığa çıktı: '||oyun.kad(h)||'. Eylemden çıkarıldı. Hükümetin itibarı sarsıldı.');
    perform oyun.sokak_sicil_yaz(h,x.id,'muhbir','Muhbir olarak açığa çıktı');
   else
    perform oyun.bm_kasa_harca('icisleri',10000/oyun.pazar_tl_milyar(),'gider','Yanlış ifşa tazminatı eylem #'||x.id);
    update oyun.cuzdan set para=para+10000 where user_id=h;
    insert into oyun.hesap_hareket(user_id,zaman,tutar,vergi,tur,aciklama) values(h,t,10000,0,'gelir','Yanlış ifşa tazminatı');
    insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'yanlis_ifsa',-4,t+interval '6 hours');
    insert into oyun.sokak_oy_yok(user_id,eylem_id,bitis)
     select veren,x.id,t+interval '24 hours' from oyun.sokak_muhbir_oy
      where eylem_id=x.id and gun=(t at time zone 'Europe/Istanbul')::date and supheli=h
     on conflict(user_id,eylem_id) do update set bitis=excluded.bitis;
    perform oyun.sokak_duyur(x.id,'Yanlış ifşa: '||oyun.kad(h)||' masum çıktı. Tazminat ödendi, oy verenler bir gün oy kullanamaz.');
   end if;
   perform oyun.sokak_log(x.id,u,'ifsa_sonuc',h,case when dogru then 'dogru' else 'yanlis' end);
   perform oyun.sokak_yenile(x.id);
  end if;
  return jsonb_build_object('tamam',true,'oy',evet,'gerek',greatest(3,n/2+1));

 elsif p_islem='kirmizi_hat' then
  if x.id is null or x.durum<>'aktif' then raise exception 'Aktif eylem gerekli'; end if;
  if not exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='cb') then raise exception 'Kırmızı hattı Cumhurbaşkanı açar'; end if;
  if coalesce(p_veri->>'tur','') not in ('bakanlik','yatirim','af') then raise exception 'Teklif: bakanlık, yatırım ya da af'; end if;
  mtext:=oyun.sokak_temiz(mtext,400);
  if exists(select 1 from oyun.sokak_kirmizi_hat where eylem_id=x.id and durum='bekliyor') then raise exception 'Açık bir kırmızı hat var'; end if;
  insert into oyun.sokak_kirmizi_hat(eylem_id,yapan,teklif,metin,zaman) values(x.id,u,p_veri->>'tur',mtext,t);
  perform oyun.bildir(x.baslatan,'Cumhurbaşkanından sana gizli bir kırmızı hat teklifi var. Yalnız sen görürsün.');
  perform oyun.sokak_log(x.id,u,'kirmizi_hat',x.baslatan,p_veri->>'tur');
  return jsonb_build_object('tamam',true);

 elsif p_islem='kirmizi_yanit' then
  if x.baslatan is distinct from u then raise exception 'Kırmızı hattı organizatör yanıtlar'; end if;
  if coalesce(p_veri->>'yanit','') not in ('kabul','ret','ifsa') then raise exception 'Yanıt kabul, ret ya da ifşa olmalı'; end if;
  update oyun.sokak_kirmizi_hat set durum=p_veri->>'yanit' where eylem_id=x.id and durum='bekliyor' returning id, metin, teklif into mid, mtext, yazi;
  if mid is null then raise exception 'Açık kırmızı hat yok'; end if;
  if p_veri->>'yanit'='kabul' then
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'kirmizi_hat',-12,t+interval '12 hours');
   perform oyun.bildir(u,'Teklifi gizlice kabul ettin. Meydan 12 saat yumuşar. Duyuru yapılmadı.');
   perform oyun.sokak_sicil_yaz(u,x.id,'anlasma','Kırmızı hat teklifini gizlice kabul etti');
  elsif p_veri->>'yanit'='ifsa' then
   perform oyun.sokak_duyur(x.id,'KIRMIZI HAT İFŞA: Cumhurbaşkanı '||yazi||' teklif etti. '||left(mtext,200));
   perform oyun.sokak_manset_yaz('Kırmızı hat teklifi ifşa edildi');
  end if;
  perform oyun.sokak_yenile(x.id);
  perform oyun.sokak_log(x.id,u,'kirmizi_yanit',null,p_veri->>'yanit');
  return jsonb_build_object('tamam',true);

 elsif p_islem='boykot_ac' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Boykotu katılımcı açar'; end if;
  sid:=(p_veri->>'sirket')::bigint;
  if sid is null or not exists(select 1 from oyun.sirketler s where s.id=sid and s.aktif) then raise exception 'Şirket bulunamadı'; end if;
  if exists(select 1 from oyun.sokak_boykot where eylem_id=x.id and sirket_id=sid) then raise exception 'Bu şirket zaten boykotta'; end if;
  insert into oyun.sokak_boykot(eylem_id,sirket_id,il_id,acan,zaman) values(x.id,sid,x.il_id,u,t) returning id into bid;
  insert into oyun.sokak_musteri(sirket_id,il_id) values(sid,x.il_id) on conflict do nothing;
  h:=oyun.sirket_sahibi(sid);
  if h is not null then perform oyun.bildir(h,'Şirketin bir eylemde boykot listesine alındı. Destekliyorum, tarafsızım ya da hükümetin yanındayım demen bekleniyor.'); end if;
  perform oyun.sokak_log(x.id,u,'boykot',null,sid::text);
  return jsonb_build_object('tamam',true,'id',bid);

 elsif p_islem='boykot_soz' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Söz katılımcıdan gelir'; end if;
  bid:=(p_veri->>'id')::bigint;
  insert into oyun.sokak_boykot_soz(boykot_id,user_id,zaman) values(bid,u,t);
  update oyun.sokak_musteri m set puan=greatest(40,m.puan-4)
   from oyun.sokak_boykot b where b.id=bid and m.sirket_id=b.sirket_id and m.il_id=b.il_id;
  return jsonb_build_object('tamam',true);

 elsif p_islem='boykot_taraf' then
  if coalesce(p_veri->>'taraf','') not in ('destekliyorum','tarafsizim','hukumetin_yanindayim') then raise exception 'Taraf seç'; end if;
  bid:=(p_veri->>'id')::bigint;
  if oyun.sirket_sahibi((select sirket_id from oyun.sokak_boykot where id=bid)) is distinct from u then raise exception 'Bu açıklamayı şirket sahibi yapar'; end if;
  update oyun.sokak_boykot set taraf=p_veri->>'taraf' where id=bid returning eylem_id into p_eylem;
  perform oyun.sokak_duyur(p_eylem,'Şirket sahibi açıkladı: '||p_veri->>'taraf'||'.');
  if p_veri->>'taraf'='destekliyorum' then
   update oyun.sokak_musteri m set puan=least(100,m.puan+8) from oyun.sokak_boykot b where b.id=bid and m.sirket_id=b.sirket_id and m.il_id=b.il_id;
  end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='basin_yaz' then
  if x.id is null or x.durum<>'aktif' then raise exception 'Aktif eylem gerekli'; end if;
  if not oyun.sokak_gazeteci(u) then raise exception 'Sahadan bağlanan kişi gazeteci olmalı'; end if;
  if exists(select 1 from oyun.sokak_gozalti g where g.hedef=u and g.durum='aktif' and g.bitis>t) then raise exception 'Gözaltındaki gazeteci yayın yapamaz'; end if;
  mtext:=oyun.sokak_temiz(mtext,500);
  insert into oyun.sokak_basin(eylem_id,user_id,metin,zaman) values(x.id,u,mtext,t);
  insert into oyun.sokak_basin_koruma(user_id,eylem_id,bitis) values(u,x.id,t+interval '6 hours')
   on conflict(user_id,eylem_id) do update set bitis=excluded.bitis;
  insert into oyun.sokak_basin_tiraj(user_id,puan) values(u,1) on conflict(user_id) do update set puan=oyun.sokak_basin_tiraj.puan+1;
  perform oyun.sokak_duyur(x.id,'SAHADAN: '||oyun.kad(u)||' canlı bağlandı.');
  return jsonb_build_object('tamam',true);

 elsif p_islem='basin_oy' then
  if coalesce(p_veri->>'oy','') not in ('guvenilir','tarafli') then raise exception 'Oy güvenilir ya da taraflı olmalı'; end if;
  jid:=(p_veri->>'id')::bigint;
  if exists(select 1 from oyun.sokak_basin where id=jid and user_id=u) then raise exception 'Kendi haberine oy veremezsin'; end if;
  insert into oyun.sokak_basin_oy(not_id,user_id,oy) values(jid,u,p_veri->>'oy');
  update oyun.sokak_basin set guvenilir=guvenilir+case when p_veri->>'oy'='guvenilir' then 1 else 0 end,
    tarafli=tarafli+case when p_veri->>'oy'='tarafli' then 1 else 0 end where id=jid;
  return jsonb_build_object('tamam',true);

 elsif p_islem='juri_baslat' then
  if x.seviye<60 then raise exception 'Halk jürisi kriz eşiğine yaklaşınca kurulur'; end if;
  if exists(select 1 from oyun.sokak_juri where eylem_id=x.id) then raise exception 'Bu eylemde jüri zaten kuruldu'; end if;
  insert into oyun.sokak_juri(eylem_id,durum,bitis) values(x.id,'savunma',t+interval '6 hours');
  insert into oyun.sokak_juri_uye(eylem_id,user_id)
   select x.id, p.id from oyun.profiller p
    where not p.yasakli and p.olusturma<t-interval '3 days' and p.son_gorulme>t-interval '7 days'
     and not oyun.sokak_katilimci(x.id,p.id) and not oyun.sokak_yonetebilir(p.id) and not oyun.sokak_iktidar(p.id)
    order by random() limit 9;
  get diagnostics n=row_count;
  if n<3 then
   delete from oyun.sokak_juri where eylem_id=x.id;
   raise exception 'Tarafsız jüri için en az 3 uygun oyuncu gerekir (şu an %)', n;
  end if;
  perform oyun.sokak_duyur(x.id,'Halk jürisi kuruldu: '||n||' tarafsız oyuncu. İki taraf 3 kısa söz yazabilir.');
  return jsonb_build_object('tamam',true,'juri',n);

 elsif p_islem='juri_savun' then
  if not exists(select 1 from oyun.sokak_juri where eylem_id=x.id and durum='savunma') then raise exception 'Savunma sırası kapalı'; end if;
  yazi:=case when oyun.sokak_yonetebilir(u) then 'hukumet' when u=x.baslatan then 'meydan' end;
  if yazi is null then raise exception 'Sözü hükümet ya da organizatör yazar'; end if;
  if (select count(*) from oyun.sokak_juri_soz where eylem_id=x.id and taraf=yazi)>=3 then raise exception 'Bu taraf 3 sözünü kullandı'; end if;
  mtext:=oyun.sokak_temiz(mtext,180);
  insert into oyun.sokak_juri_soz(eylem_id,taraf,metin,zaman) values(x.id,yazi,mtext,t);
  return jsonb_build_object('tamam',true);

 elsif p_islem='juri_oy' then
  if coalesce(p_veri->>'oy','') not in ('meydan','hukumet') then raise exception 'Oy meydan ya da hükümet olmalı'; end if;
  update oyun.sokak_juri_uye set oy=p_veri->>'oy' where eylem_id=x.id and user_id=u and oy is null;
  if not found then raise exception 'Jüri üyesinin tek oyu vardır'; end if;
  if not exists(select 1 from oyun.sokak_juri_uye where eylem_id=x.id and oy is null) then
   select count(*) filter(where oy='meydan'), count(*) filter(where oy='hukumet') into evet, n from oyun.sokak_juri_uye where eylem_id=x.id;
   yazi:=case when evet>=n then 'meydan' else 'hukumet' end;
   update oyun.sokak_juri set durum='bitti', sonuc=yazi where eylem_id=x.id;
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'juri',case when yazi='meydan' then 10 else -10 end,t+interval '12 hours');
   if yazi='meydan' then update oyun.ulke set memnuniyet=greatest(0,memnuniyet-1) where id=1;
   else update oyun.ulke set memnuniyet=least(100,memnuniyet+1) where id=1; end if;
   perform oyun.sokak_duyur(x.id,'Halk jürisi kararını verdi: '||case when yazi='meydan' then 'meydan haklı' else 'hükümet haklı' end||'.');
   perform oyun.sokak_yenile(x.id);
  end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='belge_sizdir' then
  bid:=(p_veri->>'id')::bigint;
  h:=oyun.sokak_kad_bul(p_veri->>'kad');
  if not (oyun.sokak_yonetebilir(u) or exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='bakan')) then raise exception 'Belgeyi kabine üyesi sızdırır'; end if;
  if h is null or not oyun.sokak_gazeteci(h) then raise exception 'Belge bir gazeteciye gider'; end if;
  update oyun.sokak_belge set sizan=u, gazeteci=h, yayinlandi=t where id=bid and yayinlandi is null returning eylem_id, metin, tur into p_eylem, mtext, yazi;
  if p_eylem is null then raise exception 'Sızdırılacak iç not yok'; end if;
  perform oyun.sokak_duyur(p_eylem,'BELGE: '||yazi||' — '||left(mtext,220)||' (yayımlayan '||oyun.kad(h)||')');
  perform oyun.sokak_manset_yaz('BELGE: kabine notu yayımlandı');
  insert into oyun.sokak_basin_tiraj(user_id,puan) values(h,3) on conflict(user_id) do update set puan=oyun.sokak_basin_tiraj.puan+3;
  perform oyun.sokak_log(p_eylem,u,'belge_sizinti',h,yazi);
  return jsonb_build_object('tamam',true);

 elsif p_islem='belge_sorustur' then
  if not exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='cb') then raise exception 'Soruşturmayı Cumhurbaşkanı açar'; end if;
  bid:=(p_veri->>'id')::bigint;
  h:=oyun.sokak_kad_bul(p_veri->>'kad');
  select sizan, eylem_id into hedef, p_eylem from oyun.sokak_belge where id=bid and yayinlandi is not null;
  if hedef is null then raise exception 'Yayımlanmış belge yok'; end if;
  dogru:=hedef=h;
  update oyun.sokak_belge set sorusturma=case when dogru then 'tespit' else 'yanlis' end where id=bid;
  if dogru then
   update oyun.makamlar set bit=t, bitis_neden='belge sizintisi' where user_id=h and bit is null and tur in ('bakan','mv','tbmm','bskv','grup_bskv');
   perform oyun.sokak_duyur(p_eylem,'Sızıntı soruşturması: '||oyun.kad(h)||' tespit edildi ve görevinden alındı.');
   perform oyun.adliye_notu(u,h,p_eylem);
  else
   update oyun.ulke set memnuniyet=greatest(0,memnuniyet-1) where id=1;
   perform oyun.bildir(h,'Cumhurbaşkanı seni belge sızıntısıyla suçladı. Suçlama tutmadı.');
   perform oyun.sokak_duyur(p_eylem,'Sızıntı suçlaması '||oyun.kad(h)||' için tutmadı.');
  end if;
  perform oyun.sokak_log(p_eylem,u,'belge_sorusturma',h,case when dogru then 'tuttu' else 'tutmadi' end);
  return jsonb_build_object('tamam',true,'tuttu',dogru);

 elsif p_islem='meclis_gec' then
  if x.id is null or x.durum<>'aktif' then raise exception 'Aktif eylem gerekli'; end if;
  if not exists(select 1 from oyun.makamlar where user_id=u and tur='mv' and bit is null) or not oyun.sokak_iktidar(u) then
   raise exception 'Geçişi iktidar partisinden bir milletvekili yapar'; end if;
  update oyun.profiller set parti_id=null, parti_at=t where id=u;
  if not oyun.sokak_katilimci(x.id,u) then
   insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destekci_id,taraf,temsilci) values(x.id,'oyuncu',u::text,'muhalefet',u);
  end if;
  perform oyun.sokak_sicil_yaz(u,x.id,'saf','Mecliste iktidar sırasında meydana geçti');
  perform oyun.sokak_manset_yaz(oyun.kad(u)||' iktidar sırasında ayrılıp meydana geçti');
  perform oyun.sokak_duyur(x.id,oyun.kad(u)||' milletvekilliği duruyor, partiden ayrıldı. Sandalyesi bağımsız renge döndü.');
  select count(*) into n from oyun.makamlar m join oyun.profiller p on p.id=m.user_id
   where m.tur='mv' and m.bit is null and not p.yasakli and p.parti_id=(select parti_id from oyun.profiller where id=(select user_id from oyun.makamlar where tur='cb' and bit is null limit 1));
  if n < oyun.salt_cogunluk() then
   update oyun.sokak_meclis_hak set bitis=t+interval '24 hours', neden='Çoğunluk kaybedildi' where id=1;
   perform oyun.sokak_duyur(x.id,'İktidar meclis çoğunluğunu kaybetti. Muhalefetin 24 saatlik gensoru hakkı açıldı.');
  end if;
  perform oyun.sokak_yenile(x.id);
  return jsonb_build_object('tamam',true,'iktidar_vekil',n);

 elsif p_islem='gensoru_ac' then
  if not exists(select 1 from oyun.sokak_meclis_hak where id=1 and bitis>t) then raise exception 'Gensoru penceresi kapalı'; end if;
  if not exists(select 1 from oyun.makamlar where user_id=u and tur='mv' and bit is null) or oyun.sokak_iktidar(u) then raise exception 'Önergeyi muhalefet vekili verir'; end if;
  if exists(select 1 from oyun.sokak_gensoru where durum='oylamada') then raise exception 'Açık bir gensoru var'; end if;
  mtext:=oyun.sokak_temiz(mtext,500);
  insert into oyun.sokak_gensoru(acan,gerekce,bas,bit) values(u,mtext,t,t+interval '12 hours') returning id into gid;
  perform oyun.sokak_manset_yaz('Muhalefet gensoru açtı');
  return jsonb_build_object('tamam',true,'id',gid);

 elsif p_islem='gensoru_oy' then
  if coalesce(p_veri->>'oy','') not in ('kabul','ret') then raise exception 'Oy kabul ya da ret'; end if;
  gid:=(p_veri->>'id')::bigint;
  if not exists(select 1 from oyun.makamlar where user_id=u and tur='mv' and bit is null) then raise exception 'Yalnız milletvekili oy kullanır'; end if;
  insert into oyun.sokak_gensoru_oy(gensoru_id,user_id,oy) values(gid,u,p_veri->>'oy');
  select count(*) filter(where oy='kabul') into evet from oyun.sokak_gensoru_oy where gensoru_id=gid;
  if evet>=oyun.salt_cogunluk() then
   update oyun.sokak_gensoru set durum='kabul' where id=gid and durum='oylamada';
   update oyun.ulke set memnuniyet=greatest(0,memnuniyet-4) where id=1;
   perform oyun.sokak_manset_yaz('Gensoru kabul edildi. Hükümetin memnuniyeti düştü.');
  end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='istifa' then
  if not exists(select 1 from oyun.makamlar where user_id=u and tur='bakan' and bit is null) then raise exception 'İstifa mektubunu bakan yazar'; end if;
  mtext:=oyun.sokak_temiz(mtext,400);
  update oyun.makamlar set bit=t, bitis_neden='istifa mektubu' where user_id=u and tur='bakan' and bit is null;
  perform oyun.sokak_manset_yaz('İSTİFA: '||oyun.kad(u)||' — '||left(mtext,140));
  perform oyun.olay('siyaset','Bakan '||oyun.kad(u)||' istifa etti: '||left(mtext,180));
  perform oyun.sokak_log(p_eylem,u,'istifa',null,mtext);
  return jsonb_build_object('tamam',true);

 elsif p_islem='kabine_oy' then
  if not (oyun.sokak_yonetebilir(u) or exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='bakan')) then raise exception 'Kabine oyu bakanlara ve Cumhurbaşkanına açık'; end if;
  oid:=(p_veri->>'id')::bigint;
  if coalesce(p_veri->>'oy','') not in ('evet','hayir') then raise exception 'Oy evet ya da hayır'; end if;
  if exists(select 1 from oyun.sokak_kabine_oy where id=oid and aciklandi) then raise exception 'Bu oy açıklanmış'; end if;
  insert into oyun.sokak_kabine_kisi(oy_id,user_id,oy) values(oid,u,p_veri->>'oy');
  update oyun.sokak_kabine_oy set evet=(select count(*) from oyun.sokak_kabine_kisi where oy_id=oid and oy='evet'),
    hayir=(select count(*) from oyun.sokak_kabine_kisi where oy_id=oid and oy='hayir') where id=oid;
  return jsonb_build_object('tamam',true);

 elsif p_islem='hafiza_oy' then
  if not exists(select 1 from oyun.sokak_rozet where eylem_id=p_eylem and user_id=u) then raise exception 'Adı orada bulunanlar koyar'; end if;
  mtext:=oyun.sokak_temiz(p_veri->>'ad',40);
  insert into oyun.sokak_hafiza_oy(eylem_id,user_id,ad) values(p_eylem,u,mtext)
   on conflict(eylem_id,user_id) do update set ad=excluded.ad;
  update oyun.sokak_hafiza h set ad=q.ad from (
   select ad from oyun.sokak_hafiza_oy where eylem_id=p_eylem group by ad order by count(*) desc, ad limit 1) q
   where h.eylem_id=p_eylem;
  return jsonb_build_object('tamam',true);

 elsif p_islem='mesale_gonder' then
  if not exists(select 1 from oyun.sokak_hafiza where eylem_id=p_eylem and sonuc in ('anlasma','kirmizi')) then raise exception 'Meşale başarılı bir eylemden çıkar'; end if;
  if x.baslatan is distinct from u and not exists(select 1 from oyun.sokak_rozet where eylem_id=p_eylem and user_id=u) then raise exception 'Meşaleyi eylemin insanları taşır'; end if;
  il:=(p_veri->>'il')::integer;
  if il is null or il not between 1 and 81 or il=(select il_id from oyun.sokak_hafiza where eylem_id=p_eylem) then raise exception 'Başka bir il seç'; end if;
  if exists(select 1 from oyun.sokak_eylem e where e.il_id=il and e.durum='aktif' and e.bitis>t) then raise exception 'O ilde zaten eylem var'; end if;
  if exists(select 1 from oyun.sokak_mesale where eylem_id=p_eylem and durum='yolda') then raise exception 'Meşale yolda'; end if;
  insert into oyun.sokak_mesale(kaynak_il,hedef_il,eylem_id,varis,durum)
   values((select il_id from oyun.sokak_hafiza where eylem_id=p_eylem),il,p_eylem,t+interval '12 hours','yolda');
  perform oyun.sokak_duyur(p_eylem,'Meşale başka bir ile doğru yola çıktı. Hükümet talep karşılanırsa zinciri kesebilir.');
  return jsonb_build_object('tamam',true);

 elsif p_islem='mesale_kir' then
  if not oyun.sokak_yonetebilir(u) then raise exception 'Zinciri hükümet keser'; end if;
  mid:=(p_veri->>'id')::bigint;
  select hedef_il, eylem_id into il, p_eylem from oyun.sokak_mesale where id=mid and durum='yolda' for update;
  if il is null then raise exception 'Yolda meşale yok'; end if;
  perform oyun.bm_kasa_harca('icisleri',(select baslatma_bedeli*3 from oyun.sokak_eylem_ayar where id=1)/oyun.pazar_tl_milyar(),'gider','Meşale zinciri kesildi');
  perform oyun.sokak_talep_kismi(p_eylem);
  update oyun.sokak_mesale set durum='kirildi' where id=mid;
  perform oyun.sokak_duyur(p_eylem,'Hükümet talebi kısmen karşıladı. Meşale zinciri kırıldı.');
  return jsonb_build_object('tamam',true);

 elsif p_islem='mektup_yaz' then
  if x.id is null or x.durum<>'aktif' then raise exception 'Aktif eylem gerekli'; end if;
  if not oyun.sokak_iktidar(u) then raise exception 'Mektup iktidar saflarından yazılır'; end if;
  if exists(select 1 from oyun.partiler where gb=u and id=me.parti_id) then raise exception 'Parti lideri bu mektubu imzasız bırakamaz'; end if;
  if exists(select 1 from oyun.sokak_mektup where eylem_id=x.id and yazar=u) then raise exception 'Bu eylemde bir mektubun var'; end if;
  mtext:=oyun.sokak_temiz(mtext,400);
  insert into oyun.sokak_mektup(eylem_id,yazar,metin,zaman) values(x.id,u,mtext,t);
  perform oyun.sokak_duyur(x.id,'Gizli mektup: "iktidar saflarından bir isim" meydanı desteklediğini yazdı.');
  perform oyun.sokak_log(x.id,u,'mektup',null,left(mtext,80));
  return jsonb_build_object('tamam',true);

 elsif p_islem='mektup_sor' then
  if not exists(select 1 from oyun.partiler where gb=u and not kapali) or not oyun.sokak_iktidar(u) then raise exception 'Soruşturmayı iktidar partisinin genel başkanı açar'; end if;
  mid:=(p_veri->>'id')::bigint;
  h:=oyun.sokak_kad_bul(p_veri->>'kad');
  select yazar, eylem_id into hedef, p_eylem from oyun.sokak_mektup where id=mid and aciga is null;
  if hedef is null then raise exception 'Açık mektup kalmadı'; end if;
  dogru:=hedef=h;
  if dogru then
   update oyun.sokak_mektup set aciga=h where id=mid;
   insert into oyun.sokak_itibar(user_id,puan) values(h,-10) on conflict(user_id) do update set puan=oyun.sokak_itibar.puan-10;
   perform oyun.sokak_duyur(p_eylem,'Mektubun sahibi bulundu: '||oyun.kad(h)||'.');
  else
   update oyun.partiler set kasa=kasa-20000 where id=me.parti_id and kasa>=20000;
   if not found then raise exception 'Yanlış soruşturma için parti kasasında 20.000 TL gerekir'; end if;
   insert into oyun.parti_hareket(parti_id,zaman,tutar,tur,aciklama) values(me.parti_id,t,-20000,'gider','Yanlış mektup soruşturması');
   perform oyun.bildir(h,'Parti lideri seni gizli mektupla suçladı. Suçlama tutmadı.');
  end if;
  perform oyun.sokak_log(p_eylem,u,'mektup_sorusturma',h,case when dogru then 'tuttu' else 'tutmadi' end);
  return jsonb_build_object('tamam',true,'tuttu',dogru);

 else raise exception 'Bilinmeyen meydan işlemi'; end if;
end $$;

-- Adliye notu: mevcut dava kapısını zorlamadan dosyaya düşen kısa kayıt.
create or replace function oyun.adliye_notu(p_cb uuid, p_supheli uuid, p_eylem bigint) returns void
language plpgsql set search_path='' as $$
begin
 insert into oyun.sokak_denetim(eylem_id,user_id,tur,hedef,metin,zaman)
  values(p_eylem,p_cb,'adliye_notu',p_supheli,'Belge sızıntısı için Adliye kaydı açıldı. Cumhurbaşkanı şüpheliyi görevden aldı.',oyun.simdi());
 perform oyun.bildir(p_supheli,'Belge sızıntısı Adliye kaydına geçti ve görevin sona erdi.');
end $$;

-- ───────────── tick ─────────────
create or replace function oyun.sokak_meydan_tick() returns void
language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi(); r record; bas timestamptz; gun date; n integer; evet integer; sid text; ad text; yazi text;
begin
 gun:=(t at time zone 'Europe/Istanbul')::date;
 for r in select * from oyun.sokak_muhbir where durum='kabul' and not uyari_gitti and uyari_zamani is not null and uyari_zamani<=t loop
  update oyun.sokak_muhbir set uyari_gitti=true where id=r.id;
  perform oyun.sokak_duyur(r.eylem_id,'Eylem alanında bir muhbir var!');
 end loop;
 for r in select e.id, e.seviye, e.il_id from oyun.sokak_eylem e
   where e.durum='aktif' and e.bitis>t and e.seviye>=60
    and not exists(select 1 from oyun.sokak_son_gece s where s.eylem_id=e.id) loop
  bas:=oyun.tr_an(gun,21,0);
  if bas<=t+interval '20 minutes' then bas:=oyun.tr_an(gun+1,21,0); end if;
  insert into oyun.sokak_son_gece(eylem_id,bas,bit,durum) values(r.id,bas,bas+interval '60 minutes','hazir');
  perform oyun.sokak_duyur(r.id,'Meydanda son gece '||to_char(bas at time zone 'Europe/Istanbul','DD.MM HH24:MI')||' için ilan edildi.');
 end loop;
 update oyun.sokak_son_gece set durum='canli' where durum='hazir' and bas<=t and bit>t;
 update oyun.sokak_son_gece s set durum='bitti', sonuc=case when e.seviye>=75 then 'Kırmızıda kapandı' else 'Kırmızıya varmadan bitti' end
  from oyun.sokak_eylem e where s.eylem_id=e.id and s.durum in ('hazir','canli') and s.bit<=t;
 for r in select * from oyun.sokak_kabine_oy where not aciklandi and aciklama<=t loop
  update oyun.sokak_kabine_oy set aciklandi=true where id=r.id;
  perform oyun.olay('siyaset','Bir hafta önce saklanan kabine oyu açıklandı. Evet '||r.evet||', hayır '||r.hayir||'.',null,null);
  perform oyun.sokak_manset_yaz('Kabine oyu açıklandı: evet '||r.evet||', hayır '||r.hayir);
 end loop;
 for r in select * from oyun.sokak_mesale where durum='yolda' and varis<=t loop
  update oyun.sokak_mesale set durum='ulasti' where id=r.id;
  perform oyun.olay('siyaset','Meşale hedef ile vardı. Yeni eylem, o ilin parti liderinin kararıdır.',r.hedef_il,null);
 end loop;
 for r in select id, il_id, durum, baslatan, gerekce, seviye from oyun.sokak_eylem
   where durum in ('bitti','yatisti') and kapandi>t-interval '15 minutes'
    and not exists(select 1 from oyun.sokak_hafiza h where h.eylem_id=oyun.sokak_eylem.id) loop
  select metin into sid from public.sokak_eylem_sohbet where eylem_id=r.id order by id desc limit 1;
  ad:=case when r.durum='yatisti' then 'anlasma' when r.seviye>=75 then 'kirmizi' else 'dagildi' end;
  insert into oyun.sokak_hafiza(eylem_id,il_id,slogan,ozet,sonuc,zaman,anma)
   values(r.id,r.il_id,left(coalesce(sid,r.gerekce),120),left(r.gerekce,200),ad,t,(gun+7));
  insert into oyun.sokak_rozet(user_id,eylem_id)
   select distinct d.temsilci, r.id from oyun.sokak_eylem_destek d
    where d.eylem_id=r.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet'
   on conflict do nothing;
  insert into oyun.sokak_sicil(user_id,eylem_id,tur,ozet,zaman)
   select distinct d.temsilci,r.id,'sahada','Eylemde bulundu',t from oyun.sokak_eylem_destek d
    where d.eylem_id=r.id and d.taraf='muhalefet' and d.destek_turu='katilim' and d.destekci_tur='oyuncu';
 end loop;
 for r in select * from oyun.sokak_hafiza where anma=gun and ad is not null loop
  insert into oyun.bildirimler(user_id,zaman,metin)
   select z.user_id, t, 'Oradaydın: '||coalesce(r.ad,'bir eylem')||' anılıyor.'
   from oyun.sokak_rozet z where z.eylem_id=r.eylem_id;
  update oyun.sokak_hafiza set anma=anma+interval '358 days' where eylem_id=r.eylem_id and anma=gun;
 end loop;
 for r in select * from oyun.sokak_juri where durum='savunma' and bitis<=t loop
  update oyun.sokak_juri set durum='oy', bitis=t+interval '6 hours' where eylem_id=r.eylem_id;
 end loop;
 for r in select * from oyun.sokak_juri where durum='oy' and bitis<=t loop
  select count(*) filter(where oy='meydan'), count(*) filter(where oy='hukumet') into evet, n from oyun.sokak_juri_uye where eylem_id=r.eylem_id;
  yazi:=case when evet>=n then 'meydan' else 'hukumet' end;
  update oyun.sokak_juri set durum='bitti', sonuc=yazi where eylem_id=r.eylem_id;
  insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(r.eylem_id,'juri',case when yazi='meydan' then 10 else -10 end,t+interval '12 hours');
 end loop;
 for r in select * from oyun.sokak_gensoru where durum='oylamada' and bit<=t loop
  select count(*) filter(where oy='kabul') into evet from oyun.sokak_gensoru_oy where gensoru_id=r.id;
  update oyun.sokak_gensoru set durum=case when evet>=oyun.salt_cogunluk() then 'kabul' else 'ret' end where id=r.id;
  if evet>=oyun.salt_cogunluk() then update oyun.ulke set memnuniyet=greatest(0,memnuniyet-4) where id=1; end if;
 end loop;
end $$;

-- ───────────── panel ve harita ─────────────
create or replace function public.sokak_meydan_panel() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); yonet boolean; kabine boolean; arr jsonb;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 yonet:=oyun.sokak_yonetebilir(u);
 kabine:=yonet or exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='bakan');
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',e.id,'il_id',e.il_id,'baslatan',e.baslatan=u,'katilimci',oyun.sokak_katilimci(e.id,u),
  'seviye',e.seviye,
  'sohbet_hak',oyun.sokak_katilimci(e.id,u),
  'muhbir_teklif',case when yonet then null else (select jsonb_build_object('para',m.para,'makam',m.makam_sozu,'durum',m.durum) from oyun.sokak_muhbir m where m.eylem_id=e.id and m.user_id=u and m.durum='bekliyor') end,
  'muhbirim',exists(select 1 from oyun.sokak_muhbir m where m.eylem_id=e.id and m.user_id=u and m.durum='kabul'),
  'iceri',case when yonet then coalesce((select jsonb_agg(jsonb_build_object('ad',oyun.kad(m.user_id),'metin',s.metin,'zaman',s.zaman) order by s.zaman desc)
     from oyun.sokak_muhbir_sizinti s join oyun.sokak_muhbir m on m.id=s.muhbir_id where s.eylem_id=e.id),'[]'::jsonb) end,
  'kirmizi_hat',case when e.baslatan=u or yonet then (select jsonb_build_object('id',k.id,'teklif',k.teklif,'metin',k.metin,'durum',k.durum) from oyun.sokak_kirmizi_hat k where k.eylem_id=e.id order by k.zaman desc limit 1) end,
  'son_gece',(select jsonb_build_object('bas',s.bas,'bit',s.bit,'durum',s.durum,'sonuc',s.sonuc) from oyun.sokak_son_gece s where s.eylem_id=e.id),
  'basin',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'ad',oyun.kad(b.user_id),'metin',b.metin,'guvenilir',b.guvenilir,'tarafli',b.tarafli,'zaman',b.zaman) order by b.zaman desc) from (select * from oyun.sokak_basin b where b.eylem_id=e.id order by b.zaman desc limit 8) b),'[]'::jsonb),
  'juri',(select jsonb_build_object('durum',j.durum,'bitis',j.bitis,'sonuc',j.sonuc,'uyeyim',exists(select 1 from oyun.sokak_juri_uye y where y.eylem_id=e.id and y.user_id=u),
     'sozler',coalesce((select jsonb_agg(jsonb_build_object('taraf',z.taraf,'metin',z.metin)) from oyun.sokak_juri_soz z where z.eylem_id=e.id),'[]'::jsonb))
    from oyun.sokak_juri j where j.eylem_id=e.id),
  'boykot',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'sirket',b.sirket_id,'taraf',b.taraf,'soz',(select count(*) from oyun.sokak_boykot_soz s where s.boykot_id=b.id),
     'musteri',(select puan from oyun.sokak_musteri m where m.sirket_id=b.sirket_id and m.il_id=b.il_id))) from oyun.sokak_boykot b where b.eylem_id=e.id),'[]'::jsonb),
  'belgeler',case when kabine or yonet then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'tur',b.tur,'metin',b.metin,'yayin',b.yayinlandi is not null,'sorusturma',b.sorusturma) order by b.zaman desc) from oyun.sokak_belge b where b.eylem_id=e.id),'[]'::jsonb) end,
  'mektuplar',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'metin',m.metin,'sahip',case when m.aciga is not null then oyun.kad(m.aciga) else 'iktidar saflarından bir isim' end)) from oyun.sokak_mektup m where m.eylem_id=e.id),'[]'::jsonb)
 ) order by e.id), '[]'::jsonb) into arr
 from oyun.sokak_eylem e where e.durum='aktif' and e.bitis>t;
 return jsonb_build_object('tamam',true,'yonetebilir',yonet,'kabine',kabine,'gazeteci',oyun.sokak_gazeteci(u),
  'iktidar',oyun.sokak_iktidar(u),'vekil',exists(select 1 from oyun.makamlar where user_id=u and tur='mv' and bit is null),
  'bakan',exists(select 1 from oyun.makamlar where user_id=u and tur='bakan' and bit is null),
  'itibar',coalesce((select puan from oyun.sokak_itibar where user_id=u),0),
  'manset',coalesce((select jsonb_agg(metin order by zaman desc) from oyun.sokak_manset where bitis>t),'[]'::jsonb),
  'meclis_hak',(select bitis from oyun.sokak_meclis_hak where id=1 and bitis>t),
  'kabine_gizli',case when kabine then coalesce((select jsonb_agg(jsonb_build_object('id',k.id,'metin',k.metin,'aciklama',k.aciklama,'evet',k.evet,'hayir',k.hayir) order by k.acilis desc) from oyun.sokak_kabine_oy k where not k.aciklandi),'[]'::jsonb) end,
  'hafiza',coalesce((select jsonb_agg(jsonb_build_object('eylem',h.eylem_id,'ad',coalesce(h.ad,'adsız meydan'),'slogan',h.slogan,'sonuc',h.sonuc,'zaman',h.zaman,'oradaydim',exists(select 1 from oyun.sokak_rozet z where z.eylem_id=h.eylem_id and z.user_id=u)) order by h.zaman desc) from (select * from oyun.sokak_hafiza order by zaman desc limit 12) h),'[]'::jsonb),
  'mesale',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'kaynak',m.kaynak_il,'hedef',m.hedef_il,'durum',m.durum,'varis',m.varis)) from oyun.sokak_mesale m where m.durum in ('yolda','ulasti') and m.varis>t-interval '2 days'),'[]'::jsonb),
  'pusula',coalesce((select jsonb_build_object('sahada',count(*) filter(where tur='sahada'),'yasak',count(*) filter(where tur='yasak'),'anlasma',count(*) filter(where tur='anlasma'),'saf',count(*) filter(where tur='saf'),'muhbir',count(*) filter(where tur='muhbir')) from oyun.sokak_sicil where user_id=u),'{}'::jsonb),
  'eylemler',arr);
end $$;

-- yonetici logu ayrı, panel fonksiyonundaki değişken hatasını önlemek için düzeltme aşağıda
create or replace function public.sokak_kriz_harita() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 return jsonb_build_object(
  'iller', coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad,'memnuniyetsizlik',oyun.sokak_memnuniyetsizlik(i.id),
     'eylem',e.id,'seviye',e.seviye,'mesale',exists(select 1 from oyun.sokak_mesale m where m.durum='yolda' and (m.kaynak_il=i.id or m.hedef_il=i.id))) order by i.id)
    from oyun.iller i left join oyun.sokak_eylem e on e.il_id=i.id and e.durum='aktif' and e.bitis>oyun.simdi()),'[]'::jsonb),
  'serit', coalesce((select jsonb_agg(metin order by zaman desc) from (select metin, zaman from oyun.olaylar where tur in ('siyaset','ekonomi') order by zaman desc limit 8) q),'[]'::jsonb),
  'manset', coalesce((select jsonb_agg(metin order by zaman desc) from oyun.sokak_manset where bitis>oyun.simdi()),'[]'::jsonb));
end $$;

-- Paneldeki denetim alanını yönetici için dolduran sade sürüm: fonksiyonu baştan yazmak yerine ikinci çağrı.
create or replace function public.sokak_denetim_oku() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not coalesce((select yonetici from oyun.profiller where id=u),false) then return '[]'::jsonb; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('zaman',d.zaman,'tur',d.tur,'yapan',oyun.kad(d.user_id),'hedef',oyun.kad(d.hedef),'metin',d.metin) order by d.zaman desc)
  from (select * from oyun.sokak_denetim order by zaman desc limit 40) d),'[]'::jsonb);
end $$;

-- Güç dökümü ve sert karar bağları
do $$
declare s text;
begin
 s:=pg_get_functiondef('oyun.sokak_saha_dokum(bigint)'::regprocedure);
 if position('sokak_meydan_puan' in s)=0 then
  if position('p_heyet+p_yasak+p_jest+p_tedbir)) end;' in s)>0 then
   s:=replace(s,'p_heyet+p_yasak+p_jest+p_tedbir)) end;','p_heyet+p_yasak+p_jest+p_tedbir+oyun.sokak_meydan_puan(e))) end;');
  elsif position('p_heyet+p_yasak+p_jest)) end;' in s)>0 then
   s:=replace(s,'p_heyet+p_yasak+p_jest)) end;','p_heyet+p_yasak+p_jest+oyun.sokak_meydan_puan(e))) end;');
  else raise exception 'Meydan güç dökümü çapası bulunamadı'; end if;
  execute s;
 end if;
 s:=pg_get_functiondef('oyun.sokak_tick()'::regprocedure);
 if position('sokak_meydan_tick' in s)=0 then
  if position('perform oyun.sokak_tedbir_tick();' in s)>0 then
   s:=replace(s,'perform oyun.sokak_tedbir_tick();','perform oyun.sokak_meydan_tick(); perform oyun.sokak_tedbir_tick();');
  elsif position('perform oyun.sokak_soz_tick();' in s)>0 then
   s:=replace(s,'perform oyun.sokak_soz_tick();','perform oyun.sokak_meydan_tick(); perform oyun.sokak_soz_tick();');
  else raise exception 'Meydan tick çapası bulunamadı'; end if;
  execute s;
 end if;
 s:=pg_get_functiondef('public.sokak_hukumet_karar(bigint,text,text,uuid)'::regprocedure);
 if position('sokak_sert_iz' in s)=0 and position('return jsonb_build_object(''tamam'',true,''karar_id'',kid,''bedel'',tut);' in s)>0 then
  s:=replace(s,'return jsonb_build_object(''tamam'',true,''karar_id'',kid,''bedel'',tut);',
   'if p_tur in (''uyari'',''dagitma'',''yaptirim'') then perform oyun.sokak_sert_iz(x.id,u,p_tur,btrim(p_gerekce)); perform oyun.sokak_sicil_yaz(u,x.id,p_tur,''Sert hükümet kararı''); end if;
 return jsonb_build_object(''tamam'',true,''karar_id'',kid,''bedel'',tut);');
  execute s;
 end if;
end $$;

-- Polis sorgusundaki parantezi güvenli kur. Önceki replace hatalıysa fonksiyonu derlemeden bırakmamak için ayrı kontrol.
do $$
declare s text;
begin
 s:=pg_get_functiondef('public.sokak_polis_gonder(bigint,text,text)'::regprocedure);
 if position('sokak_basin_koruma' in s)=0 then
  if position('and not exists(select 1 from oyun.sokak_gozalti g2 where g2.hedef=p.id and g2.baslangic>t-interval ''24 hours'')' in s)=0 then
   raise exception 'Polis koruma çapası bulunamadı'; end if;
  s:=replace(s,'and not exists(select 1 from oyun.sokak_gozalti g2 where g2.hedef=p.id and g2.baslangic>t-interval ''24 hours'')',
   'and not exists(select 1 from oyun.sokak_gozalti g2 where g2.hedef=p.id and g2.baslangic>t-interval ''24 hours'') and not exists(select 1 from oyun.sokak_basin_koruma bk where bk.user_id=p.id and bk.eylem_id=x.id and bk.bitis>t)');
  execute s;
 end if;
 if position('sokak_sert_iz' in s)=0 and position('p_seviye=''yuksek''' in s)=0 then
  null;
 end if;
end $$;

revoke all on function oyun.sokak_meydan_puan(bigint),oyun.sokak_log(bigint,uuid,text,uuid,text),oyun.sokak_temiz(text,integer),
 oyun.sokak_katilimci(bigint,uuid),oyun.sokak_kad_bul(text),oyun.sokak_manset_yaz(text),oyun.sokak_sert_iz(bigint,uuid,text,text),
 oyun.sokak_sicil_yaz(uuid,bigint,text,text),oyun.adliye_notu(uuid,uuid,bigint),oyun.sokak_meydan_tick(),
 public.sokak_sohbet_oku(bigint),public.sokak_sohbet_yaz(bigint,text),public.sokak_meydan_islem(bigint,text,jsonb),
 public.sokak_meydan_panel(),public.sokak_kriz_harita(),public.sokak_denetim_oku()
 from public, anon, authenticated;
grant execute on function public.sokak_sohbet_oku(bigint),public.sokak_sohbet_yaz(bigint,text),
 public.sokak_meydan_islem(bigint,text,jsonb),public.sokak_meydan_panel(),public.sokak_kriz_harita(),public.sokak_denetim_oku()
 to authenticated;
