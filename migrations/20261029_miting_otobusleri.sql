-- 29.10.2026 -- Uygulanan Supabase miting otobusu ozelliginin kaynak migration kopyasi
-- Mevcut mitingler, oyuncular, yetkiler ve partiler korunur.
create table if not exists oyun.miting_otobus (
 id bigint generated always as identity primary key,
 miting_id bigint not null references oyun.mitingler(id) on delete cascade,
 parti_id bigint not null references oyun.partiler(id) on delete cascade,
 kaynak_il smallint not null references oyun.iller(id),
 adet integer not null default 1 check (adet between 1 and 10),
 kapasite integer not null default 40 check (kapasite = 40),
 ucret numeric not null default 0 check (ucret >= 0),
 olusturma timestamptz not null default now(),
 unique(miting_id,kaynak_il)
);
create table if not exists oyun.miting_otobus_koltuk (
 miting_id bigint not null references oyun.mitingler(id) on delete cascade,
 otobus_id bigint not null references oyun.miting_otobus(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id) on delete cascade,
 zaman timestamptz not null default now(),
 primary key(miting_id,user_id)
);
create index if not exists miting_otobus_koltuk_route on oyun.miting_otobus_koltuk(otobus_id);
alter table oyun.miting_otobus enable row level security;
alter table oyun.miting_otobus_koltuk enable row level security;
create table if not exists oyun.miting_il_konum (
 il_id smallint primary key references oyun.iller(id),
 lat numeric not null, lon numeric not null
);
alter table oyun.miting_il_konum enable row level security;
insert into oyun.miting_il_konum (il_id,lat,lon) values
(1,37.0,35.32),\n(2,37.76,38.28),\n(3,38.76,30.54),\n(4,39.72,43.05),\n(5,40.65,35.83),\n(6,39.93,32.86),\n(7,36.89,30.71),\n(8,41.18,41.82),\n(9,37.85,27.84),\n(10,39.65,27.89),\n(11,40.15,29.98),\n(12,38.89,40.50),\n(13,38.40,42.11),\n(14,40.73,31.61),\n(15,37.72,30.29),\n(16,40.19,29.06),\n(17,40.15,26.41),\n(18,40.60,33.62),\n(19,40.55,34.95),\n(20,37.77,29.09),\n(21,37.91,40.23),\n(22,41.68,26.56),\n(23,38.68,39.23),\n(24,39.75,39.49),\n(25,39.91,41.27),\n(26,39.78,30.52),\n(27,37.06,37.38),\n(28,40.91,38.39),\n(29,40.46,39.48),\n(30,37.57,43.74),\n(31,36.20,36.16),\n(32,37.76,30.55),\n(33,36.81,34.63),\n(34,41.01,28.98),\n(35,38.42,27.14),\n(36,40.60,43.10),\n(37,41.38,33.78),\n(38,38.73,35.49),\n(39,41.73,27.23),\n(40,39.15,34.16),\n(41,40.77,29.92),\n(42,37.87,32.49),\n(43,39.42,29.99),\n(44,38.35,38.31),\n(45,38.62,27.43),\n(46,37.58,36.93),\n(47,37.31,40.74),\n(48,37.21,28.36),\n(49,38.74,41.49),\n(50,38.62,34.71),\n(51,37.97,34.68),\n(52,40.99,37.88),\n(53,41.02,40.52),\n(54,40.76,30.39),\n(55,41.29,36.33),\n(56,37.93,41.94),\n(57,42.03,35.15),\n(58,39.75,37.02),\n(59,40.98,27.52),\n(60,40.31,36.55),\n(61,41.00,39.72),\n(62,39.11,39.55),\n(63,37.16,38.79),\n(64,38.68,29.41),\n(65,38.50,43.38),\n(66,39.82,34.80),\n(67,41.45,31.79),\n(68,38.37,34.03),\n(69,40.26,40.23),\n(70,37.18,33.22),\n(71,39.85,33.52),\n(72,37.88,41.13),\n(73,37.52,42.46),\n(74,41.64,32.34),\n(75,41.11,42.70),\n(76,39.92,44.04),\n(77,40.66,29.28),\n(78,41.20,32.62),\n(79,36.72,37.12),\n(80,37.07,36.25),\n(81,40.84,31.16)
on conflict (il_id) do nothing;

CREATE OR REPLACE FUNCTION public.miting_otobus_bilgi(p_miting bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); m oyun.mitingler; yetki boolean;
begin
 select * into m from oyun.mitingler where id=p_miting;
 if m.id is null then raise exception 'Miting bulunamadı.'; end if;
 yetki := m.tur='parti' and m.parti_id=p.parti_id and oyun.parti_miting_yetki(p.id) is not null;
 return jsonb_build_object(
  'id',m.id,'il',(select ad from oyun.iller where id=m.il_id),'il_id',m.il_id,
  'parti_mitingi',m.tur='parti','yetkili',yetki,'benim_ilim',p.il_id,
  'simdi',oyun.simdi(),'bas',m.bas,'bit',m.bit,
  'kasa',case when yetki then (select kasa from oyun.partiler where id=m.parti_id) end,
  'iller',case when yetki and m.bas>oyun.simdi() then
    (select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad,'ucret',oyun.miting_otobus_ucret(i.id,m.il_id)) order by i.ad),'[]'::jsonb)
     from oyun.iller i where i.id<>m.il_id) end,
  'otobusler',coalesce((select jsonb_agg(jsonb_build_object(
     'id',o.id,'kaynak_il',o.kaynak_il,'kaynak',(select ad from oyun.iller where id=o.kaynak_il),
     'adet',o.adet,'koltuk',o.adet*o.kapasite,
     'dolu',(select count(*) from oyun.miting_otobus_koltuk k where k.otobus_id=o.id),
     'ucret',o.ucret,'benim_otobusum',exists(select 1 from oyun.miting_otobus_koltuk k where k.otobus_id=o.id and k.user_id=p.id)
  ) order by o.id) from oyun.miting_otobus o where o.miting_id=m.id),'[]'::jsonb),
  'rezervasyonum',exists(select 1 from oyun.miting_otobus_koltuk k where k.miting_id=m.id and k.user_id=p.id)
 );
end $function$;

CREATE OR REPLACE FUNCTION public.miting_otobus_kaldir(p_miting bigint, p_kaynak_il integer, p_adet integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); m oyun.mitingler; pa oyun.partiler; t timestamptz:=oyun.simdi();
  onceki integer; birim numeric; tut numeric; kay_ad text; hedef_ad text;
begin
 if p_adet is null or p_adet<1 or p_adet>5 then raise exception 'Tek seferde 1–5 otobüs kaldırabilirsin.'; end if;
 if p_kaynak_il is null or p_kaynak_il<1 or p_kaynak_il>81 then raise exception 'Kalkış ili geçersiz.'; end if;
 select * into m from oyun.mitingler where id=p_miting for update;
 if m.id is null or m.tur<>'parti' or m.parti_id is null then raise exception 'Otobüs yalnız parti mitinglerinde kaldırılabilir.'; end if;
 if t>=m.bas-interval '10 minutes' then raise exception 'Mitinge 10 dakikadan az kaldı; otobüs planlaması kapandı.'; end if;
 if p_kaynak_il=m.il_id then raise exception 'Mitingin yapıldığı il için otobüse gerek yok.'; end if;
 if m.parti_id is distinct from p.parti_id or oyun.parti_miting_yetki(p.id) is null then
   raise exception 'Yalnız parti genel başkanı veya yetkili yardımcısı otobüs kaldırabilir.';
 end if;
 select * into pa from oyun.partiler where id=m.parti_id for update;
 if pa.id is null or pa.kapali then raise exception 'Parti etkin değil.'; end if;
 select adet into onceki from oyun.miting_otobus where miting_id=m.id and kaynak_il=p_kaynak_il;
 if coalesce(onceki,0)+p_adet>10 then raise exception 'Aynı ilden bir mitinge en fazla 10 otobüs kaldırılabilir.'; end if;
 birim:=oyun.miting_otobus_ucret(p_kaynak_il::smallint,m.il_id);
 tut:=birim*p_adet;
 update oyun.partiler set kasa=kasa-tut where id=pa.id and kasa>=tut;
 if not found then raise exception 'Parti kasası yetersiz. % ₺ gerekli, kasada % ₺ var.',tut,pa.kasa; end if;
 insert into oyun.miting_otobus(miting_id,parti_id,kaynak_il,adet,ucret)
 values(m.id,pa.id,p_kaynak_il,p_adet,tut)
 on conflict(miting_id,kaynak_il) do update set adet=oyun.miting_otobus.adet+excluded.adet,ucret=oyun.miting_otobus.ucret+excluded.ucret;
 select ad into kay_ad from oyun.iller where id=p_kaynak_il;
 select ad into hedef_ad from oyun.iller where id=m.il_id;
 insert into oyun.parti_hareket(parti_id,zaman,tutar,aciklama,tur)
 values(pa.id,t,-tut,format('%s → %s mitingi: %s otobüs (40 koltuk/otobüs)',kay_ad,hedef_ad,p_adet),'miting');
 insert into oyun.bildirimler(user_id,zaman,metin)
 select x.id,t,format('%s partisi %s → %s mitingine ücretsiz katılım otobüsü kaldırdı. Miting sayfasından koltuk ayırtabilirsin.',pa.kisa,kay_ad,hedef_ad)
 from oyun.profiller x where x.il_id=p_kaynak_il and not x.yasakli;
 return public.miting_otobus_bilgi(m.id);
end $function$;

CREATE OR REPLACE FUNCTION public.miting_otobus_yer_ayirt(p_miting bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); m oyun.mitingler; b oyun.miting_otobus; dolu integer;
begin
 select * into m from oyun.mitingler where id=p_miting;
 if m.id is null or m.tur<>'parti' then raise exception 'Bu miting için otobüs bulunmuyor.'; end if;
 if oyun.simdi()>=m.bit then raise exception 'Miting sona erdi.'; end if;
 if p.il_id=m.il_id then raise exception 'Aynı ilde yaşıyorsun; doğrudan mitinge katılabilirsin.'; end if;
 select * into b from oyun.miting_otobus where miting_id=m.id and kaynak_il=p.il_id for update;
 if b.id is null then raise exception 'Yaşadığın ilden bu mitinge otobüs kaldırılmamış.'; end if;
 if exists(select 1 from oyun.miting_otobus_koltuk where miting_id=m.id and user_id=p.id) then
   return public.miting_otobus_bilgi(m.id);
 end if;
 select count(*) into dolu from oyun.miting_otobus_koltuk where otobus_id=b.id;
 if dolu>=b.adet*b.kapasite then raise exception 'Bu ilin otobüsleri dolmuş. Partinin yeni otobüs kaldırmasını bekle.'; end if;
 insert into oyun.miting_otobus_koltuk(miting_id,otobus_id,user_id) values (m.id,b.id,p.id);
 perform oyun.bildir(p.id,format('Miting otobüsünde yerin ayrıldı. Miting başladığında %s meydanına katılabilirsin.',(select ad from oyun.iller where id=m.il_id)),oyun.simdi());
 return public.miting_otobus_bilgi(m.id);
end $function$;

CREATE OR REPLACE FUNCTION oyun.miting_otobus_ucret(p_kaynak smallint, p_hedef smallint)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare x oyun.miting_il_konum; y oyun.miting_il_konum; km numeric;
begin
 select * into x from oyun.miting_il_konum where il_id=p_kaynak;
 select * into y from oyun.miting_il_konum where il_id=p_hedef;
 if x.il_id is null or y.il_id is null then raise exception 'Ulaşım tarifesi bulunamadı.'; end if;
 if p_kaynak=p_hedef then return 0; end if;
 km := 1.28 * 6371 * acos(least(1,greatest(-1,
 sin(radians(x.lat::double precision))*sin(radians(y.lat::double precision))+
 cos(radians(x.lat::double precision))*cos(radians(y.lat::double precision))*
 cos(radians((x.lon-y.lon)::double precision)))));
 return ceil((14000 + 25 * km)/1000)*1000;
end $function$;

CREATE OR REPLACE FUNCTION oyun.tg_miting_otobus_iade()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare tut numeric; n text;
begin
 if old.tur='parti' and old.bas>oyun.simdi() then
   select coalesce(sum(ucret),0) into tut from oyun.miting_otobus where miting_id=old.id;
   if tut>0 then
     update oyun.partiler set kasa=kasa+tut where id=old.parti_id;
     select ad into n from oyun.iller where id=old.il_id;
     insert into oyun.parti_hareket(parti_id,zaman,tutar,aciklama,tur)
     values(old.parti_id,oyun.simdi(),tut,format('%s mitingi iptal: otobüs ücretleri iadesi',n),'miting');
   end if;
 end if;
 return old;
end $function$;

-- Var olan katilim ve meydan islevlerini sadece rezervasyonlu yolcular icin genislet.
do $m$
declare d text; eski text;
begin
 d:=pg_get_functiondef('public.miting_katil(bigint)'::regprocedure);
 eski:='if p.il_id <> m.il_id then raise exception ''Yalnızca bu ilde yaşayan oyuncular mitinge katılabilir.''; end if;';
 if position('miting_otobus_koltuk' in d)=0 then
   if position(eski in d)=0 then raise exception 'miting_katil tanimi degismis, elle kontrol gerekiyor'; end if;
   d:=replace(d,eski,'if p.il_id <> m.il_id and not exists (select 1 from oyun.miting_otobus_koltuk k where k.miting_id=m.id and k.user_id=p.id) then raise exception ''Başka ilden katılmak için partinin kaldırdığı otobüste koltuk ayırtmalısın.''; end if;');
   execute d;
 end if;
 d:=pg_get_functiondef('public.miting_meydan(bigint)'::regprocedure);
 eski:='ben.id is not null and ben.il_id = m.il_id and m.user_id <> u';
 if position('miting_otobus_koltuk' in d)=0 then
   if position(eski in d)=0 then raise exception 'miting_meydan tanimi degismis, elle kontrol gerekiyor'; end if;
   d:=replace(d,eski,'ben.id is not null and (ben.il_id = m.il_id or exists (select 1 from oyun.miting_otobus_koltuk k where k.miting_id=m.id and k.user_id=u)) and m.user_id <> u');
   execute d;
 end if;
 d:=pg_get_functiondef('public.mitingler()'::regprocedure);
 eski:='m.il_id = (select il_id from oyun.profiller where id = auth.uid())';
 if position('miting_otobus_koltuk' in d)=0 then
   if position(eski in d)=0 then raise exception 'mitingler tanimi degismis, elle kontrol gerekiyor'; end if;
   d:=replace(d,eski,'(m.il_id = (select il_id from oyun.profiller where id = auth.uid()) or exists (select 1 from oyun.miting_otobus_koltuk k where k.miting_id=m.id and k.user_id=auth.uid()))');
   execute d;
 end if;
end $m$;
drop trigger if exists miting_otobus_iade on oyun.mitingler;
create trigger miting_otobus_iade before delete on oyun.mitingler
for each row execute function oyun.tg_miting_otobus_iade();
revoke all on function public.miting_otobus_bilgi(bigint) from public,anon;
revoke all on function public.miting_otobus_kaldir(bigint,integer,integer) from public,anon;
revoke all on function public.miting_otobus_yer_ayirt(bigint) from public,anon;
grant execute on function public.miting_otobus_bilgi(bigint) to authenticated;
grant execute on function public.miting_otobus_kaldir(bigint,integer,integer) to authenticated;
grant execute on function public.miting_otobus_yer_ayirt(bigint) to authenticated;
