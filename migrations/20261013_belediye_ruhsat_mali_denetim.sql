-- Belediye yatırım ruhsatı / harç tarifeleri / mali disiplin. Eski hesaplara ve yatırımlara dokunmaz.
begin;
create table if not exists oyun.bel_yatirim_tarife (
 il_id smallint not null references oyun.iller(id),
 tur text not null check(tur in ('kur_fabrika','kur_magaza','kur_insaat','kur_sigorta','kur_pazar','arsa_insaat','yeni_proje','sube')),
 oran numeric not null check(oran between 0 and 8),
 taban_tl numeric not null check(taban_tl between 0 and 500000),
 degistiren uuid references oyun.profiller(id),
 degisim timestamptz not null default now(),
 primary key(il_id,tur)
);
create table if not exists oyun.bel_yatirim_ruhsat (
 id bigserial primary key,
 il_id smallint not null references oyun.iller(id),
 tur text not null check(tur in ('kur_fabrika','kur_magaza','kur_insaat','kur_sigorta','kur_pazar','arsa_insaat','yeni_proje','sube')),
 oyuncu uuid not null references oyun.profiller(id),
 sirket_id bigint references oyun.sirketler(id),
 hedef_id bigint,
 sirket_adi text,
 sektor text,
 tahmini_yatirim numeric not null default 0,
 durum text not null default 'bekliyor' check(durum in ('bekliyor','onay','red','kullanildi')),
 basvuru timestamptz not null default now(),
 karar_zamani timestamptz,
 baskan uuid references oyun.profiller(id),
 gerekce text,
 onay_oran numeric,
 onay_taban numeric,
 odenen_tl numeric,
 kullanma timestamptz
);
create index if not exists bel_yatirim_ruhsat_bekleyen on oyun.bel_yatirim_ruhsat(il_id,durum,basvuru);
create index if not exists bel_yatirim_ruhsat_oyuncu on oyun.bel_yatirim_ruhsat(oyuncu,durum);
create table if not exists oyun.bel_mali_gunluk (
 il_id smallint not null references oyun.iller(id),
 gun date not null,
 gelir numeric not null default 0,
 gider numeric not null default 0,
 temel_gelir numeric not null default 0,
 temel_gider numeric not null default 0,
 kasa numeric not null default 0,
 acik numeric not null default 0,
 risk_puani numeric not null default 0,
 ceza_memnuniyet numeric not null default 0,
 ceza_gelisim numeric not null default 0,
 primary key(il_id,gun)
);
alter table oyun.bel_yatirim_tarife enable row level security;
alter table oyun.bel_yatirim_ruhsat enable row level security;
alter table oyun.bel_mali_gunluk enable row level security;
revoke all on oyun.bel_yatirim_tarife,oyun.bel_yatirim_ruhsat,oyun.bel_mali_gunluk from public,anon,authenticated;
revoke all on sequence oyun.bel_yatirim_ruhsat_id_seq from public,anon,authenticated;

create or replace function oyun.bel_ruhsat_oran(p_il smallint,p_tur text)
returns numeric language sql stable set search_path='' as $f$
 select coalesce((select oran from oyun.bel_yatirim_tarife where il_id=p_il and tur=p_tur),
 case p_tur when 'kur_fabrika' then 1.5 when 'kur_insaat' then 1.3
 when 'arsa_insaat' then 1.8 when 'yeni_proje' then 1.8 when 'kur_pazar' then 1.2
 when 'sube' then 1.0 else 1.0 end)
$f$;
create or replace function oyun.bel_ruhsat_taban(p_il smallint,p_tur text)
returns numeric language sql stable set search_path='' as $f$
 select coalesce((select taban_tl from oyun.bel_yatirim_tarife where il_id=p_il and tur=p_tur),
 case p_tur when 'arsa_insaat' then 10000 when 'yeni_proje' then 10000
 when 'kur_fabrika' then 6000 when 'kur_insaat' then 5000 when 'kur_pazar' then 4000
 when 'sube' then 2500 else 3000 end)
$f$;
create or replace function oyun.bel_ruhsat_tutar(p_oran numeric,p_taban numeric,p_yatirim numeric)
returns numeric language sql immutable set search_path='' as $f$
 select least(1000000, greatest(p_taban,round(greatest(0,coalesce(p_yatirim,0))*p_oran/100)))
$f$;

create or replace function public.bel_ruhsat_merkezi()
returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare u uuid:=auth.uid(); v_il smallint; baskan_il smallint; 
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oturum açmalısın.';end if;
 select il_id into baskan_il from oyun.makamlar where user_id=u and tur='bel' and bit is null order by id desc limit 1;
 return jsonb_build_object(
 'baskan_il',baskan_il,
 'iller',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad) order by ad) from oyun.iller),'[]'::jsonb),
 'tarifeler',coalesce((select jsonb_agg(jsonb_build_object('tur',x.tur,'oran',oyun.bel_ruhsat_oran(baskan_il,x.tur),
   'taban_tl',oyun.bel_ruhsat_taban(baskan_il,x.tur),
   'degisim',(select degisim from oyun.bel_yatirim_tarife where il_id=baskan_il and tur=x.tur)) order by x.tur)
   from (values ('kur_fabrika'),('kur_magaza'),('kur_insaat'),('kur_sigorta'),('kur_pazar'),('arsa_insaat'),('yeni_proje'),('sube')) x(tur)
   where baskan_il is not null),'[]'::jsonb),
 'bekleyen',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'tur',r.tur,'il_id',r.il_id,'oyuncu',p.kad,
 'sirket',coalesce(s.ad,r.sirket_adi),'hedef',r.hedef_id,'yatirim',r.tahmini_yatirim,
 'harc_tahmini',oyun.bel_ruhsat_tutar(oyun.bel_ruhsat_oran(r.il_id,r.tur),oyun.bel_ruhsat_taban(r.il_id,r.tur),r.tahmini_yatirim),
 'basvuru',r.basvuru) order by r.id desc)
 from oyun.bel_yatirim_ruhsat r join oyun.profiller p on p.id=r.oyuncu
 left join oyun.sirketler s on s.id=r.sirket_id
 where r.il_id=baskan_il and r.durum='bekliyor'),'[]'::jsonb),
 'benim',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'tur',r.tur,'il_id',r.il_id,'durum',r.durum,
 'sirket',coalesce(s.ad,r.sirket_adi),'hedef',r.hedef_id,'gerekce',r.gerekce,'odenmis',r.odenen_tl,
 'oran',r.onay_oran,'taban',r.onay_taban,'tahmini',r.tahmini_yatirim,'tarih',r.basvuru,
 'karar_zamani',r.karar_zamani) order by r.id desc)
 from (select * from oyun.bel_yatirim_ruhsat where oyuncu=u order by id desc limit 50) r
 left join oyun.sirketler s on s.id=r.sirket_id),'[]'::jsonb),
 'mali',case when baskan_il is null then null else oyun.bel_mali_rapor(baskan_il) end);
end $f$;

create or replace function public.bel_ruhsat_basvur(
 p_tur text,p_il integer,p_sirket bigint default null,p_hedef bigint default null,
 p_ad text default null,p_sektor text default null,p_yatirim numeric default 0)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); v_id bigint; v_il smallint:=p_il::smallint; owner_sirket oyun.sirketler; v_baskan uuid; gercek_il smallint;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oturum açmalısın.';end if;
 if p_tur not in ('kur_fabrika','kur_magaza','kur_insaat','kur_sigorta','kur_pazar','arsa_insaat','yeni_proje','sube') then raise exception 'Ruhsat türü geçersiz.';end if;
 if p_il is null or p_il<1 or p_il>81 or not exists(select 1 from oyun.iller where id=v_il) then raise exception 'İl geçersiz.';end if;
 if p_yatirim is null or p_yatirim<0 or p_yatirim>1000000000 then raise exception 'Yatırım bedeli geçersiz.';end if;
 if p_sirket is not null then
  select * into owner_sirket from oyun.sirketler where id=p_sirket and aktif;
  if owner_sirket.id is null or not oyun.sirket_yonetici_mi(p_sirket,u) then raise exception 'Bu şirketi yönetme yetkin yok.';end if;
 end if;
 if p_tur in ('arsa_insaat','yeni_proje','sube') and p_sirket is null then raise exception 'Mevcut şirket seçmelisin.';end if;
 if p_tur='arsa_insaat' then
  if p_hedef is null or not exists(select 1 from oyun.eko_arsalar a where a.id=p_hedef and a.il_id=v_il and a.sahibi_sirket=p_sirket and a.durum='satildi') then raise exception 'Bu ilde şirkete ait bir arsa seç.';end if;
 elsif p_tur='sube' then
  select y.il_id into gercek_il from oyun.eko_bolumler b join oyun.eko_yapilar y on y.id=b.yapi_id where b.id=p_hedef and b.tur='dukkan';
  if gercek_il is distinct from v_il then raise exception 'Şube dükkânı seçilen ilde değil.';end if;
 elsif p_tur like 'kur_%' and p_sirket is null then
  if char_length(btrim(coalesce(p_ad,''))) not between 3 and 50 then raise exception 'Şirket adını 3-50 karakter yaz.';end if;
  if p_tur='kur_pazar' and (p_sektor is null or not exists(select 1 from oyun.pazar_sektor where kod=p_sektor)) then raise exception 'Geçerli pazar sektörünü seç.';end if;
 end if;
 if exists(select 1 from oyun.bel_yatirim_ruhsat r where r.oyuncu=u and r.il_id=v_il and r.tur=p_tur and r.durum in ('bekliyor','onay')
   and r.sirket_id is not distinct from p_sirket and r.hedef_id is not distinct from p_hedef
   and r.sirket_adi is not distinct from nullif(btrim(p_ad),'') and r.sektor is not distinct from p_sektor
   and (r.durum='bekliyor' or r.karar_zamani>now()-interval '72 hours')) then
  raise exception 'Bu yatırım için bekleyen veya kullanılmamış onaylı ruhsatın zaten var.';end if;
 insert into oyun.bel_yatirim_ruhsat(il_id,tur,oyuncu,sirket_id,hedef_id,sirket_adi,sektor,tahmini_yatirim)
 values(v_il,p_tur,u,p_sirket,p_hedef,nullif(btrim(p_ad),''),nullif(btrim(p_sektor),''),p_yatirim) returning id into v_id;
 select user_id into v_baskan from oyun.makamlar where tur='bel' and il_id=v_il and bit is null order by id desc limit 1;
 if v_baskan is not null then
   perform oyun.bildir(v_baskan,format('Yeni yatırım ruhsatı başvurusu #%s: %s. Ruhsat Merkezi ekranında onay veya ret ver.',v_id,p_tur),oyun.simdi());
 end if;
 return jsonb_build_object('id',v_id,'durum','bekliyor','baskan_var',v_baskan is not null,
 'tahmini_harc',oyun.bel_ruhsat_tutar(oyun.bel_ruhsat_oran(v_il,p_tur),oyun.bel_ruhsat_taban(v_il,p_tur),p_yatirim));
end $f$;

create or replace function public.bel_ruhsat_tarife_ayarla(p_tur text,p_oran numeric,p_taban numeric)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); il smallint; eski timestamptz;
begin
 select il_id into il from oyun.makamlar where tur='bel' and user_id=u and bit is null order by id desc limit 1;
 if il is null then raise exception 'Harçları yalnızca belediye başkanı belirler.';end if;
 if p_tur not in ('kur_fabrika','kur_magaza','kur_insaat','kur_sigorta','kur_pazar','arsa_insaat','yeni_proje','sube') then raise exception 'Tür geçersiz.';end if;
 if p_oran is null or p_oran<0 or p_oran>8 or p_oran<>round(p_oran,2)
 or p_taban is null or p_taban<0 or p_taban>500000 or p_taban<>round(p_taban) then raise exception 'Oran %%0-8, sabit harç 0-500.000 TL ve tam sayı olmalı.';end if;
 perform pg_advisory_xact_lock(93115,il::integer);
 select degisim into eski from oyun.bel_yatirim_tarife where il_id=il and tur=p_tur;
 if eski>now()-interval '24 hours' then raise exception 'Aynı harç tarifesi 24 saatte bir değiştirilebilir.';end if;
 insert into oyun.bel_yatirim_tarife(il_id,tur,oran,taban_tl,degistiren,degisim) values(il,p_tur,p_oran,p_taban,u,now())
 on conflict(il_id,tur) do update set oran=excluded.oran,taban_tl=excluded.taban_tl,degistiren=excluded.degistiren,degisim=excluded.degisim;
 perform oyun.olay('belediye',format('%s belediyesi %s yatırım harcını %% %s + %s TL taban olarak belirledi.',(select ad from oyun.iller where id=il),p_tur,p_oran,p_taban),il,null,oyun.simdi());
 return jsonb_build_object('tur',p_tur,'oran',p_oran,'taban_tl',p_taban);
end $f$;

create or replace function public.bel_ruhsat_karar(p_id bigint,p_onay boolean,p_gerekce text default null)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); r oyun.bel_yatirim_ruhsat; il smallint; act text;
begin
 select * into r from oyun.bel_yatirim_ruhsat where id=p_id for update;
 if r.id is null or r.durum<>'bekliyor' then raise exception 'Başvuru yok veya daha önce sonuçlandırılmış.';end if;
 select il_id into il from oyun.makamlar where tur='bel' and user_id=u and bit is null and il_id=r.il_id order by id desc limit 1;
 if il is null then raise exception 'Bu ilin belediye başkanı değilsin.';end if;
 if p_onay is null then raise exception 'Karar seçmelisin.';end if;
 if not p_onay and char_length(btrim(coalesce(p_gerekce,'')))<5 then raise exception 'Red gerekçesi en az 5 karakter olmalı.';end if;
 act:=case when p_onay then 'onay' else 'red' end;
 update oyun.bel_yatirim_ruhsat set durum=act,baskan=u,karar_zamani=now(),
 gerekce=left(nullif(btrim(p_gerekce),''),500),
 onay_oran=case when p_onay then oyun.bel_ruhsat_oran(r.il_id,r.tur) end,
 onay_taban=case when p_onay then oyun.bel_ruhsat_taban(r.il_id,r.tur) end where id=p_id;
 perform oyun.bildir(r.oyuncu,format('%s Belediyesi %s ruhsat başvurunu %s. %s',
 (select ad from oyun.iller where id=r.il_id),r.tur,case when p_onay then 'onayladı' else 'reddetti' end,coalesce(p_gerekce,'')),oyun.simdi());
 return jsonb_build_object('id',p_id,'durum',act);
end $f$;

-- Canlı yolları kaçırmamak için ruhsat koşulu veri katmanında zorlanır.
create or replace function oyun.bel_ruhsat_kapi() returns trigger
language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); sid bigint; il smallint; hedef bigint; tip text;
 s oyun.sirketler; r oyun.bel_yatirim_ruhsat; tutar numeric; matrah numeric; il_ad text;
begin
 if u is null then raise exception 'Yatırım işlemi için oyuncu oturumu gerekli.';end if;
 if tg_table_name='eko_isletmeler' then
   sid:=new.sirket_id; il:=new.il_id; tip:='kur_'||new.tur;
 elsif tg_table_name='pazar_sirket' then
   sid:=new.sirket_id; il:=new.il_id; tip:='kur_pazar';
 elsif tg_table_name='eko_yapilar' then
   sid:=new.sirket_id; il:=new.il_id; tip:='arsa_insaat'; hedef:=new.arsa_id;
 elsif tg_table_name='eko_projeler' then
   sid:=new.sirket_id; il:=new.il_id; tip:='yeni_proje';
 elsif tg_table_name='eko_subeler' then
   sid:=new.sirket_id; tip:='sube'; hedef:=new.bolum_id;
   select y.il_id into il from oyun.eko_bolumler b join oyun.eko_yapilar y on y.id=b.yapi_id where b.id=hedef;
 else return new; end if;
 select * into s from oyun.sirketler where id=sid;
 if s.id is null or not s.aktif or not oyun.sirket_yonetici_mi(sid,u) then raise exception 'Ruhsat için şirket yönetim yetkisi gerekli.';end if;
 select * into r from oyun.bel_yatirim_ruhsat br
 where br.oyuncu=u and br.il_id=il and br.tur=tip and br.durum='onay'
 and (br.sirket_id=sid or (br.sirket_id is null and br.sirket_adi=s.ad))
 and (br.hedef_id is null or br.hedef_id=hedef)
 and (br.sektor is null or br.sektor=s.sektor)
 and br.karar_zamani>now()-interval '72 hours'
 order by br.id asc limit 1 for update;
 if r.id is null then
  raise exception 'Bu yatırım için % belediyesinden onaylı ruhsat gerekli. Ekonomi veya Belediye menüsündeki Ruhsat Merkezi üzerinden başvur.',(select ad from oyun.iller where id=il);
 end if;
 matrah:=case tg_table_name
 when 'eko_yapilar' then new.maliyet
 when 'eko_projeler' then new.maliyet
 when 'eko_subeler' then greatest(0,s.sermaye*0.10)
 else s.sermaye end;
 tutar:=oyun.bel_ruhsat_tutar(r.onay_oran,r.onay_taban,matrah);
 update oyun.sirketler set kasa=kasa-tutar where id=sid and kasa>=tutar;
 if not found then raise exception 'Ruhsat harcı için şirket kasasında % TL gerekli.',tutar;end if;
 update oyun.il_durum set kasa=kasa+tutar/nullif(oyun.pazar_tl_milyar(),0) where il_id=il;
 update oyun.bel_yatirim_ruhsat set durum='kullanildi',odenen_tl=tutar,kullanma=now() where id=r.id;
 insert into oyun.belediye_sehir_hareket(il_id,tur,tutar,aciklama,zaman)
 values(il,'ruhsat_geliri',tutar/nullif(oyun.pazar_tl_milyar(),0),format('%s ruhsatı (#%s) - %s TL belediye geliri',tip,r.id,tutar),oyun.simdi());
 return new;
end $f$;
drop trigger if exists tr_bel_ruhsat_isletme on oyun.eko_isletmeler;
create trigger tr_bel_ruhsat_isletme before insert on oyun.eko_isletmeler for each row execute function oyun.bel_ruhsat_kapi();
drop trigger if exists tr_bel_ruhsat_pazar on oyun.pazar_sirket;
create trigger tr_bel_ruhsat_pazar before insert on oyun.pazar_sirket for each row execute function oyun.bel_ruhsat_kapi();
drop trigger if exists tr_bel_ruhsat_yapi on oyun.eko_yapilar;
create trigger tr_bel_ruhsat_yapi before insert on oyun.eko_yapilar for each row execute function oyun.bel_ruhsat_kapi();
drop trigger if exists tr_bel_ruhsat_proje on oyun.eko_projeler;
create trigger tr_bel_ruhsat_proje before insert on oyun.eko_projeler for each row execute function oyun.bel_ruhsat_kapi();
drop trigger if exists tr_bel_ruhsat_sube on oyun.eko_subeler;
create trigger tr_bel_ruhsat_sube before insert on oyun.eko_subeler for each row execute function oyun.bel_ruhsat_kapi();

create or replace function oyun.bel_mali_rapor(p_il smallint)
returns jsonb language sql stable set search_path='' as $f$
 select jsonb_build_object(
  'il',d.il_id,'kasa',d.kasa,'gunluk_gelir',oyun.il_gelir(d.il_id),'gunluk_gider',oyun.il_gider(d.il_id),
  'gunluk_net',oyun.il_gelir(d.il_id)-oyun.il_gider(d.il_id),
  'borc',coalesce((select sum(kalan) from oyun.belediye_borc where il_id=p_il and durum='aktif'),0),
  'son7_gelir',coalesce((select sum(greatest(0,tutar)) from oyun.belediye_sehir_hareket
    where il_id=p_il and zaman>now()-interval '7 days'),0),
  'son7_gider',coalesce((select sum(greatest(0,-tutar)) from oyun.belediye_sehir_hareket
    where il_id=p_il and zaman>now()-interval '7 days' and tur<>'mali_risk'),0),
  'son_kontrol',(select max(gun) from oyun.bel_mali_gunluk where il_id=p_il),
  'risk',case when d.kasa<oyun.il_gider(d.il_id)*3 then 'kritik'
          when oyun.il_gelir(d.il_id)<oyun.il_gider(d.il_id) then 'acik'
          when d.kasa<oyun.il_gelir(d.il_id)*7 then 'kirilgan'
          else 'dengeli' end,
  'gunlukler',coalesce((select jsonb_agg(jsonb_build_object('gun',gun,'gelir',gelir,'gider',gider,
    'acik',acik,'risk',risk_puani,'memnuniyet_kaybi',ceza_memnuniyet) order by gun desc)
    from (select * from oyun.bel_mali_gunluk where il_id=p_il order by gun desc limit 14) z),'[]'::jsonb))
 from oyun.il_durum d where d.il_id=p_il
$f$;

create or replace function oyun.bel_mali_gunluk_kontrol(p_gun date)
returns integer language plpgsql security definer set search_path='' as $f$
declare r record; v_gelir numeric;v_gider numeric; v_risk numeric; v_mem numeric;v_gel numeric;v_taban_gelir numeric;v_taban_gider numeric;n int:=0;
begin
 for r in select il_id,kasa from oyun.il_durum order by il_id loop
  if exists(select 1 from oyun.bel_mali_gunluk where il_id=r.il_id and gun=p_gun) then continue;end if;
  v_taban_gelir:=oyun.il_gelir(r.il_id);
  v_taban_gider:=oyun.il_gider(r.il_id);
  select coalesce(sum(greatest(0,tutar)),0),coalesce(sum(greatest(0,-tutar)),0)
  into v_gelir,v_gider from oyun.belediye_sehir_hareket
  where il_id=r.il_id and (zaman at time zone 'Europe/Istanbul')::date=p_gun;
  -- Sadece yatırımları artırıp geliri artırmayan başkan şehirde ekonomik risk yaratır.
  v_risk:=greatest(0,(v_taban_gider+v_gider)-(v_taban_gelir+v_gelir));
  v_mem:=case when r.kasa<v_taban_gider*3 and v_risk>0 then least(3,0.4+v_risk/greatest(0.02,v_taban_gelir)*0.5) else 0 end;
  v_gel:=case when v_mem>0 then least(0.8,v_mem*0.18) else 0 end;
  insert into oyun.bel_mali_gunluk(il_id,gun,gelir,gider,temel_gelir,temel_gider,kasa,acik,risk_puani,ceza_memnuniyet,ceza_gelisim)
  values(r.il_id,p_gun,v_gelir,v_gider,v_taban_gelir,v_taban_gider,r.kasa,v_risk,
   round(case when v_taban_gelir>0 then v_risk/v_taban_gelir else v_risk end,2),v_mem,v_gel)
  on conflict do nothing;
  if v_mem>0 then
   update oyun.il_durum set memnuniyet=oyun.sinir(memnuniyet-v_mem,0,100),
     gelisim=oyun.sinir(gelisim-v_gel,0,100) where il_id=r.il_id;
   insert into oyun.belediye_sehir_hareket(il_id,tur,tutar,aciklama,zaman)
    values(r.il_id,'mali_risk',0,format('%s bütçe açığı nedeniyle -%s memnuniyet, -%s gelişim.',p_gun,v_mem,v_gel),now());
  end if;
  n:=n+1;
 end loop;
 return n;
end $f$;
revoke all on function oyun.bel_mali_gunluk_kontrol(date) from public,anon,authenticated;
revoke all on function oyun.bel_ruhsat_kapi() from public,anon,authenticated;
revoke all on function public.bel_ruhsat_merkezi(),public.bel_ruhsat_basvur(text,integer,bigint,bigint,text,text,numeric),
 public.bel_ruhsat_tarife_ayarla(text,numeric,numeric),public.bel_ruhsat_karar(bigint,boolean,text)
 from public,anon,authenticated;
grant execute on function public.bel_ruhsat_merkezi(),public.bel_ruhsat_basvur(text,integer,bigint,bigint,text,text,numeric),
 public.bel_ruhsat_tarife_ayarla(text,numeric,numeric),public.bel_ruhsat_karar(bigint,boolean,text) to authenticated;
select cron.schedule('belediye-mali-denetimi','10 2 * * *',
 $$select oyun.bel_mali_gunluk_kontrol((now() at time zone 'Europe/Istanbul')::date-1)$$);
commit;
