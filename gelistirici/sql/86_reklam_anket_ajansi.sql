-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 86) Reklam ve anket ajansları
--  Gerçek oyuncuların oynadığı oyunda kampanya da gerçek oyunculara ulaşmalı. Bu yüzden:
--  • REKLAM: Parti (genel başkan, parti kasasından) ya da bir oyuncu (kendi cebinden) bir ajanstan
--    reklam satın alır. Reklam hedef ildeki (ya da tüm Türkiye'deki) oyuncuların Gündem ekranının
--    başında "Sponsorlu" kart olarak görünür; kalite 2+ ise başlarken bildirim de gider.
--    Süre ajansın kalitesine bağlı (12-36 saat). Bir ilde aynı anda en fazla 2, Türkiye genelinde 1 reklam.
--  • ANKET: Ajans hedef ildeki (ya da Türkiye'deki) gerçek oyunculara 24 saat "Bugün seçim olsa
--    hangi partiye oy verirsiniz?" sorar. Cevaplayana ajans kasasından katılım ödülü (kalite arttıkça
--    büyür, ücretin %40'ı kadar havuz) ödenir. Sonuç (oy oranları, kararsızlar, hata payı) yalnız
--    sipariş verene gelir; isterse yayımlar. Oy günü ve öncesindeki 24 saatte yayın yasağı vardır.
--  • AJANS ŞİRKETİ: Yeni şirket türü "ajans". Sahibi fiyat (ucuz/orta/premium) ve kalite (0-3) seçer.
--    Geliri siparişlerden gelir; gideri sabit gider, personel, kalite ve katılım ödülleri.
--    Haftalık hesapta kâr ortaklara, %20 kurumlar vergisi hazineye. Aynı anda yürüttüğü iş sayısı
--    kalite ve sermayeyle sınırlı. Müşteri işi 1-5 puanlar; puan ve tamamlanan işler markayı büyütür.
--  Önce 84 ve 85 kurulmuş olmalı. Yalnız ekler.
-- =====================================================================

alter table oyun.sirketler drop constraint if exists sirketler_sektor_check;
alter table oyun.sirketler add constraint sirketler_sektor_check check (sektor in
  ('tarim','sanayi','teknoloji','ticaret','insaat','medya','banka','ozel_okul','ozel_hastane','market','ulasim','enerji','ajans'));

create table if not exists oyun.ajans(
  sirket_id   bigint primary key references oyun.sirketler(id),
  fiyat       smallint not null default 2 check (fiyat between 1 and 3),
  kalite      smallint not null default 1 check (kalite between 0 and 3),
  marka       numeric not null default 10,
  hafta_gelir numeric not null default 0,
  hafta_odul  numeric not null default 0,
  is_sayisi   int not null default 0,
  son_ayar    timestamptz,
  son_uyari   timestamptz
);

create table if not exists oyun.ajans_is(
  id         bigserial primary key,
  sirket_id  bigint not null references oyun.sirketler(id),
  tur        text not null check (tur in ('reklam','anket')),
  il_id      smallint references oyun.iller(id),          -- null = tüm Türkiye
  kaynak     text not null check (kaynak in ('parti','kisi')),
  parti_id   bigint references oyun.partiler(id),
  veren      uuid not null,
  metin      text,
  ucret      numeric not null,
  kalite     smallint not null,
  odul       numeric not null default 0,                 -- katılımcı başı ödül (anket)
  havuz      numeric not null default 0,                 -- kalan ödül havuzu (anket)
  bas        timestamptz not null,
  bit        timestamptz not null,
  durum      text not null default 'yayinda' check (durum in ('yayinda','bitti')),
  gosterim   int not null default 0,
  sonuc      jsonb,
  yayimlandi timestamptz,
  puan       smallint check (puan between 1 and 5)
);
create index if not exists ajans_is_aktif on oyun.ajans_is(tur, durum, il_id);
create index if not exists ajans_is_veren on oyun.ajans_is(veren, id desc);

create table if not exists oyun.ajans_gosterim(
  is_id   bigint not null references oyun.ajans_is(id),
  user_id uuid not null,
  zaman   timestamptz not null,
  primary key (is_id, user_id)
);
create table if not exists oyun.ajans_cevap(
  is_id    bigint not null references oyun.ajans_is(id),
  user_id  uuid not null,
  parti_id bigint,                                         -- null = kararsız
  odul     numeric not null default 0,
  zaman    timestamptz not null,
  primary key (is_id, user_id)
);

do $$ declare t text; begin
  foreach t in array array['ajans','ajans_is','ajans_gosterim','ajans_cevap'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
  revoke all on sequence oyun.ajans_is_id_seq from public, anon, authenticated;
end $$;

-- ---------------------------------------------------------------- yardımcılar
-- İl büyüklüğü katsayısı (Türkiye geneli 6)
create or replace function oyun.ajans_il_kat(p_il smallint) returns numeric language sql stable set search_path = '' as $$
  select case when p_il is null then 6 else (select case when mv <= 5 then 1 when mv <= 20 then 2 else 3 end from oyun.iller where id = p_il) end
$$;
create or replace function oyun.ajans_ucret(p_sirket bigint, p_tur text, p_il smallint) returns numeric language sql stable set search_path = '' as $$
  select round((case p_tur when 'anket' then 20000 else 15000 end) * oyun.ajans_il_kat(p_il)
    * oyun.pazar_fiyat_katsayi(a.fiyat) * coalesce((select endeks from oyun.ulke where id = 1), 1), -2)
  from oyun.ajans a where a.sirket_id = p_sirket
$$;
create or replace function oyun.ajans_kapasite(p_sirket bigint) returns int language sql stable set search_path = '' as $$
  select least(6, 1 + a.kalite + floor(s.sermaye / 300000)::int) from oyun.ajans a join oyun.sirketler s on s.id = a.sirket_id where a.sirket_id = p_sirket
$$;
create or replace function oyun.ajans_dolu(p_sirket bigint) returns int language sql stable set search_path = '' as $$
  select count(*)::int from oyun.ajans_is where sirket_id = p_sirket and durum = 'yayinda'
$$;
-- Oy günü ve öncesindeki 24 saat anket yayın yasağı
create or replace function oyun.anket_yasagi(t timestamptz) returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.secimler where durum = 'bekliyor' and oy_bas is not null
                 and oy_bas - interval '24 hours' <= t and coalesce(oy_bit, oy_bas + interval '1 day') > t)
$$;
create or replace function oyun.ajans_haftalik_gider(p_sirket bigint) returns numeric language sql stable set search_path = '' as $$
  select round(s.sermaye * 0.03 + s.sermaye * 0.012 * a.kalite
    + coalesce((select asgari from oyun.ulke where id = 1), 30000) * 0.6 * power(greatest(0.5, s.sermaye / 300000.0), 0.7))
  from oyun.ajans a join oyun.sirketler s on s.id = a.sirket_id where a.sirket_id = p_sirket
$$;

-- ---------------------------------------------------------------- haftalık hesap
create or replace function oyun.ajans_hesapla(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare s oyun.sirketler; a oyun.ajans; t timestamptz := oyun.simdi(); n int; i int; gider numeric; net numeric; v_vergi numeric;
  x record; distributed numeric; distributable numeric; v_odeme numeric; kasa_son numeric; gelir numeric; odul numeric;
begin
  select * into s from oyun.sirketler where id = p_id for update;
  select * into a from oyun.ajans where sirket_id = p_id for update;
  if s.id is null or a.sirket_id is null or not s.aktif or s.sonraki_kazanc > t then return; end if;
  n := least(52, floor(extract(epoch from (t - s.sonraki_kazanc)) / 604800)::int + 1);
  for i in 1..n loop
    gelir := case when i = 1 then a.hafta_gelir else 0 end;
    odul := case when i = 1 then a.hafta_odul else 0 end;
    gider := oyun.ajans_haftalik_gider(p_id);
    net := gelir - odul - gider;
    v_vergi := round(greatest(0, net) * (select kurumlar from oyun.pazar_ayar where id = 1) / 100);
    net := net - v_vergi;
    if v_vergi > 0 then update oyun.ulke set hazine = hazine + v_vergi / oyun.pazar_tl_milyar() where id = 1; end if;
    -- gelir ve ödüller kasaya zaten işlendi; burada gider ve vergi düşer, kâr dağıtılır
    update oyun.sirketler set kasa = kasa - gider - v_vergi where id = p_id;
    distributed := 0;
    if net > 0 then
      distributable := least(net, greatest(0, (select kasa from oyun.sirketler where id = p_id)));
      for x in select * from oyun.sirket_ortaklari where sirket_id = p_id loop
        if not x.kar_kasada then
          v_odeme := least(round(distributable * x.pay / 100, 2), greatest(0, distributable - distributed));
          if v_odeme > 0 then
            perform oyun.para_islem(x.user_id, v_odeme, 'sirket', format('%s haftalık net kâr payı', s.ad), t);
            distributed := distributed + v_odeme;
          end if;
        end if;
      end loop;
      update oyun.sirketler set kasa = kasa - distributed where id = p_id;
    end if;
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
      values (p_id, t, net, '7 günlük faaliyet (ajans): sipariş geliri - katılım ödülleri - gider - vergi = net', gelir, odul + gider + v_vergi, distributed);
    update oyun.ajans set hafta_gelir = 0, hafta_odul = 0, marka = greatest(5, marka * 0.95) where sirket_id = p_id;
    a.hafta_gelir := 0; a.hafta_odul := 0;
    select kasa into kasa_son from oyun.sirketler where id = p_id;
    if kasa_son <= 0 then
      update oyun.sirketler set aktif = false, kasa = 0, satilik = null, son_islem = t,
        sonraki_kazanc = s.sonraki_kazanc + i * interval '7 days' where id = p_id;
      perform oyun.olay('ekonomi', format('%s ajansı iflas etti; kasası tükendi.', s.ad), null, null, t);
      for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
        perform oyun.bildir(x.user_id, format('%s iflas etti: ajansın kasası tükendi.', s.ad), t);
      end loop;
      return;
    end if;
  end loop;
  update oyun.sirketler set sonraki_kazanc = sonraki_kazanc + n * interval '7 days', son_islem = t where id = p_id;
  if kasa_son < s.sermaye * 0.25 and (a.son_uyari is null or a.son_uyari < t - interval '6 days') then
    update oyun.ajans set son_uyari = t where sirket_id = p_id;
    for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
      perform oyun.bildir(x.user_id, format('%s zarar ediyor: kasada %s ₺ kaldı. Fiyatı düşürmeyi ya da kaliteyi azaltmayı düşün.', s.ad, oyun.tl(kasa_son)), t);
    end loop;
  end if;
end $$;

-- sirket_hesapla: ajans dalı eklendi (84'teki hâl korunarak)
create or replace function oyun.sirket_hesapla(p_id bigint)
returns void language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare s oyun.sirketler;n int;i int;net numeric;income numeric;cost numeric;w numeric;t timestamptz:=oyun.simdi();x record;distributed numeric;rate numeric;v_taahhut numeric;v_mevduat numeric;distributable numeric;v_odeme numeric;
begin
 perform pg_advisory_xact_lock(98763,hashtext(p_id::text));
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif or s.sonraki_kazanc>t then return;end if;
 if exists(select 1 from oyun.pazar_sektor where kod=s.sektor) then perform oyun.pazar_hesapla(p_id); return; end if;
 if s.sektor='ajans' then perform oyun.ajans_hesapla(p_id); return; end if;
 n:=least(52,floor(extract(epoch from (t-s.sonraki_kazanc))/604800)::int+1);
 w:=(select asgari from oyun.ulke where id=1);
 rate:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end;
 for i in 1..n loop
  income:=round(s.sermaye*rate*(0.6+random()::numeric*.8),2);
  cost:=round(s.sermaye*(.025+random()::numeric*.055)+w*(.5+random()::numeric),2);
  income:=round(income * oyun.kriz_sektor_carpani(s.sektor,s.sonraki_kazanc + (i-1) * interval '7 days')
                       * oyun.sektor_pol_carpan(s.sektor,s.sonraki_kazanc + (i-1) * interval '7 days'),2); net:=income-cost;
  distributed:=0;
  if net<0 then
   if s.sektor='banka' then
     select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0) into v_taahhut,v_mevduat from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi;
     net:=greatest(net,-greatest(0,(select kasa from oyun.sirketler where id=p_id)-v_taahhut-greatest(s.sermaye*0.10,v_mevduat*0.10)));
   end if;
   update oyun.sirketler set kasa=kasa+net where id=p_id;
  else
   distributable:=case when s.sektor='banka' then least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net-s.sermaye-coalesce((select sum(round(m.anapara*(1+m.faiz/100),2)) from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi),0))) else least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net)) end;
   for x in select * from oyun.sirket_ortaklari where sirket_id=p_id loop
    if not x.kar_kasada then
      v_odeme:=least(round(distributable*x.pay/100,2),greatest(0,distributable-distributed));
      if v_odeme>0 then
        perform oyun.para_islem(x.user_id,v_odeme,'sirket',format('Sirket #%s haftalik net kar payi',p_id),t);
        distributed:=distributed+v_odeme;
      end if;
    end if;
   end loop;
   update oyun.sirketler set kasa=kasa+net-distributed where id=p_id;
  end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
 values(p_id,t,net,'7 günlük faaliyet: gelir - gider = net sonuç; gerçekleşen ortak ödemesi ayrıca kaydedildi',income,cost,distributed);
 end loop;
 update oyun.sirketler set sonraki_kazanc=sonraki_kazanc+n*interval '7 days',son_islem=t where id=p_id;
end $function$;

-- ---------------------------------------------------------------- ajans sahibi
create or replace function public.ajans_kur(p_ad text, p_sermaye numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_id bigint; t timestamptz := oyun.simdi();
begin
  if p_ad is null or char_length(btrim(p_ad)) not between 3 and 50 then raise exception 'Ajans adı 3-50 karakter olmalı.'; end if;
  if p_sermaye is null or p_sermaye <> round(p_sermaye) or p_sermaye < 150000 or p_sermaye > 100000000 then
    raise exception 'Ajans sermayesi en az 150.000 ₺, en fazla 100.000.000 ₺ olmalı.';
  end if;
  if exists (select 1 from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id = s.id
             where s.sektor = 'ajans' and s.aktif and o.user_id = p.id and o.pay >= 50) then
    raise exception 'Zaten çoğunluğuna sahip olduğun bir ajans var.';
  end if;
  perform oyun.para_islem(p.id, -p_sermaye, 'sirket', 'Reklam ve anket ajansı kuruluş sermayesi', t);
  insert into oyun.sirketler(ad, sektor, kurucu, sermaye, kasa, son_islem, kurulus, sonraki_kazanc)
    values (btrim(p_ad), 'ajans', p.id, p_sermaye, p_sermaye, t, t, t + interval '7 days') returning id into v_id;
  insert into oyun.sirket_ortaklari(sirket_id, user_id, pay) values (v_id, p.id, 100);
  insert into oyun.ajans(sirket_id) values (v_id);
  perform oyun.olay('ekonomi', format('%s yeni bir reklam ve anket ajansı kurdu: %s.', p.kad, btrim(p_ad)), null, null, t);
  return jsonb_build_object('id', v_id);
end $$;

create or replace function public.ajans_ayarla(p_sirket bigint, p_fiyat int, p_kalite int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.ajans; t timestamptz := oyun.simdi();
begin
  select * into a from oyun.ajans where sirket_id = p_sirket;
  if a.sirket_id is null or not (select aktif from oyun.sirketler where id = p_sirket) then raise exception 'Ajans bulunamadı.'; end if;
  if not oyun.sirket_yonetici_mi(p_sirket, p.id) then raise exception 'Ajansın kararlarını en büyük ortak verir.'; end if;
  if p_fiyat not between 1 and 3 or p_kalite not between 0 and 3 then raise exception 'Fiyat 1-3, kalite 0-3 arasında olmalı.'; end if;
  if a.son_ayar is not null and a.son_ayar > t - interval '10 minutes' then raise exception 'Ayarları 10 dakikada bir değiştirebilirsin.'; end if;
  perform oyun.sirket_hesapla(p_sirket);
  update oyun.ajans set fiyat = p_fiyat, kalite = p_kalite, son_ayar = t where sirket_id = p_sirket;
  return public.ajans_yonetim(p_sirket);
end $$;

create or replace function public.ajans_yonetim(p_sirket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; a oyun.ajans;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null or s.sektor <> 'ajans' then raise exception 'Ajans bulunamadı.'; end if;
  if not exists (select 1 from oyun.sirket_ortaklari where sirket_id = s.id and user_id = p.id) then raise exception 'Bu ajansın ortağı değilsin.'; end if;
  perform oyun.sirket_hesapla(s.id);
  select * into s from oyun.sirketler where id = p_sirket;
  select * into a from oyun.ajans where sirket_id = p_sirket;
  return jsonb_build_object('id', s.id, 'ad', s.ad, 'aktif', s.aktif, 'kasa', round(s.kasa), 'sermaye', s.sermaye,
    'fiyat', a.fiyat, 'kalite', a.kalite, 'marka', round(a.marka), 'is_sayisi', a.is_sayisi,
    'hafta_gelir', a.hafta_gelir, 'hafta_odul', a.hafta_odul, 'haftalik_gider', oyun.ajans_haftalik_gider(s.id),
    'kapasite', oyun.ajans_kapasite(s.id), 'dolu', oyun.ajans_dolu(s.id), 'sonraki', s.sonraki_kazanc,
    'yonetici', oyun.sirket_yonetici_mi(s.id, p.id),
    'puan', (select round(avg(puan), 1) from oyun.ajans_is where sirket_id = s.id and puan is not null),
    'fiyatlar', jsonb_build_object('kucuk', jsonb_build_object('reklam', oyun.ajans_ucret(s.id, 'reklam', (select id from oyun.iller where mv <= 5 order by id limit 1)),
        'anket', oyun.ajans_ucret(s.id, 'anket', (select id from oyun.iller where mv <= 5 order by id limit 1))),
      'buyuk', jsonb_build_object('reklam', oyun.ajans_ucret(s.id, 'reklam', 34::smallint), 'anket', oyun.ajans_ucret(s.id, 'anket', 34::smallint)),
      'turkiye', jsonb_build_object('reklam', oyun.ajans_ucret(s.id, 'reklam', null), 'anket', oyun.ajans_ucret(s.id, 'anket', null))),
    'reklam_saat', 12 + 8 * a.kalite, 'anket_odul', round((300 + 250 * a.kalite) * coalesce((select endeks from oyun.ulke where id = 1), 1)),
    'isler', coalesce((select jsonb_agg(oyun.ajans_is_json(j, p.id) order by j.id desc) from (select * from oyun.ajans_is where sirket_id = s.id order by id desc limit 15) j), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------- müşteri tarafı
create or replace function oyun.ajans_is_json(j oyun.ajans_is, u uuid) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id', j.id, 'tur', j.tur, 'ajans', (select ad from oyun.sirketler where id = j.sirket_id), 'sirket_id', j.sirket_id,
    'il', coalesce((select ad from oyun.iller where id = j.il_id), 'Tüm Türkiye'), 'il_id', j.il_id, 'kaynak', j.kaynak,
    'parti', (select kisa from oyun.partiler where id = j.parti_id), 'veren', oyun.kad(j.veren), 'metin', j.metin, 'ucret', j.ucret,
    'bas', j.bas, 'bit', j.bit, 'durum', j.durum, 'gosterim', j.gosterim,
    'katilim', (select count(*) from oyun.ajans_cevap where is_id = j.id),
    'sonuc', case when j.veren = u or j.yayimlandi is not null
                    or (j.parti_id is not null and exists (select 1 from oyun.partiler where id = j.parti_id and gb = u)) then j.sonuc end,
    'yayimlandi', j.yayimlandi, 'puan', j.puan, 'benim', j.veren = u)
$$;

create or replace function public.ajans_liste(p_il int default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v_il smallint := p_il; gbParti oyun.partiler;
begin
  perform oyun.ajans_tick();
  select * into gbParti from oyun.partiler where gb = p.id and not kapali limit 1;
  return jsonb_build_object(
    'ajanslar', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad, 'sahip', oyun.kad(oyun.sirket_sahibi(s.id)),
        'fiyat', a.fiyat, 'kalite', a.kalite, 'marka', round(a.marka), 'is_sayisi', a.is_sayisi,
        'puan', (select round(avg(puan), 1) from oyun.ajans_is where sirket_id = s.id and puan is not null),
        'kapasite', oyun.ajans_kapasite(s.id), 'dolu', oyun.ajans_dolu(s.id),
        'reklam_ucret', oyun.ajans_ucret(s.id, 'reklam', v_il), 'anket_ucret', oyun.ajans_ucret(s.id, 'anket', v_il),
        'reklam_saat', 12 + 8 * a.kalite, 'anket_odul', round((300 + 250 * a.kalite) * coalesce((select endeks from oyun.ulke where id = 1), 1)),
        'benim', oyun.sirket_yonetici_mi(s.id, p.id))
        order by a.marka desc, s.id) from oyun.ajans a join oyun.sirketler s on s.id = a.sirket_id where s.aktif), '[]'::jsonb),
    'il_id', v_il, 'il', coalesce((select ad from oyun.iller where id = v_il), 'Tüm Türkiye'),
    'reklam_dolu', (select count(*) from oyun.ajans_is where tur = 'reklam' and durum = 'yayinda' and il_id is not distinct from v_il),
    'reklam_sinir', case when v_il is null then 1 else 2 end,
    'parti', case when gbParti.id is not null then jsonb_build_object('id', gbParti.id, 'ad', gbParti.ad, 'kisa', gbParti.kisa, 'kasa', round(gbParti.kasa)) end,
    'cuzdan', (select para from oyun.cuzdan where user_id = p.id),
    'yasak', oyun.anket_yasagi(t),
    'ajansim', (select s.id from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id = s.id where s.sektor = 'ajans' and s.aktif and o.user_id = p.id order by o.pay desc limit 1),
    'islerim', coalesce((select jsonb_agg(oyun.ajans_is_json(j, p.id) order by j.id desc) from
        (select * from oyun.ajans_is where veren = p.id or (parti_id is not null and parti_id = gbParti.id) order by id desc limit 20) j), '[]'::jsonb));
end $$;

create or replace function public.ajans_siparis(p_sirket bigint, p_tur text, p_il int, p_kaynak text, p_metin text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; a oyun.ajans; pa oyun.partiler; t timestamptz := oyun.simdi();
  v_il smallint := p_il; ucret numeric; v_id bigint; saat int; v_odul numeric; hedef text; u uuid; metin text := btrim(coalesce(p_metin, ''));
begin
  perform oyun.ajans_tick();
  select * into s from oyun.sirketler where id = p_sirket;
  select * into a from oyun.ajans where sirket_id = p_sirket;
  if s.id is null or a.sirket_id is null or not s.aktif then raise exception 'Ajans bulunamadı.'; end if;
  if p_tur not in ('reklam','anket') then raise exception 'Hizmet reklam ya da anket olmalı.'; end if;
  if v_il is not null and not exists (select 1 from oyun.iller where id = v_il) then raise exception 'Geçersiz il.'; end if;
  if p_kaynak not in ('parti','kisi') then raise exception 'Ödeme kaynağı parti ya da kişi olmalı.'; end if;
  if oyun.sirket_yonetici_mi(s.id, p.id) then raise exception 'Kendi ajansından sipariş veremezsin.'; end if;
  if oyun.ajans_dolu(s.id) >= oyun.ajans_kapasite(s.id) then raise exception 'Bu ajansın kapasitesi dolu; başka ajans seç ya da işlerin bitmesini bekle.'; end if;
  if p_tur = 'reklam' then
    if char_length(metin) not between 10 and 200 then raise exception 'Reklam metni 10-200 karakter olmalı.'; end if;
    if (select count(*) from oyun.ajans_is where tur = 'reklam' and durum = 'yayinda' and il_id is not distinct from v_il) >= (case when v_il is null then 1 else 2 end) then
      raise exception 'Bu hedefte reklam alanı dolu; mevcut reklamlar bitince tekrar dene.';
    end if;
  else
    metin := null;
    if exists (select 1 from oyun.ajans_is where tur = 'anket' and durum = 'yayinda' and il_id is not distinct from v_il) then
      raise exception 'Bu hedefte zaten sürmekte olan bir anket var; katılımcılar bölünmesin diye 24 saat bekle.';
    end if;
  end if;
  if exists (select 1 from oyun.ajans_is where veren = p.id and bas > t - interval '1 hour') then raise exception 'Saatte en fazla bir sipariş verebilirsin.'; end if;
  ucret := oyun.ajans_ucret(s.id, p_tur, v_il);
  if p_kaynak = 'parti' then
    select * into pa from oyun.partiler where gb = p.id and not kapali limit 1;
    if pa.id is null then raise exception 'Parti adına siparişi genel başkan verir.'; end if;
    update oyun.partiler set kasa = kasa - ucret where id = pa.id and kasa >= ucret;
    if not found then raise exception 'Parti kasasında % ₺ gerekli.', oyun.tl(ucret); end if;
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, -ucret, format('%s: %s siparişi', s.ad, p_tur), 'kampanya');
  else
    perform oyun.para_islem(p.id, -ucret, 'kampanya', format('%s: %s siparişi', s.ad, p_tur), t);
  end if;
  saat := case when p_tur = 'reklam' then 12 + 8 * a.kalite else 24 end;
  v_odul := case when p_tur = 'anket' then round((300 + 250 * a.kalite) * coalesce((select endeks from oyun.ulke where id = 1), 1)) else 0 end;
  insert into oyun.ajans_is(sirket_id, tur, il_id, kaynak, parti_id, veren, metin, ucret, kalite, odul, havuz, bas, bit)
    values (s.id, p_tur, v_il, p_kaynak, pa.id, p.id, metin, ucret, a.kalite, v_odul, case when p_tur = 'anket' then round(ucret * 0.4) else 0 end,
            t, t + saat * interval '1 hour') returning id into v_id;
  update oyun.sirketler set kasa = kasa + ucret where id = s.id;
  update oyun.ajans set hafta_gelir = hafta_gelir + ucret where sirket_id = s.id;
  hedef := coalesce((select ad from oyun.iller where id = v_il), 'tüm Türkiye');
  perform oyun.bildir(oyun.sirket_sahibi(s.id), format('Yeni sipariş: %s, %s için %s (%s ₺).', coalesce(pa.kisa, p.kad), hedef, p_tur, oyun.tl(ucret)), t);
  -- kaliteli reklam başlarken hedefteki oyunculara bildirim gönderir
  if p_tur = 'reklam' and a.kalite >= 2 then
    for u in select id from oyun.profiller where (v_il is null or il_id = v_il) and id <> p.id and not coalesce(yasakli, false) loop
      perform oyun.bildir(u, format('Sponsorlu · %s: %s', coalesce(pa.kisa, p.kad), left(metin, 120)), t);
    end loop;
  end if;
  if p_tur = 'anket' then
    for u in select id from oyun.profiller where (v_il is null or il_id = v_il) and id <> p.id and not coalesce(yasakli, false) loop
      perform oyun.bildir(u, format('%s kamuoyu araştırması yapıyor: tek soruyu cevapla, %s ₺ katılım ödülü kazan (Gündem).', s.ad, oyun.tl(v_odul)), t);
    end loop;
  end if;
  return oyun.ajans_is_json((select j from oyun.ajans_is j where id = v_id), p.id);
end $$;

-- Oyuncunun Gündem'inde: bir sponsorlu reklam ve cevaplamadığı bir anket
create or replace function public.ajans_gundem() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); r oyun.ajans_is; k oyun.ajans_is;
begin
  perform oyun.ajans_tick();
  select * into r from oyun.ajans_is where tur = 'reklam' and durum = 'yayinda' and bit > t and (il_id is null or il_id = p.il_id)
    order by (select count(*) from oyun.ajans_gosterim g where g.is_id = ajans_is.id and g.user_id = p.id), gosterim, random() limit 1;
  if r.id is not null and r.veren <> p.id then
    insert into oyun.ajans_gosterim(is_id, user_id, zaman) values (r.id, p.id, t) on conflict do nothing;
    if found then update oyun.ajans_is set gosterim = gosterim + 1 where id = r.id; end if;
  end if;
  select * into k from oyun.ajans_is where tur = 'anket' and durum = 'yayinda' and bit > t and (il_id is null or il_id = p.il_id) and veren <> p.id
    and not exists (select 1 from oyun.ajans_cevap c where c.is_id = ajans_is.id and c.user_id = p.id) order by bit limit 1;
  return jsonb_build_object(
    'reklam', case when r.id is not null then jsonb_build_object('id', r.id, 'metin', r.metin,
        'kim', coalesce((select ad from oyun.partiler where id = r.parti_id), oyun.kad(r.veren)),
        'renk', (select renk from oyun.partiler where id = r.parti_id), 'ajans', (select ad from oyun.sirketler where id = r.sirket_id)) end,
    'anket', case when k.id is not null then jsonb_build_object('id', k.id, 'ajans', (select ad from oyun.sirketler where id = k.sirket_id),
        'hedef', coalesce((select ad from oyun.iller where id = k.il_id), 'Türkiye'), 'odul', case when k.havuz >= k.odul then k.odul else 0 end, 'bit', k.bit,
        'partiler', (select jsonb_agg(jsonb_build_object('id', id, 'ad', ad, 'kisa', kisa, 'renk', renk) order by ad) from oyun.partiler where not kapali)) end);
end $$;

create or replace function public.ajans_anket_cevap(p_is bigint, p_parti bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.ajans_is; v_odul numeric := 0;
begin
  select * into k from oyun.ajans_is where id = p_is for update;
  if k.id is null or k.tur <> 'anket' or k.durum <> 'yayinda' or k.bit <= t then raise exception 'Anket sona erdi.'; end if;
  if k.il_id is not null and k.il_id <> p.il_id then raise exception 'Bu anket başka bir ilde yapılıyor.'; end if;
  if k.veren = p.id then raise exception 'Kendi yaptırdığın ankete katılamazsın.'; end if;
  if p_parti is not null and not exists (select 1 from oyun.partiler where id = p_parti and not kapali) then raise exception 'Geçersiz parti.'; end if;
  if exists (select 1 from oyun.ajans_cevap where is_id = k.id and user_id = p.id) then raise exception 'Bu ankete zaten katıldın.'; end if;
  -- ödül: havuz ve ajans kasası yeterse; yeni hesaplara (1 günden genç) ödül yok
  if k.havuz >= k.odul and k.odul > 0 and p.olusturma < t - interval '1 day'
     and (select kasa from oyun.sirketler where id = k.sirket_id) >= k.odul then
    v_odul := k.odul;
    update oyun.ajans_is set havuz = havuz - v_odul where id = k.id;
    update oyun.sirketler set kasa = kasa - v_odul where id = k.sirket_id;
    update oyun.ajans set hafta_odul = hafta_odul + v_odul where sirket_id = k.sirket_id;
    perform oyun.para_islem(p.id, v_odul, 'odul', format('%s anketine katılım ödülü', (select ad from oyun.sirketler where id = k.sirket_id)), t);
  end if;
  insert into oyun.ajans_cevap(is_id, user_id, parti_id, odul, zaman) values (k.id, p.id, p_parti, v_odul, t);
  return jsonb_build_object('tamam', true, 'odul', v_odul);
end $$;

create or replace function public.ajans_anket_yayimla(p_is bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.ajans_is; ozet text;
begin
  select * into k from oyun.ajans_is where id = p_is for update;
  if k.id is null or k.tur <> 'anket' then raise exception 'Anket bulunamadı.'; end if;
  if not (k.veren = p.id or (k.parti_id is not null and exists (select 1 from oyun.partiler where id = k.parti_id and gb = p.id))) then
    raise exception 'Sonucu yalnız anketi yaptıran yayımlayabilir.';
  end if;
  if k.durum <> 'bitti' or k.sonuc is null then raise exception 'Anket henüz bitmedi.'; end if;
  if k.yayimlandi is not null then raise exception 'Bu anket zaten yayımlandı.'; end if;
  if oyun.anket_yasagi(t) then raise exception 'Seçim yasağı: oy günü ve öncesindeki 24 saatte anket sonucu yayımlanamaz.'; end if;
  if (k.sonuc->>'n')::int < 3 then raise exception 'En az 3 katılımcı olmadan sonuç yayımlanamaz.'; end if;
  select string_agg(format('%s %%%s', x->>'kisa', replace((x->>'yuzde'), '.', ',')), ', ')
    into ozet from (select x from jsonb_array_elements(k.sonuc->'partiler') x order by (x->>'oy')::int desc limit 5) z;
  update oyun.ajans_is set yayimlandi = t where id = k.id;
  update oyun.ajans set marka = least(100, marka + 2) where sirket_id = k.sirket_id;
  perform oyun.olay('anket', format('%s anketi (%s, %s kişi, hata payı ±%s): %s. Kararsız %%%s.',
    (select ad from oyun.sirketler where id = k.sirket_id), coalesce((select ad from oyun.iller where id = k.il_id), 'Türkiye'),
    k.sonuc->>'n', replace(k.sonuc->>'hata', '.', ','), coalesce(ozet, '-'), replace(k.sonuc->>'kararsiz_yuzde', '.', ',')), k.il_id, k.parti_id, t);
  return oyun.ajans_is_json((select j from oyun.ajans_is j where id = k.id), p.id);
end $$;

create or replace function public.ajans_puanla(p_is bigint, p_puan int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); k oyun.ajans_is;
begin
  select * into k from oyun.ajans_is where id = p_is for update;
  if k.id is null or k.veren <> p.id then raise exception 'Yalnız kendi siparişini puanlayabilirsin.'; end if;
  if k.durum <> 'bitti' then raise exception 'İş bitince puanlayabilirsin.'; end if;
  if k.puan is not null then raise exception 'Bu işi zaten puanladın.'; end if;
  if p_puan not between 1 and 5 then raise exception 'Puan 1-5 arasında olmalı.'; end if;
  update oyun.ajans_is set puan = p_puan where id = k.id;
  update oyun.ajans set marka = oyun.sinir(marka + (p_puan - 3) * 3, 0, 100) where sirket_id = k.sirket_id;
  return jsonb_build_object('tamam', true);
end $$;

-- Biten reklam ve anketleri kapatır
create or replace function oyun.ajans_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); k oyun.ajans_is; n int := 0; v_n int; kar int; v_sonuc jsonb; u uuid;
begin
  if not pg_try_advisory_xact_lock(84861) then return 0; end if;
  for k in select * from oyun.ajans_is where durum = 'yayinda' and bit <= t order by bit for update loop
    if k.tur = 'anket' then
      select count(*), count(*) filter (where parti_id is null) into v_n, kar from oyun.ajans_cevap where is_id = k.id;
      v_sonuc := jsonb_build_object('n', v_n, 'kararsiz', kar, 'kararsiz_yuzde', case when v_n > 0 then round(kar * 100.0 / v_n, 1) else 0 end,
        'hata', case when v_n > 0 then round((98 / sqrt(v_n))::numeric, 1) else null end,
        'partiler', coalesce((select jsonb_agg(jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'ad', pa.ad, 'renk', pa.renk, 'oy', z.oy,
            'yuzde', round(z.oy * 100.0 / nullif(v_n - kar, 0), 1)) order by z.oy desc)
          from (select parti_id, count(*) oy from oyun.ajans_cevap where is_id = k.id and parti_id is not null group by parti_id) z
          join oyun.partiler pa on pa.id = z.parti_id), '[]'::jsonb));
      -- kullanılmayan ödül havuzu ajansın gelirinde kalır
      update oyun.ajans_is set durum = 'bitti', sonuc = v_sonuc, havuz = 0 where id = k.id;
      perform oyun.bildir(k.veren, format('Anket sonucu hazır (%s, %s katılımcı). Gündem › Reklam ve anket ajansları › Siparişlerim.',
        coalesce((select ad from oyun.iller where id = k.il_id), 'Türkiye'), v_n), k.bit);
    else
      update oyun.ajans_is set durum = 'bitti' where id = k.id;
      perform oyun.bildir(k.veren, format('Reklamın sona erdi: %s oyuncu gördü.', k.gosterim), k.bit);
    end if;
    update oyun.ajans set is_sayisi = is_sayisi + 1, marka = least(100, marka + 1 + kalite) where sirket_id = k.sirket_id;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Zamanlayıcı: ajansların haftalık hesabı ve iş kapanışları da pazar_tick ile
create or replace function oyun.pazar_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  perform oyun.ihale_tick();
  perform oyun.rekabet_tick();
  perform oyun.ajans_tick();
  for r in select s.id from oyun.sirketler s
           where s.aktif and s.sonraki_kazanc <= oyun.simdi()
             and (exists (select 1 from oyun.pazar_sirket ps where ps.sirket_id = s.id) or s.sektor = 'ajans')
           order by s.sonraki_kazanc limit 200 loop
    perform oyun.sirket_hesapla(r.id); n := n + 1;
  end loop;
  perform oyun.piyasa_endeks_tick();
  return n;
end $$;

revoke all on function public.ajans_kur(text, numeric), public.ajans_ayarla(bigint, int, int), public.ajans_yonetim(bigint),
  public.ajans_liste(int), public.ajans_siparis(bigint, text, int, text, text), public.ajans_gundem(), public.ajans_anket_cevap(bigint, bigint),
  public.ajans_anket_yayimla(bigint), public.ajans_puanla(bigint, int) from public, anon;
grant execute on function public.ajans_kur(text, numeric), public.ajans_ayarla(bigint, int, int), public.ajans_yonetim(bigint),
  public.ajans_liste(int), public.ajans_siparis(bigint, text, int, text, text), public.ajans_gundem(), public.ajans_anket_cevap(bigint, bigint),
  public.ajans_anket_yayimla(bigint), public.ajans_puanla(bigint, int) to authenticated;
revoke all on function oyun.ajans_il_kat(smallint), oyun.ajans_ucret(bigint, text, smallint), oyun.ajans_kapasite(bigint), oyun.ajans_dolu(bigint),
  oyun.anket_yasagi(timestamptz), oyun.ajans_haftalik_gider(bigint), oyun.ajans_hesapla(bigint), oyun.ajans_is_json(oyun.ajans_is, uuid),
  oyun.ajans_tick() from public, anon, authenticated;
