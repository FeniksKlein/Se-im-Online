-- 2026-10-09: Provincial property stock, variable prices and rent, weekly municipal tax, 600 MV and active-member majority.
-- Existing owned properties, elections and wallets remain intact.
create table if not exists oyun.emlak_ulusal_vergi (
 id int primary key check(id=1), oran numeric(5,2) not null default 0.50 check(oran between 0 and 2),
 guncelleme timestamptz not null default now()
);
insert into oyun.emlak_ulusal_vergi(id,oran) values(1,0.50) on conflict(id) do nothing;
create table if not exists oyun.emlak_il_vergi (
 il_id smallint primary key references oyun.iller(id), fark numeric(5,2) not null default 0 check(fark between -2 and 2),
 guncelleme timestamptz
);
insert into oyun.emlak_il_vergi(il_id,fark) select id,0 from oyun.iller on conflict(il_id) do nothing;
create table if not exists oyun.emlak_stok (
 il_id smallint not null references oyun.iller(id),
 tip text not null check(tip in ('daire','dukkan','villa')),
 kapasite int not null check(kapasite>=1),
 primary key(il_id,tip)
);
-- mv is the existing population-weighted allocation (Istanbul=96; Bayburt=1).
-- Istanbul: 100 apartments; Bayburt: 8 apartments, stores / villas proportionally.
insert into oyun.emlak_stok(il_id,tip,kapasite)
select i.id,t.tip,greatest(
 case t.tip when 'daire' then greatest(8,least(100,ceil(i.mv::numeric*100/96)::int))
 when 'dukkan' then greatest(2,ceil(greatest(8,least(100,ceil(i.mv::numeric*100/96)::int))*.40)::int)
 else greatest(2,ceil(greatest(8,least(100,ceil(i.mv::numeric*100/96)::int))*.15)::int) end,
 (select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=t.tip)
)
from oyun.iller i cross join (values('daire'),('dukkan'),('villa')) as t(tip)
on conflict(il_id,tip) do nothing;
create table if not exists oyun.emlak_vergisi_kayit(
 id bigint generated always as identity primary key,
 mulk_id bigint not null, user_id uuid not null, il_id smallint not null references oyun.iller(id),
 haftalar int not null, oran numeric not null, tahsil numeric not null, zaman timestamptz not null
);
create index if not exists emlak_vergi_il on oyun.emlak_vergisi_kayit(il_id,zaman);
do $do$ declare tn text; begin
 foreach tn in array array['emlak_ulusal_vergi','emlak_il_vergi','emlak_stok','emlak_vergisi_kayit'] loop
  execute format('alter table oyun.%I enable row level security',tn);
  execute format('revoke all on oyun.%I from public,anon,authenticated',tn);
 end loop;
end $do$;
create or replace function oyun.emlak_vergi_oran(p_il smallint) returns numeric
language sql stable set search_path='' as $fn$
 select greatest(0,least(2,(select oran from oyun.emlak_ulusal_vergi where id=1)
  +coalesce((select fark from oyun.emlak_il_vergi where il_id=p_il),0)))
$fn$;
create or replace function oyun.emlak_bedel(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $fn$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end)
  * (0.70+1.60*sqrt(i.mv::numeric/96))
  * greatest(0.75,least(1.25,coalesce(d.gelisim,50)/50)),0)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$fn$;
create or replace function public.emlak_sehirler() returns jsonb
language sql stable security definer set search_path='' as $fn$
 select jsonb_build_object('iller',coalesce(jsonb_agg(jsonb_build_object(
  'id',i.id,'ad',i.ad,'gelisim',coalesce(d.gelisim,50),'emlak_orani',oyun.emlak_vergi_oran(i.id),
  'mulkler',(select jsonb_agg(jsonb_build_object('tip',st.tip,'stok',st.kapasite,
   'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=st.tip),
   'kalan',greatest(0,st.kapasite-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=st.tip)),
   'fiyat',oyun.emlak_bedel(i.id,st.tip),'haftalik_kira',round(oyun.emlak_bedel(i.id,st.tip)*.025))
   order by case st.tip when 'daire' then 1 when 'dukkan' then 2 else 3 end)
   from oyun.emlak_stok st where st.il_id=i.id)
 ) order by i.ad),'[]'::jsonb))
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id
$fn$;
revoke all on function public.emlak_sehirler() from public,anon;
grant execute on function public.emlak_sehirler() to authenticated;

create or replace function public.mulk_satin_al_il(p_tip text,p_il smallint) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric;
 t timestamptz:=oyun.simdi(); yeni bigint; stok int; sayi int;
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null or p.yasakli then raise exception 'Etkin oyuncu hesabı gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_il is null then raise exception 'Geçerli bir il ve mülk türü seç.'; end if;
 -- Serializes purchases per province and type, preventing overselling.
 perform pg_advisory_xact_lock(987510,p_il::int*10 + case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 select kapasite into stok from oyun.emlak_stok where il_id=p_il and tip=p_tip;
 if stok is null then raise exception 'Bu ilde bu mülk türü satışta değil.'; end if;
 select count(*) into sayi from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if sayi>=stok then raise exception 'Bu ilde satılabilir % kalmadı. Diğer oyuncuların satış ilanlarını kontrol et.',p_tip; end if;
 bedel:=oyun.emlak_bedel(p_il,p_tip);
 kira:=round(bedel*.025,2);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s ilinde %s satın alındı',(select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,p_tip||' · il #'||p_il::text);
 return public.mulk_liste();
end $fn$;
revoke all on function public.mulk_satin_al_il(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al_il(text,smallint) to authenticated;
-- Legacy purchases respect the same stock and locality checks, cannot bypass caps.
create or replace function public.mulk_satin_al(p_tip text) returns jsonb
language sql security definer set search_path='' as $fn$
 select public.mulk_satin_al_il(p_tip,(select il_id from oyun.profiller where id=auth.uid()))
$fn$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function public.emlak_belediye_durum() returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar; v oyun.emlak_il_vergi;
begin
 select * into m from oyun.makamlar where user_id=p.id and tur='bel' and bit is null;
 if m.id is null then return null; end if;
 select * into v from oyun.emlak_il_vergi where il_id=m.il_id;
 return jsonb_build_object('il_id',m.il_id,'ulusal',(select oran from oyun.emlak_ulusal_vergi where id=1),
  'oran',oyun.emlak_vergi_oran(m.il_id),'son_degisim',v.guncelleme,
  'kasaya',coalesce((select sum(tahsil) from oyun.emlak_vergisi_kayit where il_id=m.il_id),0));
end $fn$;
revoke all on function public.emlak_belediye_durum() from public,anon;
grant execute on function public.emlak_belediye_durum() to authenticated;
create or replace function public.emlak_belediye_oran(p_oran numeric) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar:=oyun.baskan_zorunlu(p);
 t timestamptz:=oyun.simdi(); eski numeric:=oyun.emlak_vergi_oran(m.il_id);
 mevcut numeric:=(select oran from oyun.emlak_ulusal_vergi where id=1); once timestamptz;
begin
 if p_oran is null or p_oran<0 or p_oran>2 or p_oran<>round(p_oran,2) then
  raise exception 'Haftalık emlak vergisi %%0-%%2 arasında olmalı (0,01 adımla).'; end if;
 select guncelleme into once from oyun.emlak_il_vergi where il_id=m.il_id for update;
 if once>t-interval '24 hours' then raise exception 'Belediye emlak vergisini 24 saatte bir değiştirebilir.'; end if;
 if eski=p_oran then raise exception 'Emlak vergisi zaten bu oranda.'; end if;
 update oyun.emlak_il_vergi set fark=p_oran-mevcut,guncelleme=t where il_id=m.il_id;
 perform oyun.olay('belediye',format('%s Belediye Başkanı haftalık emlak vergisini %s%% yaptı.',
 (select ad from oyun.iller where id=m.il_id),p_oran),m.il_id,p.parti_id,t);
 return public.emlak_belediye_durum();
end $fn$;
revoke all on function public.emlak_belediye_oran(numeric) from public,anon;
grant execute on function public.emlak_belediye_oran(numeric) to authenticated;

-- Parliament proposes a regular bill: voting and presidential approval still apply.
create or replace function public.emlak_kanun_teklif(p_oran numeric) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare j jsonb; idd bigint;
begin
 if p_oran is null or p_oran not between 0 and 2 or p_oran<>round(p_oran,2) then
  raise exception 'Ulusal haftalık emlak vergisi %%0-%%2 aralığında olmalı.'; end if;
 j:=public.kanun_teklif('serbest',format('Ulusal emlak vergisi %s%% düzenlemesi',p_oran),
  format('Tüm illerde haftalık emlak vergisinin ulusal temel oranı %s%% olsun. Yerel belediyelerin mevcut fark kararları korunur.',p_oran),null);
 idd:=(j->>'id')::bigint;
 update oyun.kanunlar set veri=jsonb_build_object('eylem','emlak_vergisi','oran',p_oran) where id=idd;
 return j;
end $fn$;
revoke all on function public.emlak_kanun_teklif(numeric) from public,anon;
grant execute on function public.emlak_kanun_teklif(numeric) to authenticated;

-- Preserve old rent/tax safeguards; attach weekly municipal property tax.
CREATE OR REPLACE FUNCTION oyun.mulk_kira_tahsil(p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare m record;n int;gross numeric;tax numeric; emlak_tax numeric; emlak_oran numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
       then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  emlak_oran:=oyun.emlak_vergi_oran(m.il_id);
  emlak_tax:=least(greatest(0,gross-tax),round(m.alis_bedeli*emlak_oran/100*n,2));
  perform oyun.para_islem(p_user,gross-tax-emlak_tax,'kira',
    format('Mulk #%s: %s haftalik kira, genel vergi %s TL, belediye emlak vergisi %s TL',m.id,n,tax,emlak_tax),t,tax+emlak_tax);
  if emlak_tax>0 then
    update oyun.il_durum set kasa=kasa+emlak_tax/1000000000 where il_id=m.il_id;
    insert into oyun.emlak_vergisi_kayit(mulk_id,user_id,il_id,haftalar,oran,tahsil,zaman)
     values(m.id,p_user,m.il_id,n,emlak_oran,emlak_tax,t);
  end if;
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',toplam_kira=toplam_kira+gross-tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $function$
;

-- All ordinary laws: absolute majority of actually seated deputies, not 600.
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
;
CREATE OR REPLACE FUNCTION public.kanun_detay(p_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; dolu int := oyun.dolu_sandalye();
begin
  select * into k from oyun.kanunlar where id = p_id;
  if k.id is null then raise exception 'Kanun bulunamadı.'; end if;
  return oyun.kanun_ozet(k, p, t) || jsonb_build_object(
    'metin', k.metin, 'veri', k.veri, 'veto_gerekce', k.veto_gerekce, 'sonuc_metin', k.sonuc_metin,
    'kararname', case when k.tur = 'iptal' then (select jsonb_build_object('no', no, 'baslik', baslik) from oyun.kararnameler where id = (k.veri ->> 'kararname_id')::bigint) end,
    'dolu', dolu, 'toplanti_yeter', ceil(dolu / 3.0), 'karar_yeter', floor(dolu / 2.0) + 1, 'israr_yeter', floor(dolu / 2.0) + 1,
    'vekilim', oyun.aktif_vekil(p.id),
    'oy_acik', (k.durum = 'oylamada' and t >= k.oy_bas and t < k.oy_bit) or (k.durum = 'israr' and t < k.israr_bit),
    'benim_oyum', (select oy from oyun.kanun_oylari where kanun_id = k.id and vekil = p.id and asama = case when k.durum = 'israr' then 'israr' else 'ilk' end),
    'cb_karar_verebilir', k.durum = 'cb_onayinda' and t < k.cb_bit and oyun.aktif_cb() = p.id,
    'anayasa_aciklama', case when k.tur = 'anayasa' then oyun.anayasa_aciklama(k.veri) end,
    'grup', oyun.grup_karar_json(k.id, p), 'tbmm_baskani', exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null),
    'duzenleme', case when k.tur = 'duzenleme' then (select jsonb_build_object('ad', d.ad, 'yazi', oyun.duz_yaz(d.kod, (k.veri ->> 'deger')::numeric),
                    'mevcut', oyun.duz_yaz(d.kod, oyun.duz(d.kod)), 'oyuncu', d.oyuncu, 'devlet', d.devlet) from oyun.duzenleme_tanim d where d.kod = k.veri ->> 'kod') end,
    'imza_yeter', ceil(dolu / 3.0), 'uc_bes', ceil(dolu * 3 / 5.0), 'iki_uc', ceil(dolu * 2 / 3.0),
    'imzaladim', exists (select 1 from oyun.kanun_oylari where kanun_id = k.id and vekil = p.id and asama = 'imza'),
    'referandum', (select jsonb_build_object('id', r.id, 'oy_bas', r.oy_bas, 'durum', r.durum, 'sonuc', r.sonuc) from oyun.referandumlar r where r.kanun_id = k.id),
    'benim', k.teklif_eden = p.id,
    'oylar', (select jsonb_object_agg(a.asama, a.j) from (
       select o.asama, jsonb_build_object(
         'kabul', count(*) filter (where o.oy = 'kabul'), 'ret', count(*) filter (where o.oy = 'ret'), 'cekimser', count(*) filter (where o.oy = 'cekimser'),
         'liste', case when k.tur = 'anayasa' and o.asama = 'ilk' then '[]'::jsonb
                       else jsonb_agg(jsonb_build_object('kad', oyun.kad(o.vekil), 'oy', o.oy, 'parti', oyun.parti_json(o.parti_id),
                              'aykiri', o.asama <> 'imza' and exists (select 1 from oyun.grup_kararlari g where g.kanun_id = k.id and g.parti_id = o.parti_id
                                                                         and g.karar in ('kabul','ret') and g.karar <> o.oy)) order by o.parti_id, o.zaman) end) j
       from oyun.kanun_oylari o where o.kanun_id = k.id group by o.asama) a));
end $function$
;
CREATE OR REPLACE FUNCTION oyun.kanun_yururluk(p_id bigint, t timestamp with time zone, p_not text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  k oyun.kanunlar; v_no int; kr oyun.kararnameler; pencere boolean;
  uygulama jsonb; oran numeric; eski numeric;
begin
  select * into k from oyun.kanunlar where id=p_id for update;
  v_no:=nextval('oyun.kanun_no');
  update oyun.kanunlar set durum='yururlukte',no=v_no,sonuc_at=t,sonuc_metin=p_not where id=k.id;

  if k.tur='serbest' and k.veri->>'eylem'='emlak_vergisi' then
    oran:=(k.veri->>'oran')::numeric;
    if oran is null or oran<0 or oran>2 then raise exception 'Geçersiz emlak vergisi kanunu.'; end if;
    update oyun.emlak_ulusal_vergi set oran=oran,guncelleme=t where id=1;
    insert into oyun.bildirimler(user_id,zaman,metin)
     select id,t,format('Meclis, haftalık emlak vergisinin ulusal oranını %s%% olarak belirledi. Gelir mülkün bulunduğu belediyeye aktarılır.',oran)
     from oyun.profiller where not yasakli and son_gorulme>t-interval '14 days';
  elsif k.tur='serbest' and k.veri->>'eylem'='borc_affi' then
    uygulama:=oyun.borc_affi_uygula((k.veri->>'oran')::numeric,'kanun',k.id,k.teklif_parti,k.teklif_eden,t);
    update oyun.kanunlar set veri=veri || jsonb_build_object('uygulama',uygulama) where id=k.id;

  elsif k.tur='serbest' and k.veri->>'eylem'='vergi' then
    oran:=(k.veri->>'oran')::numeric;
    select vergi into eski from oyun.ulke where id=1;
    update oyun.ulke
       set vergi_kanun=oran,vergi=oran,
           vergi_alt=least(vergi_alt,oran),vergi_ust=greatest(vergi_ust,oran)
     where id=1;
    update oyun.kanunlar set veri=veri || jsonb_build_object('onceki_vergi',eski) where id=k.id;

    insert into oyun.bildirimler(user_id,zaman,metin)
    select id,t,format(
      'Meclis gelir vergisini %%%s olarak belirledi. Vergi maaş ve gelirlerinden yapılan kesintiyi, hazine gelirini, büyümeyi ve memnuniyeti etkiler.',oran)
    from oyun.profiller where not yasakli and son_gorulme>t-interval '14 days';

  elsif k.tur='butce' then
    update oyun.kanunlar set veri=veri || jsonb_build_object('onceki',
      (select jsonb_build_object('vergi_alt',vergi_alt,'vergi_ust',vergi_ust,'belediye_payi',belediye_payi,
        'parti_yardim',parti_yardim,'vergi',vergi) from oyun.ulke where id=1))
    where id=k.id;
    update oyun.ulke
       set vergi_alt=(k.veri->>'vergi_alt')::numeric,
           vergi_ust=(k.veri->>'vergi_ust')::numeric,
           vergi=oyun.sinir(vergi,(k.veri->>'vergi_alt')::numeric,(k.veri->>'vergi_ust')::numeric),
           belediye_payi=(k.veri->>'belediye_payi')::numeric,
           parti_yardim=(k.veri->>'parti_yardim')::numeric,
           butce=k.veri->'paylar'
     where id=1;

  elsif k.tur='secim' then
    select exists(select 1 from oyun.secimler o join oyun.secimler g on g.donem=o.donem and g.tur='mv'
      where o.tur='mv_on' and t>=o.basvuru_bas and g.durum='bekliyor') into pencere;
    if pencere then
      update oyun.ulke set bekleyen_baraj=(k.veri->>'baraj')::numeric where id=1;
    else
      update oyun.ayarlar set baraj=(k.veri->>'baraj')::numeric where id=1;
    end if;

  elsif k.tur='iptal' then
    update oyun.kararnameler set durum='iptal'
    where id=(k.veri->>'kararname_id')::bigint returning * into kr;

    if kr.tur='vergi' and not exists(select 1 from oyun.kararnameler
      where tur='vergi' and durum='yururlukte' and zaman>kr.zaman) then
      update oyun.ulke set vergi=vergi_kanun where id=1;
    end if;

    if kr.tur='duzenleme' and exists(select 1 from oyun.duzenlemeler
      where kod=kr.veri->>'kod' and kaynak='kararname' and ref_id=kr.id) then
      if kr.veri->'onceki'->>'kaynak' is null then
        delete from oyun.duzenlemeler where kod=kr.veri->>'kod';
      else
        update oyun.duzenlemeler
           set deger=(kr.veri->'onceki'->>'deger')::numeric,
               kaynak=kr.veri->'onceki'->>'kaynak',
               ref_id=(kr.veri->'onceki'->>'ref_id')::bigint,zaman=t
         where kod=kr.veri->>'kod';
      end if;
    end if;

  elsif k.tur='duzenleme' then
    if not oyun.duzenleme_uygula(k.veri->>'kod',(k.veri->>'deger')::numeric,'kanun',k.id,t) then
      update oyun.kanunlar set sonuc_metin=p_not || ' Ancak kural bu arada anayasaya bağlandığı için uygulanamadı.' where id=k.id;
    end if;

  elsif k.tur='anayasa' then
    perform oyun.anayasa_uygula(k,t);
  end if;

  perform oyun.gazete_ekle(case when k.tur='anayasa' then 'anayasa' else 'kanun' end,
    format('%s sayılı %s',v_no,k.baslik),
    coalesce(case when k.tur='anayasa' then oyun.anayasa_aciklama(k.veri) || ' ' end,'') || k.metin,k.id,t);
  perform oyun.bildir(k.teklif_eden,format('Teklifin yasalaştı: %s sayılı "%s" yürürlüğe girdi.',v_no,k.baslik),t);
  perform oyun.olay('meclis',format('%s sayılı "%s" yürürlüğe girdi. %s',v_no,k.baslik,p_not),null,k.teklif_parti,t);
end $function$
;

-- Constitutional total stays 600; election allocation is restored to 600 now and for future elections.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
