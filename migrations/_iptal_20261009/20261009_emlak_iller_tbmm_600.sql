-- Şehir stokları, ulusal ve belediye emlak vergisi, 600 sandalye
-- Mevcut mülk ve vekil kayıtları korunur.
create table if not exists oyun.il_mulk_stok(
 il_id smallint not null references oyun.iller(id),
 tip text not null check(tip in ('daire','dukkan','villa')),
 toplam integer not null check(toplam>0),
 primary key(il_id,tip)
);
insert into oyun.il_mulk_stok(il_id,tip,toplam)
select i.id,v.tip,
  case v.tip when 'daire' then greatest(8,round(8+(i.mv-1)*92.0/95)::int)
             when 'dukkan' then greatest(4,round(5+(i.mv-1)*50.0/95)::int)
             else greatest(2,round(3+(i.mv-1)*27.0/95)::int) end
from oyun.iller i cross join (values('daire'),('dukkan'),('villa')) v(tip)
on conflict(il_id,tip) do nothing;
alter table oyun.il_mulk_stok enable row level security;
revoke all on oyun.il_mulk_stok from public,anon,authenticated;

create table if not exists oyun.emlak_vergi_ulusal(
 id smallint primary key check(id=1),
 haftalik_oran numeric not null default 0.4 check(haftalik_oran between 0.1 and 2.0)
);
insert into oyun.emlak_vergi_ulusal(id,haftalik_oran) values(1,0.4)
 on conflict (id) do nothing;
create table if not exists oyun.emlak_vergi_yerel(
 il_id smallint primary key references oyun.iller(id),
 carpan numeric not null default 1 check(carpan between 0.5 and 2.0),
 zaman timestamptz,
 baskan uuid references oyun.profiller(id)
);
create table if not exists oyun.emlak_vergi_kayit(
 id bigint generated always as identity primary key,
 mulk_id bigint not null,
 user_id uuid not null references oyun.profiller(id),
 il_id smallint not null references oyun.iller(id),
 hafta integer not null check(hafta>0),
 tutar numeric not null check(tutar>=0),
 zaman timestamptz not null
);
create index if not exists emlak_vergi_kayit_il_zaman on oyun.emlak_vergi_kayit(il_id,zaman);
do $$
declare n text;
begin
 foreach n in array array['emlak_vergi_ulusal','emlak_vergi_yerel','emlak_vergi_kayit'] loop
  execute format('alter table oyun.%I enable row level security',n);
  execute format('revoke all on oyun.%I from public,anon,authenticated',n);
 end loop;
end $$;

create or replace function oyun.emlak_vergi_oran(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select round((select haftalik_oran from oyun.emlak_vergi_ulusal where id=1) *
 coalesce((select carpan from oyun.emlak_vergi_yerel where il_id=p_il),1),4)
$$;

create or replace function oyun.mulk_il_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round(
 (case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end)
 * (0.65+least(96,greatest(1,i.mv))::numeric/96*1.2)
 * (0.75+d.gelisim/200.0),-2)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;

create or replace function public.mulk_katalog()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return jsonb_build_object(
  'profil_il',p.il_id,
  'ulusal_vergi',(select haftalik_oran from oyun.emlak_vergi_ulusal where id=1),
  'iller',coalesce((select jsonb_agg(jsonb_build_object(
      'id',i.id,'ad',i.ad,'mv',i.mv,'gelisim',d.gelisim,
      'vergi',oyun.emlak_vergi_oran(i.id),
      'emlaklar',coalesce((select jsonb_agg(jsonb_build_object(
         'tip',s.tip,'stok',s.toplam,'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=s.tip),
         'kalan',greatest(0,s.toplam-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=s.tip)),
         'fiyat',oyun.mulk_il_fiyat(i.id,s.tip),
         'haftalik_kira',round(oyun.mulk_il_fiyat(i.id,s.tip)*0.025,2)
      ) order by case s.tip when 'daire' then 1 when 'dukkan' then 2 else 3 end)
        from oyun.il_mulk_stok s where s.il_id=i.id),'[]'::jsonb)
   ) order by i.ad) from oyun.iller i join oyun.il_durum d on d.il_id=i.id),'[]'::jsonb));
end $$;
revoke all on function public.mulk_katalog() from public,anon;
grant execute on function public.mulk_katalog() to authenticated;

create or replace function public.mulk_satin_al_il(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();bedel numeric;kira numeric;t timestamptz:=oyun.simdi();
 stok int;adet int;yeni bigint;
begin
 if p_tip is null or p_tip not in ('daire','dukkan','villa') then raise exception 'Geçersiz mülk türü.'; end if;
 if p_il is null or not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Geçersiz il.'; end if;
 -- Şehir ve tür bazındaki stok yarışını kilitle (aynı son mülk iki kez alınamaz).
 perform pg_advisory_xact_lock(761011,p_il::int*10+
    case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 select toplam into stok from oyun.il_mulk_stok where il_id=p_il and tip=p_tip;
 select count(*) into adet from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if stok is null or adet>=stok then raise exception 'Bu ilde bu türde satılık yeni mülk kalmadı. Başka il seç veya oyuncuların ilanlarına bak.'; end if;
 bedel:=oyun.mulk_il_fiyat(p_il,p_tip);
 kira:=round(bedel*0.025,2);
 if bedel is null or bedel<=0 then raise exception 'İl fiyatı hesaplanamadı.'; end if;
 perform oyun.mulk_kira_tahsil(p.id);
 perform oyun.para_islem(p.id,-bedel,'emlak',format('%s ilinde %s satın alındı',(select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
  values(p.id,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
  values('mulk_devlet',yeni,null,p.id,bedel,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al_il(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al_il(text,smallint) to authenticated;

-- Eski istemcinin sınırsız mülk alma yolunu da kapat.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return public.mulk_satin_al_il(p_tip,p.il_id);
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m record;n int;gross numeric;tax numeric;emlak_tax numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user
       and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
       then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  emlak_tax:=least(greatest(0,gross-tax),
       round(m.alis_bedeli*oyun.emlak_vergi_oran(m.il_id)/100*n,2));
  perform oyun.para_islem(p_user,gross-tax-emlak_tax,'kira',
       format('Mulk #%s: %s haftalik kira, gelir vergisi %s TL, belediye emlak vergisi %s TL',
         m.id,n,tax,emlak_tax),t,tax+emlak_tax);
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
  if emlak_tax>0 then
    update oyun.il_durum set kasa=kasa+emlak_tax/1000000 where il_id=m.il_id;
    insert into oyun.emlak_vergi_kayit(mulk_id,user_id,il_id,hafta,tutar,zaman)
      values(m.id,p_user,m.il_id,n,emlak_tax,t);
  end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
    toplam_kira=toplam_kira+gross-tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;

create or replace function public.emlak_vergi_oranlari()
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
  'ulusal',(select haftalik_oran from oyun.emlak_vergi_ulusal where id=1),
  'iller',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad,'carpan',
     coalesce(y.carpan,1),'oran',oyun.emlak_vergi_oran(i.id)) order by i.id)
      from oyun.iller i left join oyun.emlak_vergi_yerel y on y.il_id=i.id),'[]'::jsonb),
  'baskan_il',(select m.il_id from oyun.makamlar m where m.user_id=auth.uid() and m.tur='bel' and m.bit is null limit 1));
$$;
revoke all on function public.emlak_vergi_oranlari() from public,anon;
grant execute on function public.emlak_vergi_oranlari() to authenticated;

create or replace function public.emlak_vergi_belediye_ayarla(p_carpan numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();m oyun.makamlar:=oyun.baskan_zorunlu(p); t timestamptz:=oyun.simdi();
 onceki oyun.emlak_vergi_yerel;
begin
 if p_carpan is null or p_carpan not between 0.5 and 2.0 then raise exception 'Belediye emlak vergisi çarpanı 0,50–2,00 arasında olmalı.'; end if;
 select * into onceki from oyun.emlak_vergi_yerel where il_id=m.il_id for update;
 if onceki.zaman>t-interval '24 hours' then raise exception 'Belediye emlak vergisi 24 saatte bir değiştirilebilir.';end if;
 if coalesce(onceki.carpan,1)=p_carpan then raise exception 'Vergi oranında değişiklik yok.';end if;
 insert into oyun.emlak_vergi_yerel(il_id,carpan,zaman,baskan)
 values(m.il_id,p_carpan,t,p.id)
 on conflict(il_id) do update set carpan=excluded.carpan,zaman=excluded.zaman,baskan=excluded.baskan;
 perform oyun.olay('belediye',format('%s Belediyesi emlak vergisi çarpanını %s olarak değiştirdi.',
   (select ad from oyun.iller where id=m.il_id),p_carpan),m.il_id,p.parti_id,t);
 return public.emlak_vergi_oranlari();
end $$;
revoke all on function public.emlak_vergi_belediye_ayarla(numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye_ayarla(numeric) to authenticated;

create or replace function public.emlak_vergisi_kanun_teklif(p_oran numeric,p_baslik text,p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare y jsonb; idd bigint;
begin
 if p_oran is null or p_oran not between 0.1 and 2.0 then
  raise exception 'Haftalık ulusal emlak vergisi oranı %%0,1–%%2 arasında olmalı.';end if;
 y:=public.kanun_teklif('serbest',p_baslik,p_metin,null);
 idd:=(y->>'id')::bigint;
 update oyun.kanunlar set veri=jsonb_build_object('eylem','emlak_vergisi','oran',p_oran) where id=idd;
 return y;
end $$;
revoke all on function public.emlak_vergisi_kanun_teklif(numeric,text,text) from public,anon;
grant execute on function public.emlak_vergisi_kanun_teklif(numeric,text,text) to authenticated;

-- Anayasal 600 vekil kontenjanı; oyuncu sayısı sandalye sayısını azaltmasın.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
-- Daha önce hesaplanmış, henüz sonuçlanmamış seçimlerin meta bilgisini düzelt.
update oyun.meclis_olcek_kayit k set sandalye=600 where
 exists(select 1 from oyun.secimler s where s.id=k.secim_id and s.durum='bekliyor');


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

  if k.tur='serbest' and k.veri->>'eylem'='borc_affi' then
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

  elsif k.tur='serbest' and k.veri->>'eylem'='emlak_vergisi' then
    oran:=(k.veri->>'oran')::numeric;
    if oran is null or oran not between 0.1 and 2.0 then
      raise exception 'Emlak vergisi kanunundaki oran geçersiz.';
    end if;
    insert into oyun.emlak_vergi_ulusal(id,haftalik_oran) values(1,oran)
      on conflict(id) do update set haftalik_oran=excluded.haftalik_oran;
    insert into oyun.bildirimler(user_id,zaman,metin)
      select id,t,format('Yeni kanunla haftalık emlak vergisi ulusal oranı %s%% oldu. Vergi belediye kasasına yatırılır.',oran)
      from oyun.profiller where not yasakli;
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

