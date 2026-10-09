-- 2026-10-09: illere göre sınırlı mülk arzı, haftalık belediye emlak vergisi, gerçek 600 sandalye
-- Mevcut mülkler ve oyuncu makamları korunur. Eski mülk alım çağrısı da çalışır.
alter table oyun.yatirim_mulkleri add column if not exists emlak_vergi_son timestamptz not null default now();
create table if not exists oyun.emlak_vergi_politika (
  id integer primary key check (id=1),
  ulusal_oran numeric not null default 0.30 check (ulusal_oran between 0 and 1.5),
  guncelleme timestamptz not null default now()
);
insert into oyun.emlak_vergi_politika(id,ulusal_oran) values(1,0.30) on conflict(id) do nothing;
create table if not exists oyun.emlak_il_vergi (
  il_id smallint primary key references oyun.iller(id),
  oran numeric not null check(oran between 0 and 1.5),
  baskan uuid references oyun.profiller(id),
  guncelleme timestamptz not null default now()
);
create table if not exists oyun.emlak_vergi_kayit (
 id bigint generated always as identity primary key,
 mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 user_id uuid not null references oyun.profiller(id),
 il_id smallint not null references oyun.iller(id),
 haftalar int not null check(haftalar between 1 and 520),
 oran numeric not null,
 tutar numeric not null,
 zaman timestamptz not null default now()
);
create index if not exists emlak_vergi_kayit_user on oyun.emlak_vergi_kayit(user_id,zaman);
do $$declare tab text;begin
 foreach tab in array array['emlak_vergi_politika','emlak_il_vergi','emlak_vergi_kayit'] loop
 execute format('alter table oyun.%I enable row level security',tab);
 execute format('revoke all on oyun.%I from public,anon,authenticated',tab);
 end loop;
end$$;

create or replace function oyun.emlak_vergi_oran(p_il smallint) returns numeric
language sql stable set search_path='' as $$
 select coalesce((select oran from oyun.emlak_il_vergi where il_id=p_il),
                 (select ulusal_oran from oyun.emlak_vergi_politika where id=1),0.30)
$$;

-- İl bazındaki arz, gerçek nüfusun oyundaki vekil ağırlığına göre modellenmiş yaklaşımıdır.
-- İstanbul: 100 daire, Bayburt: 8 daire. Dükkan ve villalar daha sınırlıdır.
create or replace function oyun.emlak_kapasite(p_il smallint,p_tip text)
returns int language sql stable set search_path='' as $$
 select case p_tip
 when 'daire' then z.n
 when 'dukkan' then greatest(3,round(z.n * 0.35)::int)
 when 'villa' then greatest(2,round(z.n * 0.16)::int)
 else 0 end
 from (select (8+round(92 * power(greatest(0,least(1,((i.mv::numeric-1)/95))),0.80)))::int n
       from oyun.iller i where i.id=p_il) z
$$;
create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000
                      when 'villa' then 520000 else 0 end) *
  (0.65 + power(greatest(0.01,i.mv::numeric/96),0.70)*1.25 + least(100,greatest(0,d.gelisim))/100.0*0.35)/1000)*1000
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function public.emlak_sehirler() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',i.id,'ad',i.ad,'gelisim',round(d.gelisim,1),
   'tipler',(select jsonb_agg(jsonb_build_object('tip',tip,'fiyat',oyun.emlak_fiyat(i.id,tip),
      'haftalik',round(oyun.emlak_fiyat(i.id,tip)*0.025),
      'kapasite',oyun.emlak_kapasite(i.id,tip),
      'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=tip),
      'kalan',greatest(0,oyun.emlak_kapasite(i.id,tip)-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=tip)))
    order by sira) from (values('daire',1),('dukkan',2),('villa',3)) x(tip,sira)),
   'emlak_vergi_oran',oyun.emlak_vergi_oran(i.id))
 order by i.ad),'[]'::jsonb)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_sehirler() from public,anon;
grant execute on function public.emlak_sehirler() to authenticated;

-- Aynı şehirden iki eşzamanlı satın alma stok sınırını geçiremez.
create or replace function public.mulk_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); bedel numeric; kira numeric;
        yeni bigint; adet int; stok int; il_ad text;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Profil gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk tipi.'; end if;
 select i.ad into il_ad from oyun.iller i where i.id=p_il;
 if il_ad is null then raise exception 'Önce bir il seç.'; end if;
 perform 1 from oyun.il_durum d where d.il_id=p_il for update;
 stok:=oyun.emlak_kapasite(p_il,p_tip);
 select count(*) into adet from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if adet>=stok then raise exception '% ilinde % için satılabilir yeni mülk kalmadı. Oyuncu ilanlarından satın alabilirsin.',il_ad,p_tip; end if;
 bedel:=oyun.emlak_fiyat(p_il,p_tip);kira:=round(bedel*0.025);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s - %s satın alındı',il_ad,p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira,emlak_vergi_son)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days',t) returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,il_ad||' '||p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;

-- Önceki sürüm istemcilerindeki tek parametreli API da aynı stok kurallarını kullanır.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language sql security definer set search_path='' as $$
 select public.mulk_satin_al(p_tip,(select il_id from oyun.profiller where id=auth.uid()))
$$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- İkinci el mülk el değiştirdiğinde eski sahibin tahakkuku alıcıya yüklenmez.
create or replace function oyun.emlak_devri_vergi_sifirla()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.user_id is distinct from old.user_id then new.emlak_vergi_son:=oyun.simdi(); end if;
 return new;
end $$;
drop trigger if exists emlak_devri_vergi_sifirla on oyun.yatirim_mulkleri;
create trigger emlak_devri_vergi_sifirla before update of user_id on oyun.yatirim_mulkleri
for each row execute function oyun.emlak_devri_vergi_sifirla();

create or replace function oyun.emlak_vergi_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare x record; t timestamptz:=oyun.simdi(); n int; oran numeric; borc numeric;
begin
 for x in select * from oyun.yatirim_mulkleri where user_id=p_user
  and emlak_vergi_son<=t-interval '7 days' order by id for update loop
  n:=least(520,floor(extract(epoch from (t-x.emlak_vergi_son))/604800)::int);
  if n<1 then continue;end if;
  oran:=oyun.emlak_vergi_oran(x.il_id);
  borc:=round(x.alis_bedeli * oran/100*n);
  if borc>0 then
   perform oyun.para_islem(p_user,-borc,'emlak_vergi',format('Mülk #%s: %s haftalık emlak vergisi (%%%s)',x.id,n,oran),t,borc);
   update oyun.il_durum set kasa=kasa+borc/1000000000.0 where il_id=x.il_id;
  end if;
  insert into oyun.emlak_vergi_kayit(mulk_id,user_id,il_id,haftalar,oran,tutar,zaman)
  values(x.id,p_user,x.il_id,n,oran,borc,t);
  update oyun.yatirim_mulkleri set emlak_vergi_son=emlak_vergi_son+n*interval '7 days' where id=x.id;
 end loop;
end $$;
revoke all on function oyun.emlak_vergi_tahsil(uuid) from public,anon,authenticated;

create or replace function public.emlak_vergi_durum(p_il smallint default null)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('ulusal',(select ulusal_oran from oyun.emlak_vergi_politika where id=1),
 'il',p_il,'oran',case when p_il is null then null else oyun.emlak_vergi_oran(p_il) end,
 'toplam',(select coalesce(sum(tutar),0) from oyun.emlak_vergi_kayit where user_id=auth.uid()),
 'son_kayitlar',(select coalesce(jsonb_agg(jsonb_build_object('il',i.ad,'mulk',x.mulk_id,'tutar',x.tutar,'oran',x.oran,'zaman',x.zaman)
 order by x.zaman desc),'[]'::jsonb) from
 (select * from oyun.emlak_vergi_kayit where user_id=auth.uid() order by zaman desc limit 10) x
 join oyun.iller i on i.id=x.il_id))
$$;
revoke all on function public.emlak_vergi_durum(smallint) from public,anon;
grant execute on function public.emlak_vergi_durum(smallint) to authenticated;

create or replace function public.belediye_emlak_vergi_ayarla(p_oran numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); il smallint; eski numeric; t timestamptz:=oyun.simdi(); ad text;
begin
 select il_id into il from oyun.makamlar where user_id=u and tur='bel' and bit is null limit 1;
 if il is null then raise exception 'Yalnızca görevdeki belediye başkanı emlak vergisini değiştirebilir.'; end if;
 if p_oran is null or p_oran<0 or p_oran>1.5 then raise exception 'Emlak vergisi %%0 ile %%1,5 arasında olmalı.'; end if;
 select oran into eski from oyun.emlak_il_vergi where il_id=il;
 if exists(select 1 from oyun.emlak_il_vergi where il_id=il and guncelleme>t-interval '24 hours') then
  raise exception 'Emlak vergisi 24 saatte bir değiştirilebilir.'; end if;
 insert into oyun.emlak_il_vergi(il_id,oran,baskan,guncelleme) values(il,round(p_oran,2),u,t)
 on conflict(il_id) do update set oran=excluded.oran,baskan=u,guncelleme=t;
 select ad into ad from oyun.iller where id=il;
 perform oyun.olay('belediye',format('%s Belediyesi haftalık emlak vergisini %%%s yaptı.',ad,round(p_oran,2)),il,null,t);
 return jsonb_build_object('il',il,'oran',round(p_oran,2),'onceki',eski);
end $$;
revoke all on function public.belediye_emlak_vergi_ayarla(numeric) from public,anon;
grant execute on function public.belediye_emlak_vergi_ayarla(numeric) to authenticated;

-- İlgili kanun normal Meclis teklif/oy/onay akışına girer. Yürürlüğe girince oran değişir.
create or replace function public.emlak_vergi_kanun_teklif(p_oran numeric,p_gerekce text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb; idd bigint;
begin
 if p_oran is null or p_oran not between 0 and 1.5 then raise exception 'Emlak vergisi %%0-%%1,5 arasında olmalı.'; end if;
 r:=public.kanun_teklif('serbest','Haftalık emlak vergisinin düzenlenmesi',
 coalesce(nullif(btrim(p_gerekce),''),'Belediyelerin gayrimenkul gelirlerini düzenleyen haftalık emlak vergisi oranının değiştirilmesi.'),null);
 idd:=(r->>'id')::bigint;
 update oyun.kanunlar set veri=jsonb_build_object('eylem','emlak_vergisi','oran',round(p_oran,2)) where id=idd;
 return r||jsonb_build_object('oran',round(p_oran,2));
end $$;
revoke all on function public.emlak_vergi_kanun_teklif(numeric,text) from public,anon;
grant execute on function public.emlak_vergi_kanun_teklif(numeric,text) to authenticated;

create or replace function oyun.emlak_vergi_kanun_yururluk()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.durum='yururlukte' and old.durum is distinct from new.durum
  and new.veri->>'eylem'='emlak_vergisi' then
  update oyun.emlak_vergi_politika set ulusal_oran=(new.veri->>'oran')::numeric,guncelleme=oyun.simdi() where id=1;
 end if;
 return new;
end $$;
drop trigger if exists emlak_vergi_kanun_yururluk on oyun.kanunlar;
create trigger emlak_vergi_kanun_yururluk after update of durum on oyun.kanunlar
for each row execute function oyun.emlak_vergi_kanun_yururluk();
CREATE OR REPLACE FUNCTION oyun.mulk_kira_tahsil(p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare m record;n int;gross numeric;tax numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
       then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  perform oyun.para_islem(p_user,gross-tax,'kira',format('Mulk #%s: %s haftalik kira, vergi %s TL',m.id,n,tax),t,tax);
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',toplam_kira=toplam_kira+gross-tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
 perform oyun.emlak_vergi_tahsil(p_user);
end $function$

CREATE OR REPLACE FUNCTION public.mulk_liste()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; j jsonb;
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.profiller where id=u;
 if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
 perform oyun.mulk_kira_tahsil(u);
 select jsonb_build_object(
   'mulkler',coalesce(jsonb_agg(jsonb_build_object(
      'id',m.id,'tip',m.tip,'il',i.ad,'alis',m.alis_bedeli,
      'haftalik',m.haftalik_kira,'sonraki',m.sonraki_kira,
      'toplam_kira',m.toplam_kira,'kira_sayisi',m.kira_sayisi
   ) order by m.satin_alma desc,m.id desc),'[]'::jsonb),
   'adet',count(m.id),
   'haftalik_toplam',coalesce(sum(m.haftalik_kira),0),
   'mulk_degeri',coalesce(sum(m.alis_bedeli),0),
   'cuzdan',(select para from oyun.cuzdan where user_id=u)
 ) into j
 from oyun.yatirim_mulkleri m join oyun.iller i on i.id=m.il_id where m.user_id=u;
 return j||jsonb_build_object('haftalik_emlak_vergisi',
 (select coalesce(sum(round(m.alis_bedeli*oyun.emlak_vergi_oran(m.il_id)/100)),0) from oyun.yatirim_mulkleri m where m.user_id=u),
 'toplam_emlak_vergisi', (select coalesce(sum(tutar),0) from oyun.emlak_vergi_kayit where user_id=u));
end $function$

CREATE OR REPLACE FUNCTION oyun.kanun_tick(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare k oyun.kanunlar; c record; dolu int; cb uuid; s record;
begin
  select * into s from oyun.kanun_suresi();
  -- anayasa değişikliği: görüşme bitince imza sayısı dolu sandalyelerin üçte birine ulaşmadıysa teklif düşer
  for k in select * from oyun.kanunlar where durum = 'gorusmede' and tur = 'anayasa' and t >= oy_bas order by oy_bas loop
    dolu := oyun.dolu_sandalye();
    if (select count(*) from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza') < ceil(dolu / 3.0) then
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bas,
        sonuc_metin = format('Yeterli imza toplanamadı: %s imza, en az %s gerekliydi (dolu sandalyelerin üçte biri).',
                             (select count(*) from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza'), ceil(dolu / 3.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" anayasa değişikliği teklifin yeterli imza toplayamadı.', k.baslik), k.oy_bas);
    end if;
  end loop;
  update oyun.kanunlar set durum = 'oylamada' where durum = 'gorusmede' and t >= oy_bas;
  for k in select * from oyun.kanunlar where durum = 'oylamada' and tur = 'anayasa' and t >= oy_bit order by oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.dolu_sandalye();
    cb := oyun.aktif_cb();
    if dolu > 0 and c.kabul >= ceil(dolu * 2 / 3.0) and cb is not null then
      update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
        sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: üçte iki çoğunluk sağlandı.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.bildir(cb, format('"%s" anayasa değişikliği Meclis''ten üçte iki çoğunlukla geçti. 48 saat içinde yayımla ya da halkoyuna sun.', k.baslik), k.oy_bit);
      perform oyun.olay('meclis', format('"%s" anayasa değişikliği üçte iki çoğunlukla kabul edildi (%s kabul). Cumhurbaşkanına sunuldu.', k.baslik, c.kabul), null, k.teklif_parti, k.oy_bit);
    elsif dolu > 0 and c.kabul >= ceil(dolu * 3 / 5.0) then
      update oyun.kanunlar set sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: beşte üç çoğunlukla kabul edildi, halkoyuna sunuluyor.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.referandum_baslat(k.id, k.oy_bit);
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bit,
        sonuc_metin = format('Reddedildi: gizli oylamada %s kabul oyu çıktı; halkoyuna sunulması için en az %s (beşte üç) gerekliydi.', c.kabul, ceil(dolu * 3 / 5.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" anayasa değişikliği teklifin Meclis''te gerekli çoğunluğu alamadı.', k.baslik), k.oy_bit);
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'oylamada' and tur <> 'anayasa' and t >= oy_bit order by oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.dolu_sandalye();
    if dolu > 0 and c.kabul + c.ret + c.cekimser >= ceil(dolu / 3.0) and c.kabul > c.ret and c.kabul >= floor(dolu / 2.0) + 1 then
      cb := oyun.aktif_cb();
      if cb is null then
        perform oyun.kanun_yururluk(k.id, k.oy_bit, format('Meclis''te %s kabul, %s ret oyla kabul edildi (cumhurbaşkanı makamı boş).', c.kabul, c.ret));
      else
        update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
          sonuc_metin = format('Meclis''te %s kabul, %s ret, %s çekimser oyla kabul edildi.', c.kabul, c.ret, c.cekimser) where id = k.id;
        perform oyun.bildir(cb, format('"%s" kanunu Meclis''ten geçti ve onayınızı bekliyor. 48 saat içinde onaylayın ya da veto edin.', k.baslik), k.oy_bit);
        perform oyun.olay('meclis', format('"%s" Meclis''te kabul edildi (%s kabul, %s ret). Cumhurbaşkanının onayına sunuldu.', k.baslik, c.kabul, c.ret), null, k.teklif_parti, k.oy_bit);
      end if;
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bit,
        sonuc_metin = case when c.kabul + c.ret + c.cekimser < ceil(dolu / 3.0) then format('Toplantı yeter sayısı sağlanamadı (%s vekil katıldı, en az %s gerekliydi).', c.kabul + c.ret + c.cekimser, ceil(dolu / 3.0))
                           else format('Reddedildi: %s kabul, %s ret, %s çekimser (kabul için en az %s ve retten fazla oy gerekliydi).', c.kabul, c.ret, c.cekimser, floor(dolu / 2.0) + 1) end
      where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" teklifin Meclis''te kabul edilmedi.', k.baslik), k.oy_bit);
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'cb_onayinda' and t >= cb_bit order by cb_bit loop
    perform oyun.kanun_yururluk(k.id, k.cb_bit, case when k.tur = 'anayasa' then 'Cumhurbaşkanı süresi içinde halkoyuna sunmadığı için yayımlanarak yürürlüğe girdi.'
                                                    else 'Cumhurbaşkanı süresi içinde karar vermediği için kendiliğinden yürürlüğe girdi.' end);
  end loop;
  for k in select * from oyun.kanunlar where durum = 'israr' and t >= israr_bit order by israr_bit loop
    select * into c from oyun.kanun_say(k.id, 'israr');
    dolu := oyun.dolu_sandalye();
    if dolu > 0 and c.kabul >= floor(dolu / 2.0) + 1 then
      perform oyun.kanun_yururluk(k.id, k.israr_bit, format('Veto sonrası Meclis %s oyla ısrar etti.', c.kabul));
    else
      update oyun.kanunlar set durum = 'dustu', sonuc_at = k.israr_bit,
        sonuc_metin = format('Veto sonrası ısrar için %s oy gerekiyordu, %s kabul oyu çıktı. Kanun düştü.', floor(dolu / 2.0) + 1, c.kabul) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" veto sonrası ısrar oylamasında düştü.', k.baslik), k.israr_bit);
    end if;
  end loop;
  -- seçim döneminde kabul edilen baraj, seçim bitince uygulanır
  if (select bekleyen_baraj from oyun.ulke where id = 1) is not null
     and not exists (select 1 from oyun.secimler o join oyun.secimler g on g.donem = o.donem and g.tur = 'mv'
                     where o.tur = 'mv_on' and t >= o.basvuru_bas and g.durum = 'bekliyor') then
    update oyun.ayarlar set baraj = (select bekleyen_baraj from oyun.ulke where id = 1) where id = 1;
    update oyun.ulke set bekleyen_baraj = null where id = 1;
  end if;
end $function$

CREATE OR REPLACE FUNCTION oyun.meclis_olcek_hesap(t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare a numeric := (select meclis_olcek from oyun.ayarlar where id = 1);
        anayasal int := coalesce((select round(deger)::int from oyun.anayasa where kod = 'milletvekili_sayisi'), 600);
        aktif int := (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '14 days');
        n int;
begin
  n := anayasal; -- Her seçimde anayasal sandalye sayısı, aktif oyuncudan bağımsız.
  return jsonb_build_object('aktif', aktif, 'sandalye', n, 'anayasal', anayasal, 'olcek', a);
end $function$

update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
