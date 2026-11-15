-- =====================================================================
--  209 (15.11.2026) · TV 2.0 — CANLI YAYIN DENEYİMİ (Ercan: "izlemek için can atsınlar, gerçek TV gibi olsun")
--  198'in üstüne kurulur; 198'deki tablolar, RPC adları ve parametreler aynen kalır (mağazadaki eski uygulama çalışır).
--  • İki yeni format: Bilgi Yarışması (canlı soru, süre, hız puanı, ödül havuzu) ve Açık Oturum · Halk Soruyor.
--  • Seyirci kürsüsü: izleyiciler canlı yorum ve soru yazar; sorular "ben de soruyorum" ile öne çıkar;
--    sunucu bir yorumu/soruyu tek dokunuşla ekrana alır (stüdyo akışına "İzleyici" olarak düşer).
--  • Anlık tepki: 6 emoji; 2 saniyede bir; dakikalık ve 8 parçalı sayaçlarla tutulur (1000 izleyicide tek satır kilitlenmez).
--    Son 2 dakikanın toplamı "salon ısısı"dır.
--  • Canlı anket (her formatta) ve yarışma sorusu (yalnız yarışmada). Yarışmada cevap ilk dokunuşta kilitlenir;
--    doğru cevap 100 + hız bonusu (en çok 100) puan. Program bitince ödül havuzu ilk üçe %50/%30/%20 dağıtılır.
--    Havuz yalnız kanal kasasından, program başına en çok 100.000 ₺; bir oyuncu TV yarışmalarından günde en çok 50.000 ₺ alır;
--    sunucu, konuklar ve kanal sahibi yarışamaz. Dağıtılmayan pay kasaya döner.
--  • Canlı bağlantı: izleyici "söz iste" der; sunucu "yayına al" ile onu stüdyoya konuk olarak bağlar (en çok 6 konuk).
--  • Reklam arası: sunucu onaylı reklam varken 40 saniyelik reklam kuşağı açar (8 dakikada bir); kuşakta stüdyo susar.
--  • Takip ve hatırlatma: kanal takipçileri ve hatırlatma kuranlar yayın başlayınca bildirim alır
--    (takipçiye aynı kanaldan en çok 2 saatte bir).
--  • Kanal seviyesi (toplam izlenmeye göre): Yerel 4 · Bölgesel 5 · Ulusal 6 · Ana akım 8 program/gün.
--  • Reyting: zirve izleyici, reyting (aktif oyunculara oran) ve pay (o an çevrimiçi olanlara oran); haftalık reyting tablosu
--    ve her pazartesi "Haftanın reytingleri" haberi.
--  • tv_canli: stüdyo için hafif, yalnız değişeni dönen sorgu (yeni mesaj/yorum kimliğinden sonrası). Eski tv_detay aynen durur.
--  Oyuncu verisine dokunmaz; yalnız yeni tablo/sütun ve create or replace.
-- =====================================================================

-- ---------------------------------------------------------------- şema
alter table oyun.tv_program add column if not exists zirve int not null default 0;
alter table oyun.tv_program add column if not exists odul numeric not null default 0;
alter table oyun.tv_program add column if not exists odul_dagitildi boolean not null default false;
alter table oyun.tv_program add column if not exists reklam_arasi timestamptz;
alter table oyun.tv_program add column if not exists son_reklam_arasi timestamptz;
alter table oyun.tv_program add column if not exists ekrandaki bigint;
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'tv_program_tur_check' and conrelid = 'oyun.tv_program'::regclass
                  and pg_get_constraintdef(oid) like '%yarisma%') then
    alter table oyun.tv_program drop constraint if exists tv_program_tur_check;
    alter table oyun.tv_program add constraint tv_program_tur_check check (tur in ('duello','soylesi','haber','yarisma','acik_oturum'));
  end if;
end $c$;
alter table oyun.tv_konuk add column if not exists baglanti boolean not null default false;
alter table oyun.tv_izleyici add column if not exists son_emoji timestamptz;
alter table oyun.tv_izleyici add column if not exists son_yorum timestamptz;
alter table oyun.tv_izleyici add column if not exists soz_iste timestamptz;

create table if not exists oyun.tv_yorum(
  id bigserial primary key, program_id bigint not null references oyun.tv_program(id), user_id uuid not null,
  metin text not null, zaman timestamptz not null, soru boolean not null default false, destek int not null default 0,
  gizli boolean not null default false, ekran_at timestamptz);
create index if not exists tv_yorum_p on oyun.tv_yorum(program_id, id);
create table if not exists oyun.tv_yorum_destek(
  yorum_id bigint not null references oyun.tv_yorum(id), user_id uuid not null, zaman timestamptz not null, primary key (yorum_id, user_id));
create table if not exists oyun.tv_emoji(
  program_id bigint not null references oyun.tv_program(id), tur text not null check (tur in ('alkis','kahkaha','sasirma','ofke','kalp','ates')),
  parca smallint not null, dakika timestamptz not null, sayi int not null default 0, primary key (program_id, dakika, tur, parca));
create table if not exists oyun.tv_anket(
  id bigserial primary key, program_id bigint not null references oyun.tv_program(id), tur text not null check (tur in ('anket','yarisma')),
  soru text not null, secenekler jsonb not null, dogru smallint, acilis timestamptz not null, kapanis timestamptz not null,
  plan_kapanis timestamptz not null, kapandi boolean not null default false, olusturan uuid not null);
create index if not exists tv_anket_p on oyun.tv_anket(program_id, id);
create index if not exists tv_anket_acik on oyun.tv_anket(kapanis) where not kapandi;
create table if not exists oyun.tv_anket_oy(
  anket_id bigint not null references oyun.tv_anket(id), user_id uuid not null, secim smallint not null, zaman timestamptz not null,
  puan int not null default 0, primary key (anket_id, user_id));
create table if not exists oyun.tv_takip(
  kanal_id bigint not null references oyun.tv_kanal(id), user_id uuid not null, zaman timestamptz not null, son_bildirim timestamptz,
  primary key (kanal_id, user_id));
create index if not exists tv_takip_u on oyun.tv_takip(user_id);
create table if not exists oyun.tv_hatirlat(
  program_id bigint not null references oyun.tv_program(id), user_id uuid not null, zaman timestamptz not null, primary key (program_id, user_id));
create index if not exists tv_hatirlat_u on oyun.tv_hatirlat(user_id);
create table if not exists oyun.tv_odul_kazanc(
  id bigserial primary key, program_id bigint not null references oyun.tv_program(id), user_id uuid not null, sira smallint not null,
  puan int not null, tutar numeric not null, zaman timestamptz not null);
create index if not exists tv_odul_kazanc_u on oyun.tv_odul_kazanc(user_id, zaman desc);
create table if not exists oyun.tv_hafta(hafta date primary key, zaman timestamptz not null, ozet jsonb not null);
create table if not exists oyun.tv_onbellek(anahtar text primary key, deger jsonb not null, zaman timestamptz not null);
do $r$ declare x text; begin
  foreach x in array array['tv_yorum','tv_yorum_destek','tv_emoji','tv_anket','tv_anket_oy','tv_takip','tv_hatirlat','tv_odul_kazanc','tv_hafta','tv_onbellek'] loop
    execute format('alter table oyun.%I enable row level security', x);
    execute format('revoke all on oyun.%I from anon, authenticated', x);
  end loop;
end $r$;

-- ---------------------------------------------------------------- yardımcılar
create or replace function oyun.tv_tur_ad(p text) returns text language sql immutable set search_path = '' as $$
  select case p when 'duello' then 'Siyasi düello' when 'soylesi' then 'Söyleşi' when 'yarisma' then 'Bilgi yarışması'
                when 'acik_oturum' then 'Açık oturum · Halk soruyor' else 'Haber programı' end
$$;

-- Kanal seviyesi: bitmiş programların toplam izlenmesine göre
create or replace function oyun.tv_seviye(p_kanal bigint) returns jsonb language sql stable set search_path = '' as $$
  with s as (select coalesce(sum(izleyici), 0)::int toplam from oyun.tv_program where kanal_id = p_kanal and durum = 'bitti'),
  k(kademe, esik, ad, gunluk) as (values (1, 0, 'Yerel kanal', 4), (2, 100, 'Bölgesel kanal', 5), (3, 500, 'Ulusal kanal', 6), (4, 2000, 'Ana akım kanal', 8))
  select jsonb_build_object('kademe', a.kademe, 'ad', a.ad, 'gunluk', a.gunluk, 'toplam', s.toplam, 'esik', a.esik,
    'sonraki_esik', (select b.esik from k b where b.kademe = a.kademe + 1), 'sonraki_ad', (select b.ad from k b where b.kademe = a.kademe + 1),
    'sonraki_gunluk', (select b.gunluk from k b where b.kademe = a.kademe + 1))
  from s, lateral (select * from k where k.esik <= s.toplam order by k.esik desc limit 1) a
$$;

create or replace function oyun.tv_yonetici_mi(pr oyun.tv_program, u uuid) returns boolean language sql stable set search_path = '' as $$
  select pr.sunucu = u or exists (select 1 from oyun.tv_kanal k where k.id = pr.kanal_id and k.sahip = u)
$$;
create or replace function oyun.tv_konusmaci_mi(pr oyun.tv_program, u uuid) returns boolean language sql stable set search_path = '' as $$
  select pr.sunucu = u or exists (select 1 from oyun.tv_konuk x where x.program_id = pr.id and x.user_id = u and x.durum = 'kabul')
$$;

-- Reyting tabanı (30 sn önbellek): o an çevrimiçi ve son 7 günde aktif oyuncu sayısı
create or replace function oyun.tv_baz() returns jsonb language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); d jsonb;
begin
  select deger into d from oyun.tv_onbellek where anahtar = 'baz' and zaman > t - interval '30 seconds';
  if d is not null then return d; end if;
  select jsonb_build_object('cevrimici', greatest(1, count(*) filter (where son_gorulme > t - interval '5 minutes')),
                            'aktif', greatest(1, count(*) filter (where son_gorulme > t - interval '7 days')))
    into d from oyun.profiller where not yasakli;
  insert into oyun.tv_onbellek(anahtar, deger, zaman) values ('baz', d, t)
    on conflict (anahtar) do update set deger = excluded.deger, zaman = excluded.zaman;
  return d;
end $$;

-- Anket / yarışma sorusunu kapatır; yarışmada puanları hesaplar ve stüdyo akışına sonucu yazar
create or replace function oyun.tv_anket_kapat_ic(p_anket bigint) returns void language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); a oyun.tv_anket; sure numeric; n int; bilen int; ozet text;
begin
  select * into a from oyun.tv_anket where id = p_anket for update;
  if a.id is null or a.kapandi then return; end if;
  update oyun.tv_anket set kapandi = true, kapanis = least(kapanis, t) where id = a.id;
  select count(*) into n from oyun.tv_anket_oy where anket_id = a.id;
  if a.tur = 'yarisma' then
    sure := greatest(1, extract(epoch from (a.plan_kapanis - a.acilis)));
    update oyun.tv_anket_oy o set puan = case when o.secim = a.dogru
        then 100 + least(100, greatest(0, floor(100 * extract(epoch from (a.plan_kapanis - o.zaman)) / sure)))::int else 0 end
      where o.anket_id = a.id;
    select count(*) into bilen from oyun.tv_anket_oy where anket_id = a.id and secim = a.dogru;
    insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (a.program_id, a.olusturan, 'sistem',
      format('Doğru cevap: %s) %s · %s yarışmacıdan %s kişi bildi.', chr(65 + a.dogru), a.secenekler ->> a.dogru::int, n, bilen), t);
  else
    select string_agg(format('%s) %s %%%s', chr(65 + i::int - 1), x, case when n = 0 then 0 else round(100.0 * c / n) end), ' · ' order by i) into ozet
      from (select e.i, e.x, (select count(*) from oyun.tv_anket_oy o where o.anket_id = a.id and o.secim = e.i - 1) c
              from jsonb_array_elements_text(a.secenekler) with ordinality e(x, i)) q;
    insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (a.program_id, a.olusturan, 'sistem',
      format('Anket sonucu (%s oy) · %s — %s', n, a.soru, coalesce(ozet, '')), t);
  end if;
  perform oyun.tv_sinyal(a.program_id);
end $$;

-- Yarışma ödül havuzunun dağıtımı (program bitince bir kez)
create or replace function oyun.tv_odul_dagit(p_program bigint) returns void language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; r record; sira int := 0; pay numeric; bugun numeric; ver numeric;
  kalan numeric; ilk text; a record;
begin
  select * into pr from oyun.tv_program where id = p_program for update;
  if pr.id is null or pr.odul_dagitildi or pr.durum not in ('bitti','iptal') then return; end if;
  for a in select id from oyun.tv_anket where program_id = pr.id and not kapandi loop perform oyun.tv_anket_kapat_ic(a.id); end loop;
  select * into k from oyun.tv_kanal where id = pr.kanal_id for update;
  kalan := coalesce(pr.odul, 0);
  if kalan > 0 and pr.durum = 'bitti' then
    for r in select o.user_id, sum(o.puan)::int puan, min(o.zaman) ilk_cevap
               from oyun.tv_anket_oy o join oyun.tv_anket q on q.id = o.anket_id and q.program_id = pr.id and q.tur = 'yarisma'
              where o.user_id <> k.sahip and o.user_id <> pr.sunucu
                and not exists (select 1 from oyun.tv_konuk x where x.program_id = pr.id and x.user_id = o.user_id and x.durum = 'kabul')
                and not exists (select 1 from oyun.profiller pp where pp.id = o.user_id and pp.yasakli)
              group by o.user_id having sum(o.puan) > 0 order by sum(o.puan) desc, min(o.zaman) limit 3 loop
      sira := sira + 1;
      pay := round(pr.odul * case sira when 1 then 0.5 when 2 then 0.3 else 0.2 end);
      select coalesce(sum(z.tutar), 0) into bugun from oyun.tv_odul_kazanc z
        where z.user_id = r.user_id and (z.zaman at time zone 'Europe/Istanbul')::date = (t at time zone 'Europe/Istanbul')::date;
      ver := least(pay, greatest(0, 50000 - bugun), kalan);
      insert into oyun.tv_odul_kazanc(program_id, user_id, sira, puan, tutar, zaman) values (pr.id, r.user_id, sira, r.puan, ver, t);
      if ver > 0 then
        perform oyun.para_islem(r.user_id, ver, 'odul', format('%s · "%s" yarışması %s.liği ödülü', k.ad, pr.baslik, sira), t);
        kalan := kalan - ver;
      end if;
      perform oyun.bildir(r.user_id, format('%s · "%s" yarışmasında %s. oldun (%s puan)%s', k.ad, pr.baslik, sira, r.puan,
        case when ver > 0 then format(': %s ₺ ödül cüzdanına geçti.', oyun.tl(ver)) else '. Bugünkü TV ödülü sınırına (50.000 ₺) ulaştığın için ödül kasaya döndü.' end), t);
      if sira = 1 then ilk := oyun.kad(r.user_id) || ' (' || r.puan || ' puan)'; end if;
    end loop;
    if ilk is not null then
      perform oyun.olay('basin', format('%s · "%s" bilgi yarışmasının birincisi %s; ödül havuzu %s ₺.', k.ad, pr.baslik, ilk, oyun.tl(pr.odul)), null, null, t);
    end if;
  end if;
  if kalan > 0 then
    update oyun.tv_kanal set kasa = kasa + kalan where id = k.id;
    insert into oyun.tv_hareket(kanal_id, zaman, tutar, tur, aciklama) values (k.id, t, kalan, 'odul_iade', format('"%s" · dağıtılmayan yarışma ödülü kasaya döndü', pr.baslik));
  end if;
  update oyun.tv_program set odul_dagitildi = true where id = pr.id;
end $$;

create or replace function oyun.tv_program_ozet(pr oyun.tv_program, t timestamptz) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id', pr.id, 'kanal_id', pr.kanal_id, 'kanal', (select ad from oyun.tv_kanal where id = pr.kanal_id), 'tur', pr.tur, 'tur_ad', oyun.tv_tur_ad(pr.tur),
    'baslik', pr.baslik, 'aciklama', pr.aciklama, 'bas', pr.bas, 'bit', case when pr.durum in ('bitti','iptal') then coalesce(pr.gercek_bit, pr.bit) else pr.bit end,
    'acik_uclu', pr.acik_uclu, 'durum', pr.durum, 'sunucu', oyun.kad(pr.sunucu),
    'konuklar', (select coalesce(jsonb_agg(oyun.kad(x.user_id) order by x.zaman), '[]'::jsonb) from oyun.tv_konuk x where x.program_id = pr.id and x.durum = 'kabul'),
    'izleyici', case when pr.durum = 'canli' then (select count(*) from oyun.tv_izleyici z where z.program_id = pr.id and z.son > t - interval '45 seconds')
                     else greatest(pr.izleyici, (select count(*) from oyun.tv_izleyici z where z.program_id = pr.id)) end,
    'reklam', (select count(*) from oyun.tv_reklam r where r.program_id = pr.id and r.durum in ('onay','yayinlandi')),
    'zirve', pr.zirve, 'odul', round(pr.odul))
$$;

-- ---------------------------------------------------------------- 198'den yenilenenler (gövde aynı; işaretli satırlar yeni)
create or replace function oyun.tv_program_guncelle(p_program bigint) returns oyun.tv_program language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; r record;
begin
  select * into pr from oyun.tv_program where id = p_program;
  if pr.id is null or pr.durum in ('bitti','iptal') or (pr.durum = 'planli' and t < pr.bas) or (pr.durum = 'canli' and t < pr.bit) then return pr; end if;
  select * into pr from oyun.tv_program where id = p_program for update;
  select * into k from oyun.tv_kanal where id = pr.kanal_id;
  if pr.durum = 'planli' and t >= pr.bas then
    update oyun.tv_program set durum = 'canli', gercek_bas = pr.bas where id = pr.id returning * into pr;
    for r in select * from oyun.tv_reklam where program_id = pr.id and durum = 'onay' order by id loop
      insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, r.veren, 'reklam', r.marka || ': ' || r.metin, pr.bas);
    end loop;
    if t < pr.bit then
      perform oyun.bildir(x.user_id, format('%s · "%s" programı başladı. Konuksun: Gündem › TV Kanalları''ndan stüdyoya gir.', k.ad, pr.baslik), t)
         from oyun.tv_konuk x where x.program_id = pr.id and x.durum = 'kabul';
      if pr.sunucu is distinct from pr.olusturan or pr.olusturma < t - interval '2 minutes' then
        perform oyun.bildir(pr.sunucu, format('%s · "%s" programın yayında. Stüdyoya gir.', k.ad, pr.baslik), t); end if;
      perform oyun.olay('basin', format('%s canlı yayında: "%s" (%s, sunucu %s).', k.ad, pr.baslik, oyun.tv_tur_ad(pr.tur), oyun.kad(pr.sunucu)), null, null, t);
      -- 209: hatırlatma kuranlar her zaman, takipçiler aynı kanaldan en çok 2 saatte bir bildirim alır
      perform oyun.bildir(h.user_id, format('Hatırlatma: %s şimdi canlı yayında — "%s" (%s). Gündem › TV Kanalları''ndan izle.', k.ad, pr.baslik, oyun.tv_tur_ad(pr.tur)), t)
         from oyun.tv_hatirlat h where h.program_id = pr.id and not oyun.tv_konusmaci_mi(pr, h.user_id);
      for r in update oyun.tv_takip f set son_bildirim = t
                  where f.kanal_id = k.id and (f.son_bildirim is null or f.son_bildirim < t - interval '2 hours')
                    and not oyun.tv_konusmaci_mi(pr, f.user_id) and f.user_id <> k.sahip
                    and not exists (select 1 from oyun.tv_hatirlat h where h.program_id = pr.id and h.user_id = f.user_id)
                  returning f.user_id loop
        perform oyun.bildir(r.user_id, format('Takip ettiğin %s canlı yayında: "%s" (%s). Gündem › TV Kanalları''ndan izle.', k.ad, pr.baslik, oyun.tv_tur_ad(pr.tur)), t);
      end loop;
    end if;
    perform oyun.tv_sinyal(pr.id);
  end if;
  if pr.durum = 'canli' and t >= pr.bit then
    update oyun.tv_program set durum = 'bitti', gercek_bit = pr.bit, reklam_arasi = null where id = pr.id returning * into pr;
    perform oyun.tv_program_hesapla(pr.id);
    perform oyun.tv_sinyal(pr.id);
    select * into pr from oyun.tv_program where id = p_program;
  end if;
  return pr;
end $$;

create or replace function oyun.tv_guncelle_hepsi() returns int language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); r record; n int := 0; kaz record;
begin
  for r in select id from oyun.tv_program where (durum = 'planli' and bas <= t) or (durum = 'canli' and bit <= t) order by id loop
    perform oyun.tv_program_guncelle(r.id); n := n + 1;
  end loop;
  -- 209: süresi dolan anket / yarışma soruları ve bitmiş programların açık soruları kapanır; ödüller dağıtılır
  for r in select a.id from oyun.tv_anket a join oyun.tv_program p on p.id = a.program_id
            where not a.kapandi and (a.kapanis <= t or p.durum in ('bitti','iptal')) order by a.id loop
    perform oyun.tv_anket_kapat_ic(r.id); n := n + 1;
  end loop;
  for r in select id from oyun.tv_program where durum in ('bitti','iptal') and not odul_dagitildi and (odul > 0 or tur = 'yarisma') order by id loop
    perform oyun.tv_odul_dagit(r.id); n := n + 1;
  end loop;
  update oyun.tv_program set odul_dagitildi = true where durum in ('bitti','iptal') and not odul_dagitildi and odul = 0 and tur <> 'yarisma';
  -- düello sonucu: oylama program bittikten 15 dakika sonra kapanır
  for r in select p.*, k.ad kanal from oyun.tv_program p join oyun.tv_kanal k on k.id = p.kanal_id
            where p.durum = 'bitti' and not p.sonuc_yazildi and p.gercek_bit <= t - interval '15 minutes' loop
    if r.tur = 'duello' then
      select o.konuk, count(*) oy into kaz from oyun.tv_oy o where o.program_id = r.id group by o.konuk order by count(*) desc, min(o.zaman) limit 1;
      if kaz.konuk is not null then
        perform oyun.olay('basin', format('%s · "%s" düellosunu izleyici oylamasıyla %s kazandı (%s oy, %s izleyici).', r.kanal, r.baslik, oyun.kad(kaz.konuk), kaz.oy, r.izleyici), null, null, t);
        perform oyun.bildir(kaz.konuk, format('%s kanalındaki "%s" düellosunu izleyici oylamasıyla sen kazandın (%s oy).', r.kanal, r.baslik, kaz.oy), t);
      end if;
    end if;
    update oyun.tv_program set sonuc_yazildi = true where id = r.id; n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.tv_program_ac(p_kanal bigint, p_tur text, p_baslik text, p_aciklama text default null, p_bas timestamptz default null,
  p_dakika integer default null, p_sunucu text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.tv_kanal; b text; a text; v_bas timestamptz; v_bit timestamptz; sun uuid; i bigint; h oyun.profiller;
  sv jsonb; gunluk int;
begin
  perform oyun.yazabilir_mi(p, t);
  select * into k from oyun.tv_kanal where id = p_kanal and aktif;
  if k.id is null or not oyun.tv_yayinci_mi(k.id, p.id) then raise exception 'Programı kanalın sahibi ya da sunucusu açar.'; end if;
  if p_tur not in ('duello','soylesi','haber','yarisma','acik_oturum') then raise exception 'Geçersiz program türü.'; end if;
  b := oyun.metin_ops(p_baslik, 90); a := oyun.metin_ops(p_aciklama, 300);
  if char_length(b) < 4 then raise exception 'Program başlığı en az 4 karakter olmalı.'; end if;
  v_bas := greatest(coalesce(p_bas, t), t);
  if v_bas > t + interval '14 days' then raise exception 'Program en çok 14 gün sonrasına planlanabilir.'; end if;
  if p_dakika is not null and (p_dakika < 10 or p_dakika > 180) then raise exception 'Program süresi 10 ile 180 dakika arasında olmalı.'; end if;
  v_bit := v_bas + make_interval(mins => coalesce(p_dakika, 180));
  sun := p.id;
  if p_sunucu is not null and btrim(p_sunucu) <> '' then
    if k.sahip <> p.id then raise exception 'Sunucuyu yalnız kanal sahibi belirler.'; end if;
    h := oyun.profil_bul(p_sunucu);
    if not oyun.tv_yayinci_mi(k.id, h.id) then raise exception 'Bu oyuncu kanalın sunucusu değil. Önce sunuculuk teklif et.'; end if;
    sun := h.id;
  end if;
  if exists (select 1 from oyun.tv_program x where x.kanal_id = k.id and x.durum in ('planli','canli') and x.bas < v_bit and x.bit > v_bas) then
    raise exception 'Kanalın bu saatlerde başka bir programı var.'; end if;
  sv := oyun.tv_seviye(k.id); gunluk := coalesce((sv ->> 'gunluk')::int, 4);
  if (select count(*) from oyun.tv_program x where x.kanal_id = k.id and x.durum <> 'iptal'
        and (x.bas at time zone 'Europe/Istanbul')::date = (v_bas at time zone 'Europe/Istanbul')::date) >= gunluk then
    raise exception 'Bu kanal (%) günde en çok % program yapabilir. Kanalın izlendikçe seviyesi ve program hakkı artar.', sv ->> 'ad', gunluk; end if;
  insert into oyun.tv_program(kanal_id, sunucu, tur, baslik, aciklama, bas, bit, acik_uclu, olusturan, olusturma)
    values (k.id, sun, p_tur, b, nullif(a, ''), v_bas, v_bit, p_dakika is null, p.id, t) returning id into i;
  if v_bas > t + interval '1 minute' then
    perform oyun.olay('basin', format('%s program duyurusu: "%s" (%s) · %s · sunucu %s.', k.ad, b, oyun.tv_tur_ad(p_tur),
      to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'), oyun.kad(sun)), null, null, t);
    if sun <> p.id then perform oyun.bildir(sun, format('%s kanalında "%s" programının sunucususun: %s.', k.ad, b, to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), t); end if;
  end if;
  perform oyun.tv_program_guncelle(i);
  return public.tv_detay(i);
end $$;

create or replace function public.tv_yaz(p_program bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; m text; r text; i bigint;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  if pr.durum = 'planli' then raise exception 'Yayın henüz başlamadı.'; end if;
  if pr.durum <> 'canli' then raise exception 'Yayın sona erdi.'; end if;
  perform oyun.yazabilir_mi(p, t);
  if pr.sunucu = p.id then r := 'sunucu';
  elsif exists (select 1 from oyun.tv_konuk where program_id = pr.id and user_id = p.id and durum = 'kabul') then r := 'konuk';
  else raise exception 'Stüdyoda yalnız sunucu ve konuklar konuşur. Sen Seyirci sekmesinden yorum ya da soru yazabilir, söz isteyebilirsin.'; end if;
  if pr.reklam_arasi is not null and pr.reklam_arasi > t then raise exception 'Reklam arasındayız; yayın birkaç saniye sonra sürecek.'; end if;   -- 209
  m := oyun.metin_temizle(p_metin, 600);
  if char_length(coalesce(m, '')) < 1 then raise exception 'Boş mesaj gönderilemez.'; end if;
  if exists (select 1 from oyun.tv_mesaj where program_id = pr.id and user_id = p.id and zaman > t - interval '2 seconds') then raise exception 'Çok hızlı yazıyorsun; bir an bekle.'; end if;
  insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, p.id, r, m, t) returning id into i;
  update oyun.profiller set son_mesaj = t where id = p.id;
  perform oyun.tv_sinyal(pr.id);
  return jsonb_build_object('tamam', true, 'id', i);
end $$;

-- ---------------------------------------------------------------- stüdyo: hafif canlı katman
create or replace function oyun.tv_mesaj_json(m oyun.tv_mesaj, u uuid) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id', m.id, 'rol', m.rol, 'metin', m.metin, 'zaman', m.zaman,
    'kisi', case when m.rol = 'reklam' then null else oyun.sm_kisi(m.user_id) end, 'benim', m.user_id = u)
$$;

create or replace function public.tv_canli(p_program bigint, p_mesaj bigint default 0, p_yorum bigint default 0) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; rol text; anlik int; toplam int;
  a oyun.tv_anket; aj jsonb; yj jsonb; yonetici boolean; konusan boolean; rr record; baz jsonb;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  select * into k from oyun.tv_kanal where id = pr.kanal_id;
  rol := case when pr.sunucu = p.id then 'sunucu'
              when exists (select 1 from oyun.tv_konuk x where x.program_id = pr.id and x.user_id = p.id and x.durum = 'kabul') then 'konuk'
              when exists (select 1 from oyun.tv_konuk x where x.program_id = pr.id and x.user_id = p.id and x.durum = 'davet') then 'davetli'
              when k.sahip = p.id then 'sahip' else 'izleyici' end;
  yonetici := pr.sunucu = p.id or k.sahip = p.id; konusan := rol in ('sunucu','konuk');
  if pr.durum = 'canli' and rol in ('izleyici','davetli') then
    insert into oyun.tv_izleyici(program_id, user_id, ilk, son) values (pr.id, p.id, t, t)
      on conflict (program_id, user_id) do update set son = excluded.son where oyun.tv_izleyici.son < t - interval '12 seconds';
  end if;
  select count(*) filter (where z.son > t - interval '45 seconds'), count(*) into anlik, toplam from oyun.tv_izleyici z where z.program_id = pr.id;
  if pr.durum = 'canli' and anlik > pr.zirve then update oyun.tv_program set zirve = anlik where id = pr.id and zirve < anlik; pr.zirve := anlik; end if;
  for rr in select id from oyun.tv_anket where program_id = pr.id and not kapandi and kapanis <= t loop perform oyun.tv_anket_kapat_ic(rr.id); end loop;
  if pr.durum in ('bitti','iptal') and not pr.odul_dagitildi and (pr.odul > 0 or pr.tur = 'yarisma') then perform oyun.tv_odul_dagit(pr.id); end if;
  baz := oyun.tv_baz();
  -- etkin anket: açık olan ya da son 90 saniyede kapanan
  select * into a from oyun.tv_anket q where q.program_id = pr.id and (not q.kapandi or q.kapanis > t - interval '90 seconds') order by q.id desc limit 1;
  if a.id is not null then
    aj := jsonb_build_object('id', a.id, 'tur', a.tur, 'soru', a.soru, 'secenekler', a.secenekler, 'acilis', a.acilis, 'kapanis', a.kapanis, 'kapandi', a.kapandi,
      'no', (select count(*) from oyun.tv_anket q where q.program_id = pr.id and q.tur = a.tur and q.id <= a.id),
      'toplam', (select count(*) from oyun.tv_anket_oy o where o.anket_id = a.id),
      'oylar', case when a.tur = 'anket' or a.kapandi or yonetici then
         (select jsonb_agg((select count(*) from oyun.tv_anket_oy o where o.anket_id = a.id and o.secim = g.i) order by g.i)
            from generate_series(0, jsonb_array_length(a.secenekler) - 1) g(i)) end,
      'dogru', case when a.kapandi or yonetici then a.dogru end,
      'secimim', (select o.secim from oyun.tv_anket_oy o where o.anket_id = a.id and o.user_id = p.id),
      'puanim', case when a.kapandi then (select o.puan from oyun.tv_anket_oy o where o.anket_id = a.id and o.user_id = p.id) end);
  end if;
  if pr.tur = 'yarisma' then
    yj := jsonb_build_object('odul', round(pr.odul), 'soru_sayisi', (select count(*) from oyun.tv_anket q where q.program_id = pr.id and q.tur = 'yarisma'),
      'tablo', (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(s.user_id), 'puan', s.puan, 'ben', s.user_id = p.id) order by s.puan desc, s.ilk), '[]'::jsonb)
                  from (select o.user_id, sum(o.puan)::int puan, min(o.zaman) ilk from oyun.tv_anket_oy o join oyun.tv_anket q on q.id = o.anket_id and q.program_id = pr.id and q.tur = 'yarisma' and q.kapandi
                         group by o.user_id having sum(o.puan) > 0 order by sum(o.puan) desc, min(o.zaman) limit 5) s),
      'puanim', (select coalesce(sum(o.puan), 0)::int from oyun.tv_anket_oy o join oyun.tv_anket q on q.id = o.anket_id and q.program_id = pr.id and q.tur = 'yarisma' and q.kapandi where o.user_id = p.id),
      'kazananlar', (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(z.user_id), 'sira', z.sira, 'puan', z.puan, 'tutar', round(z.tutar)) order by z.sira), '[]'::jsonb)
                       from oyun.tv_odul_kazanc z where z.program_id = pr.id));
  end if;
  return jsonb_build_object('id', pr.id, 'durum', pr.durum, 'rolum', rol, 'simdi', t, 'yonetici', yonetici, 'kanal_sahibi', k.sahip = p.id,
    'konuk_imza', (select coalesce(string_agg(oyun.kad(x.user_id) || ':' || x.durum, ',' order by x.zaman), '') from oyun.tv_konuk x where x.program_id = pr.id),
    'reklam_n', (select count(*) from oyun.tv_reklam r where r.program_id = pr.id and r.durum in ('onay','yayinlandi')),
    'oy_acik', pr.tur = 'duello' and (pr.durum = 'canli' or (pr.durum = 'bitti' and coalesce(pr.gercek_bit, pr.bit) > t - interval '15 minutes')),
    'izleyici', jsonb_build_object('anlik', anlik, 'toplam', toplam, 'zirve', greatest(pr.zirve, case when pr.durum = 'canli' then anlik else 0 end)),
    'reyting', round(100.0 * case when pr.durum = 'canli' then anlik else greatest(pr.zirve, 0) end / greatest(1, (baz ->> 'aktif')::int), 1),
    'pay', case when pr.durum = 'canli' then round(100.0 * anlik / greatest(1, (baz ->> 'cevrimici')::int)) end,
    'cevrimici', (baz ->> 'cevrimici')::int,
    'alkis', (select count(*) from oyun.tv_tepki x where x.program_id = pr.id and x.tur = 'alkis'),
    'yuh', (select count(*) from oyun.tv_tepki x where x.program_id = pr.id and x.tur = 'yuh'),
    'tepkim', (select tur from oyun.tv_tepki where program_id = pr.id and user_id = p.id),
    'emoji', (select coalesce(jsonb_object_agg(e.tur, e.s), '{}'::jsonb) from (select tur, sum(sayi)::int s from oyun.tv_emoji where program_id = pr.id group by tur) e),
    'emoji_son', (select coalesce(jsonb_object_agg(e.tur, e.s), '{}'::jsonb) from (select tur, sum(sayi)::int s from oyun.tv_emoji
                    where program_id = pr.id and dakika >= date_trunc('minute', t) - interval '1 minute' group by tur) e),
    'isi', (select coalesce(sum(sayi), 0)::int from oyun.tv_emoji where program_id = pr.id and dakika >= date_trunc('minute', t) - interval '1 minute'),
    'mesajlar', (select coalesce(jsonb_agg(oyun.tv_mesaj_json(m, p.id) order by m.id), '[]'::jsonb)
                   from (select * from (select * from oyun.tv_mesaj where program_id = pr.id and id > coalesce(p_mesaj, 0) and not gizli order by id desc limit 60) q order by id) m),
    'yorumlar', (select coalesce(jsonb_agg(jsonb_build_object('id', y.id, 'kad', oyun.kad(y.user_id), 'metin', y.metin, 'zaman', y.zaman, 'soru', y.soru,
                    'ekranda', y.ekran_at is not null, 'benim', y.user_id = p.id) order by y.id), '[]'::jsonb)
                   from (select * from (select * from oyun.tv_yorum where program_id = pr.id and id > coalesce(p_yorum, 0) and not gizli order by id desc limit 40) q order by id) y),
    'yorum_sayi', (select count(*) from oyun.tv_yorum where program_id = pr.id and not gizli),
    'sorular', (select coalesce(jsonb_agg(jsonb_build_object('id', y.id, 'kad', oyun.kad(y.user_id), 'metin', y.metin, 'destek', y.destek, 'benim', y.user_id = p.id,
                    'destekledim', exists (select 1 from oyun.tv_yorum_destek d where d.yorum_id = y.id and d.user_id = p.id)) order by y.destek desc, y.id), '[]'::jsonb)
                  from (select * from oyun.tv_yorum where program_id = pr.id and soru and not gizli and ekran_at is null order by destek desc, id limit 6) y),
    'ekranda', (select jsonb_build_object('id', y.id, 'kad', oyun.kad(y.user_id), 'metin', y.metin, 'soru', y.soru, 'zaman', y.ekran_at)
                  from oyun.tv_yorum y where y.id = pr.ekrandaki and not y.gizli and y.ekran_at > t - interval '3 minutes'),
    'anket', aj, 'yarisma', yj,
    'reklam_arasi', case when pr.reklam_arasi > t then jsonb_build_object('bitis', pr.reklam_arasi,
        'reklamlar', (select coalesce(jsonb_agg(jsonb_build_object('marka', r.marka, 'metin', r.metin) order by r.id), '[]'::jsonb) from oyun.tv_reklam r where r.program_id = pr.id and r.durum = 'onay')) end,
    'reklam_arasi_hazir', pr.durum = 'canli' and exists (select 1 from oyun.tv_reklam r where r.program_id = pr.id and r.durum = 'onay')
        and (pr.son_reklam_arasi is null or pr.son_reklam_arasi < t - interval '8 minutes'),
    'soz', jsonb_build_object('istedim', (select z.soz_iste is not null from oyun.tv_izleyici z where z.program_id = pr.id and z.user_id = p.id),
        'sayi', (select count(*) from oyun.tv_izleyici z where z.program_id = pr.id and z.soz_iste is not null and z.son > t - interval '2 minutes'),
        'kuyruk', case when yonetici then (select coalesce(jsonb_agg(oyun.sm_kisi(z.user_id) || jsonb_build_object('zaman', z.soz_iste) order by z.soz_iste), '[]'::jsonb)
                   from (select * from oyun.tv_izleyici z where z.program_id = pr.id and z.soz_iste is not null and z.son > t - interval '2 minutes' order by z.soz_iste limit 10) z) end),
    'konuk_oy', case when pr.tur = 'duello' then (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(x.user_id),
        'oy', (select count(*) from oyun.tv_oy o where o.program_id = pr.id and o.konuk = x.user_id)) order by x.zaman), '[]'::jsonb)
        from oyun.tv_konuk x where x.program_id = pr.id and x.durum = 'kabul') end,
    'oyum', (select oyun.kad(konuk) from oyun.tv_oy where program_id = pr.id and user_id = p.id),
    'takip', exists (select 1 from oyun.tv_takip f where f.kanal_id = k.id and f.user_id = p.id),
    'takipci', (select count(*) from oyun.tv_takip f where f.kanal_id = k.id),
    'hatirlat', exists (select 1 from oyun.tv_hatirlat h where h.program_id = pr.id and h.user_id = p.id),
    'diger', (select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'baslik', q.baslik, 'kanal', q.kanal) order by q.id), '[]'::jsonb)
                from (select x.id, x.baslik, kk.ad kanal from oyun.tv_program x join oyun.tv_kanal kk on kk.id = x.kanal_id
                       where x.durum = 'canli' and x.bit > t order by x.id limit 12) q));
end $$;

-- ---------------------------------------------------------------- anlık emoji
create or replace function public.tv_emoji(p_program bigint, p_tur text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program;
begin
  if p_tur not in ('alkis','kahkaha','sasirma','ofke','kalp','ates') then raise exception 'Geçersiz tepki.'; end if;
  if p.yasakli then raise exception 'Hesabın kısıtlı.'; end if;
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null or pr.durum <> 'canli' then raise exception 'Bu yayın şu an canlı değil.'; end if;
  if oyun.tv_konusmaci_mi(pr, p.id) then raise exception 'Stüdyodakiler seyirci tepkisi veremez.'; end if;
  update oyun.tv_izleyici set son_emoji = t, son = t
   where program_id = pr.id and user_id = p.id and (son_emoji is null or son_emoji < t - interval '1800 milliseconds');
  if not found then
    insert into oyun.tv_izleyici(program_id, user_id, ilk, son, son_emoji) values (pr.id, p.id, t, t, t) on conflict (program_id, user_id) do nothing;
    if not found then return jsonb_build_object('tamam', false); end if;
  end if;
  insert into oyun.tv_emoji(program_id, tur, parca, dakika, sayi) values (pr.id, p_tur, (hashtext(p.id::text) & 7), date_trunc('minute', t), 1)
    on conflict (program_id, dakika, tur, parca) do update set sayi = oyun.tv_emoji.sayi + 1;
  return jsonb_build_object('tamam', true);
end $$;

-- ---------------------------------------------------------------- seyirci kürsüsü
create or replace function public.tv_yorum_yaz(p_program bigint, p_metin text, p_soru boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; m text; i bigint;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  if pr.durum <> 'canli' then raise exception 'Seyirci yorumları yalnız canlı yayında yazılır.'; end if;
  perform oyun.yazabilir_mi(p, t);
  if oyun.tv_konusmaci_mi(pr, p.id) then raise exception 'Stüdyodasın; yayına doğrudan yaz.'; end if;
  m := oyun.metin_temizle(p_metin, 200);
  if char_length(coalesce(m, '')) < 2 then raise exception 'Yorum en az 2 karakter olmalı.'; end if;
  update oyun.tv_izleyici set son_yorum = t, son = t where program_id = pr.id and user_id = p.id and (son_yorum is null or son_yorum < t - interval '6 seconds');
  if not found then
    insert into oyun.tv_izleyici(program_id, user_id, ilk, son, son_yorum) values (pr.id, p.id, t, t, t) on conflict (program_id, user_id) do nothing;
    if not found then raise exception 'Seyirci kürsüsünde 6 saniyede bir yazabilirsin.'; end if;
  end if;
  if coalesce(p_soru, false) and (select count(*) from oyun.tv_yorum where program_id = pr.id and user_id = p.id and soru and ekran_at is null and not gizli) >= 3 then
    raise exception 'Bu yayında yanıt bekleyen 3 sorun var; biri ekrana alınınca yenisini sorabilirsin.'; end if;
  insert into oyun.tv_yorum(program_id, user_id, metin, zaman, soru) values (pr.id, p.id, m, t, coalesce(p_soru, false)) returning id into i;
  return jsonb_build_object('tamam', true, 'id', i);
end $$;

create or replace function public.tv_yorum_destek(p_yorum bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); y oyun.tv_yorum; pr oyun.tv_program; n int;
begin
  select * into y from oyun.tv_yorum where id = p_yorum;
  if y.id is null or y.gizli or not y.soru then raise exception 'Soru bulunamadı.'; end if;
  pr := oyun.tv_program_guncelle(y.program_id);
  if pr.durum <> 'canli' then raise exception 'Yayın sona erdi.'; end if;
  if y.user_id = p.id then raise exception 'Kendi sorunu destekleyemezsin.'; end if;
  insert into oyun.tv_yorum_destek(yorum_id, user_id, zaman) values (y.id, p.id, t) on conflict do nothing;
  if found then update oyun.tv_yorum set destek = destek + 1 where id = y.id returning destek into n; else n := y.destek; end if;
  return jsonb_build_object('tamam', true, 'destek', n);
end $$;

create or replace function public.tv_yorum_ekrana(p_yorum bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); y oyun.tv_yorum; pr oyun.tv_program; k oyun.tv_kanal;
begin
  select * into y from oyun.tv_yorum where id = p_yorum for update;
  if y.id is null or y.gizli then raise exception 'Yorum bulunamadı.'; end if;
  pr := oyun.tv_program_guncelle(y.program_id);
  if not oyun.tv_yonetici_mi(pr, p.id) then raise exception 'Yorumu ekrana programın sunucusu ya da kanal sahibi alır.'; end if;
  if pr.durum <> 'canli' then raise exception 'Yayın canlı değil.'; end if;
  if y.ekran_at is not null then raise exception 'Bu yorum zaten ekrana alındı.'; end if;
  select * into k from oyun.tv_kanal where id = pr.kanal_id;
  update oyun.tv_yorum set ekran_at = t where id = y.id;
  update oyun.tv_program set ekrandaki = y.id where id = pr.id;
  insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, y.user_id, 'seyirci', y.metin, t);
  perform oyun.bildir(y.user_id, format('%s · "%s" yayınında %s ekrana alındı: "%s"', k.ad, pr.baslik, case when y.soru then 'sorun' else 'yorumun' end, left(y.metin, 80)), t);
  perform oyun.tv_sinyal(pr.id);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.tv_yorum_gizle(p_yorum bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); y oyun.tv_yorum; pr oyun.tv_program;
begin
  select * into y from oyun.tv_yorum where id = p_yorum for update;
  if y.id is null then raise exception 'Yorum bulunamadı.'; end if;
  select * into pr from oyun.tv_program where id = y.program_id;
  if not oyun.tv_yonetici_mi(pr, p.id) and y.user_id <> p.id then raise exception 'Yorumu yalnız yazan, sunucu ya da kanal sahibi kaldırır.'; end if;
  update oyun.tv_yorum set gizli = true where id = y.id;
  update oyun.tv_program set ekrandaki = null where id = pr.id and ekrandaki = y.id;
  return jsonb_build_object('tamam', true);
end $$;

-- ---------------------------------------------------------------- canlı anket ve yarışma sorusu
create or replace function public.tv_anket_ac(p_program bigint, p_soru text, p_secenekler text[], p_saniye integer default 60, p_dogru integer default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; s text; sec jsonb := '[]'::jsonb; x text; n int; v_tur text; sn int; i bigint; no int;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  if not oyun.tv_yonetici_mi(pr, p.id) then raise exception 'Anketi ve yarışma sorusunu programın sunucusu ya da kanal sahibi açar.'; end if;
  if pr.durum <> 'canli' then raise exception 'Anket yalnız canlı yayında açılır.'; end if;
  perform oyun.yazabilir_mi(p, t);
  if exists (select 1 from oyun.tv_anket where program_id = pr.id and not kapandi and kapanis > t) then raise exception 'Açık bir soru var; önce onu kapat ya da süresinin dolmasını bekle.'; end if;
  if (select count(*) from oyun.tv_anket where program_id = pr.id) >= 60 then raise exception 'Bir programda en çok 60 soru/anket açılır.'; end if;
  s := oyun.metin_ops(p_soru, 160);
  if char_length(s) < 4 then raise exception 'Soru en az 4 karakter olmalı.'; end if;
  foreach x in array coalesce(p_secenekler, array[]::text[]) loop
    x := oyun.metin_ops(x, 60);
    if char_length(x) >= 1 then sec := sec || to_jsonb(x); end if;
  end loop;
  n := jsonb_array_length(sec);
  if n < 2 or n > 4 then raise exception 'İki ile dört arasında seçenek yaz.'; end if;
  if p_dogru is not null then
    if pr.tur <> 'yarisma' then raise exception 'Doğru cevaplı soru yalnız bilgi yarışmasında sorulur; diğer programlarda anket açabilirsin.'; end if;
    if p_dogru < 0 or p_dogru >= n then raise exception 'Doğru cevabı seç.'; end if;
    v_tur := 'yarisma'; sn := least(90, greatest(10, coalesce(p_saniye, 30)));
  else
    v_tur := 'anket'; sn := least(600, greatest(15, coalesce(p_saniye, 60)));
  end if;
  insert into oyun.tv_anket(program_id, tur, soru, secenekler, dogru, acilis, kapanis, plan_kapanis, olusturan)
    values (pr.id, v_tur, s, sec, p_dogru, t, t + make_interval(secs => sn), t + make_interval(secs => sn), p.id) returning id into i;
  select count(*) into no from oyun.tv_anket where program_id = pr.id and tur = 'yarisma';
  insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, p.id, 'sistem',
    case when v_tur = 'yarisma' then format('Soru %s · %s (%s saniye)', no, s, sn) else format('Canlı anket · %s (%s saniye)', s, sn) end, t);
  perform oyun.tv_sinyal(pr.id);
  return jsonb_build_object('tamam', true, 'id', i);
end $$;

create or replace function public.tv_anket_oyla(p_anket bigint, p_secim integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.tv_anket; pr oyun.tv_program;
begin
  if p.yasakli then raise exception 'Hesabın kısıtlı.'; end if;
  select * into a from oyun.tv_anket where id = p_anket;
  if a.id is null then raise exception 'Soru bulunamadı.'; end if;
  select * into pr from oyun.tv_program where id = a.program_id;
  if a.kapandi or t >= a.kapanis or pr.durum <> 'canli' then raise exception 'Süre doldu.'; end if;
  if p_secim is null or p_secim < 0 or p_secim >= jsonb_array_length(a.secenekler) then raise exception 'Geçersiz seçenek.'; end if;
  if pr.sunucu = p.id then raise exception 'Sunucu oy kullanamaz.'; end if;
  insert into oyun.tv_izleyici(program_id, user_id, ilk, son) values (pr.id, p.id, t, t) on conflict (program_id, user_id) do nothing;
  if a.tur = 'yarisma' then
    if oyun.tv_konusmaci_mi(pr, p.id) or exists (select 1 from oyun.tv_kanal k where k.id = pr.kanal_id and k.sahip = p.id) then
      raise exception 'Yarışmaya sunucu, konuklar ve kanal sahibi katılamaz.'; end if;
    insert into oyun.tv_anket_oy(anket_id, user_id, secim, zaman) values (a.id, p.id, p_secim, t) on conflict do nothing;
    if not found then raise exception 'Cevabın zaten kilitlendi.'; end if;
  else
    insert into oyun.tv_anket_oy(anket_id, user_id, secim, zaman) values (a.id, p.id, p_secim, t)
      on conflict (anket_id, user_id) do update set secim = excluded.secim, zaman = excluded.zaman;
  end if;
  return jsonb_build_object('tamam', true, 'secim', p_secim);
end $$;

create or replace function public.tv_anket_kapat(p_anket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.tv_anket; pr oyun.tv_program;
begin
  select * into a from oyun.tv_anket where id = p_anket;
  if a.id is null then raise exception 'Soru bulunamadı.'; end if;
  select * into pr from oyun.tv_program where id = a.program_id;
  if not oyun.tv_yonetici_mi(pr, p.id) then raise exception 'Soruyu sunucu ya da kanal sahibi kapatır.'; end if;
  perform oyun.tv_anket_kapat_ic(a.id);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.tv_odul_koy(p_program bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; m numeric := round(coalesce(p_tutar, 0));
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  select * into k from oyun.tv_kanal where id = pr.kanal_id and aktif for update;
  if k.id is null or k.sahip <> p.id then raise exception 'Ödül havuzuna yalnız kanal sahibi, kanal kasasından para koyar.'; end if;
  if pr.tur <> 'yarisma' then raise exception 'Ödül havuzu yalnız bilgi yarışmalarında olur.'; end if;
  if pr.durum not in ('planli','canli') then raise exception 'Program bitti.'; end if;
  if m < 1000 then raise exception 'En az 1.000 ₺ koy.'; end if;
  select * into pr from oyun.tv_program where id = pr.id for update;
  if pr.odul + m > 100000 then raise exception 'Bir yarışmanın ödül havuzu en çok 100.000 ₺ olur (şu an % ₺).', oyun.tl(pr.odul); end if;
  if k.kasa < m then raise exception 'Kanal kasasında yeterli para yok (% ₺).', oyun.tl(k.kasa); end if;
  update oyun.tv_kanal set kasa = kasa - m where id = k.id;
  insert into oyun.tv_hareket(kanal_id, zaman, tutar, tur, aciklama) values (k.id, t, -m, 'odul', format('"%s" yarışma ödül havuzu', pr.baslik));
  update oyun.tv_program set odul = odul + m where id = pr.id;
  if pr.durum = 'canli' then
    insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, p.id, 'sistem', format('Ödül havuzu büyüdü: %s ₺. İlk üç: %%50 · %%30 · %%20.', oyun.tl(pr.odul + m)), t);
  end if;
  perform oyun.tv_sinyal(pr.id);
  return jsonb_build_object('tamam', true, 'odul', round(pr.odul + m), 'kasa', round(k.kasa - m));
end $$;

-- ---------------------------------------------------------------- reklam arası, canlı bağlantı
create or replace function public.tv_reklam_arasi(p_program bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; n int;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null or not oyun.tv_yonetici_mi(pr, p.id) then raise exception 'Reklam arasını programın sunucusu ya da kanal sahibi verir.'; end if;
  if pr.durum <> 'canli' then raise exception 'Yayın canlı değil.'; end if;
  select count(*) into n from oyun.tv_reklam where program_id = pr.id and durum = 'onay';
  if n = 0 then raise exception 'Bu programda onaylı reklam yok.'; end if;
  if pr.son_reklam_arasi is not null and pr.son_reklam_arasi > t - interval '8 minutes' then raise exception 'Reklam arası 8 dakikada bir verilebilir.'; end if;
  update oyun.tv_program set reklam_arasi = t + interval '40 seconds', son_reklam_arasi = t where id = pr.id;
  insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, p.id, 'sistem', format('Reklam arası · %s reklamveren · 40 saniye sonra kaldığımız yerden.', n), t);
  perform oyun.tv_sinyal(pr.id);
  return jsonb_build_object('tamam', true, 'bitis', t + interval '40 seconds');
end $$;

create or replace function public.tv_soz_iste(p_program bigint, p_ac boolean default true) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null or pr.durum <> 'canli' then raise exception 'Söz yalnız canlı yayında istenir.'; end if;
  if oyun.tv_konusmaci_mi(pr, p.id) then raise exception 'Zaten stüdyodasın.'; end if;
  if coalesce(p_ac, true) then perform oyun.yazabilir_mi(p, t); end if;
  insert into oyun.tv_izleyici(program_id, user_id, ilk, son, soz_iste) values (pr.id, p.id, t, t, case when coalesce(p_ac, true) then t end)
    on conflict (program_id, user_id) do update set soz_iste = case when coalesce(p_ac, true) then coalesce(oyun.tv_izleyici.soz_iste, t) end, son = t;
  if coalesce(p_ac, true) then
    perform oyun.bildir(pr.sunucu, format('%s "%s" yayınında canlı bağlantı için söz istiyor (Stüdyo › Reji).', p.kad, pr.baslik), t)
     where not exists (select 1 from oyun.bildirimler b where b.user_id = pr.sunucu and b.zaman > t - interval '3 minutes' and b.metin like '%canlı bağlantı için söz istiyor%');
  end if;
  return jsonb_build_object('tamam', true, 'istedim', coalesce(p_ac, true));
end $$;

create or replace function public.tv_soz_ver(p_program bigint, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; h oyun.profiller;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null or not oyun.tv_yonetici_mi(pr, p.id) then raise exception 'Yayına bağlantıyı sunucu ya da kanal sahibi alır.'; end if;
  if pr.durum <> 'canli' then raise exception 'Yayın canlı değil.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.id = pr.sunucu or h.yasakli then raise exception 'Bu oyuncu yayına alınamaz.'; end if;
  if oyun.engelli(h.id, p.id) then raise exception 'Bu oyuncu seni engellediği için yayına alınamaz.'; end if;
  if (select count(*) from oyun.tv_konuk where program_id = pr.id and durum <> 'ret' and user_id <> h.id) >= 6 then raise exception 'Stüdyo dolu: en çok 6 konuk.'; end if;
  select * into k from oyun.tv_kanal where id = pr.kanal_id;
  insert into oyun.tv_konuk(program_id, user_id, durum, zaman, baglanti) values (pr.id, h.id, 'kabul', t, true)
    on conflict (program_id, user_id) do update set durum = 'kabul', zaman = excluded.zaman, baglanti = true where oyun.tv_konuk.durum <> 'kabul';
  if not found then raise exception 'Bu oyuncu zaten stüdyoda.'; end if;
  update oyun.tv_izleyici set soz_iste = null where program_id = pr.id and user_id = h.id;
  insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, p.id, 'sistem', format('%s canlı bağlantıyla yayına katıldı.', h.kad), t);
  perform oyun.bildir(h.id, format('%s · "%s" yayınına canlı bağlandın; artık söz alabilirsin. Stüdyoya dön.', k.ad, pr.baslik), t);
  perform oyun.tv_sinyal(pr.id);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.tv_konuk_cikar(p_program bigint, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; h oyun.profiller;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  h := oyun.profil_bul(p_kad);
  if not (oyun.tv_yonetici_mi(pr, p.id) or h.id = p.id) then raise exception 'Konuğu sunucu ya da kanal sahibi yayından alır.'; end if;
  if pr.durum not in ('planli','canli') then raise exception 'Program bitti.'; end if;
  update oyun.tv_konuk set durum = 'ret', zaman = t where program_id = pr.id and user_id = h.id and durum in ('kabul','davet');
  if not found then raise exception 'Bu oyuncu programda değil.'; end if;
  if pr.durum = 'canli' then
    insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, p.id, 'sistem', format('%s stüdyodan ayrıldı.', h.kad), t);
  end if;
  perform oyun.tv_sinyal(pr.id);
  return jsonb_build_object('tamam', true);
end $$;

-- ---------------------------------------------------------------- takip, hatırlatma, seviye ve reyting
create or replace function public.tv_takip(p_kanal bigint, p_ac boolean default true) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if not exists (select 1 from oyun.tv_kanal where id = p_kanal and aktif) then raise exception 'Kanal bulunamadı.'; end if;
  if coalesce(p_ac, true) then
    if (select count(*) from oyun.tv_takip where user_id = p.id) >= 50 then raise exception 'En çok 50 kanal takip edebilirsin.'; end if;
    insert into oyun.tv_takip(kanal_id, user_id, zaman) values (p_kanal, p.id, t) on conflict do nothing;
  else
    delete from oyun.tv_takip where kanal_id = p_kanal and user_id = p.id;
  end if;
  return jsonb_build_object('takip', coalesce(p_ac, true), 'takipci', (select count(*) from oyun.tv_takip where kanal_id = p_kanal));
end $$;

create or replace function public.tv_hatirlat(p_program bigint, p_ac boolean default true) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  if coalesce(p_ac, true) then
    if pr.durum <> 'planli' then raise exception 'Hatırlatma yalnız başlamamış programa kurulur.'; end if;
    if (select count(*) from oyun.tv_hatirlat h join oyun.tv_program x on x.id = h.program_id and x.durum = 'planli' where h.user_id = p.id) >= 30 then
      raise exception 'En çok 30 programa hatırlatma kurabilirsin.'; end if;
    insert into oyun.tv_hatirlat(program_id, user_id, zaman) values (pr.id, p.id, t) on conflict do nothing;
  else
    delete from oyun.tv_hatirlat where program_id = pr.id and user_id = p.id;
  end if;
  return jsonb_build_object('hatirlat', coalesce(p_ac, true), 'sayi', (select count(*) from oyun.tv_hatirlat where program_id = pr.id));
end $$;

-- Ana ekran eki (tv_liste'ye dokunmadan): takip, hatırlatma, kanal seviyeleri, takipçi sayıları
create or replace function public.tv_liste_ek() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  return jsonb_build_object(
    'takip', (select coalesce(jsonb_agg(kanal_id), '[]'::jsonb) from oyun.tv_takip where user_id = p.id),
    'hatirlat', (select coalesce(jsonb_agg(h.program_id), '[]'::jsonb) from oyun.tv_hatirlat h join oyun.tv_program x on x.id = h.program_id and x.durum = 'planli' where h.user_id = p.id),
    'kanallar', (select coalesce(jsonb_object_agg(k.id::text, jsonb_build_object('takipci', (select count(*) from oyun.tv_takip f where f.kanal_id = k.id),
        'seviye', oyun.tv_seviye(k.id))), '{}'::jsonb) from oyun.tv_kanal k where k.aktif),
    'hatirlat_sayi', (select coalesce(jsonb_object_agg(q.program_id::text, q.n), '{}'::jsonb)
        from (select h.program_id, count(*) n from oyun.tv_hatirlat h join oyun.tv_program x on x.id = h.program_id and x.durum = 'planli' group by h.program_id) q));
end $$;

create or replace function public.tv_kanal_ek(p_kanal bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if not exists (select 1 from oyun.tv_kanal where id = p_kanal and aktif) then raise exception 'Kanal bulunamadı.'; end if;
  return jsonb_build_object('takip', exists (select 1 from oyun.tv_takip where kanal_id = p_kanal and user_id = p.id),
    'takipci', (select count(*) from oyun.tv_takip where kanal_id = p_kanal), 'seviye', oyun.tv_seviye(p_kanal),
    'hafta_izlenme', (select coalesce(sum(izleyici), 0) from oyun.tv_program where kanal_id = p_kanal and durum = 'bitti' and coalesce(gercek_bit, bit) > t - interval '7 days'),
    'hafta_sira', (select q.s from (select k.id, rank() over (order by coalesce(sum(x.izleyici), 0) desc) s from oyun.tv_kanal k
        left join oyun.tv_program x on x.kanal_id = k.id and x.durum = 'bitti' and coalesce(x.gercek_bit, x.bit) > t - interval '7 days' where k.aktif group by k.id) q where q.id = p_kanal),
    'rekor', (select jsonb_build_object('baslik', x.baslik, 'izleyici', x.izleyici, 'zirve', x.zirve) from oyun.tv_program x where x.kanal_id = p_kanal and x.durum = 'bitti' order by x.izleyici desc, x.zirve desc limit 1));
end $$;

create or replace function oyun.tv_reyting_hesap(p_bas timestamptz, p_bit timestamptz) returns jsonb language sql stable set search_path = '' as $$
  with pr as (select * from oyun.tv_program x where x.durum = 'bitti' and coalesce(x.gercek_bit, x.bit) >= p_bas and coalesce(x.gercek_bit, x.bit) < p_bit),
  duel as (select distinct on (o.program_id) o.program_id, o.konuk, count(*) oy from oyun.tv_oy o join pr on pr.id = o.program_id and pr.tur = 'duello'
             group by o.program_id, o.konuk order by o.program_id, count(*) desc, min(o.zaman))
  select jsonb_build_object(
    'program_sayi', (select count(*) from pr), 'izlenme', (select coalesce(sum(izleyici), 0) from pr),
    'programlar', (select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'baslik', q.baslik, 'kanal', k.ad, 'kanal_id', k.id, 'tur', q.tur, 'tur_ad', oyun.tv_tur_ad(q.tur),
        'sunucu', oyun.kad(q.sunucu), 'izleyici', q.izleyici, 'zirve', q.zirve, 'bas', q.bas) order by q.izleyici desc, q.zirve desc, q.id desc), '[]'::jsonb)
        from (select * from pr order by izleyici desc, zirve desc, id desc limit 10) q join oyun.tv_kanal k on k.id = q.kanal_id),
    'kanallar', (select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'ad', q.ad, 'izlenme', q.iz, 'program', q.n,
        'takipci', (select count(*) from oyun.tv_takip f where f.kanal_id = q.id), 'seviye', oyun.tv_seviye(q.id) ->> 'ad') order by q.iz desc, q.n desc), '[]'::jsonb)
        from (select k.id, k.ad, sum(pr.izleyici)::int iz, count(*) n from pr join oyun.tv_kanal k on k.id = pr.kanal_id group by k.id, k.ad order by sum(pr.izleyici) desc limit 10) q),
    'sunucular', (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(q.sunucu), 'izlenme', q.iz, 'program', q.n) order by q.iz desc), '[]'::jsonb)
        from (select sunucu, sum(izleyici)::int iz, count(*) n from pr group by sunucu order by sum(izleyici) desc limit 8) q),
    'duellocular', (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(q.konuk), 'galibiyet', q.g, 'oy', q.oy) order by q.g desc, q.oy desc), '[]'::jsonb)
        from (select konuk, count(*) g, sum(oy)::int oy from duel group by konuk order by count(*) desc, sum(oy) desc limit 5) q),
    'yarismacilar', (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(q.user_id), 'derece', q.d, 'birincilik', q.b, 'odul', q.o) order by q.b desc, q.d desc, q.o desc), '[]'::jsonb)
        from (select z.user_id, count(*) d, count(*) filter (where z.sira = 1) b, round(sum(z.tutar)) o from oyun.tv_odul_kazanc z join pr on pr.id = z.program_id
               group by z.user_id order by count(*) filter (where z.sira = 1) desc, count(*) desc limit 5) q))
$$;

create or replace function public.tv_reyting() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  perform oyun.tv_guncelle_hepsi();
  return oyun.tv_reyting_hesap(t - interval '7 days', t + interval '1 second')
    || jsonb_build_object('simdi', t, 'baz', oyun.tv_baz(),
       'gecen_hafta', (select jsonb_build_object('hafta', h.hafta, 'ozet', h.ozet) from oyun.tv_hafta h order by h.hafta desc limit 1));
end $$;

-- Her pazartesi: geçen haftanın reytinglerini haber yap, birinci kanalın sahibine bildir
create or replace function oyun.tv_hafta_kontrol() returns int language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); h date := date_trunc('week', t at time zone 'Europe/Istanbul')::date; bas timestamptz; o jsonb; k jsonb; pg jsonb;
begin
  if exists (select 1 from oyun.tv_hafta where hafta = h) then return 0; end if;
  bas := (h - 7)::timestamp at time zone 'Europe/Istanbul';
  o := oyun.tv_reyting_hesap(bas, h::timestamp at time zone 'Europe/Istanbul');
  insert into oyun.tv_hafta(hafta, zaman, ozet) values (h, t, o) on conflict do nothing;
  if not found or coalesce((o ->> 'program_sayi')::int, 0) = 0 then return 0; end if;
  k := o -> 'kanallar' -> 0; pg := o -> 'programlar' -> 0;
  perform oyun.olay('basin', format('Haftanın TV reytingleri: 1. %s (%s izlenme). En çok izlenen program "%s" (%s, %s izleyici). Haftada %s program, toplam %s izlenme.',
    k ->> 'ad', k ->> 'izlenme', pg ->> 'baslik', pg ->> 'kanal', pg ->> 'izleyici', o ->> 'program_sayi', o ->> 'izlenme'), null, null, t);
  perform oyun.bildir(kk.sahip, format('Tebrikler! %s geçen haftanın en çok izlenen kanalı oldu (%s izlenme).', kk.ad, k ->> 'izlenme'), t)
    from oyun.tv_kanal kk where kk.id = (k ->> 'id')::bigint;
  return 1;
end $$;

-- ---------------------------------------------------------------- yetkiler
revoke all on function oyun.tv_seviye(bigint), oyun.tv_yonetici_mi(oyun.tv_program, uuid), oyun.tv_konusmaci_mi(oyun.tv_program, uuid), oyun.tv_baz(),
  oyun.tv_anket_kapat_ic(bigint), oyun.tv_odul_dagit(bigint), oyun.tv_mesaj_json(oyun.tv_mesaj, uuid), oyun.tv_reyting_hesap(timestamptz, timestamptz),
  oyun.tv_hafta_kontrol(), oyun.tv_program_ozet(oyun.tv_program, timestamptz), oyun.tv_program_guncelle(bigint), oyun.tv_guncelle_hepsi(), oyun.tv_tur_ad(text)
  from public, anon, authenticated;
do $g$ declare f text; begin
  foreach f in array array['tv_canli(bigint,bigint,bigint)','tv_emoji(bigint,text)','tv_yorum_yaz(bigint,text,boolean)','tv_yorum_destek(bigint)',
    'tv_yorum_ekrana(bigint)','tv_yorum_gizle(bigint)','tv_anket_ac(bigint,text,text[],integer,integer)','tv_anket_oyla(bigint,integer)','tv_anket_kapat(bigint)',
    'tv_odul_koy(bigint,numeric)','tv_reklam_arasi(bigint)','tv_soz_iste(bigint,boolean)','tv_soz_ver(bigint,text)','tv_konuk_cikar(bigint,text)',
    'tv_takip(bigint,boolean)','tv_hatirlat(bigint,boolean)','tv_liste_ek()','tv_kanal_ek(bigint)','tv_reyting()',
    'tv_program_ac(bigint,text,text,text,timestamptz,integer,text)','tv_yaz(bigint,text)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $g$;

do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, sira, periyot_dk, ofset_dk, komut, aktif)
    values ('tv_haftalik', 84, 60, 7, 'select oyun.tv_hafta_kontrol()', true)
    on conflict (adim) do nothing;
  end if;
exception when others then raise notice 'tv_haftalik zamanlanamadı: %', sqlerrm;
end $z$;

-- Bu haftanın satırı kurulumda yazılır: ilk pazartesi duyurusu gerçekten geçen haftayı kapsasın (bugünden geriye haber üretmez)
insert into oyun.tv_hafta(hafta, zaman, ozet)
  values (date_trunc('week', oyun.simdi() at time zone 'Europe/Istanbul')::date, oyun.simdi(), '{"kurulum": true}'::jsonb) on conflict do nothing;

do $s$ begin if to_regprocedure('oyun.sonlu_kisit_kur()') is not null then perform oyun.sonlu_kisit_kur(); end if; end $s$;
