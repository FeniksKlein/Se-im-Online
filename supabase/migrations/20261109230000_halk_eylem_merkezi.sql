-- Eylemci sert hamleleri, sembolik işgal ve hazinenin eylem maliyeti.
-- Canlı fonksiyon gövdelerine yama yok. Yeni tablo, tetikleyici ve RPC.
-- Bu dosya canlı veritabanına elle uygulanır. İkinci kez çalıştırılabilir.

create table if not exists oyun.sokak_hamle(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 tur text not null check(tur in ('grev','yol','aclik','vergi','oturma','uluslararasi','zincir','sizma','gensoru','kalkan','mesale','isgal')),
 yapan uuid not null references oyun.profiller,
 bedel numeric not null default 0 check(bedel>=0),
 durum text not null default 'aktif' check(durum in ('aktif','bitti','coktu')),
 zaman timestamptz not null, bitis timestamptz not null,
 etki jsonb not null default '{}'::jsonb
);
create index if not exists sokak_hamle_eylem on oyun.sokak_hamle(eylem_id,zaman desc);
create table if not exists oyun.sokak_aclik(
 eylem_id bigint not null, user_id uuid not null, bitis timestamptz not null, primary key(eylem_id,user_id)
);
create table if not exists oyun.sokak_isik(
 eylem_id bigint not null, user_id uuid not null, gun date not null, zaman timestamptz not null,
 primary key(eylem_id,user_id,gun)
);
create table if not exists oyun.sokak_sizma(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem, user_id uuid not null references oyun.profiller,
 durum text not null default 'aktif' check(durum in ('aktif','ifsa')), zaman timestamptz not null
);
create table if not exists oyun.sokak_sizma_not(
 id bigint generated always as identity primary key,
 sizma_id bigint not null references oyun.sokak_sizma, metin text not null, zaman timestamptz not null
);
create table if not exists oyun.sokak_sizma_oy(
 sizma_id bigint not null references oyun.sokak_sizma, veren uuid not null, primary key(sizma_id,veren)
);
create table if not exists oyun.sokak_isgal(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem, il_id integer not null,
 bina text not null check(bina in ('belediye','valilik')),
 durum text not null default 'aktif' check(durum in ('aktif','coktu','anlasma','temizlendi','direndi')),
 guc numeric not null default 10, bas timestamptz not null, bitis timestamptz not null, son timestamptz not null
);
create table if not exists oyun.sokak_vardiya(
 id bigint generated always as identity primary key,
 isgal_id bigint not null references oyun.sokak_isgal, user_id uuid not null,
 taraf text not null check(taraf in ('isgal','kusatma','ziyaret')),
 bas timestamptz not null, bitis timestamptz not null
);
create table if not exists oyun.sokak_kusatma(
 id bigint generated always as identity primary key,
 isgal_id bigint not null references oyun.sokak_isgal, yapan uuid not null,
 bedel numeric not null, bas timestamptz not null, bitis timestamptz not null,
 durum text not null default 'aktif' check(durum in ('aktif','bitti'))
);
create table if not exists oyun.sokak_tahliye(
 id bigint generated always as identity primary key,
 isgal_id bigint not null references oyun.sokak_isgal, yapan uuid not null, bedel numeric not null,
 bas timestamptz not null, bitis timestamptz not null,
 durum text not null check(durum in ('geri_sayim','hukumet','meydan')), sonuc text
);
create table if not exists oyun.sokak_tahliye_katilim(
 tahliye_id bigint not null references oyun.sokak_tahliye, user_id uuid not null,
 taraf text not null check(taraf in ('hukumet','savun')), primary key(tahliye_id,user_id)
);
create table if not exists oyun.sokak_tahliye_bekle(
 eylem_id bigint primary key, bitis timestamptz not null
);
create table if not exists oyun.sokak_muzakere(
 id bigint generated always as identity primary key,
 isgal_id bigint not null references oyun.sokak_isgal, metin text not null, bedel numeric not null,
 durum text not null default 'oy' check(durum in ('oy','kabul','ret')),
 bas timestamptz not null, bitis timestamptz not null
);
create table if not exists oyun.sokak_muzakere_oy(
 muzakere_id bigint not null references oyun.sokak_muzakere, user_id uuid not null, oy text not null,
 primary key(muzakere_id,user_id)
);
create table if not exists oyun.sokak_men(
 eylem_id bigint not null, user_id uuid not null, bitis timestamptz not null, primary key(eylem_id,user_id)
);
create table if not exists oyun.sokak_hazine_sayac(
 eylem_id bigint primary key, son timestamptz not null, toplam numeric not null default 0, saatlik numeric not null default 0
);
create table if not exists oyun.sokak_hazine_defter(
 id bigint generated always as identity primary key,
 eylem_id bigint not null, tutar_milyar numeric not null, saat numeric not null, aciklama text not null, zaman timestamptz not null
);
create index if not exists sokak_hazine_defter_eylem on oyun.sokak_hazine_defter(eylem_id,zaman desc);

do $$ declare t text; begin
 foreach t in array array['sokak_hamle','sokak_aclik','sokak_isik','sokak_sizma','sokak_sizma_not','sokak_sizma_oy','sokak_isgal','sokak_vardiya','sokak_kusatma','sokak_tahliye','sokak_tahliye_katilim','sokak_tahliye_bekle','sokak_muzakere','sokak_muzakere_oy','sokak_men','sokak_hazine_sayac','sokak_hazine_defter'] loop
  execute format('alter table oyun.%I enable row level security', t);
  execute format('revoke all on oyun.%I from public, anon, authenticated', t);
 end loop;
end $$;

create or replace function oyun.sokak_hamle_ad(k text) returns text
language sql immutable set search_path='' as $$
 select case k
  when 'grev' then 'Genel Grev' when 'yol' then 'Yol Kapatma' when 'aclik' then 'Açlık Grevi'
  when 'vergi' then 'Vergi İtaatsizliği' when 'oturma' then 'Bakanlık Önü Oturma'
  when 'uluslararasi' then 'Uluslararası Kamuoyu Çağrısı' when 'zincir' then 'Sivil İtaatsizlik Zinciri'
  when 'sizma' then 'İçeriden Sızma' when 'gensoru' then 'Gensoru Baskısı'
  when 'kalkan' then 'Boykot Kalkanı' when 'mesale' then 'Gece Meşalesi' when 'isgal' then 'Sembolik İşgal'
  else k end
$$;

create or replace function oyun.sokak_org_ode(e oyun.sokak_eylem, tutar numeric, aciklama text) returns void
language plpgsql set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
begin
 if coalesce(tutar,0)<=0 then return; end if;
 if e.org_tur='dernek' then
  update oyun.dernekler set kasa=kasa-tutar where id=e.org_id and kasa>=tutar;
  if not found then raise exception 'Dernek kasası bu hamle için yetersiz'; end if;
  insert into oyun.dernek_hareket(dernek_id,zaman,tutar,tur,aciklama,user_id) values(e.org_id,t,-tutar,'gider',aciklama,u);
 elsif e.parti_id is not null then
  update oyun.partiler set kasa=kasa-tutar where id=e.parti_id and kasa>=tutar;
  if not found then raise exception 'Parti kasası bu hamle için yetersiz'; end if;
  insert into oyun.parti_hareket(parti_id,zaman,tutar,tur,aciklama) values(e.parti_id,t,-tutar,'gider',aciklama);
 else
  update oyun.cuzdan c set para=c.para-tutar where c.user_id=u and c.para>=tutar;
  if not found then raise exception 'Bu hamle için yeterli para yok'; end if;
 end if;
end $$;

create or replace function oyun.sokak_icisleri_ode(tutar numeric, aciklama text) returns void
language plpgsql set search_path='' as $$
declare kalan numeric;
begin
 if coalesce(tutar,0)<=0 then return; end if;
 select kasa*oyun.pazar_tl_milyar() into kalan from oyun.bakanlik_kasa where kod='icisleri';
 if kalan is null or kalan<tutar then raise exception 'İçişleri bütçesi yetersiz. Gerekli % TL.', trim(to_char(tutar,'999G999G999')) ; end if;
 perform oyun.bm_kasa_harca('icisleri', tutar/oyun.pazar_tl_milyar(), 'gider', aciklama);
end $$;

create or replace function oyun.sokak_merkez_tick() returns void
language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi(); r record; s record; saat numeric; oran numeric; tutar numeric;
 n int; nobet int; gerek int; kus int; gov int; occ int; ziy int; nabiz numeric; evet int; hayir int;
begin
 if not pg_try_advisory_xact_lock(781231,7) then return; end if;
 update oyun.sokak_hamle set durum='bitti' where durum='aktif' and bitis<=t and tur<>'isgal';
 for r in select e.id, e.il_id, e.baslangic from oyun.sokak_eylem e where e.durum='aktif' and e.bitis>t loop
  insert into oyun.sokak_hazine_sayac(eylem_id,son) values(r.id, coalesce(r.baslangic,t)) on conflict(eylem_id) do nothing;
  select extract(epoch from (t-son))/3600 into saat from oyun.sokak_hazine_sayac where eylem_id=r.id;
  if saat is null or saat<0.02 then continue; end if;
  if saat>48 then saat:=48; end if;
  select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=r.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet';
  oran:=0.008+least(40,coalesce(n,0))*0.00035;
  if exists(select 1 from oyun.sokak_hamle h where h.eylem_id=r.id and h.durum='aktif' and h.bitis>t and h.tur='grev') then oran:=oran+0.02; end if;
  if exists(select 1 from oyun.sokak_hamle h where h.eylem_id=r.id and h.durum='aktif' and h.bitis>t and h.tur='yol') then oran:=oran+0.012; end if;
  if exists(select 1 from oyun.sokak_hamle h where h.eylem_id=r.id and h.durum='aktif' and h.bitis>t and h.tur='vergi') then oran:=oran+0.018; end if;
  if exists(select 1 from oyun.sokak_isgal i where i.eylem_id=r.id and i.durum='aktif' and i.bitis>t) then oran:=oran+0.025; end if;
  if exists(select 1 from oyun.sokak_hamle h where h.eylem_id=r.id and h.durum='aktif' and h.bitis>t and h.tur not in ('grev','yol','vergi','isgal')) then oran:=oran+0.004; end if;
  tutar:=round(oran*saat,4);
  update oyun.ulke set hazine=hazine-tutar where id=1;
  insert into oyun.sokak_hazine_defter(eylem_id,tutar_milyar,saat,aciklama,zaman)
   values(r.id,tutar,saat,'Süregelen eylem ve sert hamleler',t);
  update oyun.sokak_hazine_sayac set son=t, toplam=toplam+tutar, saatlik=oran where eylem_id=r.id;
 end loop;
 for r in select * from oyun.sokak_hamle where tur='vergi' and durum='aktif' and zaman<=t-interval '6 hours' and not (etki ? 'ceza') loop
  update oyun.partiler set kasa=kasa-40000 where id=(select parti_id from oyun.sokak_eylem where id=r.eylem_id) and kasa>=40000;
  if found then
   perform oyun.sokak_duyur(r.eylem_id,'Vergi itaatsizliği cezası: parti kasasından 40.000 TL.');
  else
   update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-1) where il_id=(select il_id from oyun.sokak_eylem where id=r.eylem_id);
  end if;
  update oyun.sokak_hamle set etki=etki||jsonb_build_object('ceza',true) where id=r.id;
 end loop;
 for r in select * from oyun.sokak_hamle where tur='aclik' and durum='aktif' and bitis>t loop
  saat:=extract(epoch from (t-coalesce((r.etki->>'son')::timestamptz, r.zaman)))/3600;
  if saat>=1 then
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(r.eylem_id,'aclik',least(8,floor(saat)),t+interval '6 hours');
   update oyun.sokak_hamle set etki=etki||jsonb_build_object('son',t,'sempati',coalesce((etki->>'sempati')::int,0)+floor(saat)::int) where id=r.id;
  end if;
 end loop;
 for r in select * from oyun.sokak_isgal where durum='aktif' and bitis>t loop
  select count(*) into nobet from oyun.sokak_vardiya v where v.isgal_id=r.id and v.taraf='isgal' and v.bitis>t;
  select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=r.eylem_id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet';
  gerek:=greatest(2, ceil(coalesce(n,0)/5.0));
  select count(*) into kus from oyun.sokak_vardiya v where v.isgal_id=r.id and v.taraf='kusatma' and v.bitis>t;
  saat:=extract(epoch from (t-r.son))/3600;
  if nobet<gerek and r.bas<=t-interval '15 minutes' then
   update oyun.sokak_isgal set durum='coktu', bitis=t where id=r.id;
   update oyun.sokak_hamle set durum='coktu', bitis=t where eylem_id=r.eylem_id and tur='isgal' and durum='aktif';
   perform oyun.sokak_duyur(r.eylem_id,'Bina nöbeti seyrelince sembolik işgal kendiliğinden dağıldı.');
  elsif saat>=1 then
   if kus>=3 then update oyun.sokak_isgal set guc=greatest(0,guc-2*floor(saat)), son=t where id=r.id;
   else update oyun.sokak_isgal set son=t where id=r.id; end if;
   update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-0.4*floor(saat)) where il_id=r.il_id;
  end if;
 end loop;
 for r in select * from oyun.sokak_muzakere where durum='oy' and bitis<=t loop
  select count(*) filter(where oy='evet'), count(*) filter(where oy='hayir') into evet, hayir from oyun.sokak_muzakere_oy where muzakere_id=r.id;
  if evet>=2 and evet>hayir then
   update oyun.sokak_muzakere set durum='kabul' where id=r.id;
   update oyun.sokak_isgal set durum='anlasma', bitis=t where id=r.isgal_id and durum='aktif';
   update oyun.ulke set memnuniyet=least(100,memnuniyet+1) where id=1;
  else
   update oyun.sokak_muzakere set durum='ret' where id=r.id;
  end if;
 end loop;
 for r in select q.*, i.eylem_id, i.il_id, i.guc from oyun.sokak_tahliye q join oyun.sokak_isgal i on i.id=q.isgal_id
           where q.durum='geri_sayim' and q.bitis<=t loop
  select count(*) filter(where taraf='hukumet'), count(*) filter(where taraf='savun') into gov, occ from oyun.sokak_tahliye_katilim where tahliye_id=r.id;
  select count(*) into nobet from oyun.sokak_vardiya where isgal_id=r.isgal_id and taraf='isgal' and bitis>t;
  select count(*) into ziy from oyun.sokak_vardiya where isgal_id=r.isgal_id and taraf='ziyaret' and bitis>t;
  select count(*) into kus from oyun.sokak_vardiya where isgal_id=r.isgal_id and taraf='kusatma' and bitis>t;
  nabiz:=oyun.sokak_memnuniyetsizlik(r.il_id);
  if gov>=1 and (gov*3 + kus*2) > ((nobet+occ)*3 + ziy*2 + r.guc + case when nabiz>=50 then 5 else 0 end) then
   update oyun.sokak_tahliye set durum='hukumet', sonuc='Bina boşaltıldı' where id=r.id;
   update oyun.sokak_isgal set durum='temizlendi', bitis=t where id=r.isgal_id;
   insert into oyun.sokak_men(eylem_id,user_id,bitis)
    select distinct r.eylem_id, user_id, t+interval '6 hours' from (
      select user_id from oyun.sokak_vardiya where isgal_id=r.isgal_id and taraf='isgal'
      union select user_id from oyun.sokak_tahliye_katilim where tahliye_id=r.id and taraf='savun'
    ) q on conflict(eylem_id,user_id) do update set bitis=excluded.bitis;
   if nabiz>=45 then update oyun.ulke set memnuniyet=greatest(0,memnuniyet-2) where id=1; end if;
   update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-1) where il_id=r.il_id;
   perform oyun.sokak_duyur(r.eylem_id,'Tahliye tamamlandı. Savunanlar 6 saat eylem hamlesi kullanamaz.');
  else
   update oyun.sokak_tahliye set durum='meydan', sonuc='Operasyon tutmadı' where id=r.id;
   update oyun.sokak_isgal set durum='direndi', guc=guc+4 where id=r.isgal_id and durum='aktif';
   update oyun.ulke set memnuniyet=greatest(0,memnuniyet-3) where id=1;
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(r.eylem_id,'tahliye',8,t+interval '12 hours');
   insert into oyun.sokak_tahliye_bekle(eylem_id,bitis) values(r.eylem_id,t+interval '12 hours')
    on conflict(eylem_id) do update set bitis=excluded.bitis;
   perform oyun.sokak_manset_yaz('Tahliye operasyonu tutmadı');
   perform oyun.sokak_duyur(r.eylem_id,'Tahliye tutmadı. Hükümet sempati kaybetti ve 12 saat yeniden deneyemez.');
  end if;
 end loop;
end $$;

create or replace function public.sokak_eylem_merkezi_islem(p_eylem bigint, p_islem text, p_veri jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi();
 txt text; n int; gerek int; bedel numeric; hid bigint; iid bigint; sid bigint; qid bigint; mid bigint; mole uuid;
 saat int; isik_gun date; bina_ad text; kus int;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform pg_advisory_xact_lock(781231,1);
 perform oyun.sokak_merkez_tick();
 if p_eylem is not null then select * into x from oyun.sokak_eylem where id=p_eylem for update; end if;
 if p_islem='hamle' then
  if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli'; end if;
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Sert hamleyi eylemin içindeki oyuncu açar'; end if;
  if exists(select 1 from oyun.sokak_men m where m.eylem_id=x.id and m.user_id=u and m.bitis>t) then raise exception 'Tahliye sonrası 6 saat eylem hamlesi yok'; end if;
  if coalesce(p_veri->>'tur','') not in ('grev','yol','aclik','vergi','oturma','uluslararasi','zincir','gensoru','kalkan','isgal') then raise exception 'Geçersiz sert hamle'; end if;
  txt:=oyun.sokak_temiz(coalesce(p_veri->>'gerekce','Bu hamle için ortak gerekçe yazıldı'),300);
  if exists(select 1 from oyun.sokak_hamle h where h.eylem_id=x.id and h.tur=p_veri->>'tur' and h.durum='aktif' and h.bitis>t) then raise exception 'Bu hamle sürüyor'; end if;
  if (select count(*) from oyun.sokak_hamle h where h.eylem_id=x.id and h.zaman>t-interval '6 hours')>=2 then raise exception '6 saatte en çok 2 sert hamle'; end if;
  select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=x.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet';
  bedel:=case p_veri->>'tur' when 'grev' then 150000 when 'yol' then 80000 when 'aclik' then 0 when 'vergi' then 120000
   when 'oturma' then 60000 when 'uluslararasi' then 100000 when 'zincir' then 80000 when 'gensoru' then 70000
   when 'kalkan' then 90000 when 'isgal' then 200000 else 0 end;
  gerek:=case p_veri->>'tur' when 'grev' then greatest(4,ceil(n*0.4)) when 'yol' then 3 when 'vergi' then 4
   when 'oturma' then 3 when 'uluslararasi' then 3 when 'zincir' then 3 when 'gensoru' then 5 when 'kalkan' then 3
   when 'isgal' then greatest(4,ceil(n/3.0)) else 1 end;
  if n<gerek then raise exception 'Bu hamle için en az % katılımcı gerekir', gerek; end if;
  if p_veri->>'tur'='zincir' and (select count(distinct il_id) from oyun.sokak_eylem where durum='aktif' and bitis>t)<3 then
   raise exception 'Zincir için üç ayrı ilde süren eylem gerekir'; end if;
  perform oyun.sokak_org_ode(x,bedel,oyun.sokak_hamle_ad(p_veri->>'tur'));
  insert into oyun.sokak_hamle(eylem_id,tur,yapan,bedel,zaman,bitis) values(x.id,p_veri->>'tur',u,bedel,t,
   t+case p_veri->>'tur' when 'grev' then interval '6 hours' when 'yol' then interval '3 hours' when 'aclik' then interval '8 hours'
    when 'vergi' then interval '12 hours' when 'oturma' then interval '4 hours' when 'uluslararasi' then interval '6 hours'
    when 'zincir' then interval '6 hours' when 'gensoru' then interval '12 hours' when 'kalkan' then interval '8 hours'
    else interval '12 hours' end) returning id into hid;
  perform oyun.sokak_sicil_yaz(u,x.id,'hamle',oyun.sokak_hamle_ad(p_veri->>'tur'));
  if p_veri->>'tur'='grev' then
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'grev',6,t+interval '6 hours');
   update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-1) where il_id=x.il_id;
  elsif p_veri->>'tur'='yol' then
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'yol',4,t+interval '3 hours');
   update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-1) where il_id=x.il_id;
  elsif p_veri->>'tur'='aclik' then
   insert into oyun.sokak_aclik(eylem_id,user_id,bitis) values(x.id,u,t+interval '8 hours') on conflict(eylem_id,user_id) do update set bitis=excluded.bitis;
  elsif p_veri->>'tur'='vergi' then
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'vergi',4,t+interval '12 hours');
  elsif p_veri->>'tur'='oturma' then
   perform oyun.bildir(m.user_id,'Bakanlığın önünde oturma eylemi var.') from oyun.makamlar m
    where m.tur='bakan' and m.bit is null and m.bakanlik=coalesce(nullif(p_veri->>'bakanlik',''),'icisleri');
   insert into oyun.sokak_itibar(user_id,puan)
    select m.user_id,-5 from oyun.makamlar m where m.tur='bakan' and m.bit is null and m.bakanlik=coalesce(nullif(p_veri->>'bakanlik',''),'icisleri')
    on conflict(user_id) do update set puan=oyun.sokak_itibar.puan-5;
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'oturma',3,t+interval '4 hours');
  elsif p_veri->>'tur'='uluslararasi' then
   update oyun.ulke set memnuniyet=greatest(0,memnuniyet-2) where id=1;
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'uluslararasi',5,t+interval '6 hours');
   perform oyun.sokak_manset_yaz('Uluslararası kamuoyu çağrısı');
  elsif p_veri->>'tur'='zincir' then
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis)
    select e.id,'zincir',4,t+interval '6 hours' from oyun.sokak_eylem e where e.durum='aktif' and e.bitis>t;
   update oyun.ulke set memnuniyet=greatest(0,memnuniyet-2) where id=1;
  elsif p_veri->>'tur'='gensoru' then
   if not exists(select 1 from oyun.sokak_gensoru where durum='oylamada') then
    insert into oyun.sokak_gensoru(acan,gerekce,bas,bit) values(u,'İçişleri Bakanı hakkında gensoru baskısı: '||txt,t,t+interval '12 hours');
   end if;
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'gensoru',4,t+interval '12 hours');
   perform oyun.bildir(m.user_id,'İçişleri hakkında gensoru baskısı var. Oy Meclis ekranında.') from oyun.makamlar m where m.tur='mv' and m.bit is null;
  elsif p_veri->>'tur'='kalkan' then
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'kalkan',2,t+interval '8 hours');
  elsif p_veri->>'tur'='isgal' then
   bina_ad:=coalesce(p_veri->>'bina','belediye');
   if bina_ad not in ('belediye','valilik') then raise exception 'Bina belediye ya da valilik olmalı'; end if;
   if exists(select 1 from oyun.sokak_isgal i where i.il_id=x.il_id and i.bina=bina_ad and i.durum='aktif' and i.bitis>t) then raise exception 'Bu bina zaten işgalde'; end if;
   insert into oyun.sokak_isgal(eylem_id,il_id,bina,bas,bitis,son) values(x.id,x.il_id,bina_ad,t,t+interval '12 hours',t) returning id into iid;
   insert into oyun.sokak_vardiya(isgal_id,user_id,taraf,bas,bitis) values(iid,u,'isgal',t,t+interval '1 hour');
   update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-1) where il_id=x.il_id;
  end if;
  perform oyun.sokak_duyur(x.id,oyun.sokak_hamle_ad(p_veri->>'tur')||' başladı.');
  return jsonb_build_object('tamam',true,'tur',p_veri->>'tur','bedel',bedel);

 elsif p_islem='aclik' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Açlık grevine katılımcı yazılır'; end if;
  insert into oyun.sokak_aclik(eylem_id,user_id,bitis)
   select x.id,u,h.bitis from oyun.sokak_hamle h where h.eylem_id=x.id and h.tur='aclik' and h.durum='aktif' and h.bitis>t limit 1
   on conflict(eylem_id,user_id) do update set bitis=excluded.bitis;
  if not found then raise exception 'Açık bir açlık grevi yok'; end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='mesale' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Işığı katılımcı yakar'; end if;
  saat:=extract(hour from t at time zone 'Europe/Istanbul')::int;
  if saat<>0 then raise exception 'Gece meşalesi yalnız 00.00–01.00 arasında yakılır'; end if;
  isik_gun:=(t at time zone 'Europe/Istanbul')::date;
  insert into oyun.sokak_isik(eylem_id,user_id,gun,zaman) values(x.id,u,isik_gun,t) on conflict do nothing;
  select count(*) into n from oyun.sokak_isik q where q.eylem_id=x.id and q.gun=isik_gun;
  if n>=3 then
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'mesale',least(12,n*2),t+interval '6 hours');
   update oyun.il_durum set memnuniyet=least(100,memnuniyet+0.2) where il_id=x.il_id;
  end if;
  return jsonb_build_object('tamam',true,'isik',n);

 elsif p_islem='sizma' then
  if not (oyun.sokak_iktidar(u) or exists(select 1 from oyun.makamlar m where m.user_id=u and m.bit is null and m.tur in ('cb','bakan','mv','vali'))) then
   raise exception 'Sızmayı hükümette veya iktidarda olan biri yapar'; end if;
  insert into oyun.sokak_sizma(eylem_id,user_id,zaman)
   select x.id,u,t where not exists(select 1 from oyun.sokak_sizma s where s.eylem_id=x.id and s.user_id=u and s.durum='aktif')
   returning id into sid;
  if sid is null then select id into sid from oyun.sokak_sizma where eylem_id=x.id and user_id=u and durum='aktif'; end if;
  txt:=oyun.sokak_temiz(coalesce(p_veri->>'metin','Hükümet planı sızdı'),400);
  insert into oyun.sokak_sizma_not(sizma_id,metin,zaman) values(sid,txt,t);
  insert into public.sokak_eylem_sohbet(eylem_id,user_id,metin,zaman) values(x.id,u,'İçeriden not: '||left(txt,360),t);
  return jsonb_build_object('tamam',true);

 elsif p_islem='sizma_oy' then
  if not exists(select 1 from oyun.makamlar m where m.user_id=u and m.bit is null and m.tur in ('cb','bakan')) then raise exception 'Sızmayı kabine oyu açığa çıkarır'; end if;
  sid:=(p_veri->>'id')::bigint;
  insert into oyun.sokak_sizma_oy(sizma_id,veren) values(sid,u);
  select count(*) into n from oyun.sokak_sizma_oy where sizma_id=sid;
  select count(*) into gerek from oyun.makamlar where bit is null and tur in ('cb','bakan');
  if n>=2 and n*2>gerek then
   update oyun.sokak_sizma set durum='ifsa' where id=sid and durum='aktif' returning user_id, eylem_id into mole, p_eylem;
   if found then
    insert into oyun.sokak_itibar(user_id,puan) values(mole,-10) on conflict(user_id) do update set puan=oyun.sokak_itibar.puan-10;
    insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(p_eylem,'sizma',-4,t+interval '6 hours');
    perform oyun.sokak_duyur(p_eylem,'Hükümet içindeki sızıntı açığa çıktı.');
   end if;
  end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='nobet' then
  select id into iid from oyun.sokak_isgal where eylem_id=x.id and durum='aktif' and bitis>t order by id desc limit 1;
  if iid is null then raise exception 'Süregelen işgal yok'; end if;
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Bina nöbetine katılımcı yazılır'; end if;
  if exists(select 1 from oyun.sokak_vardiya v where v.isgal_id=iid and v.user_id=u and v.taraf='isgal' and v.bitis>t) then raise exception 'Nöbetin sürüyor'; end if;
  insert into oyun.sokak_vardiya(isgal_id,user_id,taraf,bas,bitis) values(iid,u,'isgal',t,t+interval '1 hour');
  update oyun.sokak_isgal set guc=guc+1 where id=iid;
  return jsonb_build_object('tamam',true);

 elsif p_islem='ziyaret' then
  select id, il_id into iid, n from oyun.sokak_isgal where eylem_id=x.id and durum='aktif' and bitis>t order by id desc limit 1;
  if iid is null then raise exception 'Süregelen işgal yok'; end if;
  if oyun.sokak_katilimci(x.id,u) or oyun.sokak_sert_yetkili(u,x.il_id) then raise exception 'Dayanışma ziyaretini dışarıdan biri yapar'; end if;
  if (select il_id from oyun.profiller where id=u)=x.il_id then raise exception 'Ziyaret başka ilden gelir'; end if;
  select count(*) into kus from oyun.sokak_vardiya where isgal_id=iid and taraf='kusatma' and bitis>t;
  if kus>=8 then raise exception 'Kuşatma sıkı; dayanışma ziyareti şu an giremiyor'; end if;
  insert into oyun.sokak_vardiya(isgal_id,user_id,taraf,bas,bitis) values(iid,u,'ziyaret',t,t+interval '1 hour');
  update oyun.sokak_isgal set guc=guc+case when kus>=4 then 1 else 3 end where id=iid;
  return jsonb_build_object('tamam',true);

 elsif p_islem='kusatma' then
  if not oyun.sokak_sert_yetkili(u,x.il_id) then raise exception 'Kuşatmayı Cumhurbaşkanı, İçişleri Bakanı veya vali başlatır'; end if;
  select id into iid from oyun.sokak_isgal where eylem_id=x.id and durum='aktif' and bitis>t limit 1;
  if iid is null then raise exception 'İşgal yok'; end if;
  if exists(select 1 from oyun.sokak_kusatma k where k.isgal_id=iid and k.durum='aktif' and k.bitis>t) then raise exception 'Kuşatma sürüyor'; end if;
  perform oyun.sokak_icisleri_ode(200000,'Sembolik işgal kuşatması eylem #'||x.id);
  insert into oyun.sokak_kusatma(isgal_id,yapan,bedel,bas,bitis) values(iid,u,200000,t,t+interval '6 hours');
  perform oyun.sokak_duyur(x.id,'Hükümet binayı kuşattı. İktidar oyuncuları birer saatlik kuşatma nöbeti tutabilir.');
  return jsonb_build_object('tamam',true,'bedel',200000);

 elsif p_islem='kusatma_nobet' then
  if not oyun.sokak_iktidar(u) or (select il_id from oyun.profiller where id=u) is distinct from x.il_id then
   raise exception 'Kuşatma nöbetini bu ildeki iktidar oyuncusu tutar'; end if;
  select k.isgal_id into iid from oyun.sokak_kusatma k join oyun.sokak_isgal i on i.id=k.isgal_id
   where i.eylem_id=x.id and k.durum='aktif' and k.bitis>t limit 1;
  if iid is null then raise exception 'Açık kuşatma yok'; end if;
  if exists(select 1 from oyun.sokak_vardiya v where v.isgal_id=iid and v.user_id=u and v.taraf='kusatma' and v.bitis>t) then raise exception 'Nöbetin sürüyor'; end if;
  insert into oyun.sokak_vardiya(isgal_id,user_id,taraf,bas,bitis) values(iid,u,'kusatma',t,t+interval '1 hour');
  return jsonb_build_object('tamam',true);

 elsif p_islem='muzakere' then
  if not oyun.sokak_sert_yetkili(u,x.il_id) then raise exception 'Teklifi yetkili hükümet oyuncusu yapar'; end if;
  select id into iid from oyun.sokak_isgal where eylem_id=x.id and durum='aktif' and bitis>t limit 1;
  if iid is null then raise exception 'İşgal yok'; end if;
  txt:=oyun.sokak_temiz(coalesce(p_veri->>'metin',''),400);
  perform oyun.sokak_icisleri_ode(100000,'Müzakereli tahliye teklifi eylem #'||x.id);
  insert into oyun.sokak_muzakere(isgal_id,metin,bedel,bas,bitis) values(iid,txt,100000,t,t+interval '1 hour');
  perform oyun.sokak_duyur(x.id,'Tahliye teklifi: '||left(txt,180));
  return jsonb_build_object('tamam',true,'bedel',100000);

 elsif p_islem='muzakere_oy' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Teklif oyunu işgalciler kullanır'; end if;
  select id into mid from oyun.sokak_muzakere q join oyun.sokak_isgal i on i.id=q.isgal_id
   where i.eylem_id=x.id and q.durum='oy' and q.bitis>t order by q.id desc limit 1;
  if mid is null then raise exception 'Açık teklif yok'; end if;
  if coalesce(p_veri->>'oy','') not in ('evet','hayir') then raise exception 'Oy evet ya da hayır'; end if;
  insert into oyun.sokak_muzakere_oy(muzakere_id,user_id,oy) values(mid,u,p_veri->>'oy');
  select count(*) filter(where oy='evet'), count(*) filter(where oy='hayir'), count(*) into n, gerek, saat
   from oyun.sokak_muzakere_oy where muzakere_id=mid;
  select count(*) into kus from oyun.sokak_vardiya v join oyun.sokak_isgal i on i.id=v.isgal_id
   where i.eylem_id=x.id and v.taraf='isgal' and v.bitis>t;
  if n>=2 and n*2>greatest(kus,1) then
   update oyun.sokak_muzakere set durum='kabul' where id=mid;
   update oyun.sokak_isgal set durum='anlasma', bitis=t where eylem_id=x.id and durum='aktif';
   update oyun.ulke set memnuniyet=least(100,memnuniyet+1) where id=1;
   update oyun.il_durum set memnuniyet=least(100,memnuniyet+1) where il_id=x.il_id;
   perform oyun.sokak_duyur(x.id,'İşgalciler tahliye teklifini kabul etti. Bina yumuşak biçimde boşaldı.');
  elsif gerek>=2 and gerek>=n then
   update oyun.sokak_muzakere set durum='ret' where id=mid;
   perform oyun.sokak_duyur(x.id,'Tahliye teklifi reddedildi.');
  end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='tahliye' then
  if not oyun.sokak_sert_yetkili(u,x.il_id) then raise exception 'Tahliye emrini yetkili hükümet oyuncusu verir'; end if;
  if exists(select 1 from oyun.sokak_tahliye_bekle b where b.eylem_id=x.id and b.bitis>t) then raise exception 'Başarısız operasyondan sonra 12 saat bekleme var'; end if;
  select id into iid from oyun.sokak_isgal where eylem_id=x.id and durum='aktif' and bitis>t limit 1;
  if iid is null then raise exception 'İşgal yok'; end if;
  if exists(select 1 from oyun.sokak_tahliye q where q.isgal_id=iid and q.durum='geri_sayim' and q.bitis>t) then raise exception 'Geri sayım sürüyor'; end if;
  perform oyun.sokak_icisleri_ode(250000,'Tahliye operasyonu eylem #'||x.id);
  insert into oyun.sokak_tahliye(isgal_id,yapan,bedel,bas,bitis,durum) values(iid,u,250000,t,t+interval '30 minutes','geri_sayim');
  perform oyun.sokak_duyur(x.id,'Tahliye emri: 30 dakika. Hükümet operasyona katılır, işgalciler binayı savunur.');
  return jsonb_build_object('tamam',true,'bedel',250000,'bitis',t+interval '30 minutes');

 elsif p_islem='operasyon' then
  if not oyun.sokak_iktidar(u) and not oyun.sokak_sert_yetkili(u,x.il_id) then raise exception 'Operasyona iktidar ya da yetkili katılır'; end if;
  select q.id into qid from oyun.sokak_tahliye q join oyun.sokak_isgal i on i.id=q.isgal_id
   where i.eylem_id=x.id and q.durum='geri_sayim' and q.bitis>t limit 1;
  if qid is null then raise exception 'Açık tahliye emri yok'; end if;
  insert into oyun.sokak_tahliye_katilim(tahliye_id,user_id,taraf) values(qid,u,'hukumet') on conflict do nothing;
  return jsonb_build_object('tamam',true);

 elsif p_islem='savun' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Binayı eylemin içindeki oyuncu savunur'; end if;
  select q.id into qid from oyun.sokak_tahliye q join oyun.sokak_isgal i on i.id=q.isgal_id
   where i.eylem_id=x.id and q.durum='geri_sayim' and q.bitis>t limit 1;
  if qid is null then raise exception 'Açık tahliye emri yok'; end if;
  insert into oyun.sokak_tahliye_katilim(tahliye_id,user_id,taraf) values(qid,u,'savun') on conflict do nothing;
  return jsonb_build_object('tamam',true);

 else raise exception 'Bilinmeyen eylem merkezi işlemi'; end if;
end $$;

create or replace function public.sokak_eylem_merkezi() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); arr jsonb; carpan numeric;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform oyun.sokak_merkez_tick();
 carpan:=oyun.pazar_tl_milyar();
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',e.id,'il_id',e.il_id,'seviye',e.seviye,
  'katilim',(select count(*) from oyun.sokak_eylem_destek d where d.eylem_id=e.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet'),
  'memnuniyet',(select memnuniyet from oyun.il_durum where il_id=e.il_id),
  'nabiz',oyun.sokak_memnuniyetsizlik(e.il_id),
  'yetkili',oyun.sokak_sert_yetkili(u,e.il_id),
  'katilimci',oyun.sokak_katilimci(e.id,u),
  'iktidar',oyun.sokak_iktidar(u),
  'vekil',exists(select 1 from oyun.makamlar m where m.user_id=u and m.tur='mv' and m.bit is null),
  'il_ici',(select il_id from oyun.profiller where id=u)=e.il_id,
  'saat',extract(hour from t at time zone 'Europe/Istanbul')::int,
  'hazine',(select jsonb_build_object('toplam_tl',round(s.toplam*carpan),'saatlik_tl',round(s.saatlik*carpan),'toplam_milyar',s.toplam,'saatlik_milyar',s.saatlik)
     from oyun.sokak_hazine_sayac s where s.eylem_id=e.id),
  'hamleler',coalesce((select jsonb_agg(jsonb_build_object('tur',h.tur,'ad',oyun.sokak_hamle_ad(h.tur),'durum',h.durum,'bitis',h.bitis,'bedel',h.bedel) order by h.zaman desc)
     from oyun.sokak_hamle h where h.eylem_id=e.id and (h.bitis>t or h.zaman>t-interval '6 hours')),'[]'::jsonb),
  'isgal',(select jsonb_build_object('id',i.id,'bina',i.bina,'durum',i.durum,'guc',i.guc,'bitis',i.bitis,
      'nobet',(select count(*) from oyun.sokak_vardiya v where v.isgal_id=i.id and v.taraf='isgal' and v.bitis>t),
      'kusatma',(select count(*) from oyun.sokak_vardiya v where v.isgal_id=i.id and v.taraf='kusatma' and v.bitis>t),
      'ziyaret',(select count(*) from oyun.sokak_vardiya v where v.isgal_id=i.id and v.taraf='ziyaret' and v.bitis>t),
      'tahliye',(select jsonb_build_object('id',q.id,'bitis',q.bitis,'durum',q.durum,'sonuc',q.sonuc,
         'hukumet',(select count(*) from oyun.sokak_tahliye_katilim k where k.tahliye_id=q.id and k.taraf='hukumet'),
         'savun',(select count(*) from oyun.sokak_tahliye_katilim k where k.tahliye_id=q.id and k.taraf='savun'))
         from oyun.sokak_tahliye q where q.isgal_id=i.id order by q.id desc limit 1),
      'teklif',(select jsonb_build_object('id',z.id,'metin',z.metin,'durum',z.durum,'bitis',z.bitis) from oyun.sokak_muzakere z where z.isgal_id=i.id and z.durum='oy' and z.bitis>t limit 1))
    from oyun.sokak_isgal i where i.eylem_id=e.id and (i.durum='aktif' or i.bitis>t-interval '2 hours') order by i.id desc limit 1),
  'sizmalar',case when oyun.sokak_katilimci(e.id,u) or oyun.sokak_sert_yetkili(u,e.il_id) then
    coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'durum',s.durum,'ad',case when s.durum='ifsa' then oyun.kad(s.user_id) else 'gizli' end,
      'notlar',(select jsonb_agg(n.metin order by n.zaman desc) from (select metin,zaman from oyun.sokak_sizma_not n where n.sizma_id=s.id order by n.zaman desc limit 3) n)))
     from oyun.sokak_sizma s where s.eylem_id=e.id),'[]'::jsonb) else '[]'::jsonb end
 ) order by e.id),'[]'::jsonb) into arr
 from oyun.sokak_eylem e where e.durum='aktif' and e.bitis>t;
 return jsonb_build_object('tamam',true,'eylemler',arr,
  'kabine',exists(select 1 from oyun.makamlar m where m.user_id=u and m.bit is null and m.tur in ('cb','bakan')));
end $$;

-- Gelir kırpma ve bina kararı: fonksiyon gövdesine dokunulmaz.
create or replace function oyun.sokak_il_gelir_kirp() returns trigger
language plpgsql set search_path='' as $$
declare kes numeric:=0; t timestamptz:=oyun.simdi();
begin
 if new.kasa is null or old.kasa is null or new.kasa<=old.kasa then return new; end if;
 if exists(select 1 from oyun.sokak_hamle h join oyun.sokak_eylem e on e.id=h.eylem_id
           where e.il_id=new.il_id and e.durum='aktif' and h.tur='grev' and h.durum='aktif' and h.bitis>t) then kes:=kes+0.40; end if;
 if exists(select 1 from oyun.sokak_hamle h join oyun.sokak_eylem e on e.id=h.eylem_id
           where e.il_id=new.il_id and e.durum='aktif' and h.tur='yol' and h.durum='aktif' and h.bitis>t) then kes:=kes+0.20; end if;
 if exists(select 1 from oyun.sokak_hamle h join oyun.sokak_eylem e on e.id=h.eylem_id
           where e.il_id=new.il_id and e.durum='aktif' and h.tur='vergi' and h.durum='aktif' and h.bitis>t) then kes:=kes+0.25; end if;
 if kes>0.70 then kes:=0.70; end if;
 if kes>0 then new.kasa:=old.kasa+(new.kasa-old.kasa)*(1-kes); end if;
 return new;
end $$;
create or replace function oyun.sokak_taktik_engel() returns trigger
language plpgsql set search_path='' as $$
begin
 if exists(select 1 from oyun.sokak_aclik a where a.eylem_id=new.eylem_id and a.user_id=new.user_id and a.bitis>oyun.simdi()) then
  raise exception 'Açlık grevinde taktik uygulanamaz'; end if;
 if exists(select 1 from oyun.sokak_men m where m.eylem_id=new.eylem_id and m.user_id=new.user_id and m.bitis>oyun.simdi()) then
  raise exception 'Tahliye sonrası 6 saat taktik yok'; end if;
 return new;
end $$;
create or replace function oyun.sokak_kalkan_engel() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.tur in ('ihale','mali') and exists(select 1 from oyun.sokak_hamle h where h.eylem_id=new.eylem_id and h.tur='kalkan' and h.durum='aktif' and h.bitis>oyun.simdi()) then
  raise exception 'Boykot kalkanı bu ekonomik önlemi durdurdu'; end if;
 return new;
end $$;
create or replace function oyun.sokak_bina_karar_engel() returns trigger
language plpgsql set search_path='' as $$
begin
 if exists(select 1 from oyun.sokak_isgal i where i.il_id=new.il_id and i.bina=tg_argv[0] and i.durum='aktif' and i.bitis>oyun.simdi()) then
  if tg_op='INSERT' or (tg_op='UPDATE' and new.durum is distinct from old.durum and new.durum in ('insa','aktif')) then
   raise exception 'Bu ilde % binası sembolik işgal altında; yeni karar yazılamaz', tg_argv[0];
  end if;
 end if;
 return new;
end $$;

do $$ begin
 if to_regclass('oyun.il_durum') is not null then
  drop trigger if exists sokak_il_gelir_kirp on oyun.il_durum;
  create trigger sokak_il_gelir_kirp before update of kasa on oyun.il_durum
   for each row execute function oyun.sokak_il_gelir_kirp();
 end if;
 if to_regclass('oyun.sokak_taktik') is not null then
  drop trigger if exists sokak_taktik_engel on oyun.sokak_taktik;
  create trigger sokak_taktik_engel before insert on oyun.sokak_taktik
   for each row execute function oyun.sokak_taktik_engel();
 end if;
 if to_regclass('oyun.sokak_sert') is not null then
  drop trigger if exists sokak_kalkan_engel on oyun.sokak_sert;
  create trigger sokak_kalkan_engel before insert on oyun.sokak_sert
   for each row execute function oyun.sokak_kalkan_engel();
 end if;
 if to_regclass('oyun.belediye_bina') is not null then
  drop trigger if exists sokak_belediye_isgal on oyun.belediye_bina;
  create trigger sokak_belediye_isgal before insert or update on oyun.belediye_bina
   for each row execute function oyun.sokak_bina_karar_engel('belediye');
 end if;
 if to_regclass('oyun.belediye_ekonomi_karar') is not null then
  drop trigger if exists sokak_belediye_ekonomi_isgal on oyun.belediye_ekonomi_karar;
  create trigger sokak_belediye_ekonomi_isgal before insert on oyun.belediye_ekonomi_karar
   for each row execute function oyun.sokak_bina_karar_engel('belediye');
 end if;
 if to_regclass('oyun.icisleri_atama') is not null then
  drop trigger if exists sokak_valilik_isgal on oyun.icisleri_atama;
  create trigger sokak_valilik_isgal before insert on oyun.icisleri_atama
   for each row execute function oyun.sokak_bina_karar_engel('valilik');
 end if;
 if exists(select 1 from pg_extension where extname='pg_cron') then
  if not exists(select 1 from cron.job where jobname='sokak-merkez') then
   perform cron.schedule('sokak-merkez','*/5 * * * *','select oyun.sokak_merkez_tick()');
  end if;
 end if;
end $$;

revoke all on function oyun.sokak_hamle_ad(text),oyun.sokak_org_ode(oyun.sokak_eylem,numeric,text),oyun.sokak_icisleri_ode(numeric,text),
 oyun.sokak_merkez_tick(),oyun.sokak_il_gelir_kirp(),oyun.sokak_taktik_engel(),oyun.sokak_kalkan_engel(),oyun.sokak_bina_karar_engel(),
 public.sokak_eylem_merkezi_islem(bigint,text,jsonb),public.sokak_eylem_merkezi()
 from public,anon,authenticated;
grant execute on function public.sokak_eylem_merkezi_islem(bigint,text,jsonb),public.sokak_eylem_merkezi() to authenticated;
