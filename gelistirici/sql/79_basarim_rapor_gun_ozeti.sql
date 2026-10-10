-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 79) BAŞARIMLAR, AY SONU RAPOR KARTI, GÜN SONU ÖZETİ
--  • Başarımlar: oyuncunun zaten yaptığı şeylerden (makam, parti, paylaşım, kıdem) türetilir; yeni kural koymaz.
--  • Ay sonu raporu: o ayın kısa dökümü + paylaşılabilir metin; ayın son günü 20:00'de bildirim gider.
--  • Gün sonu özeti: her akşam 21:00'de "Bugün Türkiye'de" bildirimi (en önemli 3 gelişme).
--  Yalnız yeni tablo ve işlev ekler.
-- =====================================================================

create table if not exists oyun.basarim(
  user_id uuid not null,
  kod     text not null,
  zaman   timestamptz not null default now(),
  bildirildi boolean not null default false,
  primary key (user_id, kod)
);
create table if not exists oyun.rapor_bildirim(
  user_id uuid not null,
  ay      date not null,
  primary key (user_id, ay)
);
create table if not exists oyun.gun_ozeti_gonderim(
  gun date primary key,
  zaman timestamptz not null default now(),
  metin text
);
alter table oyun.basarim enable row level security;
alter table oyun.rapor_bildirim enable row level security;
alter table oyun.gun_ozeti_gonderim enable row level security;
revoke all on oyun.basarim, oyun.rapor_bildirim, oyun.gun_ozeti_gonderim from public, anon, authenticated;

-- Başarım tanımları ve oyuncunun durumu
create or replace function oyun.basarim_durum(u uuid)
returns table(kod text, ad text, aciklama text, sinif text, sira int, kazandi boolean)
language plpgsql stable as $$
declare t timestamptz := oyun.simdi(); hesap timestamptz; n_akis int; n_begeni int; mv_gun numeric;
begin
  select pr.olusturma into hesap from oyun.profiller pr where pr.id = u;
  select count(*) into n_akis from oyun.akis where user_id = u;
  select count(*) into n_begeni from oyun.akis_begeni b join oyun.akis a on a.id = b.akis_id where a.user_id = u and b.user_id <> u;
  select coalesce(sum(extract(epoch from coalesce(m.bit, t) - m.bas) / 86400), 0) into mv_gun from oyun.makamlar m where m.user_id = u and m.tur = 'mv';
  return query select * from (values
    ('yerlesik',   'Yerleşik Vatandaş',  'Hesabın 7 günü geçti.',                                'bronz', 1, hesap is not null and hesap <= t - interval '7 days'),
    ('koklu',      'Köklü Vatandaş',     'Hesabın 30 günü geçti.',                               'gumus', 2, hesap is not null and hesap <= t - interval '30 days'),
    ('ilk_soz',    'İlk Söz',            'İlk kısa paylaşımını yaptın.',                         'bronz', 3, n_akis >= 1),
    ('gundem',     'Gündem Belirleyici', '25 paylaşıma ulaştın.',                                'gumus', 4, n_akis >= 25),
    ('sesini',     'Sesini Duyuran',     'Paylaşımların 50 beğeni topladı.',                     'gumus', 5, n_begeni >= 50),
    ('kurucu',     'Parti Kurucusu',     'Bir parti kurdun.',                                    'gumus', 6, exists (select 1 from oyun.partiler pa where pa.kurucu = u)),
    ('genel_baskan','Genel Başkan',      'Bir partinin genel başkanısın.',                       'gumus', 7, exists (select 1 from oyun.partiler pa where pa.gb = u and not pa.kapali)),
    ('vekil',      'Meclis Kürsüsü',     'Milletvekili seçildin.',                               'gumus', 8, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'mv')),
    ('belediye',   'Şehrin Başkanı',     'Belediye başkanı seçildin.',                           'gumus', 9, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'bel')),
    ('bakan',      'Kabine Üyesi',       'Bakan oldun.',                                         'altin', 10, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'bakan')),
    ('kidemli',    'Kıdemli Vekil',      'Meclis''te toplam 30 gün görev yaptın.',               'altin', 11, mv_gun >= 30),
    ('cumhurbaskani','Çankaya',          'Cumhurbaşkanı seçildin.',                              'altin', 12, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'cb'))
  ) v(kod, ad, aciklama, sinif, sira, kazandi);
end $$;
revoke all on function oyun.basarim_durum(uuid) from public, anon, authenticated;

-- Kazanılanları kaydeder; yeni kazanılanların kodlarını döndürür
create or replace function oyun.basarim_tara(u uuid) returns text[]
language plpgsql as $$
declare yeni text[];
begin
  with e as (
    insert into oyun.basarim(user_id, kod, zaman)
    select u, d.kod, oyun.simdi() from oyun.basarim_durum(u) d where d.kazandi
    on conflict do nothing returning kod)
  select coalesce(array_agg(kod), '{}') into yeni from e;
  return yeni;
end $$;
revoke all on function oyun.basarim_tara(uuid) from public, anon, authenticated;

create or replace function public.basarimlar() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  perform oyun.basarim_tara(p.id);
  return coalesce((select jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'aciklama', d.aciklama, 'sinif', d.sinif,
           'kazandi', b.user_id is not null, 'zaman', b.zaman) order by d.sira)
     from oyun.basarim_durum(p.id) d left join oyun.basarim b on b.user_id = p.id and b.kod = d.kod), '[]'::jsonb);
end $$;

-- Ay raporu (p_ay verilmezse içinde bulunulan ay)
create or replace function public.ay_raporu(p_ay date default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
  ay0 date := date_trunc('month', coalesce(p_ay, (t at time zone 'Europe/Istanbul')::date))::date;
  b timestamptz; s timestamptz; paylasim int; begeni int; gun numeric; yeni jsonb; makamlar jsonb; vekil int; sira int; unv text; basarim_n int;
  adlar text[] := array['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
  metin text;
begin
  b := (ay0::timestamp) at time zone 'Europe/Istanbul'; s := ((ay0 + interval '1 month')::timestamp) at time zone 'Europe/Istanbul';
  perform oyun.basarim_tara(p.id);
  select count(*) into paylasim from oyun.akis where user_id = p.id and zaman >= b and zaman < s;
  select count(*) into begeni from oyun.akis_begeni x join oyun.akis a on a.id = x.akis_id
   where a.user_id = p.id and x.user_id <> p.id and x.zaman >= b and x.zaman < s;
  select coalesce(sum(extract(epoch from least(coalesce(m.bit, s), s) - greatest(m.bas, b)) / 86400), 0) into gun
    from oyun.makamlar m where m.user_id = p.id and m.bas < s and coalesce(m.bit, s) > b;
  select coalesce(jsonb_agg(jsonb_build_object('tur', m.tur, 'il', (select ad from oyun.iller where id = m.il_id), 'bas', m.bas) order by m.bas), '[]'::jsonb)
    into makamlar from oyun.makamlar m where m.user_id = p.id and m.bas >= b and m.bas < s;
  select coalesce(jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'sinif', d.sinif) order by d.sira), '[]'::jsonb) into yeni
    from oyun.basarim x join oyun.basarim_durum(p.id) d on d.kod = x.kod where x.user_id = p.id and x.zaman >= b and x.zaman < s;
  select count(*) into basarim_n from oyun.basarim where user_id = p.id;
  if p.parti_id is not null then
    select count(*) into vekil from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = p.parti_id;
    select r into sira from (select pa.id, row_number() over (order by (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pa.id) desc, pa.id) r
                               from oyun.partiler pa where not pa.kapali) q where q.id = p.parti_id;
  end if;
  unv := oyun.unvan(p.id);
  metin := format('%s %s raporum: %s%s%s paylaşım, %s beğeni, %s başarım. Seçim Simülasyonu Online',
     adlar[extract(month from ay0)::int], extract(year from ay0)::int,
     case when unv is not null then unv || ' · ' else '' end,
     case when p.parti_id is not null then (select kisa from oyun.partiler where id = p.parti_id) || ' · ' else '' end,
     paylasim, begeni, basarim_n);
  return jsonb_build_object('ay', to_char(ay0, 'YYYY-MM'), 'ay_ad', adlar[extract(month from ay0)::int] || ' ' || extract(year from ay0)::int,
    'kad', p.kad, 'unvan', unv, 'il', (select ad from oyun.iller where id = p.il_id), 'parti', oyun.parti_json(p.parti_id),
    'parti_vekil', vekil, 'parti_sira', sira, 'paylasim', paylasim, 'begeni', begeni, 'makam_gun', round(gun, 1),
    'yeni_makamlar', makamlar, 'yeni_basarimlar', yeni, 'basarim_toplam', basarim_n, 'paylasim_metni', metin,
    'son_gun', ((s - interval '1 second') at time zone 'Europe/Istanbul')::date);
end $$;

-- "Bugün Türkiye'de": bugünün en önemli gelişmeleri (Gündem kartı + akşam bildirimi)
create or replace function oyun.gun_ozeti_liste(p_gun date) returns jsonb
language sql stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('tur', x.tur, 'metin', x.metin, 'zaman', x.zaman) order by x.oncelik, x.zaman desc), '[]'::jsonb)
  from (select o.tur, o.metin, o.zaman,
               case o.tur when 'secim' then 1 when 'hukumet' then 2 when 'anayasa' then 2 when 'referandum' then 2 when 'meclis' then 3 when 'makam' then 3
                          when 'kararname' then 4 when 'parti' then 5 when 'ittifak' then 5 when 'belediye' then 6 when 'siyaset' then 6 else 8 end oncelik
          from oyun.olaylar o
         where o.zaman >= (p_gun::timestamp) at time zone 'Europe/Istanbul' and o.zaman < ((p_gun + 1)::timestamp) at time zone 'Europe/Istanbul'
           and o.zaman <= oyun.simdi() and o.metin not like 'Seçim gecesi ·%'
         order by 4, o.zaman desc limit 6) x
$$;

create or replace function public.gun_ozeti() returns jsonb
language sql stable security definer set search_path = oyun, public, pg_temp as $$
  select jsonb_build_object('gun', (oyun.simdi() at time zone 'Europe/Istanbul')::date,
    'gelismeler', oyun.gun_ozeti_liste((oyun.simdi() at time zone 'Europe/Istanbul')::date),
    'etiketler', (select coalesce(jsonb_agg(e->>'etiket'), '[]'::jsonb) from jsonb_array_elements(public.akis_gundem()) e))
$$;

-- Günlük iş: 21:00'den sonra bir kez özet bildirimi; ayın son günü 20:00'den sonra rapor bildirimi; başarım taraması
create or replace function oyun.gun_sonu_tick() returns integer
language plpgsql set search_path = oyun, public, pg_temp as $$
declare t timestamptz := oyun.simdi(); yerel timestamp := t at time zone 'Europe/Istanbul'; bugun date := yerel::date; saat int := extract(hour from yerel)::int;
  liste jsonb; govde text; n int := 0; u record; yeni text[]; ay0 date;
begin
  if not pg_try_advisory_xact_lock(424244) then return 0; end if;

  -- 1) gün sonu özeti
  if saat >= 21 and not exists (select 1 from oyun.gun_ozeti_gonderim where gun = bugun) then
    liste := oyun.gun_ozeti_liste(bugun);
    insert into oyun.gun_ozeti_gonderim(gun, zaman) values (bugun, t) on conflict do nothing;
    if jsonb_array_length(liste) > 0 then
      govde := (select string_agg(left(x->>'metin', 90), ' · ') from (select x from jsonb_array_elements(liste) x limit 3) q);
      update oyun.gun_ozeti_gonderim set metin = govde where gun_ozeti_gonderim.gun = bugun;
      perform oyun.push_konuya('s_tum', null, 'Bugün Türkiye''de', govde, '{"ekran":"gundem"}');
      n := n + 1;
    end if;
    perform oyun.akis_temizle();
  end if;

  -- 2) ay raporu bildirimi (ayın son günü 20:00'den sonra, son 14 günde görülmüş oyunculara)
  ay0 := date_trunc('month', yerel)::date;
  if saat >= 20 and bugun = (ay0 + interval '1 month' - interval '1 day')::date then
    for u in select pr.id from oyun.profiller pr
              where not pr.yasakli and pr.son_gorulme > t - interval '14 days'
                and not exists (select 1 from oyun.rapor_bildirim r where r.user_id = pr.id and r.ay = ay0) limit 2000 loop
      insert into oyun.rapor_bildirim(user_id, ay) values (u.id, ay0) on conflict do nothing;
      perform oyun.push_kisiye(u.id, 'kisisel', 'Ay raporun hazır', 'Bu ayın özeti ve başarımların seni bekliyor.', '{"ekran":"rapor"}');
      n := n + 1;
    end loop;
  end if;

  -- 3) başarım taraması (günde bir kez, 03:00 sonrası) — yeni kazanılanlar tek bildirimle haber verilir
  if saat >= 3 and not exists (select 1 from oyun.basarim_tarama where gun = bugun) then
    insert into oyun.basarim_tarama(gun) values (bugun) on conflict do nothing;
    for u in select pr.id from oyun.profiller pr where not pr.yasakli and pr.son_gorulme > t - interval '30 days' loop
      yeni := oyun.basarim_tara(u.id);
      if array_length(yeni, 1) > 0 then
        update oyun.basarim set bildirildi = true where user_id = u.id and kod = any(yeni);
        perform oyun.bildir(u.id, 'Yeni başarım kazandın: ' || (select string_agg(d.ad, ', ') from oyun.basarim_durum(u.id) d where d.kod = any(yeni)));
        n := n + 1;
      end if;
    end loop;
  end if;
  return n;
end $$;
revoke all on function oyun.gun_sonu_tick() from public, anon, authenticated;

create table if not exists oyun.basarim_tarama(gun date primary key);
alter table oyun.basarim_tarama enable row level security;
revoke all on oyun.basarim_tarama from public, anon, authenticated;

revoke all on function public.basarimlar(), public.ay_raporu(date), public.gun_ozeti() from public, anon;
grant execute on function public.basarimlar(), public.ay_raporu(date), public.gun_ozeti() to authenticated;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'gun-sonu';
    perform cron.schedule('gun-sonu', '*/15 * * * *', 'select oyun.gun_sonu_tick()');
  end if;
end $$;
