-- 2026-10-16 Siyaset Merkezi (gelistirici/sql/102_siyaset_merkezi.sql). Canlıya Claude tarafından uygulandı (siyaset_merkezi_a/b/c1/c2/d_20261016); tekrar çalıştırmak zararsızdır.
begin;
-- 16 Ekim 2026 · Siyaset Merkezi: oyuncuyu her hafta oyuna bağlayan siyasi ritim ve dram katmanı.
--  1) Haftalık siyasi takvim (Meclis/basın/grup/oylama/anket/saha/özet günleri) + hatırlatmalar
--  2) "Şu an seçim olsa" Meclis projeksiyonu (haftalık anketten, il il D'Hondt + ülke barajı)
--  3) Haftanın özeti (her pazar 20.00 otomatik)
--  4) Canlı yayınlar: basın toplantısı (gazeteciler soru sorar) ve tartışma programı (gazete sahibi moderatör)
--  5) Parti geçişleri (transfer) kaydı, bildirimi ve rozet takma töreni
--  6) Seçim sonrası balkon konuşması ve tebrik mesajları
--  7) Müşahitler (sandık görevlileri): atama, sandık başı, tutanak
--  8) Resmî günler ve bayram mesajları
--  9) Saha çalışması: seçim standı ve kapı kapı ziyaret
-- 10) Yol arkadaşı (yeni oyuncuya deneyimli oyuncu eşliği)
-- 11) Yeni rozetler: Kurucu Vatandaş, Sandık Görevlisi, Yol Arkadaşı
-- Oyuncu verisini değiştirmez; yalnızca yeni tablo, sütun ve fonksiyon ekler.

alter table oyun.ayarlar add column if not exists kurucu_rozet_bitis timestamptz default '2026-12-31 23:59:59+03';
alter table oyun.ayarlar add column if not exists mentor_odul numeric default 1000;
alter table oyun.ayarlar add column if not exists stant_bedel numeric default 2000;

create table if not exists oyun.parti_gecis(
  id bigserial primary key, user_id uuid not null, eski_parti bigint, yeni_parti bigint,
  zaman timestamptz not null, onemli boolean not null default false, makam text,
  rozet_takan uuid, rozet_at timestamptz, rozet_mesaj text);
create index if not exists parti_gecis_user on oyun.parti_gecis(user_id, zaman desc);
create index if not exists parti_gecis_zaman on oyun.parti_gecis(zaman desc);

create table if not exists oyun.canli_yayin(
  id bigserial primary key, tur text not null check (tur in ('basin','program')), sahibi uuid not null,
  gazete_id bigint, parti_id bigint, baslik text not null, bas timestamptz not null, bit timestamptz not null,
  olusturma timestamptz not null, iptal boolean not null default false, ozet_yazildi boolean not null default false,
  basladi_bildirildi boolean not null default false);
create index if not exists canli_yayin_bit on oyun.canli_yayin(bit desc);
create table if not exists oyun.canli_yayin_konuk(
  yayin_id bigint not null references oyun.canli_yayin(id), user_id uuid not null,
  durum text not null default 'davet' check (durum in ('davet','kabul','ret')), zaman timestamptz not null,
  primary key (yayin_id, user_id));
create table if not exists oyun.canli_yayin_mesaj(
  id bigserial primary key, yayin_id bigint not null references oyun.canli_yayin(id), user_id uuid not null,
  rol text not null, metin text not null, yanit_id bigint, zaman timestamptz not null, gizli boolean not null default false);
create index if not exists canli_yayin_mesaj_y on oyun.canli_yayin_mesaj(yayin_id, id);
create table if not exists oyun.canli_yayin_tepki(
  yayin_id bigint not null references oyun.canli_yayin(id), user_id uuid not null,
  tur text not null check (tur in ('alkis','yuh')), zaman timestamptz not null, primary key (yayin_id, user_id));
create table if not exists oyun.canli_yayin_oy(
  yayin_id bigint not null references oyun.canli_yayin(id), user_id uuid not null, konuk uuid not null,
  zaman timestamptz not null, primary key (yayin_id, user_id));

create table if not exists oyun.balkon(
  secim_id bigint not null, user_id uuid not null, metin text not null, zaman timestamptz not null,
  primary key (secim_id, user_id));
create table if not exists oyun.tebrik(
  secim_id bigint not null, gonderen uuid not null, alici uuid not null, metin text not null, zaman timestamptz not null,
  primary key (secim_id, gonderen));

create table if not exists oyun.musahit(
  secim_id bigint not null, il_id smallint not null, parti_id bigint not null, user_id uuid not null,
  atayan uuid not null, zaman timestamptz not null, sandik_at timestamptz,
  tutanak_tur text check (tutanak_tur in ('temiz','itiraz')), tutanak text, tutanak_at timestamptz,
  primary key (secim_id, il_id, parti_id));
create unique index if not exists musahit_kisi on oyun.musahit(secim_id, user_id);
-- Kaldırılan müşahit silinmez, iptal_at ile işaretlenir (geçmiş korunur).
alter table oyun.musahit add column if not exists iptal_at timestamptz;

create table if not exists oyun.resmi_gun(tarih date primary key, ad text not null, tur text not null default 'milli', aciklama text);
create table if not exists oyun.resmi_gun_mesaj(
  tarih date not null, user_id uuid not null, metin text not null, zaman timestamptz not null, unvan text,
  primary key (tarih, user_id));

create table if not exists oyun.stant(
  id bigserial primary key, parti_id bigint not null, il_id smallint not null, acan uuid not null,
  baslik text not null, bas timestamptz not null, bit timestamptz not null, bedel numeric not null default 0);
create index if not exists stant_il on oyun.stant(il_id, bit desc);
create table if not exists oyun.stant_ziyaret(
  id bigserial primary key, stant_id bigint not null references oyun.stant(id), user_id uuid not null,
  soru text, cevap text, cevaplayan uuid, zaman timestamptz not null, cevap_at timestamptz, unique (stant_id, user_id));
create table if not exists oyun.stant_gonullu(
  stant_id bigint not null references oyun.stant(id), user_id uuid not null, zaman timestamptz not null, primary key (stant_id, user_id));
create table if not exists oyun.kapi_ziyaret(
  id bigserial primary key, gonderen uuid not null, alici uuid not null, parti_id bigint not null, metin text not null, zaman timestamptz not null);
create index if not exists kapi_ziyaret_g on oyun.kapi_ziyaret(gonderen, zaman desc);
create index if not exists kapi_ziyaret_a on oyun.kapi_ziyaret(alici, zaman desc);

create table if not exists oyun.mentor_gonullu(user_id uuid primary key, tanitim text, aktif boolean not null default true, zaman timestamptz not null);
create table if not exists oyun.mentor_bag(
  acemi uuid primary key, mentor uuid not null, bas timestamptz not null, odul_at timestamptz, bitti_at timestamptz, neden text);
create index if not exists mentor_bag_m on oyun.mentor_bag(mentor);

create table if not exists oyun.haftanin_ozeti(hafta date primary key, veri jsonb not null, zaman timestamptz not null);
create table if not exists oyun.hafta_bildirim(anahtar text primary key, zaman timestamptz not null);

do $$ declare t text; begin
  foreach t in array array['parti_gecis','canli_yayin','canli_yayin_konuk','canli_yayin_mesaj','canli_yayin_tepki','canli_yayin_oy',
    'balkon','tebrik','musahit','resmi_gun','resmi_gun_mesaj','stant','stant_ziyaret','stant_gonullu','kapi_ziyaret',
    'mentor_gonullu','mentor_bag','haftanin_ozeti','hafta_bildirim'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
end $$;

-- ---------- Resmî günler (sabit milli günler 2026-2030, dini bayramlar Diyanet takvimiyle) ----------
insert into oyun.resmi_gun(tarih, ad, tur, aciklama)
select make_date(y, x.ay, x.gun), x.ad, x.tur, x.aciklama
from generate_series(2026, 2030) y,
  (values (10,29,'Cumhuriyet Bayramı','milli','Cumhuriyet''in ilanının yıl dönümü'),
          (11,10,'Atatürk''ü Anma Günü','anma','Gazi Mustafa Kemal Atatürk''ün ölüm yıl dönümü'),
          (3,18,'Çanakkale Zaferi ve Şehitleri Anma Günü','anma','Çanakkale Deniz Zaferi''nin yıl dönümü'),
          (4,23,'Ulusal Egemenlik ve Çocuk Bayramı','milli','TBMM''nin açılışının yıl dönümü'),
          (5,1,'Emek ve Dayanışma Günü','milli','İşçi bayramı'),
          (5,19,'Atatürk''ü Anma, Gençlik ve Spor Bayramı','milli','Kurtuluş Savaşı''nın başlangıcı'),
          (7,15,'Demokrasi ve Milli Birlik Günü','anma','15 Temmuz''un yıl dönümü'),
          (8,30,'Zafer Bayramı','milli','Büyük Taarruz zaferinin yıl dönümü')) x(ay, gun, ad, tur, aciklama)
where make_date(y, x.ay, x.gun) >= date '2026-10-16'
on conflict (tarih) do nothing;
insert into oyun.resmi_gun(tarih, ad, tur, aciklama) values
  (date '2027-03-09', 'Ramazan Bayramı', 'dini', 'Ramazan Bayramı''nın 1. günü'),
  (date '2027-05-16', 'Kurban Bayramı', 'dini', 'Kurban Bayramı''nın 1. günü')
on conflict (tarih) do nothing;

-- ---------- Yardımcılar ----------
create or replace function oyun.sm_gun(t timestamptz) returns date language sql stable as $$
  select (t at time zone 'Europe/Istanbul')::date $$;
create or replace function oyun.sm_hafta(t timestamptz) returns date language sql stable as $$
  select date_trunc('week', (t at time zone 'Europe/Istanbul'))::date $$;
-- Makamlı ya da parti yöneticisi mi? (basın toplantısı ve resmî gün mesajı için)
create or replace function oyun.sm_siyasetci(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.makamlar where user_id = u and bit is null)
      or exists (select 1 from oyun.partiler where gb = u and not kapali)
      or exists (select 1 from oyun.parti_gby where user_id = u)
      or exists (select 1 from oyun.parti_sozcu where user_id = u) $$;
create or replace function oyun.sm_gazeteci(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.oyuncu_gazeteleri where sahip = u and aktif)
      or exists (select 1 from oyun.gazete_yazarlar y join oyun.oyuncu_gazeteleri g on g.id = y.gazete_id and g.aktif
                 where y.user_id = u and y.aktif) $$;
create or replace function oyun.sm_kisi(u uuid) returns jsonb language sql stable as $$
  select case when p.id is null then null else jsonb_build_object('kad', p.kad, 'unvan', oyun.unvan(p.id), 'parti', oyun.parti_json(p.parti_id)) end
  from (select 1) d left join oyun.profiller p on p.id = u $$;
-- Bildirim + (tercih açıksa) telefona bildirim
create or replace function oyun.sm_haber(u uuid, p_metin text, p_baslik text, t timestamptz, p_push boolean default true) returns void
language plpgsql as $$
begin
  if u is null then return; end if;
  perform oyun.bildir(u, p_metin, t);
  if p_push then perform oyun.push_kisiye(u, 'kisisel', p_baslik, p_metin, '{"ekran":"bildirim"}'::jsonb); end if;
end $$;

-- ====================================================================
-- 1) HAFTALIK SİYASİ TAKVİM
-- ====================================================================
create or replace function oyun.sm_gun_tema(g int) returns jsonb language sql immutable as $$
  select (array[
    '{"gun":"Pazartesi","ad":"Meclis haftası","alt":"Yeni teklifler gündeme girer; milletvekilleri haftanın gündemini görür.","ekran":"meclis"}',
    '{"gun":"Salı","ad":"Basın günü","alt":"Makam sahipleri basın toplantısı düzenler, gazeteler tartışma programı yapar.","ekran":"yayin"}',
    '{"gun":"Çarşamba","ad":"Grup günü","alt":"Genel başkanlar Meclis grubuna seslenir; parti içi duyurular yapılır.","ekran":"parti"}',
    '{"gun":"Perşembe","ad":"Oylama günü","alt":"Meclis''te bekleyen tekliflere oy verilir.","ekran":"meclis"}',
    '{"gun":"Cuma","ad":"Anket günü","alt":"Haftalık anket ve \"Şu an seçim olsa\" Meclis tablosu.","ekran":"projeksiyon"}',
    '{"gun":"Cumartesi","ad":"Saha günü","alt":"Seçim standları, kapı kapı ziyaretler ve mitingler.","ekran":"saha"}',
    '{"gun":"Pazar","ad":"Haftanın özeti","alt":"Saat 20.00''de haftanın özeti yayımlanır.","ekran":"ozet"}'])[g]::jsonb $$;

create or replace function public.siyasi_hafta() returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); bugun date := oyun.sm_gun(t);
  h date := oyun.sm_hafta(t); bg int := extract(isodow from bugun)::int;
begin
  return jsonb_build_object('bugun', bugun, 'hafta', h, 'gun_no', bg,
    'gunler', (select jsonb_agg(oyun.sm_gun_tema(i) || jsonb_build_object('no', i, 'tarih', h + (i - 1), 'bugun', i = bg) order by i) from generate_series(1, 7) i),
    'sayilar', jsonb_build_object(
      'oylamada', (select count(*) from oyun.kanunlar where durum = 'oylamada'),
      'anket', (select count(*) from oyun.haftalik_anket_oy where hafta = h),
      'yayin', (select count(*) from oyun.canli_yayin where not iptal and oyun.sm_hafta(bas) = h),
      'stant', (select count(*) from oyun.stant where oyun.sm_hafta(bas) = h),
      'miting', (select count(*) from oyun.mitingler where oyun.sm_hafta(bas) = h),
      'transfer', (select count(*) from oyun.parti_gecis where onemli and oyun.sm_hafta(zaman) = h)),
    'resmi_gun', (select jsonb_build_object('ad', ad, 'tur', tur, 'aciklama', aciklama) from oyun.resmi_gun where tarih = bugun),
    'yaklasan_resmi', (select jsonb_build_object('tarih', tarih, 'ad', ad) from oyun.resmi_gun where tarih > bugun order by tarih limit 1),
    'son_ozet', (select hafta from oyun.haftanin_ozeti order by hafta desc limit 1));
end $$;

-- ====================================================================
-- 2) "ŞU AN SEÇİM OLSA" MECLİS PROJEKSİYONU
-- ====================================================================
create or replace function public.meclis_projeksiyon() returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h date := oyun.sm_hafta(t);
  toplam int; v_baraj numeric; sonuc jsonb; v_iller jsonb;
begin
  if (select count(*) from oyun.haftalik_anket_oy where hafta = h) < 10
     and exists (select 1 from oyun.haftalik_anket_oy where hafta = h - 7) then h := h - 7; end if;
  select count(*) into toplam from oyun.haftalik_anket_oy o join oyun.partiler pa on pa.id = o.parti_id and not pa.kapali where o.hafta = h;
  v_baraj := coalesce((select a.baraj from oyun.ayarlar a where a.id = 1), 7);
  if toplam = 0 then
    return jsonb_build_object('hafta', h, 'toplam', 0, 'baraj', v_baraj, 'partiler', '[]'::jsonb, 'iller', '[]'::jsonb,
      'uyari', 'Bu hafta henüz ankete katılan yok. Gündem''deki haftalık ankette oy ver; tablo kendiliğinden oluşur.');
  end if;
  with oy as (
    select o.parti_id, pr.il_id from oyun.haftalik_anket_oy o join oyun.profiller pr on pr.id = o.user_id
    join oyun.partiler pa on pa.id = o.parti_id and not pa.kapali where o.hafta = h),
  ulusal as (select parti_id, count(*) n from oy group by 1),
  gecen as (select parti_id, n from ulusal where 100.0 * n / toplam >= v_baraj),
  gecen2 as (select * from gecen union all select * from ulusal where not exists (select 1 from gecen)),
  il_oy as (select i.id il_id, i.mv, g.parti_id,
      coalesce((select count(*) from oy where oy.il_id = i.id and oy.parti_id = g.parti_id), 0)::numeric n,
      exists (select 1 from oy join gecen2 g2 on g2.parti_id = oy.parti_id where oy.il_id = i.id) dolu, g.n ulusal_n
    from oyun.iller i cross join gecen2 g),
  agirlik as (select il_id, mv, parti_id, case when dolu then n else ulusal_n end w from il_oy),
  bolum as (select a.il_id, a.parti_id, a.w / d q, row_number() over (partition by a.il_id order by a.w / d desc, a.parti_id) sira, a.mv
    from agirlik a cross join lateral generate_series(1, greatest(a.mv, 1)) d where a.w > 0),
  koltuk as (select il_id, parti_id, count(*) s from bolum where sira <= mv group by 1, 2)
  select
    (select coalesce(jsonb_agg(jsonb_build_object('parti', oyun.parti_json(u.parti_id), 'oy', u.n,
        'yuzde', round(100.0 * u.n / toplam, 1), 'baraj_ustu', 100.0 * u.n / toplam >= v_baraj,
        'sandalye', coalesce((select sum(s) from koltuk k where k.parti_id = u.parti_id), 0)) order by u.n desc), '[]'::jsonb) from ulusal u),
    (select coalesce(jsonb_agg(jsonb_build_object('il_id', i.id, 'il', i.ad, 'mv', i.mv,
        'birinci', oyun.parti_json((select k.parti_id from koltuk k where k.il_id = i.id order by k.s desc, k.parti_id limit 1)),
        'dagilim', (select coalesce(jsonb_agg(jsonb_build_object('kisa', pa.kisa, 'renk', pa.renk, 's', k.s) order by k.s desc), '[]'::jsonb)
                    from koltuk k join oyun.partiler pa on pa.id = k.parti_id where k.il_id = i.id),
        'anketci', (select count(*) from oy where oy.il_id = i.id)) order by i.ad), '[]'::jsonb) from oyun.iller i)
  into sonuc, v_iller;
  return jsonb_build_object('hafta', h, 'toplam', toplam, 'baraj', v_baraj, 'partiler', sonuc, 'iller', v_iller,
    'uyari', case when toplam < 30 then format('Yalnızca %s oyuncu katıldı; sonuçlar kesin değildir.', toplam) end,
    'aciklama', 'Haftalık ankete katılan oyuncuların yaşadıkları ile göre dağıtıldı: her ilin sandalyesi d''Hondt yöntemiyle, ülke barajını geçen partiler arasında paylaştırılır. Ankete kimsenin katılmadığı illerde ülke geneli oranlar kullanılır.');
end $$;

-- ====================================================================
-- 3) HAFTANIN ÖZETİ
-- ====================================================================
create or replace function oyun.haftanin_ozeti_hesapla(h date) returns jsonb
language sql stable as $$
  with r as (select oyun.tr_an(h, 0, 0) bas, oyun.tr_an(h + 7, 0, 0) bit)
  select jsonb_build_object('hafta', h,
    'kanunlar', (select jsonb_build_object('sayi', count(*), 'liste', coalesce(jsonb_agg(jsonb_build_object('no', k.no, 'baslik', k.baslik) order by k.no) filter (where k.no is not null), '[]'::jsonb))
                 from oyun.kanunlar k, r where k.no is not null and k.sonuc_at >= r.bas and k.sonuc_at < r.bit),
    'transferler', (select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad, 'eski', oyun.parti_json(g.eski_parti), 'yeni', oyun.parti_json(g.yeni_parti), 'makam', g.makam) order by g.zaman), '[]'::jsonb)
                    from oyun.parti_gecis g join oyun.profiller pr on pr.id = g.user_id, r where g.onemli and g.zaman >= r.bas and g.zaman < r.bit),
    'yeni_partiler', (select coalesce(jsonb_agg(oyun.parti_json(pa.id)), '[]'::jsonb) from oyun.partiler pa, r
                      where not pa.sistem and pa.kurulus >= r.bas and pa.kurulus < r.bit),
    'secimler', (select coalesce(jsonb_agg(jsonb_build_object('tur', s.tur, 'donem', s.donem, 'tarih', s.sonuc_at) order by s.sonuc_at), '[]'::jsonb)
                 from oyun.secimler s, r where s.durum = 'tamam' and s.sonuc_at >= r.bas and s.sonuc_at < r.bit and s.tur in ('mv','cb','cb2','bel','kurultay')),
    'miting', (select jsonb_build_object('sayi', (select count(*) from oyun.mitingler m where m.bas >= r.bas and m.bas < r.bit),
               'en_kalabalik', (select jsonb_build_object('kad', pr.kad, 'il', i.ad, 'kisi', count(c.*))
                 from oyun.mitingler m2 join oyun.profiller pr on pr.id = m2.user_id join oyun.iller i on i.id = m2.il_id
                 left join oyun.miting_katilim c on c.miting_id = m2.id where m2.bas >= r.bas and m2.bas < r.bit
                 group by m2.id, pr.kad, i.ad order by count(c.*) desc, m2.id limit 1)) from r),
    'anket', (select coalesce(jsonb_agg(jsonb_build_object('parti', oyun.parti_json(x.parti_id), 'oy', x.n) order by x.n desc), '[]'::jsonb)
              from (select parti_id, count(*) n from oyun.haftalik_anket_oy where hafta = h group by 1 order by 2 desc limit 5) x),
    'one_cikan', (select jsonb_build_object('kad', pr.kad, 'metin', left(a.metin, 200), 'begeni', b.n)
                  from (select akis_id, count(*) n from oyun.akis_begeni group by 1) b join oyun.akis a on a.id = b.akis_id
                  join oyun.profiller pr on pr.id = a.user_id, r where a.zaman >= r.bas and a.zaman < r.bit and not a.gizli and a.yanit_id is null
                  order by b.n desc, a.id limit 1),
    'yayinlar', (select jsonb_build_object('sayi', count(*), 'basin', count(*) filter (where tur = 'basin'), 'program', count(*) filter (where tur = 'program'))
                 from oyun.canli_yayin c, r where not c.iptal and c.bas >= r.bas and c.bas < r.bit),
    'saha', (select jsonb_build_object('stant', (select count(*) from oyun.stant s where s.bas >= r.bas and s.bas < r.bit),
               'kapi', (select count(*) from oyun.kapi_ziyaret k where k.zaman >= r.bas and k.zaman < r.bit)) from r),
    'yeni_oyuncu', (select count(*) from oyun.profiller pr, r where pr.olusturma >= r.bas and pr.olusturma < r.bit))
$$;

create or replace function public.haftanin_ozeti(p_hafta date default null) returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); h date := coalesce(p_hafta, oyun.sm_hafta(oyun.simdi())); v jsonb;
begin
  select veri into v from oyun.haftanin_ozeti where hafta = h;
  return jsonb_build_object('hafta', h, 'kesin', v is not null, 'veri', coalesce(v, oyun.haftanin_ozeti_hesapla(h)),
    'arsiv', (select coalesce(jsonb_agg(hafta order by hafta desc), '[]'::jsonb) from (select hafta from oyun.haftanin_ozeti order by hafta desc limit 12) x));
end $$;

-- ====================================================================
-- 4) CANLI YAYINLAR: BASIN TOPLANTISI VE TARTIŞMA PROGRAMI
-- ====================================================================
create or replace function oyun.canli_yayin_json(c oyun.canli_yayin, ben uuid, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_build_object('id', c.id, 'tur', c.tur, 'baslik', c.baslik, 'bas', c.bas, 'bit', c.bit, 'iptal', c.iptal,
    'durum', case when c.iptal then 'iptal' when t < c.bas then 'yakinda' when t < c.bit then 'canli' else 'bitti' end,
    'sahibi', oyun.sm_kisi(c.sahibi), 'benim', c.sahibi = ben,
    'gazete', (select jsonb_build_object('id', g.id, 'ad', g.ad) from oyun.oyuncu_gazeteleri g where g.id = c.gazete_id),
    'konuklar', (select coalesce(jsonb_agg(oyun.sm_kisi(k.user_id) || jsonb_build_object('durum', k.durum,
        'oy', (select count(*) from oyun.canli_yayin_oy o where o.yayin_id = c.id and o.konuk = k.user_id)) order by k.zaman), '[]'::jsonb)
      from oyun.canli_yayin_konuk k where k.yayin_id = c.id),
    'mesaj', (select count(*) from oyun.canli_yayin_mesaj m where m.yayin_id = c.id and not m.gizli),
    'alkis', (select count(*) from oyun.canli_yayin_tepki x where x.yayin_id = c.id and x.tur = 'alkis'),
    'yuh', (select count(*) from oyun.canli_yayin_tepki x where x.yayin_id = c.id and x.tur = 'yuh'))
$$;

create or replace function public.canli_yayin_ac(p_tur text, p_baslik text, p_bas timestamptz default null, p_gazete bigint default null) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b text; g oyun.oyuncu_gazeteleri; c oyun.canli_yayin; v_bas timestamptz; u uuid;
begin
  perform oyun.yazabilir_mi(p, t);
  b := oyun.metin_temizle(p_baslik, 90);
  if p_tur = 'basin' then
    if not oyun.sm_siyasetci(p.id) then raise exception 'Basın toplantısını makam sahipleri, genel başkanlar, genel başkan yardımcıları ve parti sözcüleri düzenler.'; end if;
    if exists (select 1 from oyun.canli_yayin where sahibi = p.id and tur = 'basin' and not iptal and oyun.sm_gun(bas) = oyun.sm_gun(t)) then
      raise exception 'Bugün zaten bir basın toplantısı düzenledin; yarın yeniden yapabilirsin.'; end if;
    insert into oyun.canli_yayin(tur, sahibi, parti_id, baslik, bas, bit, olusturma, basladi_bildirildi)
      values ('basin', p.id, p.parti_id, b, t, t + interval '30 minutes', t, true) returning * into c;
    -- Gazetecilere ve parti üyelerine haber ver
    for u in select distinct x from (select sahip x from oyun.oyuncu_gazeteleri where aktif
             union select y.user_id from oyun.gazete_yazarlar y join oyun.oyuncu_gazeteleri g2 on g2.id = y.gazete_id and g2.aktif where y.aktif) z where x <> p.id loop
      perform oyun.sm_haber(u, format('%s basın toplantısı düzenliyor: "%s". Gazeteci olarak 30 dakika içinde soru sorabilirsin.', p.kad, b), 'Basın toplantısı başladı', t);
    end loop;
    if p.parti_id is not null then
      insert into oyun.bildirimler(user_id, zaman, metin)
        select id, t, format('%s basın toplantısında: "%s". Canlı izle, tepki ver.', p.kad, b) from oyun.profiller
        where parti_id = p.parti_id and id <> p.id and not yasakli and not oyun.sm_gazeteci(id);
    end if;
    perform oyun.olay('basin', format('%s basın toplantısı düzenliyor: "%s"', p.kad, b), null, p.parti_id, t);
  elsif p_tur = 'program' then
    select * into g from oyun.oyuncu_gazeteleri where sahip = p.id and aktif and (p_gazete is null or id = p_gazete) order by id limit 1;
    if g.id is null then raise exception 'Tartışma programını yalnızca bir gazetenin sahibi açabilir. Önce Gündem › Gazeteler''den gazete kur.'; end if;
    v_bas := coalesce(p_bas, t + interval '15 minutes');
    if v_bas < t - interval '1 minute' or v_bas > t + interval '48 hours' then raise exception 'Program şimdi ile 48 saat sonrası arasında başlamalı.'; end if;
    if exists (select 1 from oyun.canli_yayin x where x.gazete_id = g.id and not x.iptal and oyun.sm_gun(x.bas) = oyun.sm_gun(v_bas)) then
      raise exception 'Gazeten o gün için zaten bir program yaptı.'; end if;
    if exists (select 1 from oyun.canli_yayin x where x.gazete_id = g.id and not x.iptal and x.bit > t) then
      raise exception 'Gazetenin henüz bitmemiş bir programı var.'; end if;
    insert into oyun.canli_yayin(tur, sahibi, gazete_id, parti_id, baslik, bas, bit, olusturma)
      values ('program', p.id, g.id, p.parti_id, b, greatest(v_bas, t), greatest(v_bas, t) + interval '45 minutes', t) returning * into c;
    perform oyun.olay('basin', format('%s gazetesinde tartışma programı: "%s" (%s)', g.ad, b,
      to_char(c.bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), null, null, t);
  else
    raise exception 'Geçersiz yayın türü.';
  end if;
  return oyun.canli_yayin_json(c, p.id, t);
end $$;

create or replace function public.canli_yayin_davet(p_yayin bigint, p_kad text) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.canli_yayin; h oyun.profiller;
begin
  select * into c from oyun.canli_yayin where id = p_yayin for update;
  if c.id is null or c.sahibi <> p.id or c.tur <> 'program' then raise exception 'Yalnızca kendi programına konuk davet edebilirsin.'; end if;
  if c.iptal or c.bit <= t then raise exception 'Program bitti.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.id = p.id or h.yasakli then raise exception 'Bu oyuncu davet edilemez.'; end if;
  if oyun.engelli(h.id, p.id) then raise exception 'Bu oyuncu seni engellediği için davet edilemez.'; end if;
  if (select count(*) from oyun.canli_yayin_konuk where yayin_id = c.id and durum <> 'ret') >= 4 then raise exception 'Programa en fazla 4 konuk çağrılabilir.'; end if;
  insert into oyun.canli_yayin_konuk(yayin_id, user_id, durum, zaman) values (c.id, h.id, 'davet', t)
    on conflict (yayin_id, user_id) do nothing;
  if not found then raise exception 'Bu oyuncu zaten davet edildi.'; end if;
  perform oyun.sm_haber(h.id, format('%s seni "%s" tartışma programına konuk olarak çağırdı (%s). Siyaset Merkezi › Canlı yayınlar''dan yanıtla.',
    p.kad, c.baslik, to_char(c.bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), 'Programa davet edildin', t);
  return oyun.canli_yayin_json(c, p.id, t);
end $$;

create or replace function public.canli_yayin_davet_yanit(p_yayin bigint, p_kabul boolean) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.canli_yayin;
begin
  select * into c from oyun.canli_yayin where id = p_yayin;
  if c.id is null or c.iptal or c.bit <= t then raise exception 'Program bulunamadı ya da bitti.'; end if;
  update oyun.canli_yayin_konuk set durum = case when p_kabul then 'kabul' else 'ret' end, zaman = t
    where yayin_id = c.id and user_id = p.id and durum = 'davet';
  if not found then raise exception 'Bekleyen bir davetin yok.'; end if;
  perform oyun.bildir(c.sahibi, format('%s, "%s" programına davetini %s.', p.kad, c.baslik, case when p_kabul then 'kabul etti' else 'reddetti' end), t);
  return oyun.canli_yayin_json(c, p.id, t);
end $$;

create or replace function public.canli_yayin_yaz(p_yayin bigint, p_metin text, p_yanit bigint default null) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.canli_yayin; m text; r text; i bigint; y oyun.canli_yayin_mesaj;
begin
  select * into c from oyun.canli_yayin where id = p_yayin;
  if c.id is null or c.iptal then raise exception 'Yayın bulunamadı.'; end if;
  if t < c.bas then raise exception 'Yayın henüz başlamadı.'; end if;
  if t >= c.bit then raise exception 'Yayın sona erdi.'; end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 400);
  if p.id = c.sahibi then r := case when c.tur = 'basin' then 'konusmaci' else 'moderator' end;
  elsif c.tur = 'program' and exists (select 1 from oyun.canli_yayin_konuk where yayin_id = c.id and user_id = p.id and durum = 'kabul') then r := 'konuk';
  elsif c.tur = 'basin' and oyun.sm_gazeteci(p.id) then
    r := 'soru';
    if (select count(*) from oyun.canli_yayin_mesaj where yayin_id = c.id and user_id = p.id) >= 2 then
      raise exception 'Bir basın toplantısında en fazla 2 soru sorabilirsin.'; end if;
  else
    raise exception '%', case when c.tur = 'basin' then 'Basın toplantısında yalnızca gazeteciler (gazete sahibi ya da yazarı) soru sorabilir. Sen tepki verebilirsin.'
                              else 'Programda yalnızca moderatör ve konuklar konuşur. Sen tepki verip oy kullanabilirsin.' end;
  end if;
  if p_yanit is not null then
    select * into y from oyun.canli_yayin_mesaj where id = p_yanit and yayin_id = c.id;
    if y.id is null then p_yanit := null; end if;
  end if;
  insert into oyun.canli_yayin_mesaj(yayin_id, user_id, rol, metin, yanit_id, zaman) values (c.id, p.id, r, m, p_yanit, t) returning id into i;
  update oyun.profiller set son_mesaj = t where id = p.id;
  if r = 'soru' then perform oyun.bildir(c.sahibi, format('%s basın toplantında soru sordu: "%s"', p.kad, left(m, 120)), t); end if;
  return jsonb_build_object('tamam', true, 'id', i);
end $$;

create or replace function public.canli_yayin_tepki(p_yayin bigint, p_tur text) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.canli_yayin;
begin
  if p_tur not in ('alkis','yuh') then raise exception 'Geçersiz tepki.'; end if;
  select * into c from oyun.canli_yayin where id = p_yayin;
  if c.id is null or c.iptal or t < c.bas or t >= c.bit + interval '15 minutes' then raise exception 'Bu yayına şu an tepki verilemez.'; end if;
  if c.sahibi = p.id then raise exception 'Kendi yayınına tepki veremezsin.'; end if;
  insert into oyun.canli_yayin_tepki(yayin_id, user_id, tur, zaman) values (c.id, p.id, p_tur, t)
    on conflict (yayin_id, user_id) do update set tur = excluded.tur, zaman = excluded.zaman;
  return oyun.canli_yayin_json(c, p.id, t);
end $$;

create or replace function public.canli_yayin_oyla(p_yayin bigint, p_kad text) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.canli_yayin; h oyun.profiller;
begin
  select * into c from oyun.canli_yayin where id = p_yayin;
  if c.id is null or c.tur <> 'program' or c.iptal then raise exception 'Oylama yalnızca tartışma programlarında yapılır.'; end if;
  if t < c.bas or t >= c.bit + interval '15 minutes' then raise exception 'Oylama, program sürerken ve bittikten sonraki 15 dakika içinde yapılır.'; end if;
  if c.sahibi = p.id or exists (select 1 from oyun.canli_yayin_konuk where yayin_id = c.id and user_id = p.id and durum = 'kabul') then
    raise exception 'Moderatör ve konuklar oy kullanamaz.'; end if;
  h := oyun.profil_bul(p_kad);
  if not exists (select 1 from oyun.canli_yayin_konuk where yayin_id = c.id and user_id = h.id and durum = 'kabul') then raise exception 'Bu oyuncu programın konuğu değil.'; end if;
  insert into oyun.canli_yayin_oy(yayin_id, user_id, konuk, zaman) values (c.id, p.id, h.id, t)
    on conflict (yayin_id, user_id) do update set konuk = excluded.konuk, zaman = excluded.zaman;
  return oyun.canli_yayin_json(c, p.id, t);
end $$;

create or replace function public.canli_yayin_bitir(p_yayin bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.canli_yayin;
begin
  select * into c from oyun.canli_yayin where id = p_yayin for update;
  if c.id is null or c.sahibi <> p.id then raise exception 'Yalnızca yayının sahibi bitirebilir.'; end if;
  if c.iptal or c.bit <= t then raise exception 'Yayın zaten bitti.'; end if;
  if t < c.bas then
    update oyun.canli_yayin set iptal = true, bit = t where id = c.id returning * into c;
    perform oyun.bildir(k.user_id, format('"%s" programı iptal edildi.', c.baslik), t) from oyun.canli_yayin_konuk k where k.yayin_id = c.id;
  else
    update oyun.canli_yayin set bit = t where id = c.id returning * into c;
  end if;
  return oyun.canli_yayin_json(c, p.id, t);
end $$;

create or replace function public.canli_yayinlar() returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'canli', (select coalesce(jsonb_agg(oyun.canli_yayin_json(c, p.id, t) order by c.bas), '[]'::jsonb) from oyun.canli_yayin c where not c.iptal and c.bas <= t and c.bit > t),
    'yakinda', (select coalesce(jsonb_agg(oyun.canli_yayin_json(c, p.id, t) order by c.bas), '[]'::jsonb) from oyun.canli_yayin c where not c.iptal and c.bas > t),
    'biten', (select coalesce(jsonb_agg(x order by (x->>'bit') desc), '[]'::jsonb) from (select oyun.canli_yayin_json(c, p.id, t) x from oyun.canli_yayin c
              where not c.iptal and c.bit <= t order by c.bit desc limit 15) y),
    'davetlerim', (select coalesce(jsonb_agg(oyun.canli_yayin_json(c, p.id, t)), '[]'::jsonb) from oyun.canli_yayin c
                   join oyun.canli_yayin_konuk k on k.yayin_id = c.id and k.user_id = p.id and k.durum = 'davet' where not c.iptal and c.bit > t),
    'basin_hakki', oyun.sm_siyasetci(p.id), 'gazeteci', oyun.sm_gazeteci(p.id),
    'gazetelerim', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'ad', ad) order by id), '[]'::jsonb) from oyun.oyuncu_gazeteleri where sahip = p.id and aktif));
end $$;

create or replace function public.canli_yayin_detay(p_yayin bigint, p_son_id bigint default 0) returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.canli_yayin;
begin
  select * into c from oyun.canli_yayin where id = p_yayin;
  if c.id is null then raise exception 'Yayın bulunamadı.'; end if;
  return oyun.canli_yayin_json(c, p.id, t) || jsonb_build_object(
    'mesajlar', (select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'rol', m.rol, 'metin', m.metin, 'yanit_id', m.yanit_id, 'zaman', m.zaman,
        'kisi', oyun.sm_kisi(m.user_id), 'benim', m.user_id = p.id) order by m.id), '[]'::jsonb)
      from (select * from oyun.canli_yayin_mesaj where yayin_id = c.id and not gizli and id > coalesce(p_son_id, 0) order by id limit 300) m),
    'tepkim', (select tur from oyun.canli_yayin_tepki where yayin_id = c.id and user_id = p.id),
    'oyum', (select oyun.kad(konuk) from oyun.canli_yayin_oy where yayin_id = c.id and user_id = p.id),
    'rolum', case when c.sahibi = p.id then 'sahip'
                  when exists (select 1 from oyun.canli_yayin_konuk where yayin_id = c.id and user_id = p.id and durum = 'kabul') then 'konuk'
                  when exists (select 1 from oyun.canli_yayin_konuk where yayin_id = c.id and user_id = p.id and durum = 'davet') then 'davetli'
                  when c.tur = 'basin' and oyun.sm_gazeteci(p.id) then 'gazeteci' else 'izleyici' end,
    'sorum', (select count(*) from oyun.canli_yayin_mesaj where yayin_id = c.id and user_id = p.id), 'simdi', t);
end $$;

-- ====================================================================
-- 5) PARTİ GEÇİŞLERİ VE ROZET TAKMA
-- ====================================================================
create or replace function oyun.parti_gecis_tg() returns trigger language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare t timestamptz := oyun.simdi(); mk text; onemli boolean; eski oyun.partiler; yeni oyun.partiler; ayni int;
begin
  if new.parti_id is not distinct from old.parti_id then return new; end if;
  select string_agg(oyun.makam_ad(tur, il_id, bakanlik), ', ') into mk from oyun.makamlar where user_id = new.id and bit is null;
  onemli := mk is not null or oyun.kidem_puani(new.id) >= 60;
  select * into eski from oyun.partiler where id = old.parti_id;
  select * into yeni from oyun.partiler where id = new.parti_id;
  -- Toplu geçişler (parti kapanması, birleşme) duyuru yağmuruna dönmesin
  select count(*) into ayni from oyun.parti_gecis where eski_parti = old.parti_id and zaman = t;
  if coalesce(eski.kapali, false) or ayni >= 3 then onemli := false; end if;
  insert into oyun.parti_gecis(user_id, eski_parti, yeni_parti, zaman, onemli, makam) values (new.id, old.parti_id, new.parti_id, t, onemli, mk);
  if onemli then
    if yeni.id is not null and eski.id is not null then
      perform oyun.olay('parti', format('Transfer: %s%s, %s partisinden ayrılıp %s partisine katıldı.', new.kad, coalesce(' (' || mk || ')', ''), eski.ad, yeni.ad), null, yeni.id, t);
    elsif yeni.id is not null then
      perform oyun.olay('parti', format('%s%s, %s partisine katıldı.', new.kad, coalesce(' (' || mk || ')', ''), yeni.ad), null, yeni.id, t);
    elsif eski.id is not null then
      perform oyun.olay('parti', format('%s%s, %s partisinden istifa etti.', new.kad, coalesce(' (' || mk || ')', ''), eski.ad), null, eski.id, t);
    end if;
    if yeni.id is not null then
      insert into oyun.bildirimler(user_id, zaman, metin)
        select id, t, format('%s partimize katıldı%s. %s', new.kad, coalesce(' (' || mk || ')', ''),
          case when id = yeni.gb then 'Genel başkan olarak rozetini takabilirsin: Siyaset Merkezi › Transferler.' else 'Hoş geldin demeyi unutma.' end)
        from oyun.profiller where parti_id = yeni.id and id <> new.id and not yasakli;
    end if;
    if eski.id is not null then
      insert into oyun.bildirimler(user_id, zaman, metin)
        select id, t, format('%s partimizden ayrıldı%s.', new.kad, coalesce(' (' || mk || ')', ''))
        from oyun.profiller where parti_id = eski.id and id <> new.id and not yasakli;
    end if;
  end if;
  return new;
end $$;
create or replace trigger parti_gecis_tg after update of parti_id on oyun.profiller for each row execute function oyun.parti_gecis_tg();

create or replace function public.parti_gecisleri(p_limit int default 30) returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return coalesce((select jsonb_agg(x order by (x->>'zaman') desc) from (
    select jsonb_build_object('id', g.id, 'kad', pr.kad, 'unvan', oyun.unvan(pr.id), 'makam', g.makam, 'zaman', g.zaman,
      'eski', oyun.parti_json(g.eski_parti), 'yeni', oyun.parti_json(g.yeni_parti), 'rozet_at', g.rozet_at,
      'rozet_takan', oyun.kad(g.rozet_takan), 'rozet_mesaj', g.rozet_mesaj,
      'rozet_takabilirim', g.rozet_at is null and g.yeni_parti is not null and g.zaman > t - interval '72 hours' and pr.parti_id = g.yeni_parti
        and g.user_id <> p.id and (exists (select 1 from oyun.partiler where id = g.yeni_parti and gb = p.id)
          or exists (select 1 from oyun.parti_gby where parti_id = g.yeni_parti and user_id = p.id))) x
    from oyun.parti_gecis g join oyun.profiller pr on pr.id = g.user_id
    where g.onemli order by g.zaman desc limit least(greatest(coalesce(p_limit, 30), 1), 100)) y), '[]'::jsonb);
end $$;

create or replace function public.rozet_tak(p_gecis bigint, p_mesaj text default null) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); g oyun.parti_gecis; h oyun.profiller; pa oyun.partiler; m text; metin text;
begin
  select * into g from oyun.parti_gecis where id = p_gecis for update;
  if g.id is null or g.yeni_parti is null then raise exception 'Geçiş bulunamadı.'; end if;
  select * into pa from oyun.partiler where id = g.yeni_parti;
  if not (pa.gb = p.id or exists (select 1 from oyun.parti_gby where parti_id = pa.id and user_id = p.id)) then
    raise exception 'Rozeti genel başkan ya da genel başkan yardımcıları takar.'; end if;
  if g.rozet_at is not null then raise exception 'Rozet zaten takıldı.'; end if;
  if g.zaman < t - interval '72 hours' then raise exception 'Rozet töreni katılımdan sonraki 72 saat içinde yapılır.'; end if;
  select * into h from oyun.profiller where id = g.user_id;
  if h.parti_id is distinct from pa.id then raise exception 'Bu oyuncu artık partinde değil.'; end if;
  if nullif(btrim(coalesce(p_mesaj, '')), '') is not null then m := oyun.metin_temizle(p_mesaj, 200); end if;
  update oyun.parti_gecis set rozet_takan = p.id, rozet_at = t, rozet_mesaj = m where id = g.id;
  metin := left(format('Rozetini taktık: %s artık %s ailesinin bir parçası. Hoş geldin!%s', h.kad, pa.ad, coalesce(' ' || m, '')), 280);
  insert into oyun.akis(user_id, metin, zaman, il_id, parti_id) values (p.id, metin, t, p.il_id, p.parti_id);
  perform oyun.sm_haber(h.id, format('%s sana %s rozetini taktı.%s', p.kad, pa.ad, coalesce(' "' || m || '"', '')), 'Rozetin takıldı', t);
  perform oyun.olay('parti', format('Rozet töreni: %s, %s''e %s rozetini taktı.', p.kad, h.kad, pa.ad), null, pa.id, t);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.oyuncu_parti_gecmisi(p_kad text) returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller := oyun.profil_bul(p_kad);
begin
  return coalesce((select jsonb_agg(jsonb_build_object('zaman', g.zaman, 'eski', oyun.parti_json(g.eski_parti), 'yeni', oyun.parti_json(g.yeni_parti),
      'rozet', g.rozet_at is not null) order by g.zaman desc) from (select * from oyun.parti_gecis where user_id = h.id order by zaman desc limit 20) g), '[]'::jsonb);
end $$;

-- ====================================================================
-- 6) BALKON KONUŞMASI VE TEBRİK
-- ====================================================================
create or replace function oyun.balkon_kazanan(s oyun.secimler) returns uuid language sql stable as $$
  select case when s.tur in ('cb','cb2') then (select user_id from oyun.kazananlar where secim_id = s.id limit 1)
              when s.tur = 'mv' then (select pa.gb from jsonb_array_elements(coalesce(s.sonuc -> 'ulusal', '[]'::jsonb)) x
                                       join oyun.partiler pa on pa.id = (x ->> 'parti_id')::bigint
                                       where coalesce((x ->> 'sandalye')::int, 0) > 0 order by (x ->> 'sandalye')::int desc limit 1) end $$;

create or replace function public.balkon_durum() returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return coalesce((select jsonb_agg(x order by (x->>'sonuc_at') desc) from (
    select jsonb_build_object('secim_id', s.id, 'tur', s.tur, 'donem', s.donem, 'sonuc_at', s.sonuc_at,
      'kazanan', oyun.sm_kisi(k.u), 'benim', k.u = p.id,
      'konusma', (select jsonb_build_object('metin', b.metin, 'zaman', b.zaman) from oyun.balkon b where b.secim_id = s.id and b.user_id = k.u),
      'tebrikler', (select coalesce(jsonb_agg(oyun.sm_kisi(tb.gonderen) || jsonb_build_object('metin', tb.metin, 'zaman', tb.zaman) order by tb.zaman), '[]'::jsonb)
                    from oyun.tebrik tb where tb.secim_id = s.id),
      'tebrik_edebilirim', k.u <> p.id and not exists (select 1 from oyun.tebrik where secim_id = s.id and gonderen = p.id)
        and (exists (select 1 from oyun.partiler where gb = p.id and not kapali and id is distinct from (select parti_id from oyun.profiller where id = k.u))
             or exists (select 1 from oyun.adaylar where secim_id = s.id and user_id = p.id))) x
    from oyun.secimler s cross join lateral (select oyun.balkon_kazanan(s) u) k
    where s.tur in ('mv','cb','cb2') and s.durum = 'tamam' and s.sonuc_at > t - interval '48 hours' and k.u is not null) y), '[]'::jsonb);
end $$;

create or replace function public.balkon_konus(p_secim bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; m text;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.tur not in ('mv','cb','cb2') or s.durum <> 'tamam' then raise exception 'Bu seçim için balkon konuşması yapılamaz.'; end if;
  if s.sonuc_at < t - interval '48 hours' then raise exception 'Balkon konuşması sonuçlardan sonraki 48 saat içinde yapılır.'; end if;
  if oyun.balkon_kazanan(s) is distinct from p.id then raise exception 'Balkon konuşmasını seçimi kazanan yapar.'; end if;
  m := oyun.metin_temizle(p_metin, 1200);
  insert into oyun.balkon(secim_id, user_id, metin, zaman) values (s.id, p.id, m, t) on conflict do nothing;
  if not found then raise exception 'Balkon konuşmanı zaten yaptın.'; end if;
  perform oyun.olay('secim', format('Balkon konuşması · %s: "%s"', p.kad, left(m, 160)), null, p.parti_id, t);
  perform oyun.push_konuya('s_tum', null, 'Balkon konuşması: ' || p.kad, left(m, 170), jsonb_build_object('ekran', 'secim', 'id', s.id));
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.tebrik_et(p_secim bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; k uuid; m text;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.tur not in ('mv','cb','cb2') or s.durum <> 'tamam' or s.sonuc_at < t - interval '48 hours' then raise exception 'Bu seçim için tebrik süresi geçti.'; end if;
  k := oyun.balkon_kazanan(s);
  if k is null or k = p.id then raise exception 'Kendini tebrik edemezsin.'; end if;
  if not (exists (select 1 from oyun.partiler where gb = p.id and not kapali and id is distinct from (select parti_id from oyun.profiller where id = k))
          or exists (select 1 from oyun.adaylar where secim_id = s.id and user_id = p.id)) then
    raise exception 'Tebrik mesajını rakip partilerin genel başkanları ve seçimin adayları gönderir.'; end if;
  m := oyun.metin_temizle(p_metin, 300);
  insert into oyun.tebrik(secim_id, gonderen, alici, metin, zaman) values (s.id, p.id, k, m, t) on conflict do nothing;
  if not found then raise exception 'Bu seçim için zaten tebrik ettin.'; end if;
  perform oyun.sm_haber(k, format('%s seni tebrik etti: "%s"', p.kad, left(m, 140)), 'Tebrik mesajı', t);
  perform oyun.olay('secim', format('%s, %s''i seçim zaferi için tebrik etti.', p.kad, oyun.kad(k)), null, p.parti_id, t);
  return jsonb_build_object('tamam', true);
end $$;

-- ====================================================================
-- 7) MÜŞAHİTLER
-- ====================================================================
create or replace function public.musahit_paneli() returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); yonetici boolean;
begin
  yonetici := p.parti_id is not null and oyun.teskilat_yonetici(p.id, p.parti_id);
  return jsonb_build_object('yonetici', yonetici, 'parti', oyun.parti_json(p.parti_id),
    'secimler', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'tur', s.tur, 'donem', s.donem, 'oy_bas', s.oy_bas, 'oy_bit', s.oy_bit,
        'durum', s.durum, 'sonuc_at', s.sonuc_at,
        'atananlar', case when p.parti_id is null then '[]'::jsonb else (select coalesce(jsonb_agg(jsonb_build_object('il_id', m.il_id, 'il', i.ad, 'kad', oyun.kad(m.user_id),
            'sandik', m.sandik_at is not null, 'tutanak', m.tutanak_tur, 'not', m.tutanak) order by i.ad), '[]'::jsonb)
          from oyun.musahit m join oyun.iller i on i.id = m.il_id where m.secim_id = s.id and m.parti_id = p.parti_id and m.iptal_at is null) end,
        'kapsama', (select coalesce(jsonb_agg(jsonb_build_object('parti', oyun.parti_json(x.parti_id), 'il', x.n) order by x.n desc), '[]'::jsonb)
          from (select parti_id, count(*) n from oyun.musahit where secim_id = s.id and iptal_at is null group by 1) x)) order by s.oy_bas), '[]'::jsonb)
      from oyun.secimler s where s.tur in ('mv','cb','cb2','bel') and ((s.durum = 'bekliyor' and s.oy_bit > t) or (s.durum = 'tamam' and s.sonuc_at > t - interval '48 hours'))),
    'gorevlerim', (select coalesce(jsonb_agg(jsonb_build_object('secim_id', m.secim_id, 'tur', s.tur, 'il', i.ad, 'oy_bas', s.oy_bas, 'oy_bit', s.oy_bit,
        'sonuc_at', s.sonuc_at, 'durum', s.durum, 'sandik_at', m.sandik_at, 'tutanak', m.tutanak_tur,
        'sandik_acik', t >= s.oy_bas and t < s.oy_bit and m.sandik_at is null,
        'tutanak_acik', s.durum = 'tamam' and m.tutanak_tur is null and s.sonuc_at > t - interval '48 hours') order by s.oy_bas), '[]'::jsonb)
      from oyun.musahit m join oyun.secimler s on s.id = m.secim_id join oyun.iller i on i.id = m.il_id
      where m.user_id = p.id and m.iptal_at is null and (s.durum = 'bekliyor' or s.sonuc_at > t - interval '48 hours')),
    'adaylar', case when yonetici then (select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad, 'il_id', pr.il_id) order by pr.kad), '[]'::jsonb)
      from oyun.profiller pr where pr.parti_id = p.parti_id and not pr.yasakli) else '[]'::jsonb end);
end $$;

create or replace function public.musahit_ata(p_secim bigint, p_il int, p_kad text) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; h oyun.profiller;
begin
  if p.parti_id is null or not oyun.teskilat_yonetici(p.id, p.parti_id) then
    raise exception 'Müşahitleri genel başkan ya da teşkilattan sorumlu genel başkan yardımcısı atar.'; end if;
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.tur not in ('mv','cb','cb2','bel') or s.durum <> 'bekliyor' or s.oy_bit <= t then raise exception 'Bu seçim için müşahit atanamaz.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.parti_id is distinct from p.parti_id or h.yasakli then raise exception 'Müşahit partinin üyesi olmalı.'; end if;
  if h.il_id <> p_il then raise exception 'Müşahit, görev yapacağı ilde yaşamalı.'; end if;
  if exists (select 1 from oyun.adaylar where secim_id = s.id and user_id = h.id) then raise exception 'Bu seçimde aday olan kişi müşahit olamaz.'; end if;
  if exists (select 1 from oyun.musahit where secim_id = s.id and user_id = h.id and not (il_id = p_il and parti_id = p.parti_id)) then
    raise exception 'Bu oyuncu bu seçimde zaten müşahit olarak kaydedildi.'; end if;
  insert into oyun.musahit(secim_id, il_id, parti_id, user_id, atayan, zaman) values (s.id, p_il, p.parti_id, h.id, p.id, t)
    on conflict (secim_id, il_id, parti_id) do update set user_id = excluded.user_id, atayan = excluded.atayan, zaman = excluded.zaman,
      sandik_at = null, tutanak_tur = null, tutanak = null, tutanak_at = null, iptal_at = null;
  perform oyun.sm_haber(h.id, format('%s seni %s ilinde müşahit (sandık görevlisi) olarak atadı. Oy saatlerinde Siyaset Merkezi › Seçim''den sandık başına geç.',
    p.kad, (select ad from oyun.iller where id = p_il)), 'Müşahit oldun', t);
  return public.musahit_paneli();
end $$;

create or replace function public.musahit_kaldir(p_secim bigint, p_il int) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim();
begin
  if p.parti_id is null or not oyun.teskilat_yonetici(p.id, p.parti_id) then raise exception 'Yetkin yok.'; end if;
  update oyun.musahit m set iptal_at = oyun.simdi() from oyun.secimler s where s.id = m.secim_id and m.secim_id = p_secim and m.il_id = p_il
    and m.parti_id = p.parti_id and s.durum = 'bekliyor' and m.sandik_at is null and m.iptal_at is null;
  if not found then raise exception 'Kaldırılacak müşahit yok ya da görevine başladı.'; end if;
  return public.musahit_paneli();
end $$;

create or replace function public.musahit_sandik(p_secim bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or t < s.oy_bas or t >= s.oy_bit then raise exception 'Sandık başı görevi yalnızca oy saatlerinde yapılır.'; end if;
  update oyun.musahit set sandik_at = t where secim_id = s.id and user_id = p.id and sandik_at is null and iptal_at is null;
  if not found then raise exception 'Bu seçimde müşahitlik görevin yok ya da zaten sandık başındasın.'; end if;
  perform oyun.kidem_ekle(p.id, 1);
  perform oyun.bildir(p.id, 'Sandık başındasın. Sonuçlar açıklanınca 48 saat içinde tutanağını yaz. Kıdem +1.', t);
  return public.musahit_paneli();
end $$;

create or replace function public.musahit_tutanak(p_secim bigint, p_tur text, p_metin text default null) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; m oyun.musahit; n text; v_gb uuid;
begin
  if p_tur not in ('temiz','itiraz') then raise exception 'Geçersiz tutanak.'; end if;
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.durum <> 'tamam' or s.sonuc_at < t - interval '48 hours' then raise exception 'Tutanak, sonuçlardan sonraki 48 saat içinde yazılır.'; end if;
  select * into m from oyun.musahit where secim_id = s.id and user_id = p.id and iptal_at is null;
  if m.secim_id is null then raise exception 'Bu seçimde müşahit değilsin.'; end if;
  if m.tutanak_tur is not null then raise exception 'Tutanağını zaten yazdın.'; end if;
  if p_tur = 'itiraz' then n := oyun.metin_temizle(p_metin, 500);
  elsif nullif(btrim(coalesce(p_metin, '')), '') is not null then n := oyun.metin_temizle(p_metin, 500); end if;
  update oyun.musahit set tutanak_tur = p_tur, tutanak = n, tutanak_at = t where secim_id = m.secim_id and il_id = m.il_id and parti_id = m.parti_id;
  if p_tur = 'itiraz' then
    select pa.gb into v_gb from oyun.partiler pa where pa.id = m.parti_id;
    perform oyun.sm_haber(v_gb, format('%s ilindeki müşahidin %s itiraz tutanağı yazdı: "%s". Adliye''den seçim itirazı açabilirsin.',
      (select ad from oyun.iller where id = m.il_id), p.kad, left(n, 140)), 'İtiraz tutanağı', t);
    perform oyun.olay('secim', format('%s müşahidi %s ilinde itiraz tutanağı düzenledi.', (select kisa from oyun.partiler where id = m.parti_id),
      (select ad from oyun.iller where id = m.il_id)), m.il_id, m.parti_id, t);
  end if;
  return public.musahit_paneli();
end $$;

-- ====================================================================
-- 8) RESMÎ GÜNLER
-- ====================================================================
create or replace function public.resmi_gunler() returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); g date := oyun.sm_gun(t);
begin
  return jsonb_build_object(
    'bugun', (select jsonb_build_object('tarih', tarih, 'ad', ad, 'tur', tur, 'aciklama', aciklama) from oyun.resmi_gun where tarih = g),
    'yazabilirim', exists (select 1 from oyun.resmi_gun where tarih = g) and oyun.sm_siyasetci(p.id)
      and not exists (select 1 from oyun.resmi_gun_mesaj where tarih = g and user_id = p.id),
    'mesajlar', (select coalesce(jsonb_agg(oyun.sm_kisi(m.user_id) || jsonb_build_object('metin', m.metin, 'zaman', m.zaman, 'unvan_o_gun', m.unvan)
        order by (m.unvan = 'Cumhurbaşkanı') desc, m.zaman), '[]'::jsonb) from oyun.resmi_gun_mesaj m where m.tarih = g),
    'yaklasan', (select coalesce(jsonb_agg(jsonb_build_object('tarih', tarih, 'ad', ad, 'tur', tur) order by tarih), '[]'::jsonb)
      from (select * from oyun.resmi_gun where tarih > g order by tarih limit 6) x),
    'gecmis', (select coalesce(jsonb_agg(jsonb_build_object('tarih', r.tarih, 'ad', r.ad, 'mesaj', (select count(*) from oyun.resmi_gun_mesaj m where m.tarih = r.tarih)) order by r.tarih desc), '[]'::jsonb)
      from (select * from oyun.resmi_gun where tarih < g and tarih >= date '2026-10-16' order by tarih desc limit 6) r));
end $$;

create or replace function public.resmi_gun_mesaj_yaz(p_metin text) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); g date := oyun.sm_gun(t); r oyun.resmi_gun; m text;
begin
  select * into r from oyun.resmi_gun where tarih = g;
  if r.tarih is null then raise exception 'Bugün resmî bir gün değil.'; end if;
  if not oyun.sm_siyasetci(p.id) then raise exception 'Resmî gün mesajını makam sahipleri ve parti yöneticileri yayımlar.'; end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 600);
  insert into oyun.resmi_gun_mesaj(tarih, user_id, metin, zaman, unvan) values (g, p.id, m, t, oyun.unvan(p.id)) on conflict do nothing;
  if not found then raise exception 'Bugünkü mesajını zaten yayımladın.'; end if;
  perform oyun.olay('siyaset', format('%s mesajı · %s: "%s"', r.ad, p.kad, left(m, 140)), null, p.parti_id, t);
  return public.resmi_gunler();
end $$;

-- ====================================================================
-- 9) SAHA ÇALIŞMASI: STANT VE KAPI KAPI
-- ====================================================================
create or replace function oyun.stant_json(s oyun.stant, ben uuid, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_build_object('id', s.id, 'parti', oyun.parti_json(s.parti_id), 'il_id', s.il_id, 'il', (select ad from oyun.iller where id = s.il_id),
    'baslik', s.baslik, 'acan', oyun.kad(s.acan), 'bas', s.bas, 'bit', s.bit, 'canli', t >= s.bas and t < s.bit,
    'ziyaretci', (select count(*) from oyun.stant_ziyaret z where z.stant_id = s.id),
    'gonullu', (select count(*) from oyun.stant_gonullu g where g.stant_id = s.id),
    'ziyaret_ettim', exists (select 1 from oyun.stant_ziyaret z where z.stant_id = s.id and z.user_id = ben),
    'gonulluyum', exists (select 1 from oyun.stant_gonullu g where g.stant_id = s.id and g.user_id = ben),
    'partili', (select parti_id from oyun.profiller where id = ben) = s.parti_id,
    'sorular', (select coalesce(jsonb_agg(jsonb_build_object('id', z.id, 'kad', oyun.kad(z.user_id), 'soru', z.soru, 'cevap', z.cevap,
        'cevaplayan', oyun.kad(z.cevaplayan), 'zaman', z.zaman) order by z.zaman desc), '[]'::jsonb)
      from oyun.stant_ziyaret z where z.stant_id = s.id and z.soru is not null))
$$;

create or replace function public.stantlar(p_il int default null) returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); il int := coalesce(p_il, p.il_id);
begin
  return jsonb_build_object('il_id', il, 'il', (select ad from oyun.iller where id = il),
    'canli', (select coalesce(jsonb_agg(oyun.stant_json(s, p.id, t) order by s.bas), '[]'::jsonb) from oyun.stant s where s.il_id = il and s.bit > t),
    'son', (select coalesce(jsonb_agg(oyun.stant_json(s, p.id, t) order by s.bit desc), '[]'::jsonb)
            from (select * from oyun.stant where il_id = il and bit <= t order by bit desc limit 5) s),
    'tum_canli', (select coalesce(jsonb_agg(jsonb_build_object('il', i.ad, 'il_id', i.id, 'n', x.n) order by x.n desc), '[]'::jsonb)
                  from (select il_id, count(*) n from oyun.stant where bit > t group by 1) x join oyun.iller i on i.id = x.il_id),
    'acabilirim', p.parti_id is not null and (oyun.teskilat_yonetici(p.id, p.parti_id)
        or exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.bit is null and m.tur in ('mv','bel') and m.il_id = il)),
    'teskilat_var', p.parti_id is not null and exists (select 1 from oyun.parti_teskilat where parti_id = p.parti_id and il_id = il),
    'bedel', (select stant_bedel from oyun.ayarlar where id = 1), 'kapi', public.kapi_kapi_haklarim());
end $$;

create or replace function public.stant_ac(p_il int, p_baslik text) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; b text; bedel numeric; s oyun.stant; il text;
begin
  if p.parti_id is null then raise exception 'Stant açmak için bir partiye üye olmalısın.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if not (oyun.teskilat_yonetici(p.id, pa.id) or exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.bit is null and m.tur in ('mv','bel') and m.il_id = p_il)) then
    raise exception 'Stantı genel başkan, teşkilattan sorumlu yardımcı ya da o ilin partili milletvekili/belediye başkanı açar.'; end if;
  if not exists (select 1 from oyun.parti_teskilat where parti_id = pa.id and il_id = p_il) then raise exception 'Bu ilde partinin teşkilatı yok; önce il teşkilatı aç.'; end if;
  if exists (select 1 from oyun.stant where parti_id = pa.id and il_id = p_il and oyun.sm_gun(bas) = oyun.sm_gun(t)) then
    raise exception 'Partin bugün bu ilde zaten stant açtı.'; end if;
  b := oyun.metin_temizle(p_baslik, 80);
  bedel := coalesce((select stant_bedel from oyun.ayarlar where id = 1), 2000);
  if pa.kasa < bedel then raise exception 'Parti kasasında yeterli para yok (% ₺ gerekli).', oyun.tl(bedel); end if;
  il := (select ad from oyun.iller where id = p_il);
  update oyun.partiler set kasa = kasa - bedel where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, -bedel, format('%s seçim standı · %s', il, p.kad), 'stant');
  insert into oyun.stant(parti_id, il_id, acan, baslik, bas, bit, bedel) values (pa.id, p_il, p.id, b, t, t + interval '3 hours', bedel) returning * into s;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select id, t, case when parti_id = pa.id then format('%s, %s''da parti standı açtı: "%s". Gönüllü olarak standa katıl.', p.kad, il, b)
                       else format('%s, %s''da seçim standı açtı: "%s". 3 saat boyunca uğrayıp soru sorabilirsin.', pa.ad, il, b) end
    from oyun.profiller where il_id = p_il and id <> p.id and not yasakli;
  perform oyun.olay('parti', format('%s, %s''da seçim standı açtı: "%s"', pa.ad, il, b), p_il::smallint, pa.id, t);
  return oyun.stant_json(s, p.id, t);
end $$;

create or replace function public.stant_ziyaret(p_stant bigint, p_soru text default null) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.stant; q text;
begin
  select * into s from oyun.stant where id = p_stant;
  if s.id is null or t >= s.bit then raise exception 'Stant kapandı.'; end if;
  if p.il_id <> s.il_id then raise exception 'Yalnızca bu ilde yaşayanlar stanta uğrayabilir.'; end if;
  if nullif(btrim(coalesce(p_soru, '')), '') is not null then perform oyun.yazabilir_mi(p, t); q := oyun.metin_temizle(p_soru, 280); end if;
  insert into oyun.stant_ziyaret(stant_id, user_id, soru, zaman) values (s.id, p.id, q, t)
    on conflict (stant_id, user_id) do update set soru = coalesce(oyun.stant_ziyaret.soru, excluded.soru)
    where oyun.stant_ziyaret.soru is null;
  if q is not null then
    insert into oyun.bildirimler(user_id, zaman, metin)
      select id, t, format('%s ilindeki standına %s soru bıraktı: "%s"', (select ad from oyun.iller where id = s.il_id), p.kad, left(q, 120))
      from oyun.profiller where id = s.acan or (parti_id = s.parti_id and id in (select user_id from oyun.stant_gonullu where stant_id = s.id));
  end if;
  return oyun.stant_json(s, p.id, t);
end $$;

create or replace function public.stant_cevapla(p_ziyaret bigint, p_cevap text) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); z oyun.stant_ziyaret; s oyun.stant; c text;
begin
  select * into z from oyun.stant_ziyaret where id = p_ziyaret for update;
  if z.id is null or z.soru is null then raise exception 'Soru bulunamadı.'; end if;
  select * into s from oyun.stant where id = z.stant_id;
  if p.parti_id is distinct from s.parti_id then raise exception 'Soruları partinin üyeleri yanıtlar.'; end if;
  if z.cevap is not null then raise exception 'Bu soru zaten yanıtlandı.'; end if;
  if t > s.bit + interval '24 hours' then raise exception 'Yanıt süresi doldu.'; end if;
  perform oyun.yazabilir_mi(p, t);
  c := oyun.metin_temizle(p_cevap, 400);
  update oyun.stant_ziyaret set cevap = c, cevaplayan = p.id, cevap_at = t where id = z.id;
  perform oyun.sm_haber(z.user_id, format('%s standında sorduğun soruya %s yanıt verdi: "%s"', (select kisa from oyun.partiler where id = s.parti_id), p.kad, left(c, 120)), 'Stant yanıtı', t);
  return oyun.stant_json(s, p.id, t);
end $$;

create or replace function public.stant_gonullu_ol(p_stant bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.stant;
begin
  select * into s from oyun.stant where id = p_stant;
  if s.id is null or t >= s.bit then raise exception 'Stant kapandı.'; end if;
  if p.parti_id is distinct from s.parti_id then raise exception 'Gönüllü olmak için partinin üyesi olmalısın.'; end if;
  if p.il_id <> s.il_id then raise exception 'Yalnızca bu ilde yaşayan üyeler standa gönüllü olur.'; end if;
  insert into oyun.stant_gonullu(stant_id, user_id, zaman) values (s.id, p.id, t) on conflict do nothing;
  return oyun.stant_json(s, p.id, t);
end $$;

create or replace function public.kapi_kapi_haklarim() returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h date := oyun.sm_hafta(t); kul int;
begin
  select count(*) into kul from oyun.kapi_ziyaret where gonderen = p.id and zaman >= oyun.tr_an(h, 0, 0);
  return jsonb_build_object('hak', 3, 'kalan', greatest(0, 3 - kul), 'partili', p.parti_id is not null,
    'oneriler', case when p.parti_id is null then '[]'::jsonb else (select coalesce(jsonb_agg(jsonb_build_object('kad', x.kad, 'parti', oyun.parti_json(x.parti_id))), '[]'::jsonb)
      from (select pr.kad, pr.parti_id from oyun.profiller pr where pr.il_id = p.il_id and pr.id <> p.id and not pr.yasakli
              and pr.parti_id is distinct from p.parti_id and coalesce((pr.bildirim_ayar ->> 'propaganda')::boolean, true)
              and pr.son_gorulme > t - interval '14 days'
              and not exists (select 1 from oyun.kapi_ziyaret k where k.alici = pr.id and k.parti_id = p.parti_id and k.zaman > t - interval '7 days')
            order by md5(pr.id::text || h::text) limit 8) x) end,
    'gonderdiklerim', (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(k.alici), 'zaman', k.zaman) order by k.zaman desc), '[]'::jsonb)
      from (select * from oyun.kapi_ziyaret where gonderen = p.id order by zaman desc limit 5) k));
end $$;

create or replace function public.kapi_kapi(p_kad text, p_metin text) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; m text; pa oyun.partiler;
begin
  if p.parti_id is null then raise exception 'Kapı kapı ziyaret için bir partiye üye olmalısın.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id;
  if (select count(*) from oyun.kapi_ziyaret where gonderen = p.id and zaman >= oyun.tr_an(oyun.sm_hafta(t), 0, 0)) >= 3 then
    raise exception 'Bu hafta 3 kapı ziyaretinin hepsini yaptın; pazartesi yenilenir.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.id = p.id or h.yasakli then raise exception 'Bu oyuncuya ziyaret gönderilemez.'; end if;
  if h.il_id <> p.il_id then raise exception 'Kapı kapı ziyaret yalnızca kendi ilinde yaşayanlara yapılır.'; end if;
  if h.parti_id = p.parti_id then raise exception 'Kendi partinin üyesine kapı ziyareti yapılmaz.'; end if;
  if oyun.engelli(h.id, p.id) then raise exception 'Bu oyuncu seni engelledi.'; end if;
  if not coalesce((h.bildirim_ayar ->> 'propaganda')::boolean, true) then raise exception 'Bu oyuncu siyasi ziyaret kabul etmiyor.'; end if;
  if exists (select 1 from oyun.kapi_ziyaret where alici = h.id and parti_id = p.parti_id and zaman > t - interval '7 days') then
    raise exception 'Partinden biri bu hafta bu oyuncunun kapısını zaten çaldı.'; end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 280);
  insert into oyun.kapi_ziyaret(gonderen, alici, parti_id, metin, zaman) values (p.id, h.id, p.parti_id, m, t);
  perform oyun.bildir(h.id, format('%s gönüllüsü %s kapını çaldı: "%s" · Yanıtlamak istersen profilinden özel mesaj gönderebilirsin.', pa.kisa, p.kad, m), t);
  return public.kapi_kapi_haklarim();
end $$;

-- ====================================================================
-- 10) YOL ARKADAŞI
-- ====================================================================
create or replace function oyun.mentor_uygun(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.profiller p where p.id = u and not p.yasakli and p.olusturma < oyun.simdi() - interval '14 days')
     and oyun.kidem_puani(u) >= 10 $$;

create or replace function public.mentor_durum() returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.mentor_bag;
begin
  select * into b from oyun.mentor_bag where acemi = p.id;
  return jsonb_build_object(
    'acemi_mi', p.olusturma > t - interval '14 days', 'uygun', oyun.mentor_uygun(p.id),
    'odul', (select mentor_odul from oyun.ayarlar where id = 1),
    'gonullu', (select jsonb_build_object('tanitim', tanitim, 'aktif', aktif) from oyun.mentor_gonullu where user_id = p.id),
    'mentorum', case when b.acemi is not null and b.bitti_at is null then oyun.sm_kisi(b.mentor) || jsonb_build_object('bas', b.bas, 'odul_at', b.odul_at) end,
    'acemilerim', (select coalesce(jsonb_agg(oyun.sm_kisi(x.acemi) || jsonb_build_object('bas', x.bas, 'odul_at', x.odul_at) order by x.bas desc), '[]'::jsonb)
                   from oyun.mentor_bag x where x.mentor = p.id and x.bitti_at is null),
    'mentorlar', case when p.olusturma > t - interval '14 days' and (b.acemi is null or b.bitti_at is not null) then
      (select coalesce(jsonb_agg(x.j order by x.ayni_il desc, x.n), '[]'::jsonb) from (
        select oyun.sm_kisi(g.user_id) || jsonb_build_object('tanitim', g.tanitim, 'il', (select ad from oyun.iller where id = pr.il_id)) j,
          pr.il_id = p.il_id ayni_il, (select count(*) from oyun.mentor_bag mb where mb.mentor = g.user_id and mb.bitti_at is null) n
        from oyun.mentor_gonullu g join oyun.profiller pr on pr.id = g.user_id
        where g.aktif and g.user_id <> p.id and oyun.mentor_uygun(g.user_id) and not oyun.engelli(g.user_id, p.id)
          and (select count(*) from oyun.mentor_bag mb where mb.mentor = g.user_id and mb.bitti_at is null) < 5
        order by 2 desc, 3 limit 12) x) else '[]'::jsonb end);
end $$;

create or replace function public.mentor_gonullu_ol(p_tanitim text, p_aktif boolean default true) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m text;
begin
  if p_aktif and not oyun.mentor_uygun(p.id) then raise exception 'Yol arkadaşı olmak için hesabın en az 14 günlük ve kıdem puanın en az 10 olmalı.'; end if;
  if nullif(btrim(coalesce(p_tanitim, '')), '') is not null then m := oyun.metin_temizle(p_tanitim, 200); end if;
  insert into oyun.mentor_gonullu(user_id, tanitim, aktif, zaman) values (p.id, m, p_aktif, t)
    on conflict (user_id) do update set tanitim = coalesce(excluded.tanitim, oyun.mentor_gonullu.tanitim), aktif = excluded.aktif, zaman = excluded.zaman;
  return public.mentor_durum();
end $$;

create or replace function public.mentor_sec(p_kad text default null) returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m uuid;
begin
  if p.olusturma <= t - interval '14 days' then raise exception 'Yol arkadaşı yalnızca ilk 14 gününü geçiren yeni oyunculara eşlenir.'; end if;
  if exists (select 1 from oyun.mentor_bag where acemi = p.id and bitti_at is null) then raise exception 'Zaten bir yol arkadaşın var.'; end if;
  if exists (select 1 from oyun.mentor_bag where acemi = p.id and bitti_at is not null and odul_at is not null) then raise exception 'Yol arkadaşı eşliğini zaten tamamladın.'; end if;
  if p_kad is not null and btrim(p_kad) <> '' then
    m := (oyun.profil_bul(p_kad)).id;
  else
    select g.user_id into m from oyun.mentor_gonullu g join oyun.profiller pr on pr.id = g.user_id
      where g.aktif and g.user_id <> p.id and oyun.mentor_uygun(g.user_id) and not oyun.engelli(g.user_id, p.id)
        and (select count(*) from oyun.mentor_bag mb where mb.mentor = g.user_id and mb.bitti_at is null) < 5
      order by (pr.il_id = p.il_id) desc, (select count(*) from oyun.mentor_bag mb where mb.mentor = g.user_id and mb.bitti_at is null), random() limit 1;
    if m is null then raise exception 'Şu an boşta yol arkadaşı yok; birazdan yeniden dene.'; end if;
  end if;
  if m = p.id or not exists (select 1 from oyun.mentor_gonullu where user_id = m and aktif) or not oyun.mentor_uygun(m) then
    raise exception 'Bu oyuncu yol arkadaşı olarak gönüllü değil.'; end if;
  if oyun.engelli(m, p.id) or oyun.engelli(p.id, m) then raise exception 'Bu oyuncuyla eşleşemezsin.'; end if;
  if (select count(*) from oyun.mentor_bag where mentor = m and bitti_at is null) >= 5 then raise exception 'Bu yol arkadaşının eşliği dolu.'; end if;
  insert into oyun.mentor_bag(acemi, mentor, bas) values (p.id, m, t)
    on conflict (acemi) do update set mentor = excluded.mentor, bas = excluded.bas, odul_at = null, bitti_at = null, neden = null;
  perform oyun.sm_haber(m, format('Yeni oyuncu %s (%s) seni yol arkadaşı seçti. Ona bir hoş geldin mesajı at!', p.kad, (select ad from oyun.iller where id = p.il_id)), 'Yeni yol arkadaşın var', t);
  perform oyun.bildir(p.id, format('%s artık yol arkadaşın. Soruların için ona özel mesaj gönderebilirsin. İlk oyunu kullandığında ikiniz de ödül alırsınız.', oyun.kad(m)), t);
  return public.mentor_durum();
end $$;

create or replace function public.mentor_birak() returns jsonb
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  update oyun.mentor_bag set bitti_at = t, neden = 'acemi_ayrildi' where acemi = p.id and bitti_at is null;
  if not found then raise exception 'Yol arkadaşın yok.'; end if;
  return public.mentor_durum();
end $$;

-- ====================================================================
-- 11) ROZETLER (mevcut rozetler aynen + yeni üç rozet)
-- ====================================================================
create or replace function oyun.rozetler(u uuid) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(r order by r ->> 'sira'), '[]'::jsonb) from (
    select jsonb_build_object('sira', '01', 'ad', 'Cumhurbaşkanı', 'aciklama', 'Cumhurbaşkanlığı yaptı') r where exists (select 1 from oyun.makamlar where user_id = u and tur = 'cb')
    union all select jsonb_build_object('sira', '02', 'ad', 'Bakan', 'aciklama', 'Kabinede görev aldı') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'bakan')
    union all select jsonb_build_object('sira', '03', 'ad', 'Genel Başkan', 'aciklama', 'Bir partinin genel başkanı oldu')
      where exists (select 1 from oyun.partiler where gb = u) or exists (select 1 from oyun.kazananlar k join oyun.secimler s on s.id = k.secim_id where k.user_id = u and s.tur = 'kurultay')
    union all select jsonb_build_object('sira', '04', 'ad', 'Milletvekili', 'aciklama', 'Meclis''e girdi') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv')
    union all select jsonb_build_object('sira', '05', 'ad', 'Belediye Başkanı', 'aciklama', 'Bir ili yönetti') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'bel')
    union all select jsonb_build_object('sira', '06', 'ad', 'Kanun Yapıcı', 'aciklama', 'Teklifi yasalaştı') where exists (select 1 from oyun.kanunlar where teklif_eden = u and durum = 'yururlukte')
    union all select jsonb_build_object('sira', '07', 'ad', 'Parti Kurucusu', 'aciklama', 'Yeni bir parti kurdu') where exists (select 1 from oyun.partiler where kurucu = u)
    union all select jsonb_build_object('sira', '08', 'ad', 'Hatip', 'aciklama', '10+ propaganda yayını') where (select count(*) from oyun.yayinlar where gonderen = u) >= 10
    union all select jsonb_build_object('sira', '09', 'ad', 'Demokrasi Emektarı', 'aciklama', '20+ seçimde oy kullandı') where (select count(*) from oyun.oylar where secmen = u) >= 20
    union all select jsonb_build_object('sira', '10', 'ad', 'Sandık Neferi', 'aciklama', 'İlk oyunu kullandı') where (select count(*) from oyun.oylar where secmen = u) between 1 and 19
    union all select jsonb_build_object('sira', '11', 'ad', 'Kurucu Vatandaş', 'aciklama', 'Oyunun ilk vatandaşlarından')
      where exists (select 1 from oyun.profiller p, oyun.ayarlar a where p.id = u and a.id = 1 and p.olusturma <= coalesce(a.kurucu_rozet_bitis, '2026-12-31 23:59:59+03'))
    union all select jsonb_build_object('sira', '12', 'ad', 'Sandık Görevlisi', 'aciklama', 'Müşahit olarak sandık başında görev yaptı') where exists (select 1 from oyun.musahit where user_id = u and sandik_at is not null)
    union all select jsonb_build_object('sira', '13', 'ad', 'Yol Arkadaşı', 'aciklama', 'Yeni bir oyuncuya oyunda eşlik etti') where exists (select 1 from oyun.mentor_bag where mentor = u and odul_at is not null)
  ) x
$$;

-- ====================================================================
-- GÜNDEM ÖZETİ (tek çağrı)
-- ====================================================================
create or replace function public.siyaset_merkezi_ozet() returns jsonb
language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); g date := oyun.sm_gun(t);
begin
  return jsonb_build_object('tema', oyun.sm_gun_tema(extract(isodow from g)::int),
    'resmi_gun', (select jsonb_build_object('ad', ad, 'mesaj', (select count(*) from oyun.resmi_gun_mesaj m where m.tarih = g),
       'yazabilirim', oyun.sm_siyasetci(p.id) and not exists (select 1 from oyun.resmi_gun_mesaj m where m.tarih = g and m.user_id = p.id)) from oyun.resmi_gun where tarih = g),
    'canli', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'tur', c.tur, 'baslik', c.baslik, 'kad', oyun.kad(c.sahibi), 'bit', c.bit) order by c.bas), '[]'::jsonb)
              from oyun.canli_yayin c where not c.iptal and c.bas <= t and c.bit > t),
    'yaklasan', (select jsonb_build_object('id', c.id, 'baslik', c.baslik, 'bas', c.bas, 'gazete', (select ad from oyun.oyuncu_gazeteleri where id = c.gazete_id))
                 from oyun.canli_yayin c where not c.iptal and c.bas > t and c.bas < t + interval '24 hours' order by c.bas limit 1),
    'davet', (select count(*) from oyun.canli_yayin_konuk k join oyun.canli_yayin c on c.id = k.yayin_id where k.user_id = p.id and k.durum = 'davet' and not c.iptal and c.bit > t),
    'balkon', (select jsonb_build_object('secim_id', b.secim_id, 'kad', oyun.kad(b.user_id), 'metin', left(b.metin, 160)) from oyun.balkon b where b.zaman > t - interval '48 hours' order by b.zaman desc limit 1),
    'balkon_bekleyen', exists (select 1 from oyun.secimler s where s.tur in ('mv','cb','cb2') and s.durum = 'tamam' and s.sonuc_at > t - interval '48 hours'
                               and oyun.balkon_kazanan(s) = p.id and not exists (select 1 from oyun.balkon b where b.secim_id = s.id and b.user_id = p.id)),
    'transfer', (select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad, 'eski', oyun.parti_json(x.eski_parti), 'yeni', oyun.parti_json(x.yeni_parti)) order by x.zaman desc), '[]'::jsonb)
                 from (select * from oyun.parti_gecis where onemli and zaman > t - interval '72 hours' order by zaman desc limit 3) x join oyun.profiller pr on pr.id = x.user_id),
    'stant', (select count(*) from oyun.stant where il_id = p.il_id and bas <= t and bit > t),
    'musahit', (select jsonb_build_object('il', i.ad, 'sandik_acik', t >= s.oy_bas and t < s.oy_bit and m.sandik_at is null,
                  'tutanak_acik', s.durum = 'tamam' and m.tutanak_tur is null and s.sonuc_at > t - interval '48 hours')
                from oyun.musahit m join oyun.secimler s on s.id = m.secim_id join oyun.iller i on i.id = m.il_id
                where m.user_id = p.id and m.iptal_at is null and (s.durum = 'bekliyor' or s.sonuc_at > t - interval '48 hours') order by s.oy_bas limit 1),
    'mentor_oneri', p.olusturma > t - interval '14 days' and not exists (select 1 from oyun.mentor_bag where acemi = p.id),
    'ozet_hazir', (select hafta from oyun.haftanin_ozeti where zaman > t - interval '36 hours' order by hafta desc limit 1));
end $$;

-- ====================================================================
-- ZAMANLAYICI: yayın sonları, haftalık hatırlatmalar, haftanın özeti, resmî gün, yol arkadaşı ödülü
-- ====================================================================
create or replace function oyun.sm_bir_kez(p_anahtar text) returns boolean language plpgsql as $$
begin
  insert into oyun.hafta_bildirim(anahtar, zaman) values (p_anahtar, oyun.simdi()) on conflict do nothing;
  return found;
end $$;

create or replace function oyun.siyaset_merkezi_tick(t timestamptz default null) returns void
language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $$
declare c oyun.canli_yayin; g date; gun int; saat int; h date; r record; kazanan uuid; n int; od numeric; rg oyun.resmi_gun; v jsonb;
begin
  t := coalesce(t, oyun.simdi()); g := oyun.sm_gun(t); gun := extract(isodow from g)::int;
  saat := extract(hour from t at time zone 'Europe/Istanbul')::int; h := oyun.sm_hafta(t);

  -- Program başladı bildirimi
  for c in select * from oyun.canli_yayin where tur = 'program' and not iptal and not basladi_bildirildi and bas <= t and bit > t loop
    update oyun.canli_yayin set basladi_bildirildi = true where id = c.id;
    perform oyun.sm_haber(k.user_id, format('"%s" programı başladı; stüdyo seni bekliyor.', c.baslik), 'Program başladı', t)
      from oyun.canli_yayin_konuk k where k.yayin_id = c.id and k.durum = 'kabul';
    insert into oyun.bildirimler(user_id, zaman, metin)
      select a.user_id, t, format('Abone olduğun %s gazetesinde canlı program başladı: "%s"', (select ad from oyun.oyuncu_gazeteleri where id = c.gazete_id), c.baslik)
      from oyun.gazete_abonelik a where a.gazete_id = c.gazete_id and a.bitis > t;
  end loop;
  -- Yayın sonu özetleri (oylama 15 dk sonra kapanır)
  for c in select * from oyun.canli_yayin where not ozet_yazildi and (iptal or bit + interval '15 minutes' <= t) loop
    update oyun.canli_yayin set ozet_yazildi = true where id = c.id;
    if not c.iptal then
      kazanan := null; n := null;
      select konuk, count(*) into kazanan, n from oyun.canli_yayin_oy where yayin_id = c.id group by konuk order by count(*) desc, min(zaman) limit 1;
      perform oyun.olay('basin', format('%s sona erdi: "%s" · %s mesaj, %s alkış, %s yuh%s', case when c.tur = 'basin' then oyun.kad(c.sahibi) || ' basın toplantısı' else 'Tartışma programı' end,
        c.baslik, (select count(*) from oyun.canli_yayin_mesaj where yayin_id = c.id), (select count(*) from oyun.canli_yayin_tepki where yayin_id = c.id and tur = 'alkis'),
        (select count(*) from oyun.canli_yayin_tepki where yayin_id = c.id and tur = 'yuh'),
        case when kazanan is not null then format(' · izleyicilere göre en ikna edici: %s (%s oy)', oyun.kad(kazanan), n) else '' end), null, c.parti_id, t);
      if kazanan is not null then perform oyun.sm_haber(kazanan, format('"%s" programında izleyiciler seni en ikna edici konuk seçti (%s oy).', c.baslik, n), 'Programın yıldızı oldun', t); end if;
    end if;
  end loop;

  -- Haftalık hatırlatmalar
  if gun = 1 and saat >= 10 and oyun.sm_bir_kez('meclis:' || g) then
    n := (select count(*) from oyun.kanunlar where durum = 'oylamada');
    perform oyun.sm_haber(m.user_id, format('Meclis haftası başladı. Gündemde %s teklif var; Meclis sekmesinden incele.', n), 'Meclis haftası', t)
      from oyun.makamlar m where m.tur = 'mv' and m.bit is null;
  end if;
  if gun = 3 and saat >= 11 and oyun.sm_bir_kez('grup:' || g) then
    perform oyun.sm_haber(pa.gb, 'Bugün grup günü: partinin grup toplantısında konuşma yap, haftanın mesajını ver.', 'Grup günü', t)
      from oyun.partiler pa where not pa.kapali and pa.gb is not null and exists (select 1 from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
        where m.tur = 'mv' and m.bit is null and pr.parti_id = pa.id);
  end if;
  if gun = 4 and saat >= 10 and oyun.sm_bir_kez('oylama:' || g) then
    n := (select count(*) from oyun.kanunlar where durum = 'oylamada');
    if n > 0 then
      perform oyun.sm_haber(m.user_id, format('Oylama günü: Meclis''te %s teklif oyunu bekliyor.', n), 'Oylama günü', t)
        from oyun.makamlar m where m.tur = 'mv' and m.bit is null;
    end if;
  end if;
  if gun = 5 and saat >= 18 and oyun.sm_bir_kez('anket:' || g) then
    insert into oyun.bildirimler(user_id, zaman, metin)
      select user_id, t, 'Haftalık anket sonuçları ve "Şu an seçim olsa" Meclis tablosu hazır: Siyaset Merkezi.' from oyun.haftalik_anket_oy where hafta = h;
  end if;
  if gun = 7 and saat >= 20 and oyun.sm_bir_kez('ozet:' || h) then
    v := oyun.haftanin_ozeti_hesapla(h);
    insert into oyun.haftanin_ozeti(hafta, veri, zaman) values (h, v, t) on conflict (hafta) do update set veri = excluded.veri, zaman = excluded.zaman;
    perform oyun.olay('basin', format('Haftanın özeti yayımlandı: %s yeni kanun, %s transfer, %s miting, %s canlı yayın.',
      v #>> '{kanunlar,sayi}', jsonb_array_length(v -> 'transferler'), v #>> '{miting,sayi}', v #>> '{yayinlar,sayi}'), null, null, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select id, t, 'Haftanın özeti yayımlandı: kanunlar, transferler, mitingler ve anket. Siyaset Merkezi › Haftanın özeti.'
      from oyun.profiller where not yasakli and son_gorulme > t - interval '14 days';
  end if;

  -- Resmî gün
  select * into rg from oyun.resmi_gun where tarih = g;
  if rg.tarih is not null then
    if saat >= 8 and oyun.sm_bir_kez('resmi_hatirlat:' || g) then
      insert into oyun.bildirimler(user_id, zaman, metin)
        select distinct x, t, format('Bugün %s. Bir mesaj yayımlayabilirsin: Siyaset Merkezi › Resmî günler.', rg.ad)
        from (select user_id x from oyun.makamlar where bit is null union select gb from oyun.partiler where not kapali and gb is not null) y where x is not null;
    end if;
    if saat >= 9 and oyun.sm_bir_kez('resmi_push:' || g) then
      perform oyun.push_konuya('duyuru', null, rg.ad, 'Liderlerin ' || lower(rg.ad) || ' mesajlarını Gündem''de oku.', '{"ekran":"gundem"}'::jsonb);
    end if;
  end if;

  -- Yol arkadaşı ödülü: yeni oyuncu bir seçimde ya da haftalık ankette oy kullandığında
  od := coalesce((select mentor_odul from oyun.ayarlar where id = 1), 0);
  for r in select b.* from oyun.mentor_bag b where b.bitti_at is null and b.odul_at is null and b.bas < t - interval '12 hours'
           and (exists (select 1 from oyun.oylar o where o.secmen = b.acemi and o.zaman > b.bas)
             or exists (select 1 from oyun.haftalik_anket_oy a where a.user_id = b.acemi and a.zaman > b.bas)) loop
    update oyun.mentor_bag set odul_at = t, bitti_at = case when oyun.bagli_hesap_mi(r.acemi, r.mentor) then t end,
      neden = case when oyun.bagli_hesap_mi(r.acemi, r.mentor) then 'bagli_hesap' end where acemi = r.acemi;
    if not oyun.bagli_hesap_mi(r.acemi, r.mentor) and od > 0 then
      perform oyun.para_islem(r.acemi, od, 'odul', 'Yol arkadaşı ödülü: ilk oyunu kullandın', t, 0);
      perform oyun.para_islem(r.mentor, od, 'odul', 'Yol arkadaşı ödülü: ' || oyun.kad(r.acemi) || ' ilk oyunu kullandı', t, 0);
      perform oyun.bildir(r.acemi, format('İlk oyunu kullandın! Sana ve yol arkadaşın %s''e %s ₺ ödül verildi.', oyun.kad(r.mentor), oyun.tl(od)), t);
      perform oyun.sm_haber(r.mentor, format('Yol arkadaşın %s ilk oyunu kullandı. %s ₺ ödül cüzdanında.', oyun.kad(r.acemi), oyun.tl(od)), 'Yol arkadaşı ödülü', t);
    end if;
  end loop;
  -- 21 günü dolan eşlikler biter
  update oyun.mentor_bag set bitti_at = t, neden = coalesce(neden, 'sure') where bitti_at is null and bas < t - interval '21 days';
end $$;

-- ====================================================================
-- Yetkiler
-- ====================================================================
do $$ declare f text; begin
  foreach f in array array['siyasi_hafta()','meclis_projeksiyon()','haftanin_ozeti(date)','canli_yayin_ac(text,text,timestamptz,bigint)',
    'canli_yayin_davet(bigint,text)','canli_yayin_davet_yanit(bigint,boolean)','canli_yayin_yaz(bigint,text,bigint)','canli_yayin_tepki(bigint,text)',
    'canli_yayin_oyla(bigint,text)','canli_yayin_bitir(bigint)','canli_yayinlar()','canli_yayin_detay(bigint,bigint)','parti_gecisleri(int)',
    'rozet_tak(bigint,text)','oyuncu_parti_gecmisi(text)','balkon_durum()','balkon_konus(bigint,text)','tebrik_et(bigint,text)',
    'musahit_paneli()','musahit_ata(bigint,int,text)','musahit_kaldir(bigint,int)','musahit_sandik(bigint)','musahit_tutanak(bigint,text,text)',
    'resmi_gunler()','resmi_gun_mesaj_yaz(text)','stantlar(int)','stant_ac(int,text)','stant_ziyaret(bigint,text)','stant_cevapla(bigint,text)',
    'stant_gonullu_ol(bigint)','kapi_kapi_haklarim()','kapi_kapi(text,text)','mentor_durum()','mentor_gonullu_ol(text,boolean)',
    'mentor_sec(text)','mentor_birak()','siyaset_merkezi_ozet()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['siyaset_merkezi_tick(timestamptz)','haftanin_ozeti_hesapla(date)','parti_gecis_tg()','sm_bir_kez(text)','sm_haber(uuid,text,text,timestamptz,boolean)'] loop
    execute format('revoke all on function oyun.%s from public, anon, authenticated', f);
  end loop;
end $$;
select cron.schedule('siyaset-merkezi', '1-59/5 * * * *', 'select oyun.siyaset_merkezi_tick()');
commit;
