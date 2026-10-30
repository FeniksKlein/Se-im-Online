-- 148 (30.10.2026) — EKONOMİK DENGE VE REKABET KORUMASI
-- Amaç: (1) zengin oyuncular tek başına ya da birlikte başkalarının banka/şirketini batıramasın,
--       (2) servet birkaç kişide toplanıp makas açılmasın. Kalıcı ve kendini ayarlayan kurallar:
--   • Kademeli servet vergisi: eşikler oyuncuların MEDYAN servetine bağlı (ekonomi büyüdükçe kendiliğinden ayarlanır).
--   • Fırsat Eşitliği Fonu: verginin yarısı her gün medyanın altındaki aktif oyunculara eşit dağıtılır.
--   • Otomatik Rekabet Kurumu: zarar edip en düşük fiyattan satarak pazarı ele geçiren zengin şirket
--     her saat taranır; fiyatı 72 saat ortaya çekilir, cezası o pazardaki mağdur şirketlere tazminat olur.
--   • Paravan yasağı: aynı kişi (ya da aynı cihazdaki hesapları) aynı il+sektör pazarına ikinci şirket sokamaz.
--   • Banka hücumu kalkanı: vadesiz mevduat da bankanın ödeme gücü sınırına bağlandı.
--   • Kaçak yol kapatıldı: oyuncu bankası içi havale de günlük aktarım sınırına ve aynı cihaz yasağına tabi.
-- Oyuncu verisini dönüştürmez; yalnız yeni tablo/fonksiyon/tetik ekler.

-- ===================== AYARLAR ve KAYITLAR =====================
create table if not exists oyun.denge_ayar (
  id int primary key default 1 check (id = 1),
  aktif boolean not null default true,
  esik1 numeric not null default 10,   -- medyanın katı: bu üstü %oran1
  esik2 numeric not null default 25,
  esik3 numeric not null default 50,
  oran1 numeric not null default 0.0010,  -- günlük
  oran2 numeric not null default 0.0020,
  oran3 numeric not null default 0.0035,
  taban_asgari numeric not null default 20,   -- 1. eşik en az asgari ücretin bu katı
  fon_pay numeric not null default 0.5,       -- verginin fona giden payı
  kisi_tavan_asgari numeric not null default 0.0667, -- kişi başı günlük fon tavanı (asgari ücretin oranı)
  koruma_kat numeric not null default 10,     -- yıkıcı rekabet incelemesine girecek sahip serveti (medyan katı)
  rekabet_pay numeric not null default 30,    -- pazar payı eşiği (%)
  rekabet_ceza numeric not null default 0.10, -- şirket kasasının oranı
  rekabet_saat int not null default 72
);
insert into oyun.denge_ayar(id, aktif) values (1, true) on conflict do nothing;  -- canlıda 30.10.2026'da doğrulanıp açıldı

create table if not exists oyun.denge_gun (
  gun date primary key, medyan numeric, gini numeric, toplam numeric, en_zengin_pay numeric, ust10_pay numeric,
  vergi numeric default 0, tahsil numeric default 0, fon numeric default 0, alici int default 0, zaman timestamptz);
create table if not exists oyun.servet_vergi (
  user_id uuid not null, gun date not null, servet numeric, vergi numeric, tahsil numeric, primary key (user_id, gun));
create table if not exists oyun.servet_vergi_borc (user_id uuid primary key, borc numeric not null default 0, guncelleme timestamptz);
create table if not exists oyun.firsat_fonu_odeme (user_id uuid not null, gun date not null, tutar numeric not null, primary key (user_id, gun));
create table if not exists oyun.yikici_rekabet (
  id bigserial primary key, sirket_id bigint not null, il_id smallint, sektor text, sahip uuid, neden text,
  ceza numeric default 0, bas timestamptz not null, bit timestamptz not null);
create index if not exists yikici_rekabet_s_ix on oyun.yikici_rekabet(sirket_id, bit desc);
alter table oyun.denge_ayar enable row level security;
alter table oyun.denge_gun enable row level security;
alter table oyun.servet_vergi enable row level security;
alter table oyun.servet_vergi_borc enable row level security;
alter table oyun.firsat_fonu_odeme enable row level security;
alter table oyun.yikici_rekabet enable row level security;

-- ===================== SERVET ÖLÇÜMÜ =====================
-- Nakit + devlet bankası vadesiz/vadeli + oyuncu bankası vadesiz/vadeli + hisse değeri + mülk
create or replace function oyun.net_servet_tablo()
returns table(user_id uuid, nakit numeric, hisse numeric, mulk numeric, toplam numeric)
language sql stable security definer set search_path = '' as $$
  with sd as (select s.id, oyun.sirket_deger(s.id) deger from oyun.sirketler s where s.aktif),
  h as (select o.user_id, sum(o.pay / 100.0 * sd.deger) v from oyun.sirket_ortaklari o join sd on sd.id = o.sirket_id group by o.user_id),
  n as (select p.id,
      coalesce((select c.para from oyun.cuzdan c where c.user_id = p.id), 0)
    + coalesce((select b.vadesiz from oyun.banka_musteri b where b.user_id = p.id), 0)
    + coalesce((select sum(v.anapara) from oyun.vadeli v where v.user_id = p.id and v.durum = 'acik'), 0)
    + coalesce((select sum(i.bakiye) from oyun.ib_vadesiz i where i.user_id = p.id), 0)
    + coalesce((select sum(m.anapara) from oyun.banka_mevduat m where m.user_id = p.id and not m.kapandi), 0) nakit,
      coalesce((select sum(m.bedel) from oyun.mulkler m where m.user_id = p.id), 0) mulk
    from oyun.profiller p where not p.yasakli)
  select n.id, round(n.nakit), round(coalesce(h.v, 0)), round(n.mulk), round(n.nakit + coalesce(h.v, 0) + n.mulk)
  from n left join h on h.user_id = n.id
$$;

create or replace function oyun.servet_esikler(p_medyan numeric)
returns numeric[] language sql stable security definer set search_path = '' as $$
  select array[
    greatest(a.esik1 * p_medyan, a.taban_asgari * u.asgari),
    greatest(a.esik2 * p_medyan, a.taban_asgari * u.asgari * 2.5),
    greatest(a.esik3 * p_medyan, a.taban_asgari * u.asgari * 5)]
  from oyun.denge_ayar a, oyun.ulke u where a.id = 1 and u.id = 1
$$;

create or replace function oyun.servet_vergisi(p_servet numeric, p_medyan numeric)
returns numeric language sql stable security definer set search_path = '' as $$
  select round(
      greatest(0, least(p_servet, e[2]) - e[1]) * a.oran1
    + greatest(0, least(p_servet, e[3]) - e[2]) * a.oran2
    + greatest(0, p_servet - e[3]) * a.oran3)
  from oyun.denge_ayar a, (select oyun.servet_esikler(p_medyan) e) x where a.id = 1
$$;

-- ===================== GÜNLÜK DENGE (vergi + fon) =====================
create or replace function oyun.denge_tick()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); g date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; a oyun.denge_ayar;
        med numeric; gin numeric; top numeric; ez numeric; u10 numeric; r record; vg numeric; kalan numeric; al numeric;
        c numeric; v numeric; tvergi numeric := 0; ttahsil numeric := 0; havuz numeric; kisi numeric; n int := 0; tlm numeric; asg numeric;
        pr oyun.profiller; alicilar uuid[] := '{}'; au uuid;
begin
  if not pg_try_advisory_xact_lock(hashtext('denge_tick')) then return null; end if;
  select * into a from oyun.denge_ayar where id = 1;
  if not a.aktif or exists(select 1 from oyun.denge_gun where gun = g) then return null; end if;
  select percentile_cont(.5) within group (order by toplam), sum(toplam) into med, top from oyun.net_servet_tablo();
  med := greatest(coalesce(med, 0), 1);
  select round((sum((2 * rn - cnt - 1) * v2) / nullif(cnt * sum(v2), 0))::numeric, 3) into gin
    from (select greatest(toplam, 0) v2, row_number() over (order by toplam) rn, count(*) over () cnt from oyun.net_servet_tablo()) z group by cnt;
  select round(100 * max(toplam) / nullif(top, 0), 1) into ez from oyun.net_servet_tablo();
  select round(100 * sum(toplam) / nullif(top, 0), 1) into u10 from (select toplam from oyun.net_servet_tablo() order by toplam desc limit greatest(1, (select count(*) from oyun.net_servet_tablo()) / 10)) q;
  tlm := oyun.pazar_tl_milyar(); asg := (select asgari from oyun.ulke where id = 1);

  -- 1) önce eski borçlar, sonra bugünkü vergi: cüzdandan, sonra devlet bankası vadesiz hesabından
  for r in select s.user_id, s.toplam, coalesce(b.borc, 0) borc from oyun.net_servet_tablo() s left join oyun.servet_vergi_borc b on b.user_id = s.user_id
           where coalesce(b.borc, 0) > 0 or s.toplam > (oyun.servet_esikler(med))[1] loop
    vg := oyun.servet_vergisi(r.toplam, med);
    kalan := vg + r.borc; al := 0;
    if kalan <= 0 then continue; end if;
    select para into c from oyun.cuzdan where user_id = r.user_id for update;
    c := least(greatest(coalesce(c, 0), 0), kalan);
    if c > 0 then perform oyun.para_islem(r.user_id, -c, 'vergi', 'Servet vergisi (kademeli, günlük)', t); al := al + c; kalan := kalan - c; end if;
    if kalan > 0 then
      select vadesiz into v from oyun.banka_musteri where user_id = r.user_id for update;
      v := least(greatest(coalesce(v, 0), 0), kalan);
      if v > 0 then
        update oyun.banka_musteri set vadesiz = vadesiz - v where user_id = r.user_id;
        perform oyun.banka_kayit(r.user_id, 'vadesiz', -v, 'Servet vergisi (kademeli, günlük)', t);
        al := al + v; kalan := kalan - v;
      end if;
    end if;
    insert into oyun.servet_vergi_borc(user_id, borc, guncelleme) values (r.user_id, kalan, t)
      on conflict (user_id) do update set borc = excluded.borc, guncelleme = t;
    if vg > 0 then
      insert into oyun.servet_vergi(user_id, gun, servet, vergi, tahsil) values (r.user_id, g, r.toplam, vg, al)
        on conflict (user_id, gun) do update set vergi = excluded.vergi, tahsil = excluded.tahsil;
      perform oyun.bildir(r.user_id, format('Servet vergisi: net servetin %s ₺, bugünkü vergin %s ₺ (tahsil edilen %s ₺%s). Ayrıntı: Ekonomi › Ekonomik Denge.',
        oyun.tl(r.toplam), oyun.tl(vg), oyun.tl(al), case when kalan > 0 then ', borç ' || oyun.tl(kalan) || ' ₺' else '' end), t);
    end if;
    tvergi := tvergi + vg; ttahsil := ttahsil + al;
  end loop;

  -- 2) Fırsat Eşitliği Fonu: medyanın altındaki aktif, şartları tamam oyunculara eşit pay
  havuz := floor(ttahsil * a.fon_pay);
  kisi := 0;
  for pr in select p.* from oyun.profiller p  join oyun.net_servet_tablo() s on s.user_id = p.id
            where not p.yasakli and s.toplam < med and p.son_gorulme > t - interval '3 days' and p.olusturma < t - interval '3 days' loop
    if oyun.uyari(pr, t) is null and not exists(select 1 from oyun.servet_vergi_borc b where b.user_id = pr.id and b.borc > 0) then
      alicilar := alicilar || pr.id; n := n + 1;
    end if;
  end loop;
  if n > 0 and havuz > 0 then
    kisi := least(floor(havuz / n), round(asg * a.kisi_tavan_asgari));
    if kisi >= 1 then
      foreach au in array alicilar loop
        perform oyun.para_islem(au, kisi, 'yardim', 'Fırsat Eşitliği Fonu (servet vergisinden)', t);
        insert into oyun.firsat_fonu_odeme(user_id, gun, tutar) values (au, g, kisi) on conflict do nothing;
      end loop;
    end if;
  end if;
  -- kalan her şey Hazine'ye
  if ttahsil - kisi * n > 0 then update oyun.ulke set hazine = hazine + (ttahsil - kisi * n) / tlm where id = 1; end if;
  insert into oyun.denge_gun(gun, medyan, gini, toplam, en_zengin_pay, ust10_pay, vergi, tahsil, fon, alici, zaman)
    values (g, med, gin, top, ez, u10, tvergi, ttahsil, kisi * n, case when kisi >= 1 then n else 0 end, t);
  if ttahsil > 0 then
    perform oyun.olay('ekonomi', format('Servet vergisinden %s ₺ toplandı; Fırsat Eşitliği Fonu %s oyuncuya kişi başı %s ₺ ödedi.',
      oyun.tl(ttahsil), case when kisi >= 1 then n else 0 end, oyun.tl(kisi)), null, null, t);
  end if;
  return jsonb_build_object('medyan', med, 'gini', gin, 'vergi', tvergi, 'tahsil', ttahsil, 'alici', n, 'kisi', kisi);
end $$;

-- ===================== OTOMATİK REKABET KURUMU (saatlik) =====================
create or replace function oyun.yikici_rekabet_tick()
returns int language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); a oyun.denge_ayar; med numeric; m record; x record; tah jsonb; c numeric; n int := 0;
        sahip_servet numeric; magdur int; pay_t numeric; y record; ilad text; sad text;
begin
  if not pg_try_advisory_xact_lock(hashtext('yikici_rekabet')) then return 0; end if;
  select * into a from oyun.denge_ayar where id = 1;
  if not a.aktif then return 0; end if;
  select medyan into med from oyun.denge_gun order by gun desc limit 1;
  if med is null then select percentile_cont(.5) within group (order by toplam) into med from oyun.net_servet_tablo(); end if;
  med := greatest(coalesce(med, 1), 1);
  for m in select ps.il_id, s.sektor from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id
           where s.aktif and s.sektor <> 'banka' group by ps.il_id, s.sektor
           having count(distinct oyun.sirket_sahibi(s.id)) >= 2 loop
    for x in select s.id, s.ad, s.kasa, ps.fiyat, oyun.sirket_sahibi(s.id) sahip
             from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id
             where ps.il_id = m.il_id and s.sektor = m.sektor and s.aktif and ps.fiyat <= 1 loop
      if exists(select 1 from oyun.yikici_rekabet r where r.sirket_id = x.id and r.bit > t) then continue; end if;
      tah := oyun.pazar_tahmin(x.id);
      if coalesce((tah->>'net')::numeric, 0) >= 0 or coalesce((tah->>'pay')::numeric, 0) < a.rekabet_pay then continue; end if;
      select toplam into sahip_servet from oyun.net_servet_tablo() z where z.user_id = x.sahip;
      if coalesce(sahip_servet, 0) < a.koruma_kat * med then continue; end if;
      -- Yıkıcı fiyat: zararına satış + hâkim pay + büyük sermaye
      c := round(greatest(0, x.kasa) * a.rekabet_ceza);
      update oyun.sirketler set kasa = kasa - c where id = x.id;
      update oyun.pazar_sirket set fiyat = 2, son_ayar = t where sirket_id = x.id;
      insert into oyun.yikici_rekabet(sirket_id, il_id, sektor, sahip, neden, ceza, bas, bit)
        values (x.id, m.il_id, m.sektor, x.sahip, format('Zararına satış (günlük net %s ₺), pazar payı %%%s, sahip serveti medyanın %s katı',
          oyun.tl((tah->>'net')::numeric), (tah->>'pay'), round(sahip_servet / med)), c, t, t + make_interval(hours => a.rekabet_saat));
      if c > 0 then insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
        values (x.id, t, -c, 'Rekabet Kurumu: yıkıcı fiyat cezası', 0, 0, 0); end if;
      -- ceza mağdur şirketlere tazminat
      select count(*) into magdur from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id
        where ps.il_id = m.il_id and s.sektor = m.sektor and s.aktif and s.id <> x.id and oyun.sirket_sahibi(s.id) is distinct from x.sahip
          and not exists(select 1 from oyun.bagli_hesaplar(x.sahip) b where b = oyun.sirket_sahibi(s.id));
      if magdur > 0 and c > 0 then
        pay_t := floor(c / magdur);
        for y in select s.id, s.ad, oyun.sirket_sahibi(s.id) sahip from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id
                 where ps.il_id = m.il_id and s.sektor = m.sektor and s.aktif and s.id <> x.id and oyun.sirket_sahibi(s.id) is distinct from x.sahip
                   and not exists(select 1 from oyun.bagli_hesaplar(x.sahip) b where b = oyun.sirket_sahibi(s.id)) loop
          update oyun.sirketler set kasa = kasa + pay_t where id = y.id;
          insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
            values (y.id, t, pay_t, 'Rekabet Kurumu: yıkıcı rekabet tazminatı', 0, 0, 0);
          perform oyun.bildir(y.sahip, format('Rekabet Kurumu, pazarındaki yıkıcı fiyat uygulaması nedeniyle %s şirketine %s ₺ tazminat ödedi. Rakibin fiyatı %s saat ortaya çekildi.', y.ad, oyun.tl(pay_t), a.rekabet_saat), t);
        end loop;
      elsif c > 0 then
        update oyun.ulke set hazine = hazine + c / oyun.pazar_tl_milyar() where id = 1;
      end if;
      select ad into ilad from oyun.iller where id = m.il_id; select ad into sad from oyun.pazar_sektor where kod = m.sektor;
      perform oyun.bildir(x.sahip, format('Rekabet Kurumu: %s zararına en düşük fiyattan satış yaparak %s pazarındaki rakipleri yıpratıyor. %s ₺ ceza verildi, fiyat %s saat en az orta seviyede kalacak.', x.ad, coalesce(ilad, ''), oyun.tl(c), a.rekabet_saat), t);
      perform oyun.olay('ekonomi', format('Rekabet Kurumu %s %s pazarında yıkıcı fiyat tespit etti: %s cezalandırıldı, ceza mağdur rakiplere tazminat olarak ödendi.', coalesce(ilad, ''), lower(coalesce(sad, m.sektor)), x.ad), m.il_id, null, t);
      n := n + 1;
    end loop;
  end loop;
  return n;
end $$;

-- Ceza süresince fiyat en az 2 (otopilot dahil her yerde)
create or replace function oyun.tg_yikici_fiyat() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.fiyat < 2 and exists(select 1 from oyun.yikici_rekabet r where r.sirket_id = new.sirket_id and r.bit > oyun.simdi()) then
    new.fiyat := 2;
  end if;
  return new;
end $$;
create or replace trigger tg_yikici_fiyat before update of fiyat on oyun.pazar_sirket for each row execute function oyun.tg_yikici_fiyat();

-- Paravan yasağı: aynı sahip (ve aynı cihazdaki hesapları) aynı il+sektör pazarına ikinci şirket sokamaz
create or replace function oyun.tg_paravan() returns trigger language plpgsql security definer set search_path = '' as $$
declare sh uuid; sek text;
begin
  if tg_op = 'UPDATE' and new.il_id is not distinct from old.il_id then return new; end if;
  sh := coalesce(oyun.sirket_sahibi(new.sirket_id), (select kurucu from oyun.sirketler where id = new.sirket_id));
  if sh is null then return new; end if;
  select sektor into sek from oyun.sirketler where id = new.sirket_id;
  if exists(select 1 from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id
            where ps.il_id = new.il_id and s.sektor = sek and s.aktif and s.id <> new.sirket_id
              and (oyun.sirket_sahibi(s.id) = sh or oyun.sirket_sahibi(s.id) in (select b from oyun.bagli_hesaplar(sh) b))) then
    raise exception 'Rekabet kuralı: bu ilde bu sektörde zaten bir şirketin var. Aynı pazara ikinci (paravan) şirket sokulamaz.';
  end if;
  return new;
end $$;
create or replace trigger tg_paravan before insert or update of il_id on oyun.pazar_sirket for each row execute function oyun.tg_paravan();

-- Servet vergisi borcu varken yeni şirket kurulamaz
create or replace function oyun.tg_vergi_borcu_sirket() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.kurucu is not null and exists(select 1 from oyun.servet_vergi_borc b where b.user_id = new.kurucu and b.borc > 0) then
    raise exception 'Servet vergisi borcun ödenmeden yeni şirket kuramazsın. Cüzdanına ya da banka hesabına para koyduğunda borç kendiliğinden tahsil edilir.';
  end if;
  return new;
end $$;
create or replace trigger tg_vergi_borcu_sirket before insert on oyun.sirketler for each row execute function oyun.tg_vergi_borcu_sirket();

-- ===================== BANKA HÜCUMU KALKANI =====================
-- Kişi sınırı artık vadeli + vadesiz toplamı; toplam sınır zaten ikisini sayıyordu
create or replace function oyun.oyb_mevduat_kapasite(p_banka bigint, p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b jsonb; oz numeric; vadesiz numeric; vadeli numeric; kisi numeric; kalan_t numeric; kalan_k numeric; azami numeric;
begin
  b := oyun.banka_bilanco(p_banka);
  oz := greatest(0, coalesce((b->>'ozkaynak')::numeric, 0));
  vadesiz := coalesce((b->>'vadesiz')::numeric, 0);
  vadeli := coalesce((b->>'vadeli_anapara')::numeric, 0);
  select coalesce(sum(anapara), 0) into kisi from oyun.banka_mevduat where banka_id = p_banka and user_id = p_user and not kapandi;
  kisi := kisi + coalesce((select bakiye from oyun.ib_vadesiz where banka_id = p_banka and user_id = p_user), 0);
  kalan_t := greatest(0, oz * 5 - vadesiz - vadeli);
  kalan_k := greatest(0, oz - kisi);
  azami := floor(least(kalan_t, kalan_k, 10000000) / 1000) * 1000;
  return jsonb_build_object('ozkaynak', round(oz), 'toplam_sinir', round(oz * 5), 'kisi_sinir', round(oz),
    'mevcut_mevduat', round(vadesiz + vadeli), 'senin_mevduatin', round(kisi), 'azami_tutar', azami);
end $$;
revoke all on function oyun.oyb_mevduat_kapasite(bigint, uuid) from public, anon, authenticated;

create or replace function public.ib_vadesiz_islem(p_banka bigint, p_tutar numeric, p_islem text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); b oyun.sirketler; v numeric; t numeric:=round(p_tutar,2); tm timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if t is null or t<1 or t>10000000 then raise exception 'Islem tutari 1 - 10.000.000 TL olmali';end if;
 if p_islem not in ('yatir','cek') then raise exception 'Gecersiz islem';end if;
 select * into b from oyun.sirketler where id=p_banka and sektor='banka' and aktif for update;
 if not found then raise exception 'Aktif banka bulunamadi';end if;
 if not oyun.oyb_hesap_acik(p_banka,u) then raise exception 'Once bu bankada hesap acmalisin';end if;
 insert into oyun.ib_vadesiz(banka_id,user_id) values(p_banka,u) on conflict do nothing;
 select bakiye into v from oyun.ib_vadesiz where banka_id=p_banka and user_id=u for update;
 if p_islem='yatir' then
   if not exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=p_banka and o.user_id=u and o.pay>0) then
     perform oyun.oyb_kapasite_kontrol(p_banka,u,t);
   end if;
   perform oyun.para_islem(u,-t,'banka','Vadesiz hesap yatirma: '||b.ad,tm);
   update oyun.sirketler set kasa=kasa+t where id=p_banka;
   update oyun.ib_vadesiz set bakiye=bakiye+t,guncelleme=tm where banka_id=p_banka and user_id=u;
   insert into oyun.ib_hareket(banka_id,user_id,tutar,aciklama,zaman) values(p_banka,u,t,'Cuzdandan vadesiz hesaba yatirma',tm);
 else
   if v<t then raise exception 'Vadesiz hesap bakiyen yetersiz';end if;
   update oyun.sirketler set kasa=kasa-t where id=p_banka and kasa>=t;
   if not found then raise exception 'Banka kasasi odemeyi karsilayamiyor';end if;
   update oyun.ib_vadesiz set bakiye=bakiye-t,guncelleme=tm where banka_id=p_banka and user_id=u;
   perform oyun.para_islem(u,t,'banka','Vadesiz hesap cekme: '||b.ad,tm);
   insert into oyun.ib_hareket(banka_id,user_id,tutar,aciklama,zaman) values(p_banka,u,-t,'Vadesiz hesaptan cuzdanima cekim',tm);
 end if;
 return jsonb_build_object('tamam',true,'bakiye',case when p_islem='yatir' then v+t else v-t end);
end $$;

-- ===================== AKTARIM KAÇAĞI =====================
create or replace function oyun.gunluk_aktarim(u uuid, t timestamptz)
returns numeric language plpgsql stable set search_path = '' as $$
begin
  return coalesce((select sum(tutar) from oyun.banka_transfer where gonderen = u and zaman >= oyun.bugun_bas(t)), 0)
       + coalesce((select sum(tutar) from oyun.serbest_bagis_kayit where gonderen = u and alici_tur in ('oyuncu','sirket','gazete')
                   and zaman >= oyun.bugun_bas(t)), 0)
       + coalesce((select sum(tutar) from oyun.banka_fast where gonderen = u and zaman >= oyun.bugun_bas(t)), 0)
       + coalesce((select sum(-tutar) from oyun.ib_hareket where user_id = u and tutar < 0 and aciklama like 'Havale: %' and zaman >= oyun.bugun_bas(t)), 0);
end $$;

create or replace function public.ib_havale(p_banka bigint, p_alici text, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); al uuid; t numeric:=round(p_tutar,2); v numeric; tm timestamptz:=oyun.simdi(); bugun numeric; tavan numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if t is null or t<1 or t>10000000 then raise exception 'Gecersiz havale tutari';end if;
 select id into al from oyun.profiller where lower(kad)=lower(trim(p_alici));
 if al is null or al=u then raise exception 'Gecerli bir baska alici sec';end if;
 if (select coklu_kontrol from oyun.ayarlar where id=1) and exists(select 1 from oyun.bagli_hesaplar(u) b where b=al) then
   raise exception 'Aynı cihazda açılmış hesaplar arasında havale yapılamaz.'; end if;
 if exists(select 1 from oyun.servet_vergi_borc b where b.user_id=u and b.borc>0) then
   raise exception 'Servet vergisi borcun ödenmeden başka oyuncuya para aktaramazsın.'; end if;
 bugun:=oyun.gunluk_aktarim(u,tm);
 tavan:=round((select asgari from oyun.ulke where id=1)*(select havale_sinir from oyun.ayarlar where id=1));
 if bugun+t>tavan then
   raise exception 'Günlük para aktarma sınırı % ₺ (bugün % ₺ gönderdin). Oyuncu bankası içi havaleler de bu sınıra dahildir.',oyun.tl(tavan),oyun.tl(bugun);
 end if;
 if not oyun.oyb_hesap_acik(p_banka,u) or not oyun.oyb_hesap_acik(p_banka,al) then
   raise exception 'Gonderen ve alicinin ayni bankada acik hesabi olmali';end if;
 perform 1 from oyun.ib_vadesiz where banka_id=p_banka and user_id in (u,al) order by user_id for update;
 insert into oyun.ib_vadesiz(banka_id,user_id) values(p_banka,u),(p_banka,al) on conflict do nothing;
 select bakiye into v from oyun.ib_vadesiz where banka_id=p_banka and user_id=u for update;
 if v<t then raise exception 'Havale icin yeterli paran yok';end if;
 update oyun.ib_vadesiz set bakiye=bakiye-t,guncelleme=tm where banka_id=p_banka and user_id=u;
 update oyun.ib_vadesiz set bakiye=bakiye+t,guncelleme=tm where banka_id=p_banka and user_id=al;
 insert into oyun.ib_hareket(banka_id,user_id,tutar,aciklama,zaman)
 values(p_banka,u,-t,'Havale: '||p_alici,tm),(p_banka,al,t,'Gelen havale: '||oyun.kad(u),tm);
 perform oyun.bildir(al,'Banka hesabina '||oyun.kad(u)||' tarafindan '||t||' TL havale geldi',tm);
 return jsonb_build_object('tamam',true,'tutar',t);
end $$;


-- para_gonder: servet vergisi borcu varken başka oyuncuya aktarım yok (vergiden kaçırma engeli)
create or replace function public.para_gonder(p_kad text, p_miktar numeric, p_aciklama text default null::text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); h oyun.profiller; m numeric:=round(coalesce(p_miktar,0));
  ack text; bugun numeric; tavan numeric; gm oyun.banka_musteri; am oyun.banka_musteri; tid bigint;
begin
  perform oyun.banka_acik_mi();
  h:=oyun.profil_bul(p_kad);
  if h.id=p.id then raise exception 'Kendine para gönderemezsin.'; end if;
  if h.yasakli then raise exception 'Bu oyuncunun hesabı kapatılmış.'; end if;
  if m<100 then raise exception 'En az 100 ₺ gönderebilirsin.'; end if;
  if oyun.uyari(p,t) is not null then raise exception 'Para göndermek için seçmen kartın hazır olmalı: %',oyun.uyari(p,t); end if;
  if (select coklu_kontrol from oyun.ayarlar where id=1)
     and exists(select 1 from oyun.bagli_hesaplar(p.id) b where b=h.id) then
    raise exception 'Aynı cihazda açılmış hesaplar arasında banka transferi yapılamaz.';
  end if;
  if exists(select 1 from oyun.servet_vergi_borc b where b.user_id=p.id and b.borc>0) then
    raise exception 'Servet vergisi borcun ödenmeden başka oyuncuya para aktaramazsın.';
  end if;
  if oyun.engelli(h.id,p.id) then raise exception 'Bu oyuncu seni engellediği için ona para gönderemezsin.'; end if;
  perform oyun.takip_engel(p.id,'banka transferi yapamazsın');
  bugun:=oyun.gunluk_aktarim(p.id,t);
  tavan:=round((select asgari from oyun.ulke where id=1)*(select havale_sinir from oyun.ayarlar where id=1));
  if bugun+m>tavan then
    raise exception 'Günlük para aktarma sınırı % ₺ (bugün havale ve hediyeyle % ₺ gönderdin).',oyun.tl(tavan),oyun.tl(bugun);
  end if;
  if nullif(btrim(coalesce(p_aciklama,'')),'') is not null then ack:=oyun.metin_temizle(p_aciklama,100); end if;
  gm:=oyun.vadesiz_isle(p.id,t);
  am:=oyun.vadesiz_isle(h.id,t);
  if gm.vadesiz<m then
    raise exception 'Transfer için vadesiz hesabında yeterli para yok. Bakiye: % ₺.',oyun.tl(gm.vadesiz);
  end if;
  if oyun.mevduat_toplam(h.id)+m>oyun.banka_tavani() then
    raise exception 'Alıcının banka mevduatı üst sınıra çok yakın. Bu transfer alıcının mevduat tavanını aşar.';
  end if;
  update oyun.banka_musteri set vadesiz=vadesiz-m where user_id=p.id;
  update oyun.banka_musteri set vadesiz=vadesiz+m where user_id=h.id;
  insert into oyun.banka_transfer(gonderen,alici,tutar,aciklama,zaman) values(p.id,h.id,m,ack,t) returning id into tid;
  perform oyun.banka_kayit(p.id,'vadesiz',-m,format('%s adlı oyuncuya banka transferi%s',h.kad,coalesce(': '||ack,'')),t);
  perform oyun.banka_kayit(h.id,'vadesiz',m,format('%s adlı oyuncudan banka transferi%s',p.kad,coalesce(': '||ack,'')),t);
  perform oyun.bildir(h.id,format('%s sana banka yoluyla %s ₺ gönderdi.%s',p.kad,oyun.tl(m),coalesce(' Not: “'||ack||'”','')),t);
  return jsonb_build_object('tamam',true,'transfer_id',tid,'alici',h.kad,'miktar',m,
    'bakiye',(select vadesiz from oyun.banka_musteri where user_id=p.id),'bugun',bugun+m,'tavan',tavan);
end $$;

-- ===================== OYUNCUYA GÖRÜNÜR PANEL =====================
create or replace function public.denge_paneli()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.denge_ayar; d oyun.denge_gun; ben record; med numeric; e numeric[];
begin
  select * into a from oyun.denge_ayar where id = 1;
  select * into d from oyun.denge_gun order by gun desc limit 1;
  select * into ben from oyun.net_servet_tablo() z where z.user_id = p.id;
  med := coalesce(d.medyan, (select percentile_cont(.5) within group (order by toplam) from oyun.net_servet_tablo()));
  e := oyun.servet_esikler(greatest(coalesce(med, 1), 1));
  return jsonb_build_object(
    'aktif', a.aktif,
    'gun', d.gun, 'medyan', round(med), 'gini', d.gini, 'en_zengin_pay', d.en_zengin_pay, 'ust10_pay', d.ust10_pay,
    'dun_vergi', d.tahsil, 'dun_fon', d.fon, 'dun_alici', d.alici,
    'dilimler', jsonb_build_array(
      jsonb_build_object('alt', 0, 'ust', e[1], 'oran', 0),
      jsonb_build_object('alt', e[1], 'ust', e[2], 'oran', a.oran1 * 100),
      jsonb_build_object('alt', e[2], 'ust', e[3], 'oran', a.oran2 * 100),
      jsonb_build_object('alt', e[3], 'ust', null, 'oran', a.oran3 * 100)),
    'ben', jsonb_build_object('servet', ben.toplam, 'nakit', ben.nakit, 'hisse', ben.hisse, 'mulk', ben.mulk,
       'gunluk_vergi', oyun.servet_vergisi(coalesce(ben.toplam, 0), greatest(coalesce(med, 1), 1)),
       'medyan_kat', round(coalesce(ben.toplam, 0) / greatest(coalesce(med, 1), 1), 1),
       'borc', coalesce((select borc from oyun.servet_vergi_borc where user_id = p.id), 0),
       'fon_7gun', coalesce((select sum(tutar) from oyun.firsat_fonu_odeme where user_id = p.id and gun > (t at time zone 'Europe/Istanbul')::date - 7), 0),
       'vergi_7gun', coalesce((select sum(tahsil) from oyun.servet_vergi where user_id = p.id and gun > (t at time zone 'Europe/Istanbul')::date - 7), 0)),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('gun', g.gun, 'gini', g.gini, 'medyan', round(g.medyan), 'tahsil', g.tahsil, 'fon', g.fon, 'alici', g.alici) order by g.gun) from (select * from oyun.denge_gun order by gun desc limit 14) g), '[]'::jsonb),
    'rekabet', coalesce((select jsonb_agg(jsonb_build_object('sirket', s.ad, 'il', (select ad from oyun.iller where id = r.il_id), 'sektor', (select ad from oyun.pazar_sektor where kod = r.sektor),
        'neden', r.neden, 'ceza', r.ceza, 'bas', r.bas, 'bit', r.bit, 'aktif', r.bit > t) order by r.bas desc)
        from (select * from oyun.yikici_rekabet order by bas desc limit 15) r join oyun.sirketler s on s.id = r.sirket_id), '[]'::jsonb),
    'kurallar', jsonb_build_object('rekabet_pay', a.rekabet_pay, 'koruma_kat', a.koruma_kat, 'rekabet_saat', a.rekabet_saat, 'fon_pay', round(a.fon_pay * 100),
       'kisi_tavan', round((select asgari from oyun.ulke where id = 1) * a.kisi_tavan_asgari))
  );
end $$;

revoke all on function oyun.net_servet_tablo() from public, anon, authenticated;
revoke all on function oyun.servet_esikler(numeric) from public, anon, authenticated;
revoke all on function oyun.servet_vergisi(numeric, numeric) from public, anon, authenticated;
revoke all on function oyun.denge_tick() from public, anon, authenticated;
revoke all on function oyun.yikici_rekabet_tick() from public, anon, authenticated;
revoke all on function public.denge_paneli() from public, anon;
grant execute on function public.denge_paneli() to authenticated;

-- Zamanlayıcı: her gün 03:20 (İstanbul) vergi ve fon; her saat rekabet taraması
do $$ begin
  if exists(select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('ekonomik-denge-gunluk', '20 0 * * *', 'select oyun.denge_tick()');
    perform cron.schedule('yikici-rekabet-saatlik', '17 * * * *', 'select oyun.yikici_rekabet_tick()');
  end if;
end $$;
