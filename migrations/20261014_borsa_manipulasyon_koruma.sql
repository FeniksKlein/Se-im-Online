-- 2026-10-14: Borsa fiyat manipülasyonu önleme ve gerekçeli düzeltme.
-- Yedek: yedek_20261014_171836_075182. Para, ortaklık ve eski işlemler değiştirilmez.
begin;

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

-- İki şirketin saptanan döngü öncesindeki nesnel halka arz referansları:
-- UYGAR HOLDING 6 numaralı tamamlanan arz: (6.000.000+500.000)/100 = 65.000
-- Sabancı Teknoloji 10 numaralı tamamlanan arz: (1.200.000+300.000)/100 = 15.000
-- Diğer şirketlerin görünür fiyatı değiştirilmez.
insert into oyun.borsa_fiyat_referans(sirket_id, fiyat, ilk_fiyat, gerekce)
select s.id, case when s.id=1 then 65000::numeric when s.id=9 then 15000::numeric
       else greatest(1,coalesce(oyun.borsa_son_fiyat(s.id),round(s.sermaye/100))) end,
       case when s.id=1 then 65000::numeric when s.id=9 then 15000::numeric
       else greatest(1,coalesce(oyun.borsa_son_fiyat(s.id),round(s.sermaye/100))) end,
       case when s.id in (1,9) then 'Tamamlanan halka arz bazına manipülasyon sonrası düzeltme'
            else 'Mevcut fiyatın ilk güvenli tescili' end
from oyun.sirketler s where s.halka_acik
on conflict (sirket_id) do nothing;

insert into oyun.borsa_fiyat_gecmis(sirket_id,fiyat,gerekce)
select r.sirket_id,r.fiyat,r.gerekce
from oyun.borsa_fiyat_referans r
where not exists (select 1 from oyun.borsa_fiyat_gecmis h where h.sirket_id=r.sirket_id);

-- Denetim delili: şüpheli küçük hacimli ve karşılıklı fiyat değiştiren işlemler muhafaza edilir.
insert into oyun.borsa_supheli_islem(islem_id,sirket_id,bulgu)
select i.id,i.sirket_id,
       case when i.sirket_id=1 then '14 Ekim: %0,10 pay ile düşük fiyat oluşturma / aynı karşı taraf'
            else 'Tek karşı tarafla yüksek fiyat ve/veya 14 Ekim karşılıklı %0,10 pay alım satımı' end
from oyun.borsa_islem i
where ((i.sirket_id=1 and i.id in (10,11,12))
    or (i.sirket_id=9 and i.id in (8,13,14,15,16,17,18,19)))
on conflict (islem_id) do nothing;

-- İki etkilenen şirkette korunmuş banda aykırı BEKLEYEN emirleri iptal et.
-- Yapılmış alım satım, ödeme ve pay sahipliği KESİNLİKLE geri çevrilmez.
update oyun.borsa_emir e set durum='iptal'
from oyun.borsa_fiyat_referans r
where e.sirket_id=r.sirket_id and e.sirket_id in (1,9) and e.durum='acik'
  and (e.birim < round(r.fiyat*0.90) or e.birim > round(r.fiyat*1.10));

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

commit;
