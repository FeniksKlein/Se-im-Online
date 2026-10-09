-- 2026-10-09 – İl bazlı sınırlı emlak stoğu, haftalık belediye vergisi ve 600 sandalyeli TBMM
-- Mevcut tapuları, oyuncu bakiyelerini ve geçmiş seçimleri sıfırlamaz.
create table if not exists oyun.emlak_vergi_yerel(
 il_id smallint primary key references oyun.iller(id),
 oran numeric not null check(oran between 0 and 0.5),
 baskan uuid references oyun.profiller(id),
 degis_at timestamptz not null default now()
);
create table if not exists oyun.emlak_vergi_kayit(
 id bigint generated always as identity primary key,
 mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 user_id uuid not null references oyun.profiller(id),
 il_id smallint not null references oyun.iller(id),
 zaman timestamptz not null,
 hafta integer not null check(hafta between 1 and 520),
 vergi numeric not null check(vergi>=0)
);
create index if not exists emlak_vergi_kayit_user on oyun.emlak_vergi_kayit(user_id,zaman);
create index if not exists emlak_vergi_kayit_il on oyun.emlak_vergi_kayit(il_id,zaman);
alter table oyun.emlak_vergi_yerel enable row level security;
alter table oyun.emlak_vergi_kayit enable row level security;
revoke all on oyun.emlak_vergi_yerel,oyun.emlak_vergi_kayit from public,anon,authenticated;

-- TBMM'nin mevcut genel düzenleme sistemi: vekiller bu oranı kanunla oylayabilir.
insert into oyun.duzenleme_tanim(kod,kapsam,ad,birim,varsayilan,min,max,adim,tur,aciklama,oyuncu,devlet,sira)
values('yatirim_emlak_vergisi','ulke','Haftalık belediye emlak vergisi','yuzde',0.10,0,0.50,0.05,'gelir',
  'Mülkün alış bedeli üzerinden haftada bir kesilir, mülkün bulunduğu ilin belediye kasasına aktarılır.',
  'Ev, dükkân ve villa sahiplerinin haftalık kira gelirinden kesilir.',
  'Meclis oranı kanunla değiştirebilir; belediye başkanı kendi ilinin oranını yetki sınırında ayarlayabilir.',99)
on conflict(kod) do nothing;

create or replace function oyun.emlak_vergi_oran(p_il smallint) returns numeric
language sql stable set search_path='' as $$
 select coalesce((select oran from oyun.emlak_vergi_yerel where il_id=p_il),oyun.duz('yatirim_emlak_vergisi'),0.10)
$$;

-- İl nüfusunun temsili olarak 600 sandalye dağılımındaki il MV sayısı esas alınır.
-- İstanbul 96 vekille 100 konut; Bayburt 1 vekille en az 8 konut kotası.
create or replace function oyun.emlak_kapasite(p_il smallint,p_tip text) returns int
language sql stable set search_path='' as $$
 select case
  when p_tip in ('daire','villa') then greatest(8,round(i.mv*100.0/96)::int)
  when p_tip='dukkan' then greatest(3,round(greatest(8,round(i.mv*100.0/96)::int)*0.35)::int)
  else 0 end
 from oyun.iller i where i.id=p_il
$$;
create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else 0 end) *
  (0.65 + 1.35*sqrt(i.mv::numeric/96.0)) *
  (0.90 + least(100,greatest(0,coalesce(d.gelisim,50)))/500.0))
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function public.emlak_iller() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',i.id,'ad',i.ad,'gelisim',round(coalesce(d.gelisim,50),1),
   'konut_kapasite',oyun.emlak_kapasite(i.id,'daire'),
   'konut_satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip in ('daire','villa')),
   'dukkan_kapasite',oyun.emlak_kapasite(i.id,'dukkan'),
   'dukkan_satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='dukkan'),
   'daire',oyun.emlak_fiyat(i.id,'daire'),
   'dukkan',oyun.emlak_fiyat(i.id,'dukkan'),
   'villa',oyun.emlak_fiyat(i.id,'villa'),
   'vergi_oran',oyun.emlak_vergi_oran(i.id)
 ) order by i.ad),'[]'::jsonb)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_iller() from public,anon;
grant execute on function public.emlak_iller() to authenticated;

create or replace function public.mulk_satin_al_il(p_tip text,p_il smallint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();p oyun.profiller;bedel numeric;kira numeric;t timestamptz:=oyun.simdi();
 yeni_mulk_id bigint;stok integer;kullanilan integer;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null then raise exception 'Önce profil oluşturmalısın';end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü';end if;
 if p_il is null or not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Geçerli bir il seç.';end if;
 perform pg_advisory_xact_lock(901173,p_il::integer * 10 + case when p_tip='dukkan' then 2 else 1 end);
 stok:=oyun.emlak_kapasite(p_il,p_tip);
 select count(*) into kullanilan from oyun.yatirim_mulkleri
 where il_id=p_il and (case when p_tip='dukkan' then tip='dukkan' else tip in ('daire','villa') end);
 if kullanilan>=stok then raise exception 'Bu ilde yeni % stokları tükendi. Başka il veya oyuncuların satılık ilanlarını seç.',case when p_tip='dukkan' then 'dükkân' else 'konut' end;end if;
 bedel:=oyun.emlak_fiyat(p_il,p_tip);kira:=round(bedel*0.025,2);
 if bedel is null or bedel<10000 then raise exception 'İl fiyatı hesaplanamadı.';end if;
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s ilinde %s satın alındı',
   (select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni_mulk_id;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni_mulk_id,null,u,bedel,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al_il(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al_il(text,smallint) to authenticated;

-- Eski satın alma çağrısı da kotayı aşamaz; eski ekran kullananlar kendi ilinden alır.
create or replace function public.mulk_satin_al(p_tip text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return public.mulk_satin_al_il(p_tip,p.il_id);
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function public.belediye_emlak_vergisi_ayarla(p_oran numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();m oyun.makamlar:=oyun.baskan_zorunlu(p);
 t timestamptz:=oyun.simdi(); onceki timestamptz; merkez numeric:=oyun.duz('yatirim_emlak_vergisi'); yetki numeric;
begin
 yetki:=least(100,greatest(0,coalesce(oyun.anayasa_deger('yerel_yetki'),100)));
 if p_oran is null or p_oran<0 or p_oran>0.50 or p_oran<>round(p_oran/0.05)*0.05 then
   raise exception 'Haftalık emlak vergisi %%0-%%0,50 arasında ve 0,05 puanlık adımlarla olmalı.';end if;
 if abs(p_oran-merkez)>0.15*yetki/100 then
   raise exception 'Yerel yönetim yetkisi gereği ulusal orandan en fazla % puan ayrılabilirsin.',round(0.15*yetki/100,2);end if;
 select degis_at into onceki from oyun.emlak_vergi_yerel where il_id=m.il_id;
 if onceki>t-interval '24 hours' then raise exception 'Emlak vergisi 24 saatte bir değiştirilebilir.';end if;
 insert into oyun.emlak_vergi_yerel(il_id,oran,baskan,degis_at) values(m.il_id,p_oran,p.id,t)
 on conflict(il_id) do update set oran=excluded.oran,baskan=excluded.baskan,degis_at=excluded.degis_at;
 perform oyun.olay('belediye',format('%s Belediye Başkanı emlak vergisini haftalık %s%% olarak belirledi.',
 (select ad from oyun.iller where id=m.il_id),oyun.tl(p_oran)),m.il_id,p.parti_id,t);
 return jsonb_build_object('il_id',m.il_id,'oran',p_oran,'ulusal_oran',merkez);
end $$;
revoke all on function public.belediye_emlak_vergisi_ayarla(numeric) from public,anon;
grant execute on function public.belediye_emlak_vergisi_ayarla(numeric) to authenticated;

CREATE OR REPLACE FUNCTION oyun.mulk_kira_tahsil(p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare m record;n int;gross numeric;tax numeric;emlak_vergisi numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
       then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  emlak_vergisi:=least(greatest(0,gross-tax),round(m.alis_bedeli*oyun.emlak_vergi_oran(m.il_id)/100*n,2));
  perform oyun.para_islem(p_user,gross-tax-emlak_vergisi,'kira',
    format('Mülk #%s: %s haftalık kira, gelir vergisi %s TL, belediye emlak vergisi %s TL',m.id,n,tax,emlak_vergisi),t,tax+emlak_vergisi);
  if emlak_vergisi>0 then
    update oyun.il_durum set kasa=kasa+emlak_vergisi/1000000.0 where il_id=m.il_id;
    insert into oyun.emlak_vergi_kayit(mulk_id,user_id,il_id,zaman,hafta,vergi)
      values(m.id,p_user,m.il_id,t,n,emlak_vergisi);
  end if;
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',toplam_kira=toplam_kira+gross-tax-emlak_vergisi,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
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

-- 600 sandalyeye dönüş: geçmiş seçim ve seçilmiş oyuncu kayıtları korunur.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
update oyun.meclis_olcek_kayit k
 set sandalye=600,anayasal=600
 from oyun.secimler s where s.id=k.secim_id and s.tur='mv_on' and s.durum='bekliyor';
