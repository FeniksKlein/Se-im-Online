-- 22 Ekim 2026: Halka arz menüleri düzeltmesi + gerçek hayattaki (SPK / Borsa İstanbul) sürece yaklaştırma.
--
-- HATA: "Halka arzlar" ekranı herkes için "Şirket bulunamadı" veriyordu. Faaliyeti durmuş bir
-- şirketin (CK HOLDİNG) açık arzı ve eski arzlardaki kapanmış şirketler (ASELSAN) listelenirken
-- halka_arz_json içindeki kâr tahmini istisna fırlatıyordu; tek bozuk satır bütün listeyi düşürüyordu.
--
-- YENİ SÜREÇ (gerçek hayattaki sıra, oyun süresine ölçeklenmiş):
--   1. A.Ş. şartı (vardı) + en az 3 günlük faaliyet geçmişi (izahnamedeki finansal tablolar).
--   2. SPK başvurusu: izahname 3 saat SPK incelemesinde kalır; şartlar bozulursa SPK reddeder.
--   3. Talep toplama 24/48/72 saat; hedef dolsa da süre sonuna kadar sürer (aşırı talep olabilir).
--   4. Dağıtım: talep hedefi aşarsa bireysel yatırımcılara EŞİT DAĞITIM; artan talep iade edilir.
--   5. Yöntem: sermaye artırımı (para şirkete) ve/veya ortak satışı (para satan ortağa).
--   6. Masraflar: SPK kurul ücreti binde 2 + Borsa İstanbul kotasyon binde 1 (hazineye),
--      aracı kurum komisyonu %1,5. Toplam %1,8 satış tutarından düşülür.
--   7. İlk halka arzda asgari halka açıklık %10; en fazla %49 (vardı).
--   8. Borsada işlem: ilk arzda halka arz fiyatı borsanın ilk referans fiyatı olur.
--   9. Satmama taahhüdü: arzı başlatan ve %5+ eski ortaklar 7 gün pay satamaz/devredemez;
--      başlatan, süreç sürerken de satamaz.
--  10. SPK bekleme: tamamlanan arzdan sonra 3 gün, iptal/başarısız başvurudan sonra 24 saat.
--
-- Geriye uyum: mağazadaki eski uygulamanın çağırdığı fonksiyonların imzası değişmedi
-- (halka_arz_baslat, halka_arz_talep, halka_arz_talep_geri, halka_arz_iptal, halka_arz_durum,
-- halka_arz_liste). Ortak satışı ve fon kullanım yeri için yeni halka_arz_basvur eklendi.
-- Durum listesi değişmedi: SPK incelemesi de 'acik' durumundadır (asama='spk'), böylece
-- açık arzı kontrol eden diğer sistemler (konkordato, eko_islem) aynen çalışır.
-- Oyuncu verisi silinmez; yalnız sütun/tablo/fonksiyon eklenir. Tekrar çalıştırmak güvenlidir.

-- 1) Şema (yalnız ekleme)
alter table oyun.halka_arz add column if not exists asama text not null default 'talep';
alter table oyun.halka_arz add column if not exists spk_bit timestamptz;
alter table oyun.halka_arz add column if not exists talep_bas timestamptz;
alter table oyun.halka_arz add column if not exists talep_saat integer;
alter table oyun.halka_arz add column if not exists ortak_satis numeric not null default 0;
alter table oyun.halka_arz add column if not exists fon_kullanim text;
alter table oyun.halka_arz add column if not exists talep_toplam numeric;
alter table oyun.halka_arz add column if not exists satilan numeric;
alter table oyun.halka_arz add column if not exists yeni_sermaye numeric;
alter table oyun.halka_arz add column if not exists ortak_gelir numeric;
alter table oyun.halka_arz add column if not exists masraf numeric;
alter table oyun.halka_arz add column if not exists ilk_arz boolean;
alter table oyun.halka_arz add column if not exists kilit_bit timestamptz;
alter table oyun.halka_arz_talep add column if not exists tahsis numeric;
alter table oyun.halka_arz_talep add column if not exists iade numeric;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'halka_arz_asama_check') then
    alter table oyun.halka_arz add constraint halka_arz_asama_check check (asama in ('spk','talep'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'halka_arz_ortak_satis_check') then
    alter table oyun.halka_arz add constraint halka_arz_ortak_satis_check check (ortak_satis >= 0 and ortak_satis <= hedef);
  end if;
end $$;

create table if not exists oyun.halka_arz_kilit (
  arz_id bigint not null references oyun.halka_arz(id),
  sirket_id bigint not null references oyun.sirketler(id),
  user_id uuid not null,
  bit timestamptz not null,
  primary key (arz_id, user_id)
);
create index if not exists halka_arz_kilit_sirket_idx on oyun.halka_arz_kilit(sirket_id, user_id, bit);
alter table oyun.halka_arz_kilit enable row level security;
revoke all on oyun.halka_arz_kilit from anon, authenticated;
create or replace trigger bosaltma_korumasi before truncate on oyun.halka_arz_kilit
  for each statement execute function oyun.bosaltma_korumasi();

-- 2) Kurallar (tek yerde; arayüz de buradan okur)
create or replace function oyun.halka_arz_kural()
returns jsonb language sql immutable set search_path to '' as $$
  select jsonb_build_object(
    'spk_saat', 3, 'talep_saatleri', jsonb_build_array(24, 48, 72),
    'kilit_gun', 7, 'kilit_esik_pay', 5,
    'soguma_tamam_gun', 3, 'soguma_iptal_saat', 24, 'min_faaliyet_gun', 3,
    'ilk_arz_min_pay', 10, 'en_cok_pay', 49, 'en_az_talep', 1000, 'en_az_buyukluk', 10000,
    'spk_ucret', 0.2, 'borsa_ucret', 0.1, 'araci_komisyon', 1.5, 'masraf_toplam', 1.8)
$$;

-- Kâr tahmini hiçbir zaman listeyi düşürmesin.
create or replace function oyun.halka_arz_net_guvenli(p_sirket bigint, p_ek numeric default 0)
returns numeric language plpgsql stable set search_path to '' as $$
begin
  if not exists (select 1 from oyun.sirketler where id = p_sirket and aktif) then return null; end if;
  return oyun.halka_arz_net_tahmin(p_sirket, coalesce(p_ek, 0));
exception when others then
  return null;
end $$;

-- 3) Eşit dağıtım: talep hedefi aşarsa her yatırımcıya aynı tutar (talebi daha azsa talebi kadar).
create or replace function oyun.halka_arz_tahsis(p_arz bigint)
returns table(talep_id bigint, user_id uuid, tutar numeric, tahsis numeric)
language plpgsql stable set search_path to '' as $$
#variable_conflict use_column
declare v_hedef numeric; v_toplam numeric; v_n int; v_kalan numeric; v_seviye numeric; r record;
begin
  select a.hedef into v_hedef from oyun.halka_arz a where a.id = p_arz;
  select coalesce(sum(h.tutar), 0), count(*) into v_toplam, v_n from oyun.halka_arz_talep h where h.arz_id = p_arz;
  if v_n = 0 or v_hedef is null then return; end if;
  if v_toplam <= v_hedef then
    return query select h.id, h.user_id, h.tutar, h.tutar from oyun.halka_arz_talep h where h.arz_id = p_arz;
    return;
  end if;
  v_kalan := v_hedef;
  for r in select h.tutar from oyun.halka_arz_talep h where h.arz_id = p_arz order by h.tutar, h.zaman, h.id loop
    if r.tutar * v_n <= v_kalan then
      v_kalan := v_kalan - r.tutar; v_n := v_n - 1;
    else
      v_seviye := v_kalan / v_n; exit;
    end if;
  end loop;
  v_seviye := coalesce(v_seviye, v_kalan / greatest(v_n, 1));
  return query
    with b as (
      select h.id, h.user_id, h.tutar, h.zaman, least(h.tutar, floor(v_seviye)) as taban
        from oyun.halka_arz_talep h where h.arz_id = p_arz),
    k as (select v_hedef - sum(b.taban) as artik from b),
    c as (select b.*, row_number() over (order by (b.tutar > b.taban) desc, b.zaman, b.id) as sira from b)
    select c.id, c.user_id, c.tutar,
           c.taban + case when c.tutar > c.taban and c.sira <= k.artik then 1 else 0 end
      from c, k;
end $$;

-- 4) Arayüz özeti (eski alanlar korunur; kapanmış şirkette de hata vermez)
create or replace function oyun.halka_arz_json(a oyun.halka_arz, u uuid)
returns jsonb language plpgsql stable set search_path to '' as $$
declare s oyun.sirketler; v_t oyun.halka_arz_talep; v_yeni numeric; v_tahmini numeric; v_asama text;
begin
  if a.id is null then return null; end if;
  select * into s from oyun.sirketler where id = a.sirket_id;
  select * into v_t from oyun.halka_arz_talep h where h.arz_id = a.id and h.user_id = u;
  v_yeni := a.hedef - coalesce(a.ortak_satis, 0);
  v_asama := coalesce(a.asama, 'talep');
  if a.durum = 'acik' and v_t.id is not null then
    if a.toplanan > a.hedef then
      select z.tahsis into v_tahmini from oyun.halka_arz_tahsis(a.id) z where z.user_id = u;
    else
      v_tahmini := v_t.tutar;
    end if;
  end if;
  return jsonb_build_object(
    'id', a.id, 'sirket_id', a.sirket_id, 'sirket', s.ad, 'sektor', s.sektor,
    'aktif', coalesce(s.aktif, false), 'halka_acik', coalesce(s.halka_acik, false),
    'baslatan', (select kad from oyun.profiller where id = a.baslatan), 'ben_baslattim', a.baslatan = u,
    'deger', a.deger, 'hedef', a.hedef, 'asgari', a.asgari, 'toplanan', a.toplanan,
    'bas', a.bas, 'bit', a.bit, 'durum', a.durum, 'asama', v_asama,
    'spk_bit', a.spk_bit, 'talep_bas', coalesce(a.talep_bas, case when v_asama = 'talep' then a.bas end),
    'talep_saat', a.talep_saat, 'sonuc_zaman', a.sonuc_zaman, 'aciklama', a.aciklama,
    'sermaye', s.sermaye, 'kasa', s.kasa,
    'ortak_satis', coalesce(a.ortak_satis, 0), 'yeni_pay_tutari', v_yeni, 'fon_kullanim', a.fon_kullanim,
    'ilk_arz', coalesce(a.ilk_arz, not coalesce(s.halka_acik, false)),
    'satilan_pay_hedef', round(a.hedef / (a.deger + v_yeni) * 100, 2),
    'pay_fiyati_1', round((a.deger + a.hedef) / 100, 2),
    'arz_fiyati', round((a.deger + v_yeni) / 100, 2),
    'talep_toplam', coalesce(a.talep_toplam, a.toplanan),
    'katilim_kat', round(coalesce(a.talep_toplam, a.toplanan) / a.hedef, 2),
    'satilan', a.satilan, 'yeni_sermaye', a.yeni_sermaye, 'ortak_gelir', a.ortak_gelir,
    'masraf', a.masraf, 'kilit_bit', a.kilit_bit,
    'ort_net_simdi', oyun.halka_arz_net_guvenli(a.sirket_id, 0),
    'ort_net_hedef', oyun.halka_arz_net_guvenli(a.sirket_id, case when a.durum = 'acik' then v_yeni else 0 end),
    'yatirimci', (select count(*) from oyun.halka_arz_talep h where h.arz_id = a.id),
    'talebim', coalesce(v_t.tutar, 0),
    'tahmini_tahsisim', coalesce(v_tahmini, 0),
    'tahsisim', v_t.tahsis, 'iadem', v_t.iade, 'arz_payim', v_t.pay,
    'ortaklar', coalesce((select jsonb_agg(jsonb_build_object('kad', p.kad, 'pay', round(o.pay, 2)) order by o.pay desc)
                  from oyun.sirket_ortaklari o join oyun.profiller p on p.id = o.user_id where o.sirket_id = a.sirket_id), '[]'::jsonb));
end $$;

-- 5) Kapanış: iptal / başarısız / eşit dağıtımla tamam
create or replace function oyun.halka_arz_iade_kapat(p_id bigint, p_iptal boolean, p_neden text)
returns text language plpgsql security definer set search_path to '' as $$
declare a oyun.halka_arz; s oyun.sirketler; t timestamptz := oyun.simdi(); x record; v_sonuc text; v_neden text;
  kisi int; v_toplam numeric; v_fiil text;
begin
  select * into a from oyun.halka_arz where id = p_id for update;
  if a.id is null or a.durum <> 'acik' then return coalesce(a.durum, 'yok'); end if;
  select * into s from oyun.sirketler where id = a.sirket_id;
  select count(*), coalesce(sum(tutar), 0) into kisi, v_toplam from oyun.halka_arz_talep where arz_id = a.id;
  v_sonuc := case when p_iptal then 'iptal' else 'basarisiz' end;
  v_fiil := case when p_iptal then 'iptal edildi' else 'gerçekleşmedi' end;
  v_neden := coalesce(p_neden, case
    when p_iptal then 'Şirket tarafından iptal edildi'
    when not coalesce(s.aktif, false) then 'Şirket faaliyette olmadığı için halka arz gerçekleşmedi'
    when coalesce(s.tur_hukuki, '') <> 'as' then 'Şirket anonim şirket olmadığı için halka arz gerçekleşmedi'
    when kisi = 0 or v_toplam < a.asgari then 'Asgari talep tutarına ulaşılamadı'
    else 'Halka arz şartları sağlanamadı' end);
  for x in select * from oyun.halka_arz_talep where arz_id = a.id loop
    perform oyun.para_islem(x.user_id, x.tutar, 'sirket', format('%s halka arzı %s: talep iadesi', s.ad, v_fiil), t);
    update oyun.halka_arz_talep set tahsis = 0, iade = x.tutar where id = x.id;
    perform oyun.bildir(x.user_id, format('%s halka arzı %s (%s). %s ₺ talebin cüzdanına iade edildi.',
      s.ad, v_fiil, v_neden, oyun.tl(x.tutar)), t);
  end loop;
  update oyun.halka_arz set durum = v_sonuc, sonuc_zaman = t, talep_toplam = v_toplam, aciklama = v_neden where id = a.id;
  perform oyun.bildir(a.baslatan, format('%s halka arzı %s: %s.%s', s.ad, v_fiil, v_neden,
    case when v_toplam > 0 then format(' Toplanan %s ₺ talep yatırımcılara iade edildi.', oyun.tl(v_toplam)) else '' end), t);
  return v_sonuc;
end $$;

create or replace function oyun.halka_arz_dagitim_paylar(p_id bigint, p_post numeric, p_ts numeric)
returns void language plpgsql security definer set search_path to '' as $$
declare a oyun.halka_arz; x record; v_p numeric; v_fark numeric; v_ad text; t timestamptz := oyun.simdi();
begin
  select * into a from oyun.halka_arz where id = p_id;
  select ad into v_ad from oyun.sirketler where id = a.sirket_id;
  -- Satmama taahhüdü: başlatan ve %5+ eski ortaklar 7 gün
  insert into oyun.halka_arz_kilit(arz_id, sirket_id, user_id, bit)
    select a.id, a.sirket_id, o.user_id, t + interval '7 days' from oyun.sirket_ortaklari o
     where o.sirket_id = a.sirket_id and (o.user_id = a.baslatan or o.pay >= 5)
    on conflict do nothing;
  update oyun.sirket_ortaklari set pay = round(pay * a.deger / p_post, 6) where sirket_id = a.sirket_id;
  if p_ts > 0 then
    -- En çok %49 satılır, başvuran en az %50 sahibidir: satan ortakta her zaman pay kalır.
    update oyun.sirket_ortaklari set pay = greatest(round(pay - p_ts / p_post * 100, 6), 0.000001)
     where sirket_id = a.sirket_id and user_id = a.baslatan;
  end if;
  for x in select z.talep_id, z.user_id, z.tutar, z.tahsis from oyun.halka_arz_tahsis(a.id) z loop
    v_p := case when x.tahsis > 0 then round(x.tahsis / p_post * 100, 6) else 0 end;
    update oyun.halka_arz_talep set tahsis = x.tahsis, iade = x.tutar - x.tahsis, pay = v_p where id = x.talep_id;
    if v_p > 0 then
      insert into oyun.sirket_ortaklari(sirket_id, user_id, pay) values (a.sirket_id, x.user_id, v_p)
        on conflict (sirket_id, user_id) do update set pay = oyun.sirket_ortaklari.pay + excluded.pay;
    end if;
    if x.tutar > x.tahsis then
      perform oyun.para_islem(x.user_id, x.tutar - x.tahsis, 'sirket', format('%s halka arzı: eşit dağıtım sonrası artan talep iadesi', v_ad), t);
    end if;
  end loop;
  select 100 - sum(pay) into v_fark from oyun.sirket_ortaklari where sirket_id = a.sirket_id;
  if v_fark <> 0 then
    update oyun.sirket_ortaklari set pay = pay + v_fark where sirket_id = a.sirket_id and user_id =
      (select user_id from oyun.sirket_ortaklari where sirket_id = a.sirket_id order by pay desc, user_id limit 1);
  end if;
end $$;

create or replace function oyun.halka_arz_dagitim_finans(p_id bigint, p_tn numeric, p_ts numeric)
returns numeric language plpgsql security definer set search_path to '' as $$
declare a oyun.halka_arz; v_ad text; t timestamptz := oyun.simdi(); v_m_n numeric; v_m_s numeric; v_dev numeric;
begin
  select * into a from oyun.halka_arz where id = p_id;
  select ad into v_ad from oyun.sirketler where id = a.sirket_id;
  -- Masraf %1,8: SPK binde 2 + Borsa İstanbul binde 1 hazineye, aracı kurum %1,5.
  v_m_n := round(p_tn * 0.018); v_m_s := round(p_ts * 0.018); v_dev := round((p_tn + p_ts) * 0.003);
  update oyun.sirketler set sermaye = sermaye + p_tn, kasa = kasa + p_tn - v_m_n, halka_acik = true, satilik = null where id = a.sirket_id;
  if v_dev > 0 then update oyun.ulke set hazine = hazine + v_dev / oyun.pazar_tl_milyar() where id = 1; end if;
  if p_tn > 0 then
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama) values (a.sirket_id, t, p_tn - v_m_n,
      format('Halka arz: %s ₺ yeni sermaye; SPK, Borsa İstanbul ve aracı kurum masrafı %s ₺ düşüldü', oyun.tl(p_tn), oyun.tl(v_m_n)));
  end if;
  if p_ts > 0 then
    perform oyun.para_islem(a.baslatan, p_ts - v_m_s, 'sirket',
      format('%s halka arzı: ortak satışı geliri (%s ₺ satış, %s ₺ masraf düşüldü)', v_ad, oyun.tl(p_ts), oyun.tl(v_m_s)), t);
  end if;
  return v_m_n + v_m_s;
end $$;

-- Not: Supabase bağlantı aracı bu fonksiyonu otomatik yüklemeyi iptal ediyor; canlıya
-- migrations/20261022_halka_arz_dagitim_ELLE.sql ile SQL Editor'den elle kurulur.
create or replace function oyun.halka_arz_dagitim(p_id bigint)
returns text language plpgsql security definer set search_path to '' as $$
declare a oyun.halka_arz; s oyun.sirketler; t timestamptz := oyun.simdi(); kisi int;
  v_toplam numeric; v_T numeric; v_Tn numeric; v_Ts numeric; v_post numeric; v_sat numeric; v_masraf numeric; v_ilk boolean;
begin
  select * into a from oyun.halka_arz where id = p_id for update;
  if a.id is null or a.durum <> 'acik' then return coalesce(a.durum, 'yok'); end if;
  select * into s from oyun.sirketler where id = a.sirket_id for update;
  select count(*), coalesce(sum(tutar), 0) into kisi, v_toplam from oyun.halka_arz_talep where arz_id = a.id;
  select coalesce(sum(z.tahsis), 0) into v_T from oyun.halka_arz_tahsis(a.id) z;
  select pay into v_sat from oyun.sirket_ortaklari where sirket_id = a.sirket_id and user_id = a.baslatan;
  v_Ts := least(case when coalesce(a.ortak_satis, 0) > 0 then round(v_T * a.ortak_satis / a.hedef) else 0 end,
                floor(coalesce(v_sat, 0) * a.deger / 100));
  v_Tn := v_T - v_Ts;
  v_ilk := not coalesce(s.halka_acik, false);
  perform oyun.sirket_hesapla(a.sirket_id);
  v_post := a.deger + v_Tn;
  perform oyun.halka_arz_dagitim_paylar(a.id, v_post, v_Ts);
  v_masraf := oyun.halka_arz_dagitim_finans(a.id, v_Tn, v_Ts);
  if v_ilk and not exists (select 1 from oyun.borsa_fiyat_referans where sirket_id = a.sirket_id)
     and not exists (select 1 from oyun.borsa_fiyat_gecmis where sirket_id = a.sirket_id) then
    insert into oyun.borsa_fiyat_gecmis(sirket_id, fiyat, zaman, gerekce)
    values (a.sirket_id, greatest(1, round(v_post / 100)), t, 'Halka arz fiyatı (borsada ilk işlem referansı)');
  end if;
  update oyun.halka_arz set durum = 'tamam', sonuc_zaman = t, talep_toplam = v_toplam, toplanan = v_T, satilan = v_T,
    yeni_sermaye = v_Tn, ortak_gelir = v_Ts, masraf = v_masraf, ilk_arz = v_ilk, kilit_bit = t + interval '7 days',
    aciklama = format('%s yatırımcı, %s ₺ talep (%s kat), %s ₺ satış; satılan pay %%%s%s', kisi, oyun.tl(v_toplam),
      replace(to_char(round(v_toplam / a.hedef, 2), 'FM9990.00'), '.', ','),
      oyun.tl(v_T), round(v_T / v_post * 100, 2), case when v_toplam > a.hedef then ', eşit dağıtım' else '' end)
   where id = a.id;
  perform oyun.halka_arz_sonuc_bildir(a.id);
  return 'tamam';
end $$;

create or replace function oyun.halka_arz_sonuc_bildir(p_id bigint)
returns void language plpgsql security definer set search_path to '' as $$
declare a oyun.halka_arz; v_ad text; x record; t timestamptz := oyun.simdi();
begin
  select * into a from oyun.halka_arz where id = p_id;
  select ad into v_ad from oyun.sirketler where id = a.sirket_id;
  for x in select h.user_id, h.tutar, h.tahsis, h.iade, h.pay from oyun.halka_arz_talep h where h.arz_id = a.id loop
    perform oyun.bildir(x.user_id, format('%s halka arzı tamamlandı: %s ₺ talebine %s ₺ tahsis edildi, şirketin %%%s ortağı oldun.%s Payların borsada işlem görebilir.',
      v_ad, oyun.tl(x.tutar), oyun.tl(x.tahsis), round(x.pay, 2),
      case when coalesce(x.iade, 0) > 0 then format(' Eşit dağıtım nedeniyle artan %s ₺ cüzdanına iade edildi.', oyun.tl(x.iade)) else '' end), t);
  end loop;
  for x in select o.user_id, o.pay, (select k.bit from oyun.halka_arz_kilit k where k.arz_id = a.id and k.user_id = o.user_id) as kbit
             from oyun.sirket_ortaklari o
            where o.sirket_id = a.sirket_id and not exists (select 1 from oyun.halka_arz_talep h where h.arz_id = a.id and h.user_id = o.user_id) loop
    perform oyun.bildir(x.user_id, format('%s halka arzı tamamlandı: %s ₺ talep toplandı, %s ₺ satıldı. Şirketteki payın artık %%%s.%s',
      v_ad, oyun.tl(a.talep_toplam), oyun.tl(a.satilan), round(x.pay, 2),
      case when x.kbit is not null then format(' Satmama taahhüdü: payların %s tarihine kadar satılamaz.', oyun.tr_tarih_saat(x.kbit)) else '' end), t);
  end loop;
  perform oyun.olay('ekonomi', format('%s halka arzı tamamlandı: %s ₺ talep, %s ₺ satış%s. %s',
    v_ad, oyun.tl(a.talep_toplam), oyun.tl(a.satilan),
    case when a.talep_toplam > a.hedef then ', eşit dağıtım yapıldı' else '' end,
    case when a.ilk_arz then 'Şirket borsada işlem görmeye başladı.' else 'Yeni paylar borsada işlem görüyor.' end), null, null, t);
end $$;

create or replace function oyun.halka_arz_kapat(p_id bigint, p_iptal boolean, p_neden text)
returns text language plpgsql security definer set search_path to '' as $$
declare a oyun.halka_arz; s oyun.sirketler; kisi int; v_toplam numeric;
begin
  select * into a from oyun.halka_arz where id = p_id for update;
  if a.id is null or a.durum <> 'acik' then return coalesce(a.durum, 'yok'); end if;
  perform pg_advisory_xact_lock(98763, hashtext(a.sirket_id::text));
  select * into s from oyun.sirketler where id = a.sirket_id for update;
  select count(*), coalesce(sum(tutar), 0) into kisi, v_toplam from oyun.halka_arz_talep where arz_id = a.id;
  if p_iptal or p_neden is not null or coalesce(a.asama, 'talep') = 'spk' or kisi = 0 or v_toplam < a.asgari
     or not coalesce(s.aktif, false) or coalesce(s.tur_hukuki, '') <> 'as'
     or s.sermaye + least(v_toplam, a.hedef) - coalesce(a.ortak_satis, 0) > 100000000 then
    return oyun.halka_arz_iade_kapat(p_id, p_iptal, p_neden);
  end if;
  -- Dağıtım fonksiyonu kurulmadan hiçbir arz yarım kapanmasın; talepler emanette bekler.
  if to_regprocedure('oyun.halka_arz_dagitim(bigint)') is null then return 'bekliyor'; end if;
  return oyun.halka_arz_dagitim(p_id);
end $$;

-- Eski iki parametreli çağrılar (iptal, zamanlayıcı) aynen çalışır.
create or replace function oyun.halka_arz_kapat(p_id bigint, p_iptal boolean default false)
returns text language plpgsql security definer set search_path to '' as $$
begin
  return oyun.halka_arz_kapat(p_id, p_iptal, null::text);
end $$;

-- 6) SPK kararı (inceleme süresi dolunca)
create or replace function oyun.halka_arz_spk_karar(p_id bigint)
returns text language plpgsql security definer set search_path to '' as $$
declare a oyun.halka_arz; s oyun.sirketler; t timestamptz := oyun.simdi(); v_pay numeric; v_red text; v_bit timestamptz;
begin
  select * into a from oyun.halka_arz where id = p_id for update;
  if a.id is null or a.durum <> 'acik' or a.asama <> 'spk' then return coalesce(a.durum, 'yok'); end if;
  select * into s from oyun.sirketler where id = a.sirket_id;
  select pay into v_pay from oyun.sirket_ortaklari where sirket_id = a.sirket_id and user_id = a.baslatan;
  v_red := case
    when not coalesce(s.aktif, false) then 'şirket faaliyette değil'
    when coalesce(s.tur_hukuki, '') <> 'as' then 'şirket anonim şirket değil'
    when coalesce(v_pay, 0) < 50 then 'başvuran ortağın payı %50''nin altına düştü'
    when coalesce(a.ortak_satis, 0) > floor(coalesce(v_pay, 0) * a.deger / 100) then 'ortak satışına konu paylar başvuru sahibinde bulunmuyor'
    when s.sermaye + a.hedef - coalesce(a.ortak_satis, 0) > 100000000 then 'halka arz sonrası sermaye 100.000.000 ₺ sınırını aşıyor'
  end;
  if v_red is not null then
    return oyun.halka_arz_kapat(a.id, false, 'SPK izahnameyi onaylamadı: ' || v_red);
  end if;
  v_bit := t + make_interval(hours => coalesce(a.talep_saat, 72));
  update oyun.halka_arz set asama = 'talep', talep_bas = t, bit = v_bit where id = a.id;
  perform oyun.bildir(a.baslatan, format('SPK, %s izahnamesini onayladı. Talep toplama başladı ve %s tarihinde bitecek.',
    s.ad, oyun.tr_tarih_saat(v_bit)), t);
  perform oyun.olay('ekonomi', format('SPK onayı: %s halka arzında talep toplama başladı. Büyüklük %s ₺, şirket değeri %s ₺; talepler %s tarihine kadar alınacak.',
    s.ad, oyun.tl(a.hedef), oyun.tl(a.deger), oyun.tr_tarih_saat(v_bit)), null, null, t);
  return 'talep';
end $$;

create or replace function oyun.halka_arz_tick()
returns void language plpgsql security definer set search_path to '' as $$
declare x record; t timestamptz := oyun.simdi();
begin
  for x in select id from oyun.halka_arz where durum = 'acik' and asama = 'spk' and spk_bit <= t order by spk_bit loop
    perform oyun.halka_arz_spk_karar(x.id);
  end loop;
  for x in select id from oyun.halka_arz where durum = 'acik' and asama = 'talep' and bit <= t order by bit loop
    perform oyun.halka_arz_kapat(x.id, false);
  end loop;
end $$;

-- 7) Başvuru (izahname + SPK)
create or replace function oyun.halka_arz_basvuru_ic(u uuid, p_sirket bigint, p_hedef numeric, p_deger numeric,
  p_asgari numeric, p_saat integer, p_ortak_satis numeric, p_fon text)
returns bigint language plpgsql security definer set search_path to '' as $$
declare s oyun.sirketler; d record; t timestamptz := oyun.simdi(); v_asgari numeric; v_id bigint; v_pay numeric;
  v_ortak numeric; v_yeni numeric; v_son oyun.halka_arz; v_oran numeric; v_fon text;
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u and not yasakli) then raise exception 'Oyuncu hesabı gerekli'; end if;
  perform pg_advisory_xact_lock(98763, hashtext(p_sirket::text));
  select * into s from oyun.sirketler where id = p_sirket and aktif for update;
  if s.id is null then raise exception 'Şirket bulunamadı'; end if;
  select pay into v_pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u;
  if coalesce(v_pay, 0) < 50 then raise exception 'Halka arz başvurusunu yalnız şirketin en az %%50''sine sahip ortak yapabilir'; end if;
  if coalesce(s.tur_hukuki, '') <> 'as' then
    raise exception 'Halka arz için şirketin anonim şirket (A.Ş.) olması gerekir. Önce şirket karnesinden A.Ş.''ye dönüştür (en az 250.000 ₺ sermaye).';
  end if;
  if exists (select 1 from oyun.halka_arz where sirket_id = s.id and durum = 'acik') then
    raise exception 'Bu şirketin süren bir halka arz süreci var (SPK incelemesi ya da talep toplama)';
  end if;
  if s.kurulus > t - interval '3 days' then
    raise exception 'İzahnamedeki finansal tablolar için şirketin en az 3 günlük faaliyet geçmişi olmalı. Başvuru % tarihinden itibaren yapılabilir.',
      oyun.tr_tarih_saat(s.kurulus + interval '3 days');
  end if;
  select * into v_son from oyun.halka_arz where sirket_id = s.id and durum <> 'acik' order by coalesce(sonuc_zaman, bas) desc limit 1;
  if v_son.id is not null then
    if v_son.durum = 'tamam' and v_son.sonuc_zaman > t - interval '3 days' then
      raise exception 'Son halka arz % tarihinde tamamlandı. SPK yeni pay satışı başvurusunu % tarihinden itibaren kabul eder.',
        oyun.tr_tarih_saat(v_son.sonuc_zaman), oyun.tr_tarih_saat(v_son.sonuc_zaman + interval '3 days');
    elsif v_son.durum in ('iptal', 'basarisiz') and v_son.sonuc_zaman > t - interval '24 hours' then
      raise exception 'Önceki başvuru % tarihinde sonuçlandı. Yeni başvuru % tarihinden itibaren yapılabilir.',
        oyun.tr_tarih_saat(v_son.sonuc_zaman), oyun.tr_tarih_saat(v_son.sonuc_zaman + interval '24 hours');
    end if;
  end if;
  if p_hedef is null or p_hedef <> round(p_hedef) or p_hedef < 10000 then
    raise exception 'Halka arz büyüklüğü en az 10.000 ₺ ve tam sayı olmalı';
  end if;
  v_ortak := coalesce(round(p_ortak_satis), 0);
  if v_ortak < 0 or v_ortak > p_hedef then raise exception 'Ortak satışı tutarı 0 ile halka arz büyüklüğü arasında olmalı'; end if;
  v_yeni := p_hedef - v_ortak;
  if s.sermaye + v_yeni > 100000000 then
    raise exception 'Halka arz sonrası sermaye 100.000.000 ₺''yi aşamaz (sermaye artırımıyla en fazla % ₺ toplanabilir)', oyun.tl(100000000 - s.sermaye);
  end if;
  select * into d from oyun.halka_arz_deger_sinir_sirket(s.id);
  if p_deger is null or p_deger <> round(p_deger) or p_deger < d.en_az or p_deger > d.en_cok then
    raise exception 'Fiyat tespit raporuna göre şirket değeri % ₺ ile % ₺ arasında olmalı', oyun.tl(d.en_az), oyun.tl(d.en_cok);
  end if;
  if v_ortak > floor(v_pay * p_deger / 100) then
    raise exception 'Ortak satışında en fazla kendi payının karşılığı olan % ₺ satabilirsin', oyun.tl(floor(v_pay * p_deger / 100));
  end if;
  v_oran := p_hedef / (p_deger + v_yeni);
  if v_oran > .49 then
    raise exception 'Halka arzda şirketin en fazla %%49''u satılabilir (bu yapıyla %%% satılıyor). Tutarı düşür ya da şirket değerini artır.', round(v_oran * 100, 2);
  end if;
  if not coalesce(s.halka_acik, false) and v_oran < .10 then
    raise exception 'İlk halka arzda asgari halka açıklık şartı: satılan pay en az %%10 olmalı (bu yapıyla %%%). Halka arz büyüklüğünü artır ya da şirket değerini düşür.', round(v_oran * 100, 2);
  end if;
  v_asgari := coalesce(round(p_asgari), round(p_hedef / 2));
  if v_asgari < 10000 or v_asgari > p_hedef then raise exception 'Asgari tutar 10.000 ₺ ile halka arz büyüklüğü arasında olmalı'; end if;
  if p_saat is null or p_saat not in (24, 48, 72) then raise exception 'Talep toplama süresi 24, 48 ya da 72 saat olmalı'; end if;
  v_fon := nullif(btrim(coalesce(p_fon, '')), '');
  if v_fon is not null and char_length(v_fon) > 200 then raise exception 'Fon kullanım yeri en fazla 200 karakter olabilir'; end if;
  update oyun.sirketler set satilik = null where id = s.id;
  insert into oyun.halka_arz(sirket_id, baslatan, deger, hedef, asgari, bas, bit, asama, spk_bit, talep_saat, ortak_satis, fon_kullanim, ilk_arz)
    values (s.id, u, p_deger, p_hedef, v_asgari, t, t + interval '3 hours' + make_interval(hours => p_saat), 'spk',
            t + interval '3 hours', p_saat, v_ortak, v_fon, not coalesce(s.halka_acik, false))
    returning id into v_id;
  perform oyun.olay('ekonomi', format('%s halka arz için SPK''ya başvurdu: %s ₺ büyüklük%s, şirketin %%%s''i satılacak. İzahname 3 saat incelenecek.',
    s.ad, oyun.tl(p_hedef), case when v_ortak > 0 then format(' (%s ₺ ortak satışı)', oyun.tl(v_ortak)) else '' end,
    round(v_oran * 100, 2)), null, null, t);
  return v_id;
end $$;

-- Eski uygulama: imza aynı, artık SPK başvurusu açar (yalnız sermaye artırımı).
create or replace function public.halka_arz_baslat(p_sirket bigint, p_hedef numeric, p_deger numeric,
  p_asgari numeric default null::numeric, p_saat integer default 72)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); v_id bigint;
begin
  v_id := oyun.halka_arz_basvuru_ic(u, p_sirket, p_hedef, p_deger, p_asgari, p_saat, 0, null);
  return oyun.halka_arz_json((select a from oyun.halka_arz a where a.id = v_id), u);
end $$;

-- Yeni uygulama: ortak satışı ve fon kullanım yeri ile başvuru.
create or replace function public.halka_arz_basvur(p_sirket bigint, p_hedef numeric, p_deger numeric,
  p_asgari numeric, p_saat integer, p_ortak_satis numeric default 0, p_fon_kullanim text default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); v_id bigint;
begin
  v_id := oyun.halka_arz_basvuru_ic(u, p_sirket, p_hedef, p_deger, p_asgari, p_saat, p_ortak_satis, p_fon_kullanim);
  return oyun.halka_arz_json((select a from oyun.halka_arz a where a.id = v_id), u);
end $$;

-- 8) Talep: süre sonuna kadar, hedefi aşabilir; tek yatırımcının talebi büyüklüğü aşamaz.
create or replace function public.halka_arz_talep(p_arz bigint, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); a oyun.halka_arz; t timestamptz := oyun.simdi(); v_ad text; v_mevcut numeric;
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u and not yasakli) then raise exception 'Oyuncu hesabı gerekli'; end if;
  perform oyun.halka_arz_tick();
  select * into a from oyun.halka_arz where id = p_arz for update;
  if a.id is null or a.durum <> 'acik' or a.bit <= t then raise exception 'Bu halka arz artık talep toplamıyor'; end if;
  if coalesce(a.asama, 'talep') = 'spk' then
    raise exception 'İzahname SPK incelemesinde; talep toplama % tarihinde başlayacak', oyun.tr_tarih_saat(a.spk_bit);
  end if;
  if a.baslatan = u then raise exception 'Kendi başlattığın halka arza talep veremezsin; şirketin tamamı sende ise sermaye artırımını kullan'; end if;
  if p_tutar is null or p_tutar <> round(p_tutar) or p_tutar < 1000 then raise exception 'Talep en az 1.000 ₺ ve tam sayı olmalı'; end if;
  select tutar into v_mevcut from oyun.halka_arz_talep where arz_id = a.id and user_id = u;
  if coalesce(v_mevcut, 0) + p_tutar > a.hedef then
    raise exception 'Bir yatırımcının toplam talebi halka arz büyüklüğünü (% ₺) aşamaz. En fazla % ₺ daha ekleyebilirsin',
      oyun.tl(a.hedef), oyun.tl(greatest(0, a.hedef - coalesce(v_mevcut, 0)));
  end if;
  select ad into v_ad from oyun.sirketler where id = a.sirket_id;
  perform oyun.para_islem(u, -p_tutar, 'sirket', format('%s halka arz talebi (emanet)', v_ad), t);
  insert into oyun.halka_arz_talep(arz_id, user_id, tutar, zaman) values (a.id, u, p_tutar, t)
    on conflict (arz_id, user_id) do update set tutar = oyun.halka_arz_talep.tutar + excluded.tutar, zaman = excluded.zaman;
  update oyun.halka_arz set toplanan = toplanan + p_tutar where id = a.id returning * into a;
  if v_mevcut is null then
    perform oyun.bildir(a.baslatan, format('%s halka arzına %s %s ₺ talep verdi (toplam talep %s ₺, büyüklük %s ₺).', v_ad,
      (select kad from oyun.profiller where id = u), oyun.tl(p_tutar), oyun.tl(a.toplanan), oyun.tl(a.hedef)), t);
  end if;
  return oyun.halka_arz_json(a, u);
end $$;

-- 9) Ekranlar
create or replace function public.halka_arz_durum(p_sirket bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); s oyun.sirketler; d record; t timestamptz := oyun.simdi(); v_son oyun.halka_arz;
  v_soguma timestamptz; v_neden text;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  perform oyun.halka_arz_tick();
  select * into s from oyun.sirketler where id = p_sirket and aktif;
  if s.id is null then raise exception 'Şirket bulunamadı'; end if;
  select * into d from oyun.halka_arz_deger_sinir_sirket(s.id);
  select * into v_son from oyun.halka_arz where sirket_id = s.id and durum <> 'acik' order by coalesce(sonuc_zaman, bas) desc limit 1;
  if v_son.durum = 'tamam' and v_son.sonuc_zaman > t - interval '3 days' then
    v_soguma := v_son.sonuc_zaman + interval '3 days';
    v_neden := 'Tamamlanan halka arzdan sonra SPK yeni pay satışı başvurusunu 3 gün sonra kabul eder.';
  elsif v_son.durum in ('iptal', 'basarisiz') and v_son.sonuc_zaman > t - interval '24 hours' then
    v_soguma := v_son.sonuc_zaman + interval '24 hours';
    v_neden := 'İptal edilen ya da gerçekleşmeyen başvurudan sonra yeni başvuru için 24 saat beklenir.';
  end if;
  if s.kurulus > t - interval '3 days' and (v_soguma is null or s.kurulus + interval '3 days' > v_soguma) then
    v_soguma := s.kurulus + interval '3 days';
    v_neden := 'İzahnamedeki finansal tablolar için en az 3 günlük faaliyet geçmişi gerekir.';
  end if;
  return jsonb_build_object(
    'id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'sermaye', s.sermaye, 'kasa', s.kasa, 'halka_acik', s.halka_acik,
    'tur_hukuki', s.tur_hukuki, 'as_mi', coalesce(s.tur_hukuki, '') = 'as', 'kurulus', s.kurulus,
    'payim', coalesce((select pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u), 0),
    'kar_kasada', coalesce((select kar_kasada from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u), false),
    'asgari_ucret', (select asgari from oyun.ulke where id = 1),
    'ort_net', oyun.halka_arz_net_guvenli(s.id, 0),
    'deger_en_az', d.en_az, 'deger_en_cok', d.en_cok, 'deger_onerilen', d.onerilen,
    'en_fazla_tutar', least(100000000 - s.sermaye, floor(d.en_cok * 49 / 51)),
    'ilk_arz', not coalesce(s.halka_acik, false),
    'min_pay', case when coalesce(s.halka_acik, false) then 0 else 10 end,
    'kural', oyun.halka_arz_kural(),
    'soguma_bit', v_soguma, 'soguma_neden', v_neden,
    'kilit_bit', (select max(k.bit) from oyun.halka_arz_kilit k where k.sirket_id = s.id and k.user_id = u and k.bit > t),
    'acik', (select oyun.halka_arz_json(a, u) from oyun.halka_arz a where a.sirket_id = s.id and a.durum = 'acik' order by a.id desc limit 1),
    'gecmis', coalesce((select jsonb_agg(oyun.halka_arz_json(a, u) order by a.bas desc)
                        from (select * from oyun.halka_arz where sirket_id = s.id and durum <> 'acik' order by bas desc limit 5) a), '[]'::jsonb));
end $$;

create or replace function public.halka_arz_liste()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  perform oyun.halka_arz_tick();
  return jsonb_build_object(
    'acik', coalesce((select jsonb_agg(oyun.halka_arz_json(a, u) order by (a.asama = 'spk'), a.bit) from oyun.halka_arz a where a.durum = 'acik'), '[]'::jsonb),
    'son', coalesce((select jsonb_agg(oyun.halka_arz_json(a, u) order by a.sonuc_zaman desc)
                     from (select * from oyun.halka_arz where durum <> 'acik' order by sonuc_zaman desc nulls last limit 10) a), '[]'::jsonb),
    'katildiklarim', coalesce((select jsonb_agg(oyun.halka_arz_json(a, u) order by a.sonuc_zaman desc)
                     from (select x.* from oyun.halka_arz x join oyun.halka_arz_talep h on h.arz_id = x.id and h.user_id = u
                            where x.durum <> 'acik' order by x.sonuc_zaman desc nulls last limit 5) a), '[]'::jsonb),
    'kural', oyun.halka_arz_kural(),
    'cuzdan', (select para from oyun.cuzdan where user_id = u));
end $$;

-- 10) Satmama taahhüdü
create or replace function oyun.halka_arz_kilit_engel(p_sirket bigint, p_user uuid)
returns text language sql stable set search_path to '' as $$
  select coalesce(
    (select format('Halka arz süreci devam ediyor (%s). Başvuruyu yapan ortak, süreç bitene kadar bu şirketin paylarını satamaz ya da devredemez.',
             case when a.asama = 'spk' then 'SPK incelemesi' else 'talep toplama' end)
       from oyun.halka_arz a where a.sirket_id = p_sirket and a.durum = 'acik' and a.baslatan = p_user limit 1),
    (select format('Satmama taahhüdü: halka arz öncesi ortakların payları %s tarihine kadar satılamaz ya da devredilemez.', oyun.tr_tarih_saat(max(k.bit)))
       from oyun.halka_arz_kilit k where k.sirket_id = p_sirket and k.user_id = p_user and k.bit > oyun.simdi()
     having count(*) > 0))
$$;

create or replace function oyun.tg_halka_arz_kilit()
returns trigger language plpgsql security definer set search_path to '' as $$
declare m text;
begin
  m := oyun.halka_arz_kilit_engel(new.sirket_id, new.satici);
  if m is not null then raise exception '%', m; end if;
  return new;
end $$;

create or replace trigger halka_arz_kilit before insert on oyun.borsa_emir for each row execute function oyun.tg_halka_arz_kilit();
create or replace trigger halka_arz_kilit before insert on oyun.sirket_hisse_ilanlari for each row execute function oyun.tg_halka_arz_kilit();
create or replace trigger halka_arz_kilit before insert on oyun.sirket_teklif for each row execute function oyun.tg_halka_arz_kilit();

-- 11) Faaliyeti duran şirketin süren halka arzı düşer, talepler iade edilir.
create or replace function oyun.tg_sirket_pasif_halka_arz()
returns trigger language plpgsql security definer set search_path to '' as $$
declare x record;
begin
  if coalesce(old.aktif, false) and not coalesce(new.aktif, false) then
    for x in select id from oyun.halka_arz where sirket_id = new.id and durum = 'acik' loop
      perform oyun.halka_arz_kapat(x.id, false, 'Şirket faaliyetini durdurduğu için halka arz düştü');
    end loop;
  end if;
  return null;
end $$;
create or replace trigger sirket_pasif_halka_arz after update of aktif on oyun.sirketler
  for each row execute function oyun.tg_sirket_pasif_halka_arz();

-- 12) Yetkiler
revoke all on function oyun.halka_arz_kural() from public, anon, authenticated;
revoke all on function oyun.halka_arz_net_guvenli(bigint, numeric) from public, anon, authenticated;
revoke all on function oyun.halka_arz_tahsis(bigint) from public, anon, authenticated;
revoke all on function oyun.halka_arz_kapat(bigint, boolean, text) from public, anon, authenticated;
revoke all on function oyun.halka_arz_iade_kapat(bigint, boolean, text) from public, anon, authenticated;
revoke all on function oyun.halka_arz_dagitim(bigint) from public, anon, authenticated;
revoke all on function oyun.halka_arz_dagitim_paylar(bigint, numeric, numeric) from public, anon, authenticated;
revoke all on function oyun.halka_arz_dagitim_finans(bigint, numeric, numeric) from public, anon, authenticated;
revoke all on function oyun.halka_arz_sonuc_bildir(bigint) from public, anon, authenticated;
revoke all on function oyun.halka_arz_spk_karar(bigint) from public, anon, authenticated;
revoke all on function oyun.halka_arz_basvuru_ic(uuid, bigint, numeric, numeric, numeric, integer, numeric, text) from public, anon, authenticated;
revoke all on function oyun.halka_arz_kilit_engel(bigint, uuid) from public, anon, authenticated;
revoke all on function oyun.tg_halka_arz_kilit() from public, anon, authenticated;
revoke all on function oyun.tg_sirket_pasif_halka_arz() from public, anon, authenticated;
revoke all on function public.halka_arz_basvur(bigint, numeric, numeric, numeric, integer, numeric, text) from public, anon;
grant execute on function public.halka_arz_basvur(bigint, numeric, numeric, numeric, integer, numeric, text) to authenticated, service_role;

-- 13) Faaliyeti durmuş CK HOLDİNG'in açık kalan (talepsiz) arzını kapat.
select oyun.halka_arz_kapat(h.id, false, 'Şirket faaliyetini durdurduğu için halka arz düştü')
  from oyun.halka_arz h join oyun.sirketler s on s.id = h.sirket_id
 where h.durum = 'acik' and not s.aktif;
