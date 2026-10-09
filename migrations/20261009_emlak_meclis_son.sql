-- 2026-10-09 · TEK GEÇERLİ GÜNCELLEME (sürüm 2026.10.09-8): il bazlı emlak stoğu ve fiyatı, haftalık mülk vergisi
-- (belediyeye), 600 sandalyelik Meclis ve dolu sandalyeye göre salt çoğunluk.
-- Aynı gün üretilen deneme migration'larının (migrations/_iptal_20261009) yerine geçer; onlardan hangisi
-- çalıştırılmış olursa olsun kalıntılarını temizler. Üreten: gelistirici/build/emlak_migration.sh
begin;
-- 600 potansiyel sandalye, dolu vekiller üzerinden salt çoğunluk.
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
    if dolu > 0 and c.kabul >= floor(dolu / 2.0) + 1 then
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
        sonuc_metin = format('Salt çoğunluk sağlanamadı: %s kabul, %s ret, %s çekimser (dolu %s sandalyeden en az %s EVET gerekir).', c.kabul, c.ret, c.cekimser, dolu, floor(dolu / 2.0) + 1)
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
;

-- 600 milletvekili seçilebilecek; boş koltuklar yasama çoğunluğuna dahil edilmeyecek.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
update oyun.meclis_olcek_kayit set sandalye=600,anayasal=600
 where secim_id in (select id from oyun.secimler
                   where tur='mv_on' and durum='bekliyor' and oy_bas>oyun.simdi());
-- =====================================================================
--  44 · İL BAZLI EMLAK: SINIRLI STOK, İL FİYATI, HAFTALIK MÜLK VERGİSİ
--
--  • Her ilde satılık yeni mülk sayısı nüfusa göre sınırlı (İstanbul ~100 daire, Bayburt 8 daire).
--    Nüfus göstergesi: ilin 600 sandalyelik Meclis'teki ağırlığı (oyun.iller.mv).
--  • Fiyat ve kira ilin büyüklüğüne ve gelişmişliğine göre değişir.
--    Gelişmişlik = %60 ilin kalıcı kalkınma puanı (SEGE sıralamasına yakın 6 kademe)
--                + %40 belediyenin oyun içi gelişim puanı (yatırımlarla değişir).
--  • Oyuncu parası yettikçe yaşamadığı illerden de mülk alabilir, ilana koyup satabilir.
--  • Her mülkten haftalık mülk vergisi alınır, para mülkün bulunduğu ilin belediye kasasına gider.
--    Oran = Meclis'in kanunla belirlediği ulusal oran × o ilin belediye başkanının çarpanı.
--    Ulusal oranı cumhurbaşkanı kararnameyle değiştiremez; yalnız TBMM (ya da anayasa).
--  • Vergi matrahı mülkün bugünkü il rayiç bedelidir (alış fiyatı değil).
--  • Eski mülklerin sahibi ve kirası korunur; ilk vergi bu güncellemeden 7 gün sonra alınır.
-- =====================================================================

alter table oyun.yatirim_mulkleri add column if not exists vergi_sonraki timestamptz;
alter table oyun.yatirim_mulkleri add column if not exists vergi_borc numeric not null default 0;
update oyun.yatirim_mulkleri set vergi_sonraki = oyun.simdi() + interval '7 days' where vergi_sonraki is null;
alter table oyun.yatirim_mulkleri alter column vergi_sonraki set default now() + interval '7 days';

-- Belediye kasasına giden her vergi tahsilatı (belediye başkanı ve oyuncu ekranları için)
create table if not exists oyun.emlak_vergi_tahsilat(
  id       bigint generated always as identity primary key,
  il_id    smallint not null references oyun.iller(id),
  user_id  uuid not null references oyun.profiller(id),
  mulk_id  bigint not null,
  tutar    numeric not null check (tutar >= 0),
  zaman    timestamptz not null default now()
);
create index if not exists emlak_vergi_tahsilat_il_zaman on oyun.emlak_vergi_tahsilat(il_id, zaman);
alter table oyun.emlak_vergi_tahsilat enable row level security;

-- İllerin kalıcı kalkınma puanı (0-100). Kademeler SEGE il sıralamasına yakındır; gerekirse elle ayarlanabilir.
create table if not exists oyun.il_kalkinma(
  il_id smallint primary key references oyun.iller(id),
  puan  numeric not null check (puan between 0 and 100)
);
alter table oyun.il_kalkinma enable row level security;
insert into oyun.il_kalkinma(il_id, puan)
select i.id, case
  when i.id in (6,7,16,26,34,35,41,48,59) then 90
  when i.id in (9,10,11,14,17,20,22,32,33,38,39,42,45,54,77) then 75
  when i.id in (1,3,5,8,15,19,23,24,27,31,37,40,43,44,50,51,53,55,58,61,64,67,70,71,74,78,81) then 60
  when i.id in (18,25,28,29,46,52,57,60,62,66,68,69,79,80) then 45
  when i.id in (2,12,21,36,63,72,75,76) then 30
  else 15 end
from oyun.iller i
on conflict (il_id) do nothing;

-- Yeni tablolar da TRUNCATE korumasına girsin (tam kurulumda kalicilik_son zaten ekler; migration için burada)
do $$ begin
  if to_regproc('oyun.bosaltma_korumasi') is not null then
    drop trigger if exists bosaltma_korumasi on oyun.emlak_vergi_tahsilat;
    create trigger bosaltma_korumasi before truncate on oyun.emlak_vergi_tahsilat for each statement execute function oyun.bosaltma_korumasi();
    drop trigger if exists bosaltma_korumasi on oyun.il_kalkinma;
    create trigger bosaltma_korumasi before truncate on oyun.il_kalkinma for each statement execute function oyun.bosaltma_korumasi();
  end if;
end $$;

-- Kurallar: ulusal oran (Meclis) ve il çarpanı (belediye başkanı)
insert into oyun.duzenleme_tanim(kod, kapsam, ad, birim, varsayilan, min, max, adim, tur, aciklama, oyuncu, devlet, sira) values
('mulk_vergi_ulusal','ulke','Haftalık mülk vergisi','yuzde',0.5,0.1,3.0,0.1,'gelir',
 'Mülklerin il rayiç bedeli üzerinden her hafta alınan vergi. Yalnız TBMM kanunla değiştirir; illerde belediye çarpanıyla uygulanır.',
 'Sahip olduğun her mülk için haftada bir, mülkün bugünkü il değeri üzerinden vergi ödersin.',
 'Vergi hazineye değil, mülkün bulunduğu ilin belediye kasasına gider.',21),
('mulk_vergi_yerel','il','Mülk vergisi çarpanı','yuzde',100,50,200,10,'gelir',
 'Meclis''in belirlediği haftalık mülk vergisinin bu ilde uygulanan çarpanı. 100 değişiklik yok demektir, 150 vergiyi yarı yarıya artırır.',
 'Bu ildeki mülklerin vergisi değişir; mülk sahibi başka ilde yaşasa da vergiyi bu il alır.',
 'Gelir doğrudan bu ilin belediye kasasına girer.',22)
on conflict (kod) do update set kapsam = excluded.kapsam, ad = excluded.ad, birim = excluded.birim, varsayilan = excluded.varsayilan,
  min = excluded.min, max = excluded.max, adim = excluded.adim, tur = excluded.tur, aciklama = excluded.aciklama,
  oyuncu = excluded.oyuncu, devlet = excluded.devlet, sira = excluded.sira;

-- Ulusal oranı cumhurbaşkanı kararnameyle değiştiremez.
create or replace function oyun.duzenleme_engel(p_kod text, p_kaynak text) returns text language sql stable as $$
  select case when d.kaynak = 'anayasa' and p_kaynak <> 'anayasa'
                then 'Bu kural anayasada düzenlenmiş; ancak halk oylamasıyla yapılacak bir anayasa değişikliğiyle değiştirilebilir.'
              when p_kod = 'mulk_vergi_ulusal' and p_kaynak = 'kararname'
                then 'Haftalık mülk vergisi oranını yalnız TBMM kanunla değiştirebilir; kararnameyle değiştirilemez.'
              when d.kaynak = 'kanun' and p_kaynak = 'kararname'
                then 'Bu konu Meclis tarafından kanunla düzenlenmiş; kanunla düzenlenen konuda cumhurbaşkanlığı kararnamesi çıkarılamaz.' end
  from (select 1) x left join oyun.duzenlemeler d on d.kod = p_kod
$$;

-- ---------------------------------------------------------------------
-- HESAPLAR
-- ---------------------------------------------------------------------
create or replace function oyun.mulk_il_gelismislik(p_il smallint) returns numeric
language sql stable set search_path = '' as $$
  select round(0.6 * coalesce(k.puan, 50) + 0.4 * greatest(0, least(100, coalesce(d.gelisim, 50))), 1)
  from oyun.iller i left join oyun.il_kalkinma k on k.il_id = i.id left join oyun.il_durum d on d.il_id = i.id
  where i.id = p_il
$$;

create or replace function oyun.mulk_il_kota(p_il smallint, p_tip text) returns integer
language sql stable set search_path = '' as $$
  select case p_tip
    when 'daire'  then 8 + round((least(96, greatest(1, i.mv)) - 1) * 92.0 / 95)::int
    when 'dukkan' then 3 + round((least(96, greatest(1, i.mv)) - 1) * 32.0 / 95)::int
    when 'villa'  then 2 + round((least(96, greatest(1, i.mv)) - 1) * 18.0 / 95)::int
    else 0 end
  from oyun.iller i where i.id = p_il
$$;

create or replace function oyun.mulk_il_bedel(p_il smallint, p_tip text) returns numeric
language sql stable set search_path = '' as $$
  select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end)
               * (0.55 + 1.10 * sqrt(least(96, greatest(1, i.mv))::numeric / 96.0))
               * (0.60 + oyun.mulk_il_gelismislik(p_il) / 125.0), -3)
  from oyun.iller i where i.id = p_il
$$;

-- Kira: il değerinin ~1/13'ü; gelişmiş ilde kira getirisi biraz daha yüksek.
create or replace function oyun.mulk_il_kira(p_il smallint, p_tip text) returns numeric
language sql stable set search_path = '' as $$
  select round(oyun.mulk_il_bedel(p_il, p_tip) / 13.0 * (0.85 + oyun.mulk_il_gelismislik(p_il) / 333.0), -1)
$$;

-- Bu ilde uygulanan haftalık oran (yüzde)
create or replace function oyun.mulk_vergi_oran(p_il smallint) returns numeric
language sql stable set search_path = '' as $$
  select round(oyun.duz('mulk_vergi_ulusal') * oyun.il_duz(p_il, 'mulk_vergi_yerel') / 100.0, 3)
$$;

create or replace function oyun.mulk_haftalik_vergi_tutar(p_mulk bigint) returns numeric
language sql stable set search_path = '' as $$
  select round(oyun.mulk_il_bedel(m.il_id, m.tip) * oyun.mulk_vergi_oran(m.il_id) / 100.0)
  from oyun.yatirim_mulkleri m where m.id = p_mulk
$$;

-- Vadesi gelen dönemleri tahakkuk ettirir, cüzdandaki parayla öder; yetmeyen kısım borç olarak kalır.
create or replace function oyun.mulk_haftalik_vergi(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare x record; t timestamptz := oyun.simdi(); donem int; tahakkuk numeric; odeme numeric; hazir numeric;
begin
  for x in select m.id, m.il_id, m.tip, m.vergi_sonraki, m.vergi_borc, i.ad il_ad
           from oyun.yatirim_mulkleri m join oyun.iller i on i.id = m.il_id
           where m.user_id = p_user and (m.vergi_sonraki <= t or m.vergi_borc > 0)
           order by m.id for update of m loop
    donem := case when x.vergi_sonraki <= t then least(520, floor(extract(epoch from (t - x.vergi_sonraki)) / 604800)::int + 1) else 0 end;
    tahakkuk := coalesce(oyun.mulk_haftalik_vergi_tutar(x.id), 0) * donem;
    hazir := greatest(0, coalesce((select para from oyun.cuzdan where user_id = p_user), 0));
    odeme := least(x.vergi_borc + tahakkuk, floor(hazir));
    update oyun.yatirim_mulkleri
       set vergi_borc = greatest(0, x.vergi_borc + tahakkuk - odeme),
           vergi_sonraki = x.vergi_sonraki + make_interval(days => donem * 7)
     where id = x.id;
    if odeme > 0 then
      perform oyun.para_islem(p_user, -odeme, 'emlak_vergi',
        format('%s Belediyesi mülk vergisi · mülk #%s%s', x.il_ad, x.id, case when donem > 1 then format(' (%s hafta)', donem) else '' end), t, odeme);
      update oyun.il_durum set kasa = coalesce(kasa, 0) + odeme / 1e9 where il_id = x.il_id;  -- belediye kasası milyar ₺
      insert into oyun.emlak_vergi_tahsilat(il_id, user_id, mulk_id, tutar, zaman) values (x.il_id, p_user, x.id, odeme, t);
    end if;
  end loop;
end $$;
revoke all on function oyun.mulk_haftalik_vergi(uuid) from public, anon, authenticated;

-- Kira tahsili (24'teki ile aynı) + haftalık mülk vergisi
create or replace function oyun.mulk_kira_tahsil(p_user uuid) returns void
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare m record; n int; gross numeric; tax numeric; t timestamptz := oyun.simdi();
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 78113));
  for m in select * from oyun.yatirim_mulkleri where user_id = p_user and sonraki_kira <= t order by id for update loop
    n := least(520, floor(extract(epoch from (t - m.sonraki_kira)) / 604800)::int + 1);
    gross := round(m.haftalik_kira * n, 2);
    tax := case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id = p_user
                        and (x.satin_alma < m.satin_alma or (x.satin_alma = m.satin_alma and x.id <= m.id))) >= 3
                then round(gross * oyun.yasa_oran('coklu_mulk_vergi') / 100, 2) else 0 end;
    perform oyun.para_islem(p_user, gross - tax, 'kira', format('Mülk #%s: %s haftalık kira, vergi %s ₺', m.id, n, tax), t, tax);
    if tax > 0 then update oyun.ulke set hazine = hazine + tax / 1000000 where id = 1; end if;
    update oyun.yatirim_mulkleri set sonraki_kira = sonraki_kira + n * interval '7 days', toplam_kira = toplam_kira + gross - tax,
      kira_sayisi = kira_sayisi + n where id = m.id;
  end loop;
  perform oyun.mulk_haftalik_vergi(p_user);
end $function$;

-- Tapu devrinde vergi borcu satıcıdan kesilir (satış bedeli cüzdanına girdikten sonra çalışır).
create or replace function oyun.mulk_devir_vergi() returns trigger
language plpgsql security definer set search_path = '' as $$
declare ilad text;
begin
  if new.user_id is distinct from old.user_id and old.vergi_borc > 0 then
    select ad into ilad from oyun.iller where id = old.il_id;
    perform oyun.para_islem(old.user_id, -old.vergi_borc, 'emlak_vergi',
      format('%s Belediyesi mülk vergisi borcu (tapu devri) · mülk #%s', ilad, old.id), oyun.simdi(), old.vergi_borc);
    update oyun.il_durum set kasa = coalesce(kasa, 0) + old.vergi_borc / 1e9 where il_id = old.il_id;
    insert into oyun.emlak_vergi_tahsilat(il_id, user_id, mulk_id, tutar, zaman) values (old.il_id, old.user_id, old.id, old.vergi_borc, oyun.simdi());
    new.vergi_borc := 0;
  end if;
  return new;
end $$;
drop trigger if exists mulk_devir_vergi on oyun.yatirim_mulkleri;
create trigger mulk_devir_vergi before update of user_id on oyun.yatirim_mulkleri
  for each row execute function oyun.mulk_devir_vergi();

-- ---------------------------------------------------------------------
-- UYGULAMA (RPC)
-- ---------------------------------------------------------------------
-- Deneme sürümlerinden kalmış olabilecek farklı imzalı kopyalar (uygulama çağrısı belirsiz kalmasın)
do $$ declare r record; begin
  for r in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname in ('mulk_il_satin_al', 'mulk_il_stok') loop
    execute format('drop function %s', r.f);
  end loop;
end $$;

create or replace function public.mulk_il_stok() returns jsonb
language sql stable security definer set search_path = '' as $$
  with sahip as (select il_id, tip, count(*) n from oyun.yatirim_mulkleri group by il_id, tip)
  select coalesce(jsonb_agg(jsonb_build_object(
    'il_id', i.id, 'il', i.ad, 'nufus', i.mv, 'gelismislik', oyun.mulk_il_gelismislik(i.id),
    'benim_ilim', i.id = (select p.il_id from oyun.profiller p where p.id = auth.uid()),
    'vergi_oran', oyun.mulk_vergi_oran(i.id), 'carpan', oyun.il_duz(i.id, 'mulk_vergi_yerel'),
    'urunler', (select jsonb_agg(jsonb_build_object(
        'tip', v.tip, 'kontenjan', oyun.mulk_il_kota(i.id, v.tip),
        'kalan', greatest(0, oyun.mulk_il_kota(i.id, v.tip) - coalesce((select n from sahip s where s.il_id = i.id and s.tip = v.tip), 0)),
        'fiyat', oyun.mulk_il_bedel(i.id, v.tip), 'kira', oyun.mulk_il_kira(i.id, v.tip),
        'vergi', round(oyun.mulk_il_bedel(i.id, v.tip) * oyun.mulk_vergi_oran(i.id) / 100.0)) order by v.sira)
      from (values ('daire', 1), ('dukkan', 2), ('villa', 3)) v(tip, sira))
  )), '[]'::jsonb)
  from oyun.iller i
$$;
revoke all on function public.mulk_il_stok() from public, anon;
grant execute on function public.mulk_il_stok() to authenticated;

create or replace function public.mulk_il_satin_al(p_tip text, p_il integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_il smallint := p_il; u uuid := auth.uid(); t timestamptz := oyun.simdi(); c oyun.iller; f numeric; k numeric; yeni bigint; mevcut int;
  tipad text := case p_tip when 'daire' then 'daire' when 'dukkan' then 'dükkân' when 'villa' then 'villa' end;
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u and not yasakli) then raise exception 'Oyuncu profili gerekli.'; end if;
  if tipad is null then raise exception 'Geçersiz mülk türü.'; end if;
  if v_il is null then raise exception 'Satın alacağın ili seç.'; end if;
  select * into c from oyun.iller where id = v_il for update;   -- aynı ilde eş zamanlı alımlar sırayla işlenir
  if c.id is null then raise exception 'İl bulunamadı.'; end if;
  select count(*) into mevcut from oyun.yatirim_mulkleri where il_id = v_il and tip = p_tip;
  if mevcut >= oyun.mulk_il_kota(v_il, p_tip) then
    raise exception '% ilinde satılık yeni % kalmadı. Oyuncuların ilanlarına bakabilirsin.', c.ad, tipad;
  end if;
  f := oyun.mulk_il_bedel(v_il, p_tip); k := oyun.mulk_il_kira(v_il, p_tip);
  perform oyun.mulk_kira_tahsil(u);
  perform oyun.para_islem(u, -f, 'emlak', format('%s: yeni %s satın alındı', c.ad, tipad), t);
  insert into oyun.yatirim_mulkleri(user_id, il_id, tip, alis_bedeli, haftalik_kira, satin_alma, sonraki_kira, vergi_sonraki)
  values (u, v_il, p_tip, f, k, t, t + interval '7 days', t + interval '7 days') returning id into yeni;
  insert into oyun.ticaret_devir_kayit(tur, varlik_id, satici, alici, bedel, zaman, aciklama)
  values ('mulk_devlet', yeni, null, u, f, t, format('%s ilinden %s satın alındı', c.ad, tipad));
  return public.mulk_liste();
end $$;
revoke all on function public.mulk_il_satin_al(text, integer) from public, anon;
grant execute on function public.mulk_il_satin_al(text, integer) to authenticated;

-- Eski uygulama sürümleri: kendi ilinden, aynı stok ve il fiyatıyla alır.
create or replace function public.mulk_satin_al(p_tip text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  return public.mulk_il_satin_al(p_tip, (select p.il_id from oyun.profiller p where p.id = auth.uid()));
end $$;
revoke all on function public.mulk_satin_al(text) from public, anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function public.mulk_liste() returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare u uuid := auth.uid(); p oyun.profiller; j jsonb;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  select * into p from oyun.profiller where id = u;
  if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
  perform oyun.mulk_kira_tahsil(u);
  select jsonb_build_object(
    'mulkler', coalesce(jsonb_agg(jsonb_build_object(
       'id', m.id, 'tip', m.tip, 'il', i.ad, 'il_id', m.il_id, 'alis', m.alis_bedeli, 'deger', oyun.mulk_il_bedel(m.il_id, m.tip),
       'haftalik', m.haftalik_kira, 'sonraki', m.sonraki_kira,
       'toplam_kira', m.toplam_kira, 'kira_sayisi', m.kira_sayisi,
       'vergi', oyun.mulk_haftalik_vergi_tutar(m.id), 'vergi_sonraki', m.vergi_sonraki, 'vergi_borc', m.vergi_borc
    ) order by m.satin_alma desc, m.id desc), '[]'::jsonb),
    'adet', count(m.id),
    'haftalik_toplam', coalesce(sum(m.haftalik_kira), 0),
    'haftalik_vergi', coalesce(sum(oyun.mulk_haftalik_vergi_tutar(m.id)), 0),
    'vergi_borc', coalesce(sum(m.vergi_borc), 0),
    'mulk_degeri', coalesce(sum(m.alis_bedeli), 0),
    'piyasa_degeri', coalesce(sum(oyun.mulk_il_bedel(m.il_id, m.tip)), 0),
    'ulusal_oran', oyun.duz('mulk_vergi_ulusal'),
    'cuzdan', (select para from oyun.cuzdan where user_id = u)
  ) into j
  from oyun.yatirim_mulkleri m join oyun.iller i on i.id = m.il_id where m.user_id = u;
  return j;
end $function$;

-- Belediye başkanı için: ildeki mülkler ve son 7 günün vergi geliri
create or replace function public.belediye_emlak_ozet() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); il smallint; t timestamptz := oyun.simdi();
begin
  select m.il_id into il from oyun.makamlar m where m.user_id = p.id and m.tur = 'bel' and m.bit is null limit 1;
  il := coalesce(il, p.il_id);
  return jsonb_build_object('il_id', il, 'il', (select ad from oyun.iller where id = il),
    'mulk', (select count(*) from oyun.yatirim_mulkleri where il_id = il),
    'haftalik_vergi', (select coalesce(sum(tutar), 0) from oyun.emlak_vergi_tahsilat where il_id = il and zaman > t - interval '7 days'),
    'toplam_vergi', (select coalesce(sum(tutar), 0) from oyun.emlak_vergi_tahsilat where il_id = il),
    'oran', oyun.mulk_vergi_oran(il), 'ulusal_oran', oyun.duz('mulk_vergi_ulusal'), 'carpan', oyun.il_duz(il, 'mulk_vergi_yerel'));
end $$;
revoke all on function public.belediye_emlak_ozet() from public, anon;
grant execute on function public.belediye_emlak_ozet() to authenticated;
-- =====================================================================
--  45 · 9 EKİM DENEME GEÇİŞLERİNİN TEMİZLİĞİ
--  9 Ekim'de aynı emlak/meclis isteği için birbirinin yerine geçen ~20 deneme migration'ı üretildi.
--  Canlıda hangileri çalıştırılmış olursa olsun bu modül onların bıraktığı tetikleyicileri,
--  eski satın alma kapılarını ve ölü kuralları kaldırır; geçerli tanım 43 ve 44 modülleridir.
--  Temiz bir kurulumda hiçbir şey yapmaz.
-- =====================================================================
do $$
declare r record;
begin
  -- 1) Kanunlar ve mülk tablosundaki deneme tetikleyicileri (geçerli olan yalnız mulk_devir_vergi)
  for r in select tgname, tgrelid::regclass rel from pg_trigger
           where not tgisinternal and tgrelid in ('oyun.kanunlar'::regclass, 'oyun.yatirim_mulkleri'::regclass)
             and tgname like 'emlak%' loop
    execute format('drop trigger if exists %I on %s', r.tgname, r.rel);
  end loop;

  -- 2) Deneme sürümlerinde kalan, yeni stok/fiyat kuralını atlayabilecek fonksiyonlar
  --    (geçerli emlak_* fonksiyonları yalnız emlak_pazarlik_* ve _emlak_pazarlik_tamamla)
  for r in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('oyun','public')
             and ((p.proname ~ '^(emlak_|belediye_emlak_vergi)' and p.proname !~ '^emlak_pazarlik')
                  or p.proname in ('kanun_karar_yeter','mulk_il_fiyat','mulk_katalog','mulk_satin_al_il','mulk_sehir_satin_al')) loop
    execute format('drop function if exists %s cascade', r.f);
  end loop;

  -- 2b) Eski uygulamanın çağırdığı tek parametreli mulk_satin_al dışındaki deneme kopyaları
  for r in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'mulk_satin_al' and p.pronargs <> 1 loop
    execute format('drop function if exists %s', r.f);
  end loop;

  -- 3) Deneme sütunlarındaki NOT NULL kısıtları yeni mülk eklemeyi engellemesin
  for r in select attname from pg_attribute
           where attrelid = 'oyun.yatirim_mulkleri'::regclass and attnum > 0 and not attisdropped and attnotnull
             and attname in ('emlak_vergi_son','emlak_vergi_sonraki','sonraki_emlak_vergi','sonraki_vergi','vergi_borcu','toplam_vergi') loop
    execute format('alter table oyun.yatirim_mulkleri alter column %I drop not null', r.attname);
  end loop;
end $$;

-- 4) Deneme sürümlerinin bekleyen "emlak vergisi" serbest kanun teklifleri düşer (artık "Kural düzenlemesi" kanunuyla değişir)
update oyun.kanunlar set durum = 'dustu', sonuc_at = oyun.simdi(),
  sonuc_metin = 'Teklif, mülk vergisi sisteminin yenilenmesiyle düştü. Haftalık mülk vergisi artık "Kural düzenlemesi" kanunuyla değiştirilir.'
where tur = 'serbest' and durum in ('gorusmede','oylamada','cb_onayinda','israr')
  and (veri ->> 'ozel_tur' = 'emlak_vergisi' or baslik ilike '%emlak vergi%');

-- 5) Deneme kurallarının kalıntıları (geçerli kodlar: mulk_vergi_ulusal, mulk_vergi_yerel)
--    ('emlak' = ildeki herkesin günlük emlak vergisi, asıl kuraldır; ona dokunulmaz)
delete from oyun.il_duzenleme where kod ~ '^(emlak_|yatirim_emlak)';
delete from oyun.duzenlemeler where kod ~ '^(emlak_|yatirim_emlak)';
delete from oyun.duzenleme_tanim where kod ~ '^(emlak_|yatirim_emlak)';
delete from oyun.yasa_ekonomi_ayar where kod = 'emlak_haftalik_baz';

-- 6) Bir deneme sürümü Meclis ölçeğini sabit 600'e bağlamıştı; asıl tanım (39) geri yüklenir.
create or replace function oyun.meclis_olcek_hesap(t timestamptz) returns jsonb
language plpgsql stable set search_path = '' as $$
declare a numeric := (select meclis_olcek from oyun.ayarlar where id = 1);
        anayasal int := coalesce((select round(deger)::int from oyun.anayasa where kod = 'milletvekili_sayisi'), 600);
        aktif int := (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '14 days');
        n int;
begin
  n := case when coalesce(a, 0) <= 0 then anayasal else least(anayasal, greatest(81, ceil(aktif * a)::int)) end;
  return jsonb_build_object('aktif', aktif, 'sandalye', n, 'anayasal', anayasal, 'olcek', a);
end $$;

-- ---------------------------------------------------------------------
-- Deneme migration'larının değiştirdiği asıl fonksiyonlar temiz kurulumdaki hâline döner
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION oyun._emlak_pazarlik_tamamla(p_teklif bigint, p_fiyat numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare z oyun.emlak_pazarlik;i oyun.mulk_ilan; m oyun.yatirim_mulkleri;
  vergi numeric;t timestamptz:=oyun.simdi();
begin
 select * into z from oyun.emlak_pazarlik where id=p_teklif for update;
 if z.id is null or z.durum not in ('bekliyor','karsi') then raise exception 'Teklif artık geçerli değil.'; end if;
 if p_fiyat is null or p_fiyat<10000 or p_fiyat>1000000000 then raise exception 'Geçersiz teklif bedeli.'; end if;
 select * into i from oyun.mulk_ilan where id=z.ilan_id for update;
 if i.id is null or i.durum<>'acik' or i.satici<>z.satici then raise exception 'İlan artık geçerli değil.'; end if;
 select * into m from oyun.yatirim_mulkleri where id=i.mulk_id for update;
 if m.id is null or m.user_id<>i.satici then raise exception 'Mülk artık satışta değil.'; end if;
 if z.alici=z.satici then raise exception 'Kendi mülkünü alamazsın.'; end if;
 perform oyun.mulk_kira_tahsil(z.satici);
 vergi:=round(p_fiyat*0.02);
 perform oyun.para_islem(z.alici,-p_fiyat,'emlak','Pazarlıkla mülk satın alındı #'||i.mulk_id,t);
 perform oyun.para_islem(z.satici,p_fiyat-vergi,'emlak','Pazarlıkla mülk satışı #'||i.mulk_id,t);
 update oyun.ulke set hazine=hazine+vergi/1000000.0 where id=1;
 update oyun.yatirim_mulkleri set user_id=z.alici,satin_alma=t,alis_bedeli=p_fiyat,sonraki_kira=t+interval '7 days',
   toplam_kira=0,kira_sayisi=0 where id=m.id;
 update oyun.mulk_ilan set durum='satildi',alici=z.alici,kapanma=t where id=i.id;
 update oyun.emlak_pazarlik set durum='kabul',sonuc_at=t where id=z.id;
 update oyun.emlak_pazarlik set durum='iptal',sonuc_at=t where ilan_id=i.id and id<>z.id and durum in ('bekliyor','karsi');
 perform oyun.bildir(z.alici,format('Pazarlık kabul edildi! Mülk #%s %s ₺ karşılığında senin.',i.mulk_id,oyun.tl(p_fiyat)),t);
 perform oyun.bildir(z.satici,format('Mülk #%s %s ₺ karşılığında satıldı; %%2 işlem vergisi kesildi.',i.mulk_id,oyun.tl(p_fiyat)),t);
end $function$
;
CREATE OR REPLACE FUNCTION oyun.belediye_gunluk(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare r record; h record; v_kasa numeric; bas uuid;
begin
  for r in select d.il_id, i.ad, i.mv from oyun.il_durum d join oyun.iller i on i.id = d.il_id loop
    update oyun.il_durum set kasa = least(60 * oyun.il_gelir(r.il_id), coalesce(kasa, 0) + oyun.il_gelir(r.il_id)) - oyun.il_gider(r.il_id)
     where il_id = r.il_id returning kasa into v_kasa;
    if v_kasa < 0 then
      bas := (select user_id from oyun.makamlar where tur = 'bel' and il_id = r.il_id and bit is null limit 1);
      update oyun.il_durum set hemsehri = 0 where il_id = r.il_id and hemsehri > 0;
      for h in select k.kod, b.ad from oyun.il_hizmet k join oyun.belediye_hizmetleri b on b.kod = k.kod
               where k.il_id = r.il_id order by b.oran desc loop
        exit when (select kasa from oyun.il_durum where il_id = r.il_id) >= 0;
        delete from oyun.il_hizmet where il_id = r.il_id and kod = h.kod;
        update oyun.il_durum set kasa = kasa + oyun.hizmet_gider(r.il_id, h.kod) where il_id = r.il_id;
        perform oyun.olay('belediye', format('%s Belediyesi kasası yetmediği için %s hizmetini kapattı.', r.ad, h.ad), r.il_id, null, t);
      end loop;
      if bas is not null then perform oyun.bildir(bas, 'Belediye kasası eksiye düştü: hemşehri desteği durduruldu, gerekirse hizmetler kapatıldı.', t); end if;
      update oyun.il_durum set kasa = greatest(kasa, 0) where il_id = r.il_id;
    end if;
  end loop;
  -- gelişmişlik yatırım almazsa yavaşça ortalamaya döner; memnuniyet hizmetlere, desteğe ve vergiye göre şekillenir
  update oyun.il_durum d set gelisim = gelisim + (50 - gelisim) * 0.01,
    memnuniyet = oyun.sinir(memnuniyet + (50 + 4 * (select count(*) from oyun.il_hizmet ih where ih.il_id = d.il_id) + least(10, hemsehri / 30)
                                          - kent_vergisi * 2 - oyun.il_duz(d.il_id, 'emlak') / 30 - memnuniyet) * 0.05, 0, 100);
end $function$
;
CREATE OR REPLACE FUNCTION oyun.gunluk_kesinti(u uuid, t timestamp with time zone)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
declare p oyun.profiller; c oyun.cuzdan; s numeric; muaf numeric; ks numeric := 0; em numeric; top numeric := 0; ilad text; banka numeric; a numeric; b numeric;
begin
  select * into p from oyun.profiller where id = u;
  select * into c from oyun.cuzdan where user_id = u;
  s := oyun.duz('servet_vergisi');
  if s > 0 then
    muaf := round(250000 * (select endeks from oyun.ulke where id = 1));
    banka := oyun.mevduat_toplam(u);            -- bankadaki mevduat da servete dahildir (15_ekonomi3)
    ks := floor(greatest(0, c.para + banka - muaf) * s / 1000);
    if ks > 0 then
      a := least(ks, c.para);
      if a > 0 then
        perform oyun.para_islem(u, -a, 'servet', format('Servet vergisi (binde %s, %s ₺ muafiyetin üstü%s)', replace(s::text, '.', ','), oyun.tl(muaf),
                                                       case when banka > 0 then ', banka mevduatı dahil' else '' end), t);
      end if;
      b := least(ks - a, floor(coalesce((select vadesiz from oyun.banka_musteri where user_id = u), 0)));
      if b > 0 then
        update oyun.banka_musteri set vadesiz = vadesiz - b where user_id = u;
        perform oyun.banka_kayit(u, 'vadesiz', -b, 'Servet vergisi (cüzdan yetmedi)', t);
      end if;
      top := top + a + b;
    end if;
  end if;
  em := round(oyun.il_duz(p.il_id, 'emlak') * (select endeks from oyun.ulke where id = 1));
  if em > 0 then
    em := least(em, (select para from oyun.cuzdan where user_id = u));
    if em > 0 then
      select ad into ilad from oyun.iller where id = p.il_id;
      perform oyun.para_islem(u, -em, 'emlak', ilad || ' Belediyesi emlak vergisi (günlük)', t);
      top := top + em;
    end if;
  end if;
  perform oyun.kira_ode(u, t);
  return top;
end $function$
;
CREATE OR REPLACE FUNCTION oyun.il_gelir(p_il smallint)
 RETURNS numeric
 LANGUAGE sql
 STABLE
AS $function$
  select round(oyun.il_gunluk_gelir(i.mv) * u.endeks * (0.5 + d.gelisim / 100) * (0.5 + 0.5 * u.belediye_payi / 10) * (1 + d.kent_vergisi / 10)
               + oyun.il_duz(i.id, 'emlak') * u.endeks * oyun.nufus('il_hane') * i.mv / 600 / 1e9, 4)
  from oyun.iller i join oyun.il_durum d on d.il_id = i.id, oyun.ulke u where i.id = p_il and u.id = 1
$function$
;
CREATE OR REPLACE FUNCTION oyun.il_kurallar_json(p_il smallint, t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select jsonb_agg(jsonb_build_object('kod',d.kod,'ad',d.ad,'birim',d.birim,'tur',d.tur,
    'min',greatest(d.min,d.varsayilan-(d.varsayilan-d.min)*coalesce(oyun.anayasa_deger('yerel_yetki'),100)/100.0),
    'max',least(d.max,d.varsayilan+(d.max-d.varsayilan)*coalesce(oyun.anayasa_deger('yerel_yetki'),100)/100.0),
    'adim',d.adim,'aciklama',d.aciklama,'oyuncu',d.oyuncu,'devlet',d.devlet,'deger',oyun.il_duz(p_il,d.kod),
    'yazi',oyun.duz_yaz(d.kod,oyun.il_duz(p_il,d.kod)),
    'hazir',(select z.zaman+interval '24 hours' from oyun.il_duzenleme z where z.il_id=p_il and z.kod=d.kod and z.zaman>t-interval '24 hours'),
    'gunluk_gelir',case when d.kod='emlak' then round(oyun.il_duz(p_il,'emlak')*(select endeks from oyun.ulke where id=1)*oyun.nufus('il_hane')*(select mv from oyun.iller where id=p_il)/600/1e9,4) end,
    'birim_maliyet',case when d.kod='hosgeldin' then round(oyun.il_duz(p_il,'hosgeldin')*2000/1e9,4) end) order by d.sira)
  from oyun.duzenleme_tanim d where d.kapsam='il'
$function$
;
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
    if dolu > 0 and c.kabul >= floor(dolu / 2.0) + 1 then
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
        sonuc_metin = format('Salt çoğunluk sağlanamadı: %s kabul, %s ret, %s çekimser (dolu %s sandalyeden en az %s EVET gerekir).', c.kabul, c.ret, c.cekimser, dolu, floor(dolu / 2.0) + 1)
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
;
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
;
CREATE OR REPLACE FUNCTION oyun.meclis_olcek_hesap(t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare a numeric := (select meclis_olcek from oyun.ayarlar where id = 1);
        anayasal int := coalesce((select round(deger)::int from oyun.anayasa where kod = 'milletvekili_sayisi'), 600);
        aktif int := (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '14 days');
        n int;
begin
  n := case when coalesce(a, 0) <= 0 then anayasal else least(anayasal, greatest(81, ceil(aktif * a)::int)) end;
  return jsonb_build_object('aktif', aktif, 'sandalye', n, 'anayasal', anayasal, 'olcek', a);
end $function$
;
CREATE OR REPLACE FUNCTION oyun.mulk_kira_tahsil(p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare m record; n int; gross numeric; tax numeric; t timestamptz := oyun.simdi();
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 78113));
  for m in select * from oyun.yatirim_mulkleri where user_id = p_user and sonraki_kira <= t order by id for update loop
    n := least(520, floor(extract(epoch from (t - m.sonraki_kira)) / 604800)::int + 1);
    gross := round(m.haftalik_kira * n, 2);
    tax := case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id = p_user
                        and (x.satin_alma < m.satin_alma or (x.satin_alma = m.satin_alma and x.id <= m.id))) >= 3
                then round(gross * oyun.yasa_oran('coklu_mulk_vergi') / 100, 2) else 0 end;
    perform oyun.para_islem(p_user, gross - tax, 'kira', format('Mülk #%s: %s haftalık kira, vergi %s ₺', m.id, n, tax), t, tax);
    if tax > 0 then update oyun.ulke set hazine = hazine + tax / 1000000 where id = 1; end if;
    update oyun.yatirim_mulkleri set sonraki_kira = sonraki_kira + n * interval '7 days', toplam_kira = toplam_kira + gross - tax,
      kira_sayisi = kira_sayisi + n where id = m.id;
  end loop;
  perform oyun.mulk_haftalik_vergi(p_user);
end $function$
;
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
    'dolu', dolu, 'toplanti_yeter', ceil(dolu / 3.0), 'karar_yeter', floor(dolu / 4.0) + 1, 'israr_yeter', floor(dolu / 2.0) + 1,
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
;
CREATE OR REPLACE FUNCTION public.mulk_il_satin_al(p_tip text, p_il integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_il smallint := p_il; u uuid := auth.uid(); t timestamptz := oyun.simdi(); c oyun.iller; f numeric; k numeric; yeni bigint; mevcut int;
  tipad text := case p_tip when 'daire' then 'daire' when 'dukkan' then 'dükkân' when 'villa' then 'villa' end;
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u and not yasakli) then raise exception 'Oyuncu profili gerekli.'; end if;
  if tipad is null then raise exception 'Geçersiz mülk türü.'; end if;
  if v_il is null then raise exception 'Satın alacağın ili seç.'; end if;
  select * into c from oyun.iller where id = v_il for update;   -- aynı ilde eş zamanlı alımlar sırayla işlenir
  if c.id is null then raise exception 'İl bulunamadı.'; end if;
  select count(*) into mevcut from oyun.yatirim_mulkleri where il_id = v_il and tip = p_tip;
  if mevcut >= oyun.mulk_il_kota(v_il, p_tip) then
    raise exception '% ilinde satılık yeni % kalmadı. Oyuncuların ilanlarına bakabilirsin.', c.ad, tipad;
  end if;
  f := oyun.mulk_il_bedel(v_il, p_tip); k := oyun.mulk_il_kira(v_il, p_tip);
  perform oyun.mulk_kira_tahsil(u);
  perform oyun.para_islem(u, -f, 'emlak', format('%s: yeni %s satın alındı', c.ad, tipad), t);
  insert into oyun.yatirim_mulkleri(user_id, il_id, tip, alis_bedeli, haftalik_kira, satin_alma, sonraki_kira, vergi_sonraki)
  values (u, v_il, p_tip, f, k, t, t + interval '7 days', t + interval '7 days') returning id into yeni;
  insert into oyun.ticaret_devir_kayit(tur, varlik_id, satici, alici, bedel, zaman, aciklama)
  values ('mulk_devlet', yeni, null, u, f, t, format('%s ilinden %s satın alındı', c.ad, tipad));
  return public.mulk_liste();
end $function$
;
CREATE OR REPLACE FUNCTION public.mulk_il_stok()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with sahip as (select il_id, tip, count(*) n from oyun.yatirim_mulkleri group by il_id, tip)
  select coalesce(jsonb_agg(jsonb_build_object(
    'il_id', i.id, 'il', i.ad, 'nufus', i.mv, 'gelismislik', oyun.mulk_il_gelismislik(i.id),
    'benim_ilim', i.id = (select p.il_id from oyun.profiller p where p.id = auth.uid()),
    'vergi_oran', oyun.mulk_vergi_oran(i.id), 'carpan', oyun.il_duz(i.id, 'mulk_vergi_yerel'),
    'urunler', (select jsonb_agg(jsonb_build_object(
        'tip', v.tip, 'kontenjan', oyun.mulk_il_kota(i.id, v.tip),
        'kalan', greatest(0, oyun.mulk_il_kota(i.id, v.tip) - coalesce((select n from sahip s where s.il_id = i.id and s.tip = v.tip), 0)),
        'fiyat', oyun.mulk_il_bedel(i.id, v.tip), 'kira', oyun.mulk_il_kira(i.id, v.tip),
        'vergi', round(oyun.mulk_il_bedel(i.id, v.tip) * oyun.mulk_vergi_oran(i.id) / 100.0)) order by v.sira)
      from (values ('daire', 1), ('dukkan', 2), ('villa', 3)) v(tip, sira))
  )), '[]'::jsonb)
  from oyun.iller i
$function$
;
CREATE OR REPLACE FUNCTION public.mulk_ilan_satin_al(p_ilan bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); a oyun.mulk_ilan%rowtype; m oyun.yatirim_mulkleri%rowtype;
 v_satis_vergisi numeric; t timestamptz:=oyun.simdi();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 select * into a from oyun.mulk_ilan where id=p_ilan for update;
 if not found or a.durum<>'acik' then raise exception 'İlan artık açık değil'; end if;
 if a.satici=u then raise exception 'Kendi mülkünü satın alamazsın'; end if;
 select * into m from oyun.yatirim_mulkleri where id=a.mulk_id for update;
 if not found or m.user_id<>a.satici then raise exception 'Satıcı artık mülkün sahibi değil'; end if;
 perform oyun.mulk_kira_tahsil(a.satici);
 v_satis_vergisi:=round(a.fiyat*0.02);
 perform oyun.para_islem(u,-a.fiyat,'emlak','Oyuncudan mülk satın alındı #'||a.mulk_id,t);
 perform oyun.para_islem(a.satici,a.fiyat-v_satis_vergisi,'emlak','Mülk satışı #'||a.mulk_id,t);
 update oyun.ulke set hazine=hazine+v_satis_vergisi/1000000.0 where id=1;
 update oyun.yatirim_mulkleri set user_id=u,satin_alma=t,alis_bedeli=a.fiyat,
   sonraki_kira=t+interval '7 days',toplam_kira=0,kira_sayisi=0 where id=m.id;
 update oyun.mulk_ilan set durum='satildi',alici=u,kapanma=t where id=a.id;
 perform oyun.bildir(a.satici,'Satıştaki mülkün satıldı. Satış vergisi %2.',t);
 return public.mulk_pazar();
end $function$
;
CREATE OR REPLACE FUNCTION public.mulk_liste()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid := auth.uid(); p oyun.profiller; j jsonb;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  select * into p from oyun.profiller where id = u;
  if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
  perform oyun.mulk_kira_tahsil(u);
  select jsonb_build_object(
    'mulkler', coalesce(jsonb_agg(jsonb_build_object(
       'id', m.id, 'tip', m.tip, 'il', i.ad, 'il_id', m.il_id, 'alis', m.alis_bedeli, 'deger', oyun.mulk_il_bedel(m.il_id, m.tip),
       'haftalik', m.haftalik_kira, 'sonraki', m.sonraki_kira,
       'toplam_kira', m.toplam_kira, 'kira_sayisi', m.kira_sayisi,
       'vergi', oyun.mulk_haftalik_vergi_tutar(m.id), 'vergi_sonraki', m.vergi_sonraki, 'vergi_borc', m.vergi_borc
    ) order by m.satin_alma desc, m.id desc), '[]'::jsonb),
    'adet', count(m.id),
    'haftalik_toplam', coalesce(sum(m.haftalik_kira), 0),
    'haftalik_vergi', coalesce(sum(oyun.mulk_haftalik_vergi_tutar(m.id)), 0),
    'vergi_borc', coalesce(sum(m.vergi_borc), 0),
    'mulk_degeri', coalesce(sum(m.alis_bedeli), 0),
    'piyasa_degeri', coalesce(sum(oyun.mulk_il_bedel(m.il_id, m.tip)), 0),
    'ulusal_oran', oyun.duz('mulk_vergi_ulusal'),
    'cuzdan', (select para from oyun.cuzdan where user_id = u)
  ) into j
  from oyun.yatirim_mulkleri m join oyun.iller i on i.id = m.il_id where m.user_id = u;
  return j;
end $function$
;
CREATE OR REPLACE FUNCTION public.mulk_satin_al(p_tip text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  return public.mulk_il_satin_al(p_tip, (select p.il_id from oyun.profiller p where p.id = auth.uid()));
end $function$
;
commit;
