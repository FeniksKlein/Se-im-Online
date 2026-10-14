-- 97: Manipülasyona karşı kalıcı borsa fiyat tescili ve hacimli fiyat keşfi.
-- Tarihsel CELAL işlemleriyle ilgili düzeltmeler yalnızca 20261014 özel migrationlarında.
create table if not exists oyun.borsa_fiyat_referans (
  sirket_id bigint primary key references oyun.sirketler(id),
  fiyat numeric not null check (fiyat > 0),
  ilk_fiyat numeric not null check (ilk_fiyat > 0),
  ilk_koruma timestamptz not null default now(),
  son_fiyat_guncelleme timestamptz not null default now(),
  gerekce text not null default 'Korunmuş piyasa fiyatı'
);
create table if not exists oyun.borsa_fiyat_gecmis (
  id bigint generated always as identity primary key,
  sirket_id bigint not null references oyun.sirketler(id),
  fiyat numeric not null check (fiyat > 0),
  zaman timestamptz not null default now(),
  gerekce text not null
);
create index if not exists borsa_fiyat_gecmis_idx on oyun.borsa_fiyat_gecmis(sirket_id,zaman desc,id desc);
create index if not exists borsa_islem_fiyat_koruma_idx on oyun.borsa_islem(sirket_id,zaman desc);

create table if not exists oyun.borsa_supheli_islem (
  islem_id bigint primary key references oyun.borsa_islem(id),
  sirket_id bigint not null references oyun.sirketler(id),
  bulgu text not null,
  kayit_zamani timestamptz not null default now()
);


-- Geriden yükseltmede ilk defa halka açık her şirketin son borsa fiyatını güvenceye al.
-- Her zaman ON CONFLICT DO NOTHING: önceden düzeltilmiş fiyatlara dokunmaz.
insert into oyun.borsa_fiyat_referans(sirket_id,fiyat,ilk_fiyat,gerekce)
select s.id,
       greatest(1,coalesce(oyun.borsa_son_fiyat(s.id),round(s.sermaye/100))),
       greatest(1,coalesce(oyun.borsa_son_fiyat(s.id),round(s.sermaye/100))),
       'İlk sunucu tarafı onaylı fiyat kaydı'
from oyun.sirketler s where s.halka_acik
on conflict (sirket_id) do nothing;
insert into oyun.borsa_fiyat_gecmis(sirket_id,fiyat,gerekce)
select r.sirket_id,r.fiyat,'İlk onaylı fiyat kaydı'
from oyun.borsa_fiyat_referans r
where not exists (select 1 from oyun.borsa_fiyat_gecmis g where g.sirket_id=r.sirket_id);

-- Şirket bütünü asla son %0,1 pay işleminin tekil fiyatına göre değerlenemez.
-- Tarihsel karşılaştırma da onaylanmış fiyat geçmişini kullanır.
create or replace function oyun.borsa_son_fiyat(
  p_sirket bigint, t timestamptz default null
) returns numeric
language sql stable set search_path to ''
as $fn$
  select coalesce(
    (select h.fiyat from oyun.borsa_fiyat_gecmis h
     where h.sirket_id=p_sirket and (t is null or h.zaman<=t)
     order by h.zaman desc,h.id desc limit 1),
    (select r.fiyat from oyun.borsa_fiyat_referans r where r.sirket_id=p_sirket),
    (select round((h.deger+h.toplanan)/100) from oyun.halka_arz h
     where h.sirket_id=p_sirket and h.durum='tamam' order by h.id desc limit 1),
    (select round(greatest(s.sermaye,1)/100) from oyun.sirketler s where s.id=p_sirket)
  )
$fn$;

-- Her emir onaylanan fiyata göre SINIRLI; fiyat bandı ayarı kapatılsa bile açık kalır.
create or replace function oyun.tg_borsa_emir_bant()
returns trigger language plpgsql security definer set search_path to ''
as $fn$
declare f numeric; alt numeric; ust numeric;
begin
  f:=oyun.borsa_son_fiyat(new.sirket_id);
  if f is null or f<=0 then raise exception 'Şirket için fiyat referansı bulunamadı.'; end if;
  alt:=greatest(1,round(f*0.90));
  ust:=greatest(alt,round(f*1.10));
  if new.birim is null or new.birim<alt or new.birim>ust then
    raise exception 'Manipülasyon koruması: %%1 pay fiyatı % ₺ - % ₺ aralığında olmalı.', oyun.tl(alt), oyun.tl(ust);
  end if;
  return new;
end $fn$;

-- Emir listelendiği andaki bant yeterli değildir: alındığı anda da doğrulanır.
-- Aynı hesap, bağlantılı hesap, hızlı karşılıklı devir ve bant dışı fiyat reddedilir.
create or replace function oyun.tg_borsa_islem_koruma()
returns trigger language plpgsql security definer set search_path to ''
as $fn$
declare f numeric; alt numeric; ust numeric;
begin
  if new.satici is null or new.alici is null or new.satici=new.alici then
    raise exception 'Kendi hesabınla borsa işlemi yapamazsın.';
  end if;
  if oyun.bagli_hesap_mi(new.satici,new.alici) or oyun.iliskili(new.satici,new.alici) then
    raise exception 'Bağlantılı hesaplar arasında borsa işlemi yapılamaz.';
  end if;
  if exists (
    select 1 from oyun.borsa_islem i
    where i.sirket_id=new.sirket_id
      and i.satici=new.alici and i.alici=new.satici
      and i.zaman>now()-interval '7 days'
  ) then
    raise exception 'Karşılıklı pay devirleri 7 gün boyunca engellenir (SPK koruması).';
  end if;
  if exists (
    select 1 from oyun.borsa_islem i
    where i.sirket_id=new.sirket_id
      and i.satici=new.satici and i.alici=new.alici
      and i.zaman>now()-interval '12 hours'
  ) then
    raise exception 'Aynı iki hesap bu şirkette 12 saat içinde tekrar işlem yapamaz.';
  end if;
  f:=oyun.borsa_son_fiyat(new.sirket_id);
  if f is null or f<=0 then raise exception 'Fiyat referansı bulunamadı.'; end if;
  alt:=greatest(1,round(f*0.90)); ust:=greatest(alt,round(f*1.10));
  if new.birim<alt or new.birim>ust then
    raise exception 'Satış emri güncel güvenli fiyat bandının dışında; satıcının emri yenilemesi gerekir.';
  end if;
  return new;
end $fn$;

drop trigger if exists borsa_islem_ek_koruma on oyun.borsa_islem;
create trigger borsa_islem_ek_koruma before insert on oyun.borsa_islem
for each row execute function oyun.tg_borsa_islem_koruma();

-- Gerçek fiyat keşfi: son 24 saat içinde >= %2 pay, en az iki bağımsız
-- işlem (%0,5 pay altı fiyatı ASLA etkilemez) ve en az üç katılımcı.
-- Sadece GÜVENLİK SONRASI işlemler fiyat keşfine katılır.
-- Bir şirketin fiyatı 24 saatte en fazla bir kez ve en fazla %10 değişebilir.
create or replace function oyun.tg_borsa_fiyat_kesfi()
returns trigger language plpgsql security definer set search_path to ''
as $fn$
declare r oyun.borsa_fiyat_referans; v_pay numeric; v_fiyat numeric;
        v_islem int; v_alici int; v_satici int; v_kisi int;
        v_sermaye numeric; v_alt numeric; v_ust numeric; v_yeni numeric;
begin
  if new.pay<0.5 then return new; end if;
  select * into r from oyun.borsa_fiyat_referans where sirket_id=new.sirket_id for update;
  if r.sirket_id is null then return new; end if;
  if now() < r.son_fiyat_guncelleme+interval '24 hours' then return new; end if;

  with q as (
    select i.pay,i.birim,i.alici,i.satici from oyun.borsa_islem i
    where i.sirket_id=new.sirket_id
      and i.zaman>=greatest(r.ilk_koruma, now()-interval '24 hours')
      and i.pay>=0.5
  ), k as (
    select alici id from q union select satici id from q
  )
  select coalesce(sum(q.pay),0), count(*)::int,
         count(distinct q.alici)::int, count(distinct q.satici)::int,
         coalesce(round(sum(q.pay*q.birim)/nullif(sum(q.pay),0)),0),
         (select count(*) from k)::int
  into v_pay,v_islem,v_alici,v_satici,v_fiyat,v_kisi from q;
  if v_pay<2 or v_islem<2 or v_kisi<3 or (v_alici<2 and v_satici<2) then return new; end if;

  select sermaye into v_sermaye from oyun.sirketler where id=new.sirket_id;
  v_alt:=greatest(1,least(r.ilk_fiyat*0.5,coalesce(v_sermaye,1)/200));
  v_ust:=greatest(r.ilk_fiyat*2,coalesce(v_sermaye,1)/50);
  v_yeni:=round(greatest(v_alt,least(v_ust, greatest(round(r.fiyat*0.90),least(round(r.fiyat*1.10),v_fiyat)))));
  if v_yeni=r.fiyat then return new; end if;
  update oyun.borsa_fiyat_referans
    set fiyat=v_yeni,son_fiyat_guncelleme=now(),
        gerekce='Bağımsız katılımcılı asgari %2 pay hacmi ve günlük %10 tavanlı ağırlıklı fiyat'
    where sirket_id=new.sirket_id;
  insert into oyun.borsa_fiyat_gecmis(sirket_id,fiyat,gerekce)
  values(new.sirket_id,v_yeni,'Doğrulanmış 24 saatlik ağırlıklı fiyat; toplam pay %'||v_pay);
  return new;
end $fn$;

drop trigger if exists borsa_fiyat_kesfi on oyun.borsa_islem;
create trigger borsa_fiyat_kesfi after insert on oyun.borsa_islem
for each row execute function oyun.tg_borsa_fiyat_kesfi();

revoke all on oyun.borsa_fiyat_referans,oyun.borsa_fiyat_gecmis,oyun.borsa_supheli_islem from public,anon,authenticated;


-- Gelecekte tamamlanacak halka arzlar da fiyat tescil sistemine otomatik girsin.
create or replace function oyun.tg_borsa_yeni_sirket_fiyat()
returns trigger language plpgsql security definer set search_path to ''
as $fn$
declare fiyat numeric; eklendi bigint;
begin
  if exists (select 1 from oyun.borsa_fiyat_referans where sirket_id=new.sirket_id) then return new; end if;
  if not exists (select 1 from oyun.sirketler where id=new.sirket_id and halka_acik and aktif) then return new; end if;
  fiyat:=oyun.borsa_son_fiyat(new.sirket_id);
  if fiyat is null or fiyat<=0 then return new; end if;
  insert into oyun.borsa_fiyat_referans(sirket_id,fiyat,ilk_fiyat,gerekce)
    values(new.sirket_id,fiyat,fiyat,'Yeni halka açık şirkette ilk fiyat tescili')
    on conflict(sirket_id) do nothing
    returning sirket_id into eklendi;
  if eklendi is not null then
    insert into oyun.borsa_fiyat_gecmis(sirket_id,fiyat,gerekce)
    values(eklendi,fiyat,'Yeni halka açık şirkette ilk fiyat tescili');
  end if;
  return new;
end $fn$;

drop trigger if exists borsa_fiyat_yeni_sirket on oyun.borsa_emir;
create trigger borsa_fiyat_yeni_sirket after insert on oyun.borsa_emir
for each row execute function oyun.tg_borsa_yeni_sirket_fiyat();

