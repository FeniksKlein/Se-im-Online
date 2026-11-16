-- 16.11.2026 · Davet aktiflik ödülleri (oyuncu getirene kademeli ödül)
-- Mevcut davet sistemi yalnız davet edilen oy hakkı kazanınca tek seferlik ödül veriyordu.
-- Yeni: davet edilen oyuncu oyunda aktif kaldıkça (farklı günlerde giriş yaptıkça) davet edene
-- kademeli, küçük ödüller ödenir. Davet edilenin de davet ettiği oyuncular aktif kaldıkça ilk
-- davet edene katsayılı (%20) pay gider. Yalnız iki kademe vardır; piramit derinleşmez.
-- Suistimal korumaları: ödül yalnız oy hakkı kazanmış (doğrulanmış) davetlerde; aynı cihazdan
-- açılmış hesaplar sayılmaz; kişi başı haftalık ödül tavanı; aynı ağdan çok sayıda davet MASAK'a düşer.
-- Para oyun ekonomisine sistemden girer; tutarlar 1000+ oyunculu ekonomiye göre küçük tutuldu.

create table if not exists oyun.oyuncu_aktif_gun (
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  gun date not null,
  primary key (user_id, gun)
);
alter table oyun.oyuncu_aktif_gun enable row level security;

create or replace function oyun.oturum_aktif_gun_tg()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  if new.user_id is not null and exists(select 1 from oyun.profiller where id=new.user_id) then
    insert into oyun.oyuncu_aktif_gun(user_id,gun)
    values (new.user_id, (coalesce(new.son,new.ilk,now()) at time zone 'Europe/Istanbul')::date)
    on conflict do nothing;
  end if;
  return null;
end $$;
create or replace trigger oturum_aktif_gun after insert or update of son on oyun.oturumlar
  for each row execute function oyun.oturum_aktif_gun_tg();

insert into oyun.oyuncu_aktif_gun(user_id,gun)
select distinct o.user_id, (x at time zone 'Europe/Istanbul')::date
  from oyun.oturumlar o cross join lateral (values (o.ilk),(o.son)) v(x)
 where x is not null and exists(select 1 from oyun.profiller p where p.id=o.user_id)
on conflict do nothing;

create table if not exists oyun.davet_kademe (
  gun smallint primary key check (gun between 1 and 365),
  tutar numeric not null check (tutar >= 0 and tutar <= 1000000),
  aktif boolean not null default true
);
alter table oyun.davet_kademe enable row level security;
insert into oyun.davet_kademe(gun,tutar) values (3,5000),(7,10000),(14,15000),(30,25000)
on conflict (gun) do nothing;

insert into oyun.tarife(kod,deger,birim,kategori,ad,aciklama,sira) values
 ('davet_ikinci_kademe_oran',20,'yuzde','davet','Davet 2. kademe katsayısı','Davet ettiğin oyuncunun davet ettiği kişiler aktiflik kademesine ulaşınca sana ödenen pay (yüzde).',560),
 ('davet_aktiflik_haftalik_tavan',150000,'tl','davet','Davet aktiflik haftalık tavanı','Bir oyuncunun son 7 günde davet aktiflik ödüllerinden alabileceği en yüksek toplam.',561)
on conflict (kod) do nothing;

create table if not exists oyun.davet_aktiflik_odul (
  id bigserial primary key,
  davet_id bigint not null references oyun.davet(id),
  kademe_gun smallint not null,
  seviye smallint not null check (seviye in (1,2)),
  alan uuid not null references oyun.profiller(id),
  tutar numeric not null,
  zaman timestamptz not null default now(),
  unique (davet_id, kademe_gun, seviye)
);
create index if not exists davet_aktiflik_odul_alan_ix on oyun.davet_aktiflik_odul(alan, zaman desc);
alter table oyun.davet_aktiflik_odul enable row level security;

create or replace function oyun.davet_aktif_gun_sayisi(p_user uuid, p_bas timestamptz)
returns integer language sql stable set search_path to '' as $$
  select count(*)::int from oyun.oyuncu_aktif_gun g
   where g.user_id=p_user and g.gun >= (p_bas at time zone 'Europe/Istanbul')::date
$$;

create or replace function oyun.davet_aktiflik_ode(p_davet bigint, t timestamptz)
returns integer language plpgsql security definer set search_path to '' as $$
declare d oyun.davet; ust oyun.davet; n int; k record; tavan numeric; oran numeric; alinan numeric; tutar numeric; sayi int := 0;
begin
  select * into d from oyun.davet where id=p_davet and durum='odendi' for update;
  if d.id is null then return 0; end if;
  if exists(select 1 from oyun.profiller p where p.id in (d.davet_eden,d.davet_edilen) and coalesce(p.yasakli,false)) then return 0; end if;
  if oyun.bagli_hesap_mi(d.davet_eden, d.davet_edilen) then return 0; end if;
  n := oyun.davet_aktif_gun_sayisi(d.davet_edilen, d.zaman);
  tavan := coalesce((select deger from oyun.tarife where kod='davet_aktiflik_haftalik_tavan'),150000);
  oran := coalesce((select deger from oyun.tarife where kod='davet_ikinci_kademe_oran'),20);
  select * into ust from oyun.davet u where u.davet_edilen=d.davet_eden and u.durum='odendi';
  for k in select * from oyun.davet_kademe where aktif and gun <= n order by gun loop
    -- 1. kademe: doğrudan davet eden
    if not exists(select 1 from oyun.davet_aktiflik_odul where davet_id=d.id and kademe_gun=k.gun and seviye=1) then
      select coalesce(sum(o.tutar),0) into alinan from oyun.davet_aktiflik_odul o where o.alan=d.davet_eden and o.zaman > t - interval '7 days';
      if alinan + k.tutar <= tavan then
        insert into oyun.davet_aktiflik_odul(davet_id,kademe_gun,seviye,alan,tutar,zaman) values(d.id,k.gun,1,d.davet_eden,k.tutar,t);
        if k.tutar > 0 then
          perform oyun.para_islem(d.davet_eden, k.tutar, 'davet', format('Davet aktiflik ödülü: %s %s gün aktif oldu', oyun.kad(d.davet_edilen), k.gun), t);
          perform oyun.bildir(d.davet_eden, format('Davet ettiğin %s oyunda %s farklı gün aktif oldu: %s ₺ davet ödülü cüzdanına yattı.', oyun.kad(d.davet_edilen), k.gun, oyun.tl(k.tutar)), t);
        end if;
        sayi := sayi + 1;
      end if;
    end if;
    -- 2. kademe: davet edenin davet edeni (katsayılı)
    if ust.id is not null and not exists(select 1 from oyun.davet_aktiflik_odul where davet_id=d.id and kademe_gun=k.gun and seviye=2)
       and not coalesce((select yasakli from oyun.profiller where id=ust.davet_eden),false)
       and not oyun.bagli_hesap_mi(ust.davet_eden, d.davet_edilen) then
      tutar := round(k.tutar * oran / 100);
      select coalesce(sum(o.tutar),0) into alinan from oyun.davet_aktiflik_odul o where o.alan=ust.davet_eden and o.zaman > t - interval '7 days';
      if tutar > 0 and alinan + tutar <= tavan then
        insert into oyun.davet_aktiflik_odul(davet_id,kademe_gun,seviye,alan,tutar,zaman) values(d.id,k.gun,2,ust.davet_eden,tutar,t);
        perform oyun.para_islem(ust.davet_eden, tutar, 'davet', format('Davet ağı ödülü (%%%s): %s''in davet ettiği %s %s gün aktif oldu', oran, oyun.kad(d.davet_eden), oyun.kad(d.davet_edilen), k.gun), t);
        perform oyun.bildir(ust.davet_eden, format('Davet ağın büyüyor: %s''in davet ettiği %s %s gün aktif oldu. Katsayılı payın %s ₺ cüzdanına yattı.', oyun.kad(d.davet_eden), oyun.kad(d.davet_edilen), k.gun, oyun.tl(tutar)), t);
        sayi := sayi + 1;
      end if;
    end if;
  end loop;
  return sayi;
end $$;

create or replace function oyun.davet_aktiflik_tick()
returns integer language plpgsql security definer set search_path to '' as $$
declare r record; t timestamptz := oyun.simdi(); n int := 0;
begin
  if not pg_try_advisory_xact_lock(781250) then return 0; end if;
  if not coalesce((select aktif from oyun.davet_ayar where id),false) then return 0; end if;
  for r in select d.id from oyun.davet d where d.durum='odendi' and d.zaman > t - interval '120 days'
             and exists(select 1 from oyun.davet_kademe k where k.aktif and not exists(
                 select 1 from oyun.davet_aktiflik_odul o where o.davet_id=d.id and o.kademe_gun=k.gun and o.seviye=1))
           order by d.id limit 2000 loop
    begin
      n := n + oyun.davet_aktiflik_ode(r.id, t);
    exception when others then raise warning 'davet_aktiflik #%: %', r.id, sqlerrm;
    end;
  end loop;
  -- Aynı ağ (IP) üzerinden çok sayıda davet: MASAK incelemesi (engellemez, yalnız bildirir)
  for r in select d.davet_eden u, count(distinct d.davet_edilen) c from oyun.davet d
            where d.zaman > t - interval '30 days' and d.durum in ('bekliyor','odendi')
              and exists(select 1 from oyun.oturumlar a join oyun.oturumlar b on b.ip=a.ip and coalesce(a.ip,'')<>''
                         where a.user_id=d.davet_eden and b.user_id=d.davet_edilen)
            group by d.davet_eden having count(distinct d.davet_edilen) >= 3 loop
    if not exists(select 1 from oyun.masak m where m.tur='davet_suistimal' and m.user_id=r.u and m.zaman > t - interval '7 days') then
      perform oyun.masak_ekle('davet_suistimal', r.u, null, null, null,
        format('%s son 30 günde aynı internet bağlantısını kullanan %s oyuncuyu davet etti. Davet ödüllerinin gerçek oyunculara gittiğini kontrol edin.', oyun.kad(r.u), r.c));
    end if;
  end loop;
  return n;
end $$;

insert into oyun.zamanlayici_adim(adim,komut,periyot_dk,ofset_dk,sira,aktif)
values('davet_aktiflik','select oyun.davet_aktiflik_tick()',60,11,125,true)
on conflict (adim) do update set komut=excluded.komut, periyot_dk=excluded.periyot_dk, aktif=true;

create or replace function public.davet_aktiflik_bilgim()
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi();
begin
  if u is null then raise exception 'Giriş yapmalısın.'; end if;
  return jsonb_build_object(
    'kademeler', coalesce((select jsonb_agg(jsonb_build_object('gun',gun,'tutar',tutar) order by gun) from oyun.davet_kademe where aktif),'[]'::jsonb),
    'ikinci_kademe_oran', coalesce((select deger from oyun.tarife where kod='davet_ikinci_kademe_oran'),20),
    'haftalik_tavan', coalesce((select deger from oyun.tarife where kod='davet_aktiflik_haftalik_tavan'),150000),
    'son7_gun', coalesce((select sum(tutar) from oyun.davet_aktiflik_odul where alan=u and zaman > t - interval '7 days'),0),
    'toplam_aktiflik', coalesce((select sum(tutar) from oyun.davet_aktiflik_odul where alan=u and seviye=1),0),
    'toplam_ag', coalesce((select sum(tutar) from oyun.davet_aktiflik_odul where alan=u and seviye=2),0),
    'davetliler', coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.sk_kad(d.davet_edilen),'durum',d.durum,
         'aktif_gun', oyun.davet_aktif_gun_sayisi(d.davet_edilen,d.zaman),
         'kazanc', coalesce((select sum(o.tutar) from oyun.davet_aktiflik_odul o where o.davet_id=d.id and o.seviye=1),0),
         'alt_davet', (select count(*) from oyun.davet x where x.davet_eden=d.davet_edilen and x.durum='odendi'))
         order by d.zaman desc)
       from (select * from oyun.davet where davet_eden=u order by zaman desc limit 50) d),'[]'::jsonb));
end $$;
revoke all on function public.davet_aktiflik_bilgim() from public, anon;
grant execute on function public.davet_aktiflik_bilgim() to authenticated;
revoke all on function oyun.davet_aktiflik_ode(bigint,timestamptz) from public, anon, authenticated;
revoke all on function oyun.davet_aktiflik_tick() from public, anon, authenticated;
-- Davet ekranı istemciye açılıyor (önceden istemcide ekranı yoktu, RPC kapalıydı)
grant execute on function public.davet_bilgim() to authenticated;
grant execute on function public.davet_kodu_gir(text) to authenticated;
