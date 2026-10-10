-- 2026-10-10 · Şirket halka arzı + yatırım hesaplayıcısı + haftalık şirket kârı hatası düzeltmesi. Kaynak: gelistirici/sql/62_halka_arz.sql
begin;
-- Modül 62: Şirket halka arzı (yeni pay satışıyla sermaye toplama) ve yatırım hesaplayıcısı.
-- Mevcut şirketlere, ortaklara, kasalara ve paylara dokunmaz; yalnız yeni tablo/sütun/fonksiyon ekler.
--
-- Kurallar:
--  * Halka arzı, şirketin en az %50'sine sahip ortak başlatır (aynı anda tek açık arz).
--  * Şirket değeri (arz öncesi) ortakça belirlenir: en az sermaye, en çok max(2 × sermaye, 52 × ortalama haftalık net).
--  * Satılan yeni pay en fazla %49; toplam sermaye 100 milyon ₺'yi aşamaz.
--  * Talep toplama 24/48/72 saat. Talep eden oyuncunun parası arz bitene kadar emanette tutulur.
--  * Süre dolunca toplanan tutar asgari tutara ulaştıysa arz gerçekleşir: para şirketin sermayesine ve
--    kasasına girer, eski ortakların payı oranla seyrelir, yatırımcılar yatırdıkları oranda ortak olur.
--    Ulaşmadıysa ya da arz iptal edilirse herkesin parası iade edilir.
--  * Hedef tutar dolarsa arz beklemeden tamamlanır.
--  * Toplanan para sermayeye eklendiği için kâr payı olarak dağıtılamaz; ortaklar haftalık kârdan
--    paylarına göre pay alır.

alter table oyun.sirketler add column if not exists halka_acik boolean not null default false;

create table if not exists oyun.halka_arz(
  id bigint generated always as identity primary key,
  sirket_id bigint not null references oyun.sirketler(id),
  baslatan uuid not null references auth.users(id),
  deger numeric not null check (deger > 0),
  hedef numeric not null check (hedef > 0),
  asgari numeric not null check (asgari > 0),
  toplanan numeric not null default 0,
  bas timestamptz not null,
  bit timestamptz not null,
  durum text not null default 'acik' check (durum in ('acik','tamam','basarisiz','iptal')),
  sonuc_zaman timestamptz,
  aciklama text
);
create index if not exists halka_arz_sirket on oyun.halka_arz(sirket_id, bas desc);
create index if not exists halka_arz_acik on oyun.halka_arz(bit) where durum = 'acik';
create unique index if not exists halka_arz_tek_acik on oyun.halka_arz(sirket_id) where durum = 'acik';

create table if not exists oyun.halka_arz_talep(
  id bigint generated always as identity primary key,
  arz_id bigint not null references oyun.halka_arz(id),
  user_id uuid not null references auth.users(id),
  tutar numeric not null check (tutar > 0),
  zaman timestamptz not null,
  pay numeric,
  unique (arz_id, user_id)
);
create index if not exists halka_arz_talep_user on oyun.halka_arz_talep(user_id);

alter table oyun.halka_arz enable row level security;
alter table oyun.halka_arz_talep enable row level security;
revoke all on oyun.halka_arz, oyun.halka_arz_talep from public, anon, authenticated;
do $$ begin
  if to_regproc('oyun.bosaltma_korumasi') is not null then
    drop trigger if exists bosaltma_korumasi on oyun.halka_arz;
    create trigger bosaltma_korumasi before truncate on oyun.halka_arz for each statement execute function oyun.bosaltma_korumasi();
    drop trigger if exists bosaltma_korumasi on oyun.halka_arz_talep;
    create trigger bosaltma_korumasi before truncate on oyun.halka_arz_talep for each statement execute function oyun.bosaltma_korumasi();
  end if;
end $$;

-- HATA DÜZELTMESİ: haftalık şirket hesabı ilk kez çalıştığında "round(double precision, integer) does not exist"
-- hatasıyla duruyordu (random() double döndürür). Bu yüzden hiçbir şirkete haftalık kâr yazılmamıştı ve
-- 7. gün dolunca "Şirketlerim" ekranı açılmayacaktı. Mantık canlıdakiyle aynı; yalnız random() numeric'e çevrildi.
create or replace function oyun.sirket_hesapla(p_id bigint)
returns void language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare s oyun.sirketler;n int;i int;net numeric;income numeric;cost numeric;w numeric;t timestamptz:=oyun.simdi();x record;distributed numeric;rate numeric;v_taahhut numeric;v_mevduat numeric;
begin
 perform pg_advisory_xact_lock(98763,hashtext(p_id::text));
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif or s.sonraki_kazanc>t then return;end if;
 n:=least(52,floor(extract(epoch from (t-s.sonraki_kazanc))/604800)::int+1);
 w:=(select asgari from oyun.ulke where id=1);
 rate:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end;
 for i in 1..n loop
  income:=round(s.sermaye*rate*(0.6+random()::numeric*.8),2);
  cost:=round(s.sermaye*(.025+random()::numeric*.055)+w*(.5+random()::numeric),2);
  net:=income-cost;
  distributed:=0;
  -- Zararda sirket kasasi erir. Karda dagitilabilir para ortaklara aktarilir.
  if net<0 then
   if s.sektor='banka' then
     select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0) into v_taahhut,v_mevduat from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi;
     net:=greatest(net,-greatest(0,(select kasa from oyun.sirketler where id=p_id)-v_taahhut-greatest(s.sermaye*0.10,v_mevduat*0.10)));
   end if;
   update oyun.sirketler set kasa=kasa+net where id=p_id;
  else
   distributed:=case when s.sektor='banka' then least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net-s.sermaye-coalesce((select sum(round(m.anapara*(1+m.faiz/100),2)) from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi),0))) else least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net)) end;
   for x in select * from oyun.sirket_ortaklari where sirket_id=p_id loop
    perform oyun.para_islem(x.user_id,round(distributed*x.pay/100,2),'sirket',format('Sirket #%s haftalik net kar payi',p_id),t);
   end loop;
   update oyun.sirketler set kasa=kasa+net-distributed where id=p_id;
  end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
 values(p_id,t,net,'7 günlük faaliyet: gelir - gider = net sonuç; gerçekleşen ortak ödemesi ayrıca kaydedildi',income,cost,distributed);
 end loop;
 update oyun.sirketler set sonraki_kazanc=sonraki_kazanc+n*interval '7 days',son_islem=t where id=p_id;
end $function$;

-- Haftalık ortalama net kâr: oyun formülüyle aynı (sirket_hesapla gelir/gider ortalaması).
create or replace function oyun.sirket_ort_net(p_sermaye numeric, p_sektor text)
returns numeric language sql stable set search_path = '' as $$
  select round(p_sermaye * (case p_sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20
           when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end)
         - p_sermaye * .0525 - (select u.asgari from oyun.ulke u where u.id = 1))
$$;

create or replace function oyun.halka_arz_deger_sinir(p_sermaye numeric, p_sektor text, out en_az numeric, out en_cok numeric, out onerilen numeric)
language sql stable set search_path = '' as $$
  select p_sermaye,
         least(500000000, greatest(p_sermaye * 2, 52 * oyun.sirket_ort_net(p_sermaye, p_sektor))),
         least(least(500000000, greatest(p_sermaye * 2, 52 * oyun.sirket_ort_net(p_sermaye, p_sektor))),
               greatest(p_sermaye, 26 * oyun.sirket_ort_net(p_sermaye, p_sektor)))
$$;

-- Arzı sonuçlandırır (süre doldu, hedef doldu ya da iptal).
create or replace function oyun.halka_arz_kapat(p_id bigint, p_iptal boolean default false)
returns text language plpgsql security definer set search_path = '' as $$
declare a oyun.halka_arz; s oyun.sirketler; t timestamptz := oyun.simdi(); x record; post numeric; f numeric; fark numeric; kisi int; v_sonuc text;
begin
  select * into a from oyun.halka_arz where id = p_id for update;
  if a.id is null or a.durum <> 'acik' then return coalesce(a.durum, 'yok'); end if;
  perform pg_advisory_xact_lock(98763, hashtext(a.sirket_id::text));
  select * into s from oyun.sirketler where id = a.sirket_id for update;
  select count(*) into kisi from oyun.halka_arz_talep where arz_id = a.id;

  if p_iptal or a.toplanan < a.asgari or kisi = 0 or not coalesce(s.aktif, false)
     or s.sermaye + a.toplanan > 100000000 then
    v_sonuc := case when p_iptal then 'iptal' else 'basarisiz' end;
    for x in select * from oyun.halka_arz_talep where arz_id = a.id loop
      perform oyun.para_islem(x.user_id, x.tutar, 'sirket', format('%s halka arzı %s: talep iadesi', s.ad,
        case when p_iptal then 'iptal edildi' else 'gerçekleşmedi' end), t);
      perform oyun.bildir(x.user_id, format('%s halka arzı %s. %s ₺ talebin cüzdanına iade edildi.', s.ad,
        case when p_iptal then 'iptal edildi' else format('yeterli talep toplayamadı (%s / %s ₺)', oyun.tl(a.toplanan), oyun.tl(a.asgari)) end,
        oyun.tl(x.tutar)), t);
    end loop;
    update oyun.halka_arz set durum = v_sonuc, sonuc_zaman = t,
      aciklama = case when p_iptal then 'Şirket tarafından iptal edildi' else 'Asgari talep tutarına ulaşılamadı' end
      where id = a.id;
    perform oyun.bildir(a.baslatan, format('%s halka arzı %s; toplanan %s ₺ yatırımcılara iade edildi.', s.ad,
      case when p_iptal then 'iptal edildi' else 'yeterli talep toplayamadı' end, oyun.tl(a.toplanan)), t);
    return v_sonuc;
  end if;

  -- Önce birikmiş haftalık faaliyetleri eski sermaye ve paylarla kapat.
  perform oyun.sirket_hesapla(a.sirket_id);
  post := a.deger + a.toplanan;
  f := a.deger / post;
  update oyun.sirket_ortaklari set pay = round(pay * f, 6) where sirket_id = a.sirket_id;
  for x in select * from oyun.halka_arz_talep where arz_id = a.id order by id loop
    update oyun.halka_arz_talep set pay = round(x.tutar / post * 100, 6) where id = x.id;
    insert into oyun.sirket_ortaklari(sirket_id, user_id, pay) values (a.sirket_id, x.user_id, round(x.tutar / post * 100, 6))
      on conflict (sirket_id, user_id) do update set pay = oyun.sirket_ortaklari.pay + excluded.pay;
  end loop;
  delete from oyun.sirket_ortaklari where sirket_id = a.sirket_id and pay <= 0;
  -- Yuvarlama farkı en büyük ortağa yazılır; paylar toplamı tam %100 olur.
  select 100 - sum(pay) into fark from oyun.sirket_ortaklari where sirket_id = a.sirket_id;
  if fark <> 0 then
    update oyun.sirket_ortaklari set pay = pay + fark
      where sirket_id = a.sirket_id and user_id = (select user_id from oyun.sirket_ortaklari where sirket_id = a.sirket_id order by pay desc, user_id limit 1);
  end if;
  update oyun.sirketler set sermaye = sermaye + a.toplanan, kasa = kasa + a.toplanan, halka_acik = true, satilik = null where id = a.sirket_id;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama)
    values (a.sirket_id, t, a.toplanan, format('Halka arz: %s yatırımcıdan %s ₺ yeni sermaye (şirket değeri %s ₺, satılan pay %%%s)',
      kisi, oyun.tl(a.toplanan), oyun.tl(a.deger), round(a.toplanan / post * 100, 2)));
  update oyun.halka_arz set durum = 'tamam', sonuc_zaman = t,
    aciklama = format('%s yatırımcı, %s ₺, satılan pay %%%s', kisi, oyun.tl(a.toplanan), round(a.toplanan / post * 100, 2)) where id = a.id;
  for x in select h.user_id, h.tutar, h.pay from oyun.halka_arz_talep h where h.arz_id = a.id loop
    perform oyun.bildir(x.user_id, format('%s halka arzı tamamlandı: %s ₺ karşılığında şirketin %%%s ortağı oldun. Haftalık kârdan payına düşen tutar cüzdanına gelecek.',
      s.ad, oyun.tl(x.tutar), round(x.pay, 2)), t);
  end loop;
  for x in select o.user_id, o.pay from oyun.sirket_ortaklari o
           where o.sirket_id = a.sirket_id and not exists (select 1 from oyun.halka_arz_talep h where h.arz_id = a.id and h.user_id = o.user_id) loop
    perform oyun.bildir(x.user_id, format('%s halka arzı tamamlandı: %s ₺ yeni sermaye girdi (yeni sermaye %s ₺). Şirketteki payın artık %%%s.',
      s.ad, oyun.tl(a.toplanan), oyun.tl(s.sermaye + a.toplanan), round(x.pay, 2)), t);
  end loop;
  perform oyun.olay('ekonomi', format('%s halka arzı tamamlandı: %s yatırımcı %s ₺ yatırdı, şirket sermayesi %s ₺ oldu.',
    s.ad, kisi, oyun.tl(a.toplanan), oyun.tl(s.sermaye + a.toplanan)), null, null, t);
  return 'tamam';
end $$;

-- Süresi dolan arzları kapatır. Zamanlayıcı her dakika çağırır; listeleme fonksiyonları da çağırır.
create or replace function oyun.halka_arz_tick()
returns void language plpgsql security definer set search_path = '' as $$
declare x record;
begin
  for x in select id from oyun.halka_arz where durum = 'acik' and bit <= oyun.simdi() order by bit loop
    perform oyun.halka_arz_kapat(x.id, false);
  end loop;
end $$;

create or replace function oyun.halka_arz_json(a oyun.halka_arz, u uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', a.id, 'sirket_id', a.sirket_id, 'sirket', s.ad, 'sektor', s.sektor,
    'baslatan', (select kad from oyun.profiller where id = a.baslatan), 'ben_baslattim', a.baslatan = u,
    'deger', a.deger, 'hedef', a.hedef, 'asgari', a.asgari, 'toplanan', a.toplanan,
    'bas', a.bas, 'bit', a.bit, 'durum', a.durum, 'sonuc_zaman', a.sonuc_zaman, 'aciklama', a.aciklama,
    'sermaye', s.sermaye, 'kasa', s.kasa,
    'satilan_pay_hedef', round(a.hedef / (a.deger + a.hedef) * 100, 2),
    'pay_fiyati_1', round((a.deger + a.hedef) / 100, 2),
    'ort_net_simdi', oyun.sirket_ort_net(s.sermaye, s.sektor),
    'ort_net_hedef', oyun.sirket_ort_net(s.sermaye + case when a.durum = 'acik' then a.hedef else 0 end, s.sektor),
    'yatirimci', (select count(*) from oyun.halka_arz_talep h where h.arz_id = a.id),
    'talebim', coalesce((select h.tutar from oyun.halka_arz_talep h where h.arz_id = a.id and h.user_id = u), 0),
    'ortaklar', coalesce((select jsonb_agg(jsonb_build_object('kad', p.kad, 'pay', round(o.pay, 2)) order by o.pay desc)
                  from oyun.sirket_ortaklari o join oyun.profiller p on p.id = o.user_id where o.sirket_id = s.id), '[]'::jsonb))
  from oyun.sirketler s where s.id = a.sirket_id
$$;

-- Hesaplayıcı: "şu kadar yatırım gelse haftalık ortalama kâr kaça çıkar, payım ne olur?"
create or replace function public.halka_arz_hesapla(p_sirket bigint, p_tutar numeric, p_deger numeric default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); s oyun.sirketler; d record; v_deger numeric; v_tutar numeric; post numeric; benim numeric; once numeric; sonra numeric;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  select * into s from oyun.sirketler where id = p_sirket and aktif;
  if s.id is null then raise exception 'Şirket bulunamadı'; end if;
  select * into d from oyun.halka_arz_deger_sinir(s.sermaye, s.sektor);
  v_tutar := greatest(0, round(coalesce(p_tutar, 0)));
  v_deger := least(d.en_cok, greatest(d.en_az, round(coalesce(p_deger, d.onerilen))));
  post := v_deger + v_tutar;
  benim := coalesce((select pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u), 0);
  once := oyun.sirket_ort_net(s.sermaye, s.sektor);
  sonra := oyun.sirket_ort_net(s.sermaye + v_tutar, s.sektor);
  return jsonb_build_object(
    'sirket', s.ad, 'sektor', s.sektor, 'sermaye', s.sermaye, 'yeni_sermaye', s.sermaye + v_tutar,
    'yatirim', v_tutar, 'deger', v_deger, 'deger_en_az', d.en_az, 'deger_en_cok', d.en_cok, 'deger_onerilen', d.onerilen,
    'asgari_ucret', (select asgari from oyun.ulke where id = 1),
    'ort_net_simdi', once, 'ort_net_sonra', sonra, 'ort_net_artis', sonra - once,
    'yatirimci_payi', round(v_tutar / post * 100, 2),
    'benim_payim_simdi', round(benim, 2), 'benim_payim_sonra', round(benim * v_deger / post, 2),
    'benim_haftalik_simdi', round(greatest(once, 0) * benim / 100), 'benim_haftalik_sonra', round(greatest(sonra, 0) * benim * v_deger / post / 100),
    'yatirimci_haftalik', round(greatest(sonra, 0) * v_tutar / post),
    'yatirimci_geri_donus_hafta', case when sonra > 0 and v_tutar > 0 then ceil(v_tutar / (sonra * v_tutar / post)) end,
    'sinir_asildi', s.sermaye + v_tutar > 100000000 or (v_tutar > 0 and v_tutar / post > .49));
end $$;

create or replace function public.halka_arz_baslat(p_sirket bigint, p_hedef numeric, p_deger numeric, p_asgari numeric default null, p_saat int default 72)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); s oyun.sirketler; d record; t timestamptz := oyun.simdi(); v_asgari numeric; v_id bigint;
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u and not yasakli) then raise exception 'Oyuncu hesabı gerekli'; end if;
  perform pg_advisory_xact_lock(98763, hashtext(p_sirket::text));
  select * into s from oyun.sirketler where id = p_sirket and aktif for update;
  if s.id is null then raise exception 'Şirket bulunamadı'; end if;
  if not exists (select 1 from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u and pay >= 50) then
    raise exception 'Halka arzı yalnız şirketin en az %%50''sine sahip ortak başlatabilir'; end if;
  if exists (select 1 from oyun.halka_arz where sirket_id = s.id and durum = 'acik') then raise exception 'Bu şirketin zaten açık bir halka arzı var'; end if;
  if p_hedef is null or p_hedef <> round(p_hedef) or p_hedef < 10000 then raise exception 'Halka arz tutarı en az 10.000 ₺ ve tam sayı olmalı'; end if;
  if s.sermaye + p_hedef > 100000000 then raise exception 'Halka arz sonrası sermaye 100.000.000 ₺''yi aşamaz (en fazla % ₺ toplanabilir)', oyun.tl(100000000 - s.sermaye); end if;
  select * into d from oyun.halka_arz_deger_sinir(s.sermaye, s.sektor);
  if p_deger is null or p_deger <> round(p_deger) or p_deger < d.en_az or p_deger > d.en_cok then
    raise exception 'Şirket değeri % ₺ ile % ₺ arasında olmalı', oyun.tl(d.en_az), oyun.tl(d.en_cok); end if;
  if p_hedef / (p_deger + p_hedef) > .49 then
    raise exception 'Halka arzda şirketin en fazla %%49''u satılabilir. Bu değerle en fazla % ₺ toplayabilirsin', oyun.tl(floor(p_deger * 49 / 51)); end if;
  v_asgari := coalesce(round(p_asgari), round(p_hedef / 2));
  if v_asgari < 10000 or v_asgari > p_hedef then raise exception 'Asgari tutar 10.000 ₺ ile hedef tutar arasında olmalı'; end if;
  if p_saat not in (24, 48, 72) then raise exception 'Talep süresi 24, 48 ya da 72 saat olmalı'; end if;
  update oyun.sirketler set satilik = null where id = s.id;
  insert into oyun.halka_arz(sirket_id, baslatan, deger, hedef, asgari, bas, bit)
    values (s.id, u, p_deger, p_hedef, v_asgari, t, t + make_interval(hours => p_saat)) returning id into v_id;
  perform oyun.olay('ekonomi', format('%s halka arz ediliyor: %s ₺ hedef, şirketin %%%s''i satışta. Talep toplama %s saat sürecek.',
    s.ad, oyun.tl(p_hedef), round(p_hedef / (p_deger + p_hedef) * 100, 2), p_saat), null, null, t);
  return oyun.halka_arz_json((select a from oyun.halka_arz a where a.id = v_id), u);
end $$;

create or replace function public.halka_arz_talep(p_arz bigint, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); a oyun.halka_arz; t timestamptz := oyun.simdi(); v_ad text; v_mevcut numeric;
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u and not yasakli) then raise exception 'Oyuncu hesabı gerekli'; end if;
  perform oyun.halka_arz_tick();
  select * into a from oyun.halka_arz where id = p_arz for update;
  if a.id is null or a.durum <> 'acik' or a.bit <= t then raise exception 'Bu halka arz artık talep toplamıyor'; end if;
  if a.baslatan = u then raise exception 'Kendi başlattığın halka arza talep veremezsin; şirketin tamamı sende ise sermaye artırımını kullan'; end if;
  if p_tutar is null or p_tutar <> round(p_tutar) or p_tutar < 1000 then raise exception 'Talep en az 1.000 ₺ ve tam sayı olmalı'; end if;
  if a.toplanan + p_tutar > a.hedef then raise exception 'Kalan talep miktarı % ₺', oyun.tl(a.hedef - a.toplanan); end if;
  select ad into v_ad from oyun.sirketler where id = a.sirket_id;
  perform oyun.para_islem(u, -p_tutar, 'sirket', format('%s halka arz talebi (emanet)', v_ad), t);
  select tutar into v_mevcut from oyun.halka_arz_talep where arz_id = a.id and user_id = u;
  insert into oyun.halka_arz_talep(arz_id, user_id, tutar, zaman) values (a.id, u, p_tutar, t)
    on conflict (arz_id, user_id) do update set tutar = oyun.halka_arz_talep.tutar + excluded.tutar, zaman = excluded.zaman;
  update oyun.halka_arz set toplanan = toplanan + p_tutar where id = a.id returning * into a;
  if v_mevcut is null then
    perform oyun.bildir(a.baslatan, format('%s halka arzına %s %s ₺ talep verdi (toplanan %s / %s ₺).', v_ad,
      (select kad from oyun.profiller where id = u), oyun.tl(p_tutar), oyun.tl(a.toplanan), oyun.tl(a.hedef)), t);
  end if;
  if a.toplanan >= a.hedef then perform oyun.halka_arz_kapat(a.id, false); end if;
  return oyun.halka_arz_json((select x from oyun.halka_arz x where x.id = a.id), u);
end $$;

create or replace function public.halka_arz_talep_geri(p_arz bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); a oyun.halka_arz; h oyun.halka_arz_talep; t timestamptz := oyun.simdi();
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  perform oyun.halka_arz_tick();
  select * into a from oyun.halka_arz where id = p_arz for update;
  if a.id is null or a.durum <> 'acik' then raise exception 'Bu halka arz sonuçlandı; talep geri alınamaz'; end if;
  select * into h from oyun.halka_arz_talep where arz_id = a.id and user_id = u for update;
  if h.id is null then raise exception 'Bu halka arzda talebin yok'; end if;
  delete from oyun.halka_arz_talep where id = h.id;
  update oyun.halka_arz set toplanan = toplanan - h.tutar where id = a.id;
  perform oyun.para_islem(u, h.tutar, 'sirket', format('%s halka arz talebi geri alındı', (select ad from oyun.sirketler where id = a.sirket_id)), t);
  return oyun.halka_arz_json((select x from oyun.halka_arz x where x.id = a.id), u);
end $$;

create or replace function public.halka_arz_iptal(p_arz bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); a oyun.halka_arz;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  select * into a from oyun.halka_arz where id = p_arz;
  if a.id is null or a.durum <> 'acik' then raise exception 'Açık halka arz bulunamadı'; end if;
  if a.baslatan <> u and not exists (select 1 from oyun.sirket_ortaklari where sirket_id = a.sirket_id and user_id = u and pay >= 50) then
    raise exception 'Halka arzı yalnız başlatan ya da şirketin en az %%50 ortağı iptal edebilir'; end if;
  perform oyun.halka_arz_kapat(a.id, true);
  return oyun.halka_arz_json((select x from oyun.halka_arz x where x.id = a.id), u);
end $$;

-- Açık arzlar (herkes) + son sonuçlananlar + benim taleplerim.
create or replace function public.halka_arz_liste()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  perform oyun.halka_arz_tick();
  return jsonb_build_object(
    'acik', coalesce((select jsonb_agg(oyun.halka_arz_json(a, u) order by a.bit) from oyun.halka_arz a where a.durum = 'acik'), '[]'::jsonb),
    'son', coalesce((select jsonb_agg(oyun.halka_arz_json(a, u) order by a.sonuc_zaman desc)
                     from (select * from oyun.halka_arz where durum <> 'acik' order by sonuc_zaman desc limit 10) a), '[]'::jsonb),
    'cuzdan', (select para from oyun.cuzdan where user_id = u));
end $$;

-- Bir şirketin halka arz durumu (şirket ekranı için).
create or replace function public.halka_arz_durum(p_sirket bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); s oyun.sirketler; d record;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  perform oyun.halka_arz_tick();
  select * into s from oyun.sirketler where id = p_sirket and aktif;
  if s.id is null then raise exception 'Şirket bulunamadı'; end if;
  select * into d from oyun.halka_arz_deger_sinir(s.sermaye, s.sektor);
  return jsonb_build_object(
    'id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'sermaye', s.sermaye, 'kasa', s.kasa, 'halka_acik', s.halka_acik,
    'payim', coalesce((select pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u), 0),
    'asgari_ucret', (select asgari from oyun.ulke where id = 1),
    'ort_net', oyun.sirket_ort_net(s.sermaye, s.sektor),
    'deger_en_az', d.en_az, 'deger_en_cok', d.en_cok, 'deger_onerilen', d.onerilen,
    'en_fazla_tutar', least(100000000 - s.sermaye, floor(d.en_cok * 49 / 51)),
    'acik', (select oyun.halka_arz_json(a, u) from oyun.halka_arz a where a.sirket_id = s.id and a.durum = 'acik'),
    'gecmis', coalesce((select jsonb_agg(oyun.halka_arz_json(a, u) order by a.bas desc)
                        from (select * from oyun.halka_arz where sirket_id = s.id and durum <> 'acik' order by bas desc limit 5) a), '[]'::jsonb));
end $$;

revoke all on function oyun.sirket_ort_net(numeric, text), oyun.halka_arz_deger_sinir(numeric, text), oyun.halka_arz_kapat(bigint, boolean),
  oyun.halka_arz_tick(), oyun.halka_arz_json(oyun.halka_arz, uuid) from public, anon, authenticated;
revoke all on function public.halka_arz_hesapla(bigint, numeric, numeric), public.halka_arz_baslat(bigint, numeric, numeric, numeric, int),
  public.halka_arz_talep(bigint, numeric), public.halka_arz_talep_geri(bigint), public.halka_arz_iptal(bigint),
  public.halka_arz_liste(), public.halka_arz_durum(bigint) from public, anon;
grant execute on function public.halka_arz_hesapla(bigint, numeric, numeric), public.halka_arz_baslat(bigint, numeric, numeric, numeric, int),
  public.halka_arz_talep(bigint, numeric), public.halka_arz_talep_geri(bigint), public.halka_arz_iptal(bigint),
  public.halka_arz_liste(), public.halka_arz_durum(bigint) to authenticated;
-- Süresi dolan halka arzları her dakika sonuçlandır (yalnız pg_cron olan Supabase'de)
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'halka-arz';
    perform cron.schedule('halka-arz', '* * * * *', 'select oyun.halka_arz_tick()');
  end if;
end $$;
commit;
