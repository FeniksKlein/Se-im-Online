-- 98) Gerçekçi SPK/Borsa gözetimi — 2026-10-14
-- Canlı veri koruması: para, sahiplik, geçmiş işlemler DEĞİŞMEZ.
-- Canlı yedek: yedek_20261014_174054_415830
-- İleriye dönük fiyat keşfi ve emir/işlem bütünlüğü.
create table if not exists oyun.borsa_devre_kesici (
  sirket_id bigint primary key references oyun.sirketler(id),
  bit timestamptz not null,
  neden text not null,
  olusma timestamptz not null default now()
);
create index if not exists borsa_devre_kesici_bit_idx on oyun.borsa_devre_kesici(bit);

create table if not exists oyun.borsa_gozetim_kayit (
  id bigint generated always as identity primary key,
  sirket_id bigint not null references oyun.sirketler(id),
  islem_id bigint references oyun.borsa_islem(id),
  tur text not null,
  aciklama text not null,
  zaman timestamptz not null default now(),
  unique (islem_id,tur)
);
create index if not exists borsa_gozetim_sirket_zaman_idx on oyun.borsa_gozetim_kayit(sirket_id,zaman desc);
revoke all on oyun.borsa_devre_kesici,oyun.borsa_gozetim_kayit from public,anon,authenticated;

-- Yalnız piyasanın ONAYLANMIŞ fiyatı şirket değerine ve 24 saatlik değişime yansır.
-- Ham işlemler tarihsel delil olarak ayrı tutulur.
create or replace function oyun.borsa_son_fiyat(p_sirket bigint,t timestamptz default null)
returns numeric language sql stable set search_path to '' as $fn$
 select coalesce(
  (select g.fiyat from oyun.borsa_fiyat_gecmis g
   where g.sirket_id=p_sirket and (t is null or g.zaman<=t)
   order by g.zaman desc,g.id desc limit 1),
  (select g.fiyat from oyun.borsa_fiyat_gecmis g
   where g.sirket_id=p_sirket and t is not null and g.zaman>t
   order by g.zaman asc,g.id asc limit 1),
  (select r.fiyat from oyun.borsa_fiyat_referans r where r.sirket_id=p_sirket),
  (select round((h.deger+h.toplanan)/100) from oyun.halka_arz h
   where h.sirket_id=p_sirket and h.durum='tamam' order by h.id desc limit 1),
  (select round(greatest(s.sermaye,1)/100) from oyun.sirketler s where s.id=p_sirket))
$fn$;

-- Manipülatörün sürekli emir açıp iptal ederek "tahta" yanıltması engellenir.
create or replace function oyun.tg_borsa_emir_bant()
returns trigger language plpgsql security definer set search_path to '' as $fn$
declare f numeric; alt numeric; ust numeric;
begin
  if exists(select 1 from oyun.borsa_devre_kesici h where h.sirket_id=new.sirket_id and h.bit>now()) then
    raise exception 'Borsada devre kesici: şirketin işlemleri geçici süre durdurulmuştur.';
  end if;
  f:=oyun.borsa_son_fiyat(new.sirket_id);
  if f is null or f<=0 then raise exception 'Onaylı fiyat referansı bulunamadı.'; end if;
  alt:=greatest(1,round(f*0.90));
  ust:=greatest(alt,round(f*1.10));
  if new.birim is null or new.birim<alt or new.birim>ust then
    raise exception 'Borsa fiyat bandı: %%1 pay % ₺ ile % ₺ arasında olmalı.',oyun.tl(alt),oyun.tl(ust);
  end if;
  if (select count(*) from oyun.borsa_emir e
      where e.satici=new.satici and e.sirket_id=new.sirket_id
        and e.zaman>now()-interval '15 minutes') >= 5 then
    raise exception 'SPK emir kısıtı: aynı şirket için 15 dakikada en fazla 5 yeni emir.';
  end if;
  return new;
end $fn$;

-- Para ve hisse değişimi gerçekleşmeden önce kontrol edilen atomik güvenlik.
create or replace function oyun.tg_borsa_islem_koruma()
returns trigger language plpgsql security definer set search_path to '' as $fn$
declare f numeric; alt numeric; ust numeric; tutulan numeric; son_alinan numeric;
begin
  if new.satici is null or new.alici is null or new.satici=new.alici then
    raise exception 'Kendi hesabınla borsa işlemi yapılamaz.';
  end if;
  if exists(select 1 from oyun.borsa_devre_kesici h where h.sirket_id=new.sirket_id and h.bit>now()) then
    raise exception 'Devre kesici etkin: işlemler geçici olarak durduruldu.';
  end if;
  if oyun.bagli_hesap_mi(new.satici,new.alici) or oyun.iliskili(new.satici,new.alici) then
    raise exception 'İlişkili oyuncu hesapları arasında borsa işlemi yasaktır.';
  end if;
  if exists(select 1 from oyun.borsa_islem i
      where i.sirket_id=new.sirket_id
        and i.satici=new.alici and i.alici=new.satici
        and i.zaman>now()-interval '7 days') then
    raise exception 'SPK: karşılıklı pay devirleri için 7 günlük engel uygulanır.';
  end if;
  if exists(select 1 from oyun.borsa_islem i
      where i.sirket_id=new.sirket_id
        and i.satici=new.satici and i.alici=new.alici
        and i.zaman>now()-interval '12 hours') then
    raise exception 'SPK: aynı iki hesap aynı şirket için 12 saatte tek işlem yapabilir.';
  end if;
  -- A->B yeni işlemiyle, önceki B->C ve C->A işlemlerinden halka oluşturulamaz.
  if exists(
     select 1 from oyun.borsa_islem i
     join oyun.borsa_islem j on j.sirket_id=i.sirket_id and j.satici=i.alici
     where i.sirket_id=new.sirket_id and i.satici=new.alici
       and j.alici=new.satici
       and i.zaman>now()-interval '7 days'
       and j.zaman>now()-interval '7 days'
  ) then raise exception 'SPK: üç hesap arasında döngüsel alım-satım tespit edildi.'; end if;
  -- Yeni satın alınan payları 24 saat tutma yükümlülüğü; eski mevcut payları kilitlemez.
  select coalesce(pay,0) into tutulan from oyun.sirket_ortaklari
   where sirket_id=new.sirket_id and user_id=new.satici;
  select coalesce(sum(i.pay),0) into son_alinan from oyun.borsa_islem i
   where i.sirket_id=new.sirket_id and i.alici=new.satici
     and i.zaman>now()-interval '24 hours';
  if coalesce(tutulan,0)-son_alinan < new.pay-0.000001 then
    raise exception 'Manipülasyon koruması: son 24 saatte borsadan alınan pay hemen satılamaz. Eski satılabilir pay: %% %.',greatest(0,round(coalesce(tutulan,0)-son_alinan,2));
  end if;
  f:=oyun.borsa_son_fiyat(new.sirket_id);
  if f is null or f<=0 then raise exception 'Şirketin onaylı piyasa fiyatı bulunamadı.'; end if;
  alt:=greatest(1,round(f*0.90)); ust:=greatest(alt,round(f*1.10));
  if new.birim<alt or new.birim>ust then
    raise exception 'İşlem güncel fiyat bandı dışında: emrin yenilenmesi gerekir.';
  end if;
  return new;
end $fn$;

-- Alınan payların bekleme süresini emir oluşturulurken de kontrol et.
-- Böylece alıcı, satışta görünen ancak işlemde bloke olacak bir emre tıklamaz.
create or replace function oyun.tg_borsa_emir_hisse_bekleme()
returns trigger language plpgsql security definer set search_path to '' as $fn$
declare tutulan numeric; yeni numeric; acik numeric;
begin
  select coalesce(o.pay,0) into tutulan from oyun.sirket_ortaklari o
    where o.sirket_id=new.sirket_id and o.user_id=new.satici;
  select coalesce(sum(i.pay),0) into yeni from oyun.borsa_islem i
    where i.sirket_id=new.sirket_id and i.alici=new.satici and i.zaman>now()-interval '24 hours';
  select coalesce(sum(e.kalan),0) into acik from oyun.borsa_emir e
    where e.sirket_id=new.sirket_id and e.satici=new.satici and e.durum='acik';
  if greatest(0,coalesce(tutulan,0)-coalesce(yeni,0)) + 0.000001 < new.pay+coalesce(acik,0) then
    raise exception '24 saatlik pay koruması: henüz satılabilir olmayan payları emir olarak koyamazsın. Boşta pay: %% %.',
      greatest(0,round(coalesce(tutulan,0)-coalesce(yeni,0)-coalesce(acik,0),2));
  end if;
  return new;
end $fn$;
drop trigger if exists borsa_emir_hisse_bekleme on oyun.borsa_emir;
create trigger borsa_emir_hisse_bekleme before insert on oyun.borsa_emir
for each row execute function oyun.tg_borsa_emir_hisse_bekleme();

-- İşlem sonucunda fiyatı yalnız şirket kurucusu veya büyük ortağı DIŞINDAKİ
-- bağımsız oyuncuların işlem hacmi değiştirebilir.
-- Tek oyuncunun kendi çevresiyle hacim yapması fiyat keşfi sayılmaz.
create or replace function oyun.tg_borsa_fiyat_kesfi()
returns trigger language plpgsql security definer set search_path to '' as $fn$
declare r oyun.borsa_fiyat_referans; v_pay numeric; v_fiyat numeric;
        v_islem integer; v_alici integer; v_satici integer; v_kisi integer;
        v_sermaye numeric; v_kasa numeric; v_net numeric;
        v_ust numeric; v_yeni numeric; v_eski numeric;
begin
  if new.pay < 0.5 then return new; end if;
  select * into r from oyun.borsa_fiyat_referans
    where sirket_id=new.sirket_id for update;
  if r.sirket_id is null then return new; end if;
  if now() < r.son_fiyat_guncelleme+interval '24 hours' then return new; end if;

  with q as (
    select i.pay,i.birim,i.alici,i.satici from oyun.borsa_islem i
    join oyun.sirketler s on s.id=i.sirket_id
    where i.sirket_id=new.sirket_id
      and i.zaman>=greatest(r.ilk_koruma,now()-interval '24 hours')
      and i.pay>=0.5
      and i.alici<>s.kurucu and i.satici<>s.kurucu
      and not exists (select 1 from oyun.sirket_ortaklari o
        where o.sirket_id=i.sirket_id
          and o.user_id in (i.alici,i.satici) and o.pay>=20)
      and not exists (select 1 from oyun.borsa_supheli_islem si where si.islem_id=i.id)
  ), kisi as (
    select alici id from q union select satici id from q
  )
  select coalesce(sum(q.pay),0),count(*)::int,
         count(distinct q.alici)::int,count(distinct q.satici)::int,
         coalesce(round(sum(q.pay*q.birim)/nullif(sum(q.pay),0)),0),
         (select count(*) from kisi)::int
  into v_pay,v_islem,v_alici,v_satici,v_fiyat,v_kisi from q;
  -- Hem satıcı hem alıcı tarafında en az iki bağımsız oyuncu.
  if v_pay<2 or v_islem<3 or v_kisi<4 or v_alici<2 or v_satici<2 then
    return new;
  end if;
  select s.sermaye,s.kasa into v_sermaye,v_kasa from oyun.sirketler s where id=new.sirket_id;
  v_net:=greatest(0,coalesce(oyun.borsa_haftalik_net(new.sirket_id),0));
  -- Şirketin piyasa değeri sahte al-satla aşırı büyümesin:
  -- gerçek sermaye+kasaya ve kâra dayalı tavan veya ilk güvenli değerin %130'u.
  v_ust:=greatest(r.ilk_fiyat*1.30,
     (greatest(0,coalesce(v_sermaye,0),coalesce(v_kasa,0))+v_net*26)*1.50/100);
  v_eski:=r.fiyat;
  v_yeni:=round(greatest(100,least(v_ust,round(r.fiyat*1.05),
                                     greatest(round(r.fiyat*0.95),v_fiyat))));
  if v_yeni = v_eski then return new; end if;
  update oyun.borsa_fiyat_referans set fiyat=v_yeni,
    son_fiyat_guncelleme=now(), gerekce='SPK: bağımsız işlem hacmi ve ekonomik değerleme'
    where sirket_id=new.sirket_id;
  insert into oyun.borsa_fiyat_gecmis(sirket_id,fiyat,gerekce)
   values(new.sirket_id,v_yeni,'SPK: en az 4 kişi, 2%% pay ve 3 işlem; günlük %%5 limit, bilanço sınırı');
  if abs(v_yeni/v_eski-1)>=0.04 then
    insert into oyun.borsa_devre_kesici(sirket_id,bit,neden)
    values(new.sirket_id,now()+interval '30 minutes','Onaylı piyasa fiyatında güçlü hareket; 30 dakika devre kesici')
    on conflict (sirket_id) do update
       set bit=excluded.bit,neden=excluded.neden,olusma=now();
  end if;
  insert into oyun.borsa_gozetim_kayit(sirket_id,islem_id,tur,aciklama)
    values(new.sirket_id,new.id,'fiyat_kesfi',
      format('İşlem hacmi %s%%; işlem sayısı %s; bağımsız kişi %s; eski fiyat %s; yeni %s',
      v_pay,v_islem,v_kisi,v_eski,v_yeni))
    on conflict (islem_id,tur) do nothing;
  return new;
end $fn$;

-- Sabit fiyat bandı dışı eski bekleyen emirleri temizle; yeni emir oluşturma hakları korunur.
-- (Yalnız hâlâ açık ve yeni taban/tavan bandının dışındaki teklifler)
update oyun.borsa_emir e set durum='iptal'
where e.durum='acik' and exists (
 select 1 from oyun.borsa_fiyat_referans r where r.sirket_id=e.sirket_id
 and (e.birim<round(r.fiyat*0.90) or e.birim>round(r.fiyat*1.10))
);

-- Borsa şirket detayında son işlem fiyatları değil, onaylanmış fiyatlar grafikleştirilir.
-- Aynı zamanda ekran satılabilir hisseleri doğru gösterebilsin diye "kilitli_pay" verilir.
create or replace function public.borsa_sirket(p_sirket bigint)
returns jsonb language plpgsql security definer set search_path to '' as $fn$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler;
  t timestamptz := oyun.simdi(); kilitli numeric;
begin
  select * into s from oyun.sirketler where id=p_sirket;
  if s.id is null or not s.halka_acik then raise exception 'Bu şirket borsada işlem görmüyor.'; end if;
  select least(coalesce(o.pay,0),coalesce(sum(i.pay),0))
    into kilitli
    from oyun.sirket_ortaklari o left join oyun.borsa_islem i
      on i.sirket_id=o.sirket_id and i.alici=o.user_id and i.zaman>t-interval '24 hours'
    where o.sirket_id=s.id and o.user_id=p.id
    group by o.pay;
  return jsonb_build_object(
    'id',s.id,'ad',s.ad,'sektor',s.sektor,'aktif',s.aktif,
    'sermaye',s.sermaye,'kasa',round(s.kasa),
    'son',oyun.borsa_son_fiyat(s.id),
    'dun',oyun.borsa_son_fiyat(s.id,t-interval '24 hours'),
    'haftalik_net',oyun.borsa_haftalik_net(s.id),
    'komisyon',(select komisyon from oyun.pazar_ayar where id=1),
    'benim_pay',coalesce((select pay from oyun.sirket_ortaklari where sirket_id=s.id and user_id=p.id),0),
    'kilitli_pay',coalesce(kilitli,0),
    'devre_kesici',(select bit from oyun.borsa_devre_kesici where sirket_id=s.id and bit>now()),
    'benim_satista',coalesce((select sum(kalan) from oyun.borsa_emir where sirket_id=s.id and satici=p.id and durum='acik'),0),
    'cuzdan',(select para from oyun.cuzdan where user_id=p.id),
    'emirler',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'satici',oyun.kad(e.satici),
       'kalan',e.kalan,'birim',e.birim,'benim',e.satici=p.id) order by e.birim,e.id)
       from oyun.borsa_emir e where e.sirket_id=s.id and e.durum='acik'),'[]'::jsonb),
    'islemler',coalesce((select jsonb_agg(jsonb_build_object('zaman',i.zaman,'pay',i.pay,
       'birim',i.birim,'tutar',i.tutar,'satici',oyun.kad(i.satici),'alici',oyun.kad(i.alici))
        order by i.zaman desc) from (select * from oyun.borsa_islem
          where sirket_id=s.id order by zaman desc,id desc limit 20) i),'[]'::jsonb),
    'gunluk',coalesce((select jsonb_agg(jsonb_build_object('gun',g,'fiyat',f) order by g)
      from (select distinct on ((zaman at time zone 'Europe/Istanbul')::date)
       (zaman at time zone 'Europe/Istanbul')::date g,fiyat f
       from oyun.borsa_fiyat_gecmis where sirket_id=s.id and zaman>t-interval '30 days'
       order by (zaman at time zone 'Europe/Istanbul')::date,zaman desc,id desc) d),'[]'::jsonb),
    'haftalar',coalesce((select jsonb_agg(jsonb_build_object('zaman',h.zaman,'net',h.tutar) order by h.zaman)
       from (select zaman,tutar from oyun.sirket_hareket
         where sirket_id=s.id and faaliyet_gelir>0 and aciklama like '7 günlük%'
         order by zaman desc,id desc limit 8) h),'[]'::jsonb),
    'ortaklar',(select jsonb_agg(jsonb_build_object('kad',oyun.kad(o.user_id),'pay',o.pay)
       order by o.pay desc) from oyun.sirket_ortaklari o where o.sirket_id=s.id)
  );
end $fn$;

-- Yalnız servis ve sunucu fonksiyonları tablo değiştirebilir.
revoke all on oyun.borsa_devre_kesici,oyun.borsa_gozetim_kayit from public,anon,authenticated;
