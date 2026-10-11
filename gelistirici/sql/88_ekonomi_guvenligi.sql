-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 88) Ekonomi güvenliği: ilişkili hesap kuralı, fiyat bantları,
--  MASAK (şüpheli işlem bildirimi), parti kasası şeffaflığı, yönetim hediyeleri listesi
--
--  Haksız zenginleşmenin neredeyse tek yolu: bir oyuncunun ikinci hesabıyla "meşru işlem" kılığında
--  para taşıması. Bu modül işlemleri RPC'lere dokunmadan TETİKLEYİCİLERLE korur:
--  1) İLİŞKİLİ HESAP: aynı cihazda açılmış hesaplar (oyun.bagli_hesaplar) birbirleriyle borsada,
--     hisse/şirket satışında, emlakta, ortaklık teklifinde işlem yapamaz; birbirinin ihalesine
--     giremez; birbirinin ajansından sipariş veremez; birbirinin anketine katılamaz.
--     (Banka transferi ve hediyede bu kural zaten vardı.)
--  2) FİYAT BANTLARI: Borsada son işlem fiyatının ±%20'si (ilk işlemde referansın 0,5-2 katı);
--     şirket/pay satışında şirket kasasının (defter değeri) 0,5 katı ile sermaye/kasanın 3 katı arası;
--     emlakta ilin rayiç bedelinin 0,4-2,5 katı. Değer şişirerek ya da 1 ₺'ye satarak para taşınamaz.
--  3) MASAK: sunucu şüpheli durumları kendiliğinden kaydeder: 24 saatte olağan dışı gelir (ani servet),
--     aynı iki oyuncu arasında 7 günde 3+ alım-satım, parti kasasından büyük harcama, ihalenin
--     ihaleyi açanla aynı partiden birine gitmesi. Yetkili moderatör (yeni yetki "ekonomi") inceler:
--     temiz / ihtar / el koyma (para hazineye geçer, oyuncuya bildirilir, kayıt tutulur).
--  4) Ödül tavanları anket fonksiyonunda (modül 86): ödül için en az 7 günlük hesap, günde en fazla 3 ödül.
--  5) ŞEFFAFLIK: her partinin kasa defteri herkese açık; büyük harcamada genel başkan yardımcılarına
--     bildirim gider. Yönetimin dağıttığı hediyeler herkese açık listede.
--  Ayarlar oyun.guvenlik_ayar'da; yönetici SQL ile değiştirebilir. Önce 84, 85, 86 kurulmuş olmalı.
-- =====================================================================

create table if not exists oyun.guvenlik_ayar(
  id                  int primary key default 1 check (id = 1),
  fiyat_bandi         boolean not null default true,
  masak               boolean not null default true,
  masak_servet_esik   numeric not null default 1000000,  -- 24 saatte bu kadar gelir (fiyat düzeyiyle) → bildirim
  odul_min_gun        int not null default 7,
  gunluk_odul_sinir   int not null default 3,
  parti_bildirim_esik numeric not null default 50000,
  parti_masak_esik    numeric not null default 250000
);
insert into oyun.guvenlik_ayar(id) values (1) on conflict do nothing;

create table if not exists oyun.masak(
  id          bigserial primary key,
  tur         text not null check (tur in ('ani_servet','tekrarlayan_ticaret','parti_harcama','ihale_kayirma')),
  user_id     uuid,
  karsi_id    uuid,
  parti_id    bigint,
  tutar       numeric,
  aciklama    text not null,
  zaman       timestamptz not null,
  durum       text not null default 'yeni' check (durum in ('yeni','temiz','ihtar','el_koyuldu')),
  karar_veren uuid,
  karar_not   text,
  karar_zaman timestamptz,
  el_koyulan  numeric
);
create index if not exists masak_durum on oyun.masak(durum, zaman desc);
create index if not exists masak_user on oyun.masak(user_id, tur, zaman desc);

do $$ begin
  execute 'alter table oyun.guvenlik_ayar enable row level security';
  execute 'alter table oyun.masak enable row level security';
  revoke all on oyun.guvenlik_ayar, oyun.masak from public, anon, authenticated;
  revoke all on sequence oyun.masak_id_seq from public, anon, authenticated;
end $$;

-- Moderatör yetkisi "ekonomi" (eski yetkiler aynen kalır)
create or replace function oyun.mod_yetki_tanim() returns table(kod text, ad text, aciklama text, sira int) language sql immutable as $$
  values ('ozet',        'Özet',                    'Oyuncu sayısı, aktiflik, açık şikâyet gibi özet rakamları görür.', 1),
         ('sikayet',     'Şikâyetler',              'Şikâyet edilen mesaj ve yayınları görür; "sorun yok" ya da "gizle" kararı verir.', 2),
         ('sustur',      'Susturma',                'Oyuncuyu 1 ya da 7 gün susturur, susturmayı kaldırır.', 3),
         ('hesap_kapat', 'Hesap kapatma',           'Kural ihlali yapan hesabı kapatır ya da yeniden açar.', 4),
         ('oyuncu_ara',  'Oyuncu inceleme',         'Oyuncunun bilgilerini ve son mesajlarını görür.', 5),
         ('eposta',      'E-posta görme',           'Oyuncu incelerken e-posta adresini de görür (kişisel veri; dikkatli ver).', 6),
         ('duyuru',      'Duyuru',                  'Tüm oyunculara oyun yönetimi adına duyuru gönderir.', 7),
         ('coklu_hesap', 'Çoklu hesap incelemesi',  'Aynı cihazdan açılan hesapları görür, gerçek kişi olanları onaylar.', 8),
         ('kurallar',    'Kurallar ve ayarlar',     'Vatandaşlık, parti kurma, teşkilat, havale ve banka kurallarını değiştirir.', 9),
         ('ekonomi',     'MASAK (ekonomi denetimi)', 'Şüpheli işlem bildirimlerini inceler; temiz, ihtar ya da el koyma kararı verir.', 10)
$$;

-- ---------------------------------------------------------------- temel yardımcılar
create or replace function oyun.iliskili(a uuid, b uuid) returns boolean language sql stable set search_path = '' as $$
  select a is not null and b is not null and a <> b
     and coalesce((select coklu_kontrol from oyun.ayarlar where id = 1), true)
     and exists (select 1 from oyun.bagli_hesaplar(a) x where x = b)
$$;
create or replace function oyun.iliskili_hata() returns void language plpgsql as $$
begin
  raise exception 'Aynı cihazda açılmış (ilişkili) hesaplar arasında bu işlem yapılamaz. Aileniz aynı cihazı kullanıyorsa oyun yönetimine başvurun.';
end $$;
create or replace function oyun.bant_acik() returns boolean language sql stable set search_path = '' as $$
  select coalesce((select fiyat_bandi from oyun.guvenlik_ayar where id = 1), true)
$$;
-- Şirketin %1 payının kabul edilebilir aralığı (defter değeri = kasa)
create or replace function oyun.pay_bandi(p_sirket bigint, out alt numeric, out ust numeric) language sql stable set search_path = '' as $$
  select round(greatest(0, s.kasa) * 0.5 / 100), round(greatest(s.kasa, s.sermaye, 1) * 3 / 100) from oyun.sirketler s where s.id = p_sirket
$$;
create or replace function oyun.masak_ekle(p_tur text, p_user uuid, p_karsi uuid, p_parti bigint, p_tutar numeric, p_aciklama text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce((select masak from oyun.guvenlik_ayar where id = 1), true) then return; end if;
  insert into oyun.masak(tur, user_id, karsi_id, parti_id, tutar, aciklama, zaman) values (p_tur, p_user, p_karsi, p_parti, p_tutar, p_aciklama, oyun.simdi());
end $$;

-- ---------------------------------------------------------------- 1-2) borsa
create or replace function oyun.tg_borsa_emir_bant() returns trigger language plpgsql security definer set search_path = '' as $$
declare son numeric; ref numeric; alt numeric; ust numeric;
begin
  if not oyun.bant_acik() then return new; end if;
  select birim into son from oyun.borsa_islem where sirket_id = new.sirket_id order by zaman desc, id desc limit 1;
  if son is not null then alt := round(son * 0.8); ust := round(son * 1.2);
  else ref := oyun.borsa_son_fiyat(new.sirket_id); alt := round(ref * 0.5); ust := round(ref * 2); end if;
  if new.birim < alt or new.birim > ust then
    raise exception 'Fiyat bandı: %%1 pay fiyatı % ₺ ile % ₺ arasında olmalı (son işlem fiyatına göre).', oyun.tl(alt), oyun.tl(ust);
  end if;
  return new;
end $$;
drop trigger if exists borsa_emir_bant on oyun.borsa_emir;
create trigger borsa_emir_bant before insert on oyun.borsa_emir for each row execute function oyun.tg_borsa_emir_bant();

create or replace function oyun.tg_borsa_islem() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' and tg_when = 'BEFORE' then
    if oyun.iliskili(new.satici, new.alici) then perform oyun.iliskili_hata(); end if;
    return new;
  end if;
  perform oyun.masak_cift_kontrol(new.satici, new.alici, new.tutar);
  return new;
end $$;
drop trigger if exists borsa_islem_iliski on oyun.borsa_islem;
create trigger borsa_islem_iliski before insert on oyun.borsa_islem for each row execute function oyun.tg_borsa_islem();
drop trigger if exists borsa_islem_masak on oyun.borsa_islem;
create trigger borsa_islem_masak after insert on oyun.borsa_islem for each row execute function oyun.tg_borsa_islem();

-- Aynı iki oyuncu 7 günde 3+ kez alım-satım yaptıysa (yönü fark etmez) MASAK'a düşer
create or replace function oyun.masak_cift_kontrol(a uuid, b uuid, p_tutar numeric) returns void
language plpgsql security definer set search_path = '' as $$
declare n int; t timestamptz := oyun.simdi();
begin
  if a is null or b is null or a = b then return; end if;
  select (select count(*) from oyun.borsa_islem where zaman > t - interval '7 days' and ((satici = a and alici = b) or (satici = b and alici = a)))
       + (select count(*) from oyun.ticaret_devir_kayit where zaman > t - interval '7 days' and ((satici = a and alici = b) or (satici = b and alici = a)))
    into n;
  if n >= 3 and not exists (select 1 from oyun.masak where tur = 'tekrarlayan_ticaret' and zaman > t - interval '7 days'
                            and ((user_id = a and karsi_id = b) or (user_id = b and karsi_id = a))) then
    perform oyun.masak_ekle('tekrarlayan_ticaret', a, b, null, p_tutar,
      format('%s ile %s son 7 günde %s kez birbirleriyle alım-satım yaptı.', oyun.kad(a), oyun.kad(b), n));
  end if;
end $$;

-- ---------------------------------------------------------------- şirket, hisse ve emlak satışları
create or replace function oyun.tg_ticaret_devir() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_when = 'BEFORE' then
    if oyun.iliskili(new.satici, new.alici) then perform oyun.iliskili_hata(); end if;
  else
    perform oyun.masak_cift_kontrol(new.satici, new.alici, new.bedel);
  end if;
  return new;
end $$;
drop trigger if exists ticaret_devir_iliski on oyun.ticaret_devir_kayit;
create trigger ticaret_devir_iliski before insert on oyun.ticaret_devir_kayit for each row execute function oyun.tg_ticaret_devir();
drop trigger if exists ticaret_devir_masak on oyun.ticaret_devir_kayit;
create trigger ticaret_devir_masak after insert on oyun.ticaret_devir_kayit for each row execute function oyun.tg_ticaret_devir();

-- Ortaklık teklifi: verirken bant + ilişki, kabulde ilişki
create or replace function oyun.tg_sirket_teklif() returns trigger language plpgsql security definer set search_path = '' as $$
declare b record; birim numeric;
begin
  if oyun.iliskili(new.satici, new.alici) and (tg_op = 'INSERT' or new.durum = 'kabul') then perform oyun.iliskili_hata(); end if;
  if tg_op = 'INSERT' and oyun.bant_acik() and new.pay > 0 then
    select * into b from oyun.pay_bandi(new.sirket_id);
    birim := new.bedel / new.pay;
    if birim < b.alt or birim > b.ust then
      raise exception 'Fiyat bandı: %%% pay için bedel % ₺ ile % ₺ arasında olmalı (şirketin defter değerine göre).',
        new.pay, oyun.tl(b.alt * new.pay), oyun.tl(b.ust * new.pay);
    end if;
  end if;
  if tg_op = 'UPDATE' and new.durum = 'kabul' and old.durum is distinct from 'kabul' then
    perform oyun.masak_cift_kontrol(new.satici, new.alici, new.bedel);
  end if;
  return new;
end $$;
drop trigger if exists sirket_teklif_guvenlik on oyun.sirket_teklif;
create trigger sirket_teklif_guvenlik before insert or update on oyun.sirket_teklif for each row execute function oyun.tg_sirket_teklif();

-- Şirketin tamamını satışa çıkarma fiyatı
create or replace function oyun.tg_sirket_satilik() returns trigger language plpgsql security definer set search_path = '' as $$
declare b record;
begin
  if new.satilik is null or new.satilik is not distinct from old.satilik or not oyun.bant_acik() then return new; end if;
  select * into b from oyun.pay_bandi(new.id);
  if new.satilik < b.alt * 100 or new.satilik > b.ust * 100 then
    raise exception 'Fiyat bandı: şirketin satış fiyatı % ₺ ile % ₺ arasında olmalı (şirket kasasına ve sermayesine göre).', oyun.tl(b.alt * 100), oyun.tl(b.ust * 100);
  end if;
  return new;
end $$;
drop trigger if exists sirket_satilik_bant on oyun.sirketler;
create trigger sirket_satilik_bant before update of satilik on oyun.sirketler for each row execute function oyun.tg_sirket_satilik();

-- Emlak: rayiç bedele göre bant, satışta ilişki
create or replace function oyun.mulk_bant(p_mulk bigint, out alt numeric, out ust numeric) language sql stable set search_path = '' as $$
  select round(oyun.mulk_il_bedel(m.il_id, m.tip) * 0.4), round(oyun.mulk_il_bedel(m.il_id, m.tip) * 2.5) from oyun.yatirim_mulkleri m where m.id = p_mulk
$$;
create or replace function oyun.tg_mulk_ilan() returns trigger language plpgsql security definer set search_path = '' as $$
declare b record;
begin
  if (tg_op = 'INSERT' or new.fiyat is distinct from old.fiyat) and oyun.bant_acik() then
    select * into b from oyun.mulk_bant(new.mulk_id);
    if b.alt is not null and (new.fiyat < b.alt or new.fiyat > b.ust) then
      raise exception 'Fiyat bandı: bu mülk % ₺ ile % ₺ arasında satılabilir (ilin rayiç bedeline göre).', oyun.tl(b.alt), oyun.tl(b.ust);
    end if;
  end if;
  if tg_op = 'UPDATE' and new.durum = 'satildi' and old.durum is distinct from 'satildi' then
    if oyun.iliskili(new.satici, new.alici) then perform oyun.iliskili_hata(); end if;
    perform oyun.masak_cift_kontrol(new.satici, new.alici, new.fiyat);
  end if;
  return new;
end $$;
drop trigger if exists mulk_ilan_guvenlik on oyun.mulk_ilan;
create trigger mulk_ilan_guvenlik before insert or update on oyun.mulk_ilan for each row execute function oyun.tg_mulk_ilan();

create or replace function oyun.tg_emlak_pazarlik() returns trigger language plpgsql security definer set search_path = '' as $$
declare b record; v_mulk bigint;
begin
  if tg_op = 'INSERT' and oyun.iliskili(new.alici, new.satici) then perform oyun.iliskili_hata(); end if;
  if oyun.bant_acik() and (tg_op = 'INSERT' or new.teklif is distinct from old.teklif or new.karsi_teklif is distinct from old.karsi_teklif) then
    select mulk_id into v_mulk from oyun.mulk_ilan where id = new.ilan_id;
    select * into b from oyun.mulk_bant(v_mulk);
    if b.alt is not null and ((new.teklif is not null and (new.teklif < b.alt or new.teklif > b.ust))
        or (new.karsi_teklif is not null and (new.karsi_teklif < b.alt or new.karsi_teklif > b.ust))) then
      raise exception 'Fiyat bandı: bu mülk için teklif % ₺ ile % ₺ arasında olmalı.', oyun.tl(b.alt), oyun.tl(b.ust);
    end if;
  end if;
  return new;
end $$;
do $$ begin
  if to_regclass('oyun.emlak_pazarlik') is not null then
    execute 'drop trigger if exists emlak_pazarlik_guvenlik on oyun.emlak_pazarlik';
    execute 'create trigger emlak_pazarlik_guvenlik before insert or update on oyun.emlak_pazarlik for each row execute function oyun.tg_emlak_pazarlik()';
  end if;
end $$;

-- Diğer oturumun eklediği hisse ilan pazarı (varsa): ilan verirken bant
create or replace function oyun.tg_hisse_ilan() returns trigger language plpgsql security definer set search_path = '' as $$
declare b record; birim numeric;
begin
  if not oyun.bant_acik() or new.pay is null or new.pay <= 0 then return new; end if;
  select * into b from oyun.pay_bandi(new.sirket_id);
  birim := new.bedel / new.pay;
  if birim < b.alt or birim > b.ust then
    raise exception 'Fiyat bandı: %%% pay için bedel % ₺ ile % ₺ arasında olmalı (şirketin defter değerine göre).', new.pay, oyun.tl(b.alt * new.pay), oyun.tl(b.ust * new.pay);
  end if;
  return new;
end $$;
do $$ begin
  if to_regclass('oyun.sirket_hisse_ilanlari') is not null then
    execute 'drop trigger if exists hisse_ilan_bant on oyun.sirket_hisse_ilanlari';
    execute 'create trigger hisse_ilan_bant before insert on oyun.sirket_hisse_ilanlari for each row execute function oyun.tg_hisse_ilan()';
  end if;
end $$;

-- ---------------------------------------------------------------- ihale, ajans
create or replace function oyun.tg_ihale_teklif() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_acan uuid;
begin
  select acan into v_acan from oyun.kamu_ihale where id = new.ihale_id;
  if exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = new.sirket_id and oyun.iliskili(o.user_id, v_acan)) then
    raise exception 'Çıkar çatışması: bu şirketin bir ortağı ihaleyi açan kişiyle aynı cihazı kullanıyor.';
  end if;
  return new;
end $$;
drop trigger if exists ihale_teklif_iliski on oyun.kamu_ihale_teklif;
create trigger ihale_teklif_iliski before insert or update on oyun.kamu_ihale_teklif for each row execute function oyun.tg_ihale_teklif();

-- İhale ihaleyi açanla aynı partiden birinin şirketine giderse MASAK'a düşer (engel değil, inceleme)
create or replace function oyun.tg_ihale_sonuc() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_sahip uuid; pa bigint; pb bigint;
begin
  if new.kazanan is null or old.kazanan is not distinct from new.kazanan then return new; end if;
  v_sahip := oyun.sirket_sahibi(new.kazanan);
  select parti_id into pa from oyun.profiller where id = new.acan;
  select parti_id into pb from oyun.profiller where id = v_sahip;
  if pa is not null and pa = pb then
    perform oyun.masak_ekle('ihale_kayirma', new.acan, v_sahip, pa, new.bedel,
      format('%s ihalesi (#%s) ihaleyi açan %s ile aynı partiden %s''in şirketine gitti (%s ₺).',
        (select ad from oyun.kamu_ihale_proje where kod = new.proje), new.id, oyun.kad(new.acan), oyun.kad(v_sahip), oyun.tl(new.bedel)));
  end if;
  return new;
end $$;
drop trigger if exists ihale_sonuc_masak on oyun.kamu_ihale;
create trigger ihale_sonuc_masak after update of kazanan on oyun.kamu_ihale for each row execute function oyun.tg_ihale_sonuc();

create or replace function oyun.tg_ajans_is() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = new.sirket_id and oyun.iliskili(o.user_id, new.veren)) then
    raise exception 'Bu ajansın bir ortağı seninle aynı cihazı kullanıyor; ondan sipariş veremezsin.';
  end if;
  return new;
end $$;
drop trigger if exists ajans_is_iliski on oyun.ajans_is;
create trigger ajans_is_iliski before insert on oyun.ajans_is for each row execute function oyun.tg_ajans_is();

create or replace function oyun.tg_ajans_cevap() returns trigger language plpgsql security definer set search_path = '' as $$
declare j oyun.ajans_is;
begin
  select * into j from oyun.ajans_is where id = new.is_id;
  if oyun.iliskili(new.user_id, j.veren) or exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = j.sirket_id and oyun.iliskili(o.user_id, new.user_id)) then
    raise exception 'Anketi yaptıranla ya da ajansla aynı cihazı kullanan hesaplar bu ankete katılamaz.';
  end if;
  return new;
end $$;
drop trigger if exists ajans_cevap_iliski on oyun.ajans_cevap;
create trigger ajans_cevap_iliski before insert on oyun.ajans_cevap for each row execute function oyun.tg_ajans_cevap();

-- ---------------------------------------------------------------- MASAK: ani servet, parti harcaması
create or replace function oyun.tg_masak_gelir() returns trigger language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); toplam numeric; esik numeric;
begin
  if new.tutar <= 0 or new.tur in ('yonetici','iade') then return new; end if;
  esik := (select masak_servet_esik from oyun.guvenlik_ayar where id = 1) * coalesce((select endeks from oyun.ulke where id = 1), 1);
  if new.tutar < esik * 0.1 then return new; end if;     -- küçük girişler için sorgu yapılmaz
  select coalesce(sum(tutar), 0) into toplam from oyun.hesap_hareket
    where user_id = new.user_id and tutar > 0 and tur not in ('yonetici','iade') and zaman > t - interval '24 hours';
  if toplam >= esik and not exists (select 1 from oyun.masak where tur = 'ani_servet' and user_id = new.user_id and zaman > t - interval '24 hours') then
    perform oyun.masak_ekle('ani_servet', new.user_id, null, null, toplam,
      format('%s son 24 saatte %s ₺ gelir elde etti (son kalem: %s, %s).', oyun.kad(new.user_id), oyun.tl(toplam), new.tur, left(new.aciklama, 80)));
  end if;
  return new;
end $$;
drop trigger if exists hesap_hareket_masak on oyun.hesap_hareket;
create trigger hesap_hareket_masak after insert on oyun.hesap_hareket for each row execute function oyun.tg_masak_gelir();

create or replace function oyun.tg_parti_harcama() returns trigger language plpgsql security definer set search_path = '' as $$
declare a oyun.guvenlik_ayar; pa oyun.partiler; u uuid; once numeric;
begin
  if new.tutar >= 0 then return new; end if;
  select * into a from oyun.guvenlik_ayar where id = 1;
  if -new.tutar < a.parti_bildirim_esik then return new; end if;
  select * into pa from oyun.partiler where id = new.parti_id;
  -- genel başkan yardımcılarına bilgi
  for u in select user_id from oyun.parti_gby where parti_id = new.parti_id loop
    perform oyun.bildir(u, format('%s kasasından %s ₺ harcandı: %s. Kasa defteri herkese açık.', pa.kisa, oyun.tl(-new.tutar), left(new.aciklama, 100)), new.zaman);
  end loop;
  once := coalesce(pa.kasa, 0) - new.tutar;
  if -new.tutar >= a.parti_masak_esik or (once > 0 and -new.tutar >= once * 0.3) then
    perform oyun.masak_ekle('parti_harcama', pa.gb, null, pa.id, -new.tutar,
      format('%s kasasından tek seferde %s ₺ çıktı (kasanın %%%s''i): %s.', pa.ad, oyun.tl(-new.tutar),
        case when once > 0 then round(-new.tutar * 100 / once) else 100 end, left(new.aciklama, 100)));
  end if;
  return new;
end $$;
drop trigger if exists parti_hareket_masak on oyun.parti_hareket;
create trigger parti_hareket_masak after insert on oyun.parti_hareket for each row execute function oyun.tg_parti_harcama();

-- ---------------------------------------------------------------- 4) anket ödül tavanı (modül 86'nın fonksiyonu)
create or replace function public.ajans_anket_cevap(p_is bigint, p_parti bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.ajans_is; v_odul numeric := 0; g oyun.guvenlik_ayar;
begin
  select * into g from oyun.guvenlik_ayar where id = 1;
  select * into k from oyun.ajans_is where id = p_is for update;
  if k.id is null or k.tur <> 'anket' or k.durum <> 'yayinda' or k.bit <= t then raise exception 'Anket sona erdi.'; end if;
  if k.il_id is not null and k.il_id <> p.il_id then raise exception 'Bu anket başka bir ilde yapılıyor.'; end if;
  if k.veren = p.id then raise exception 'Kendi yaptırdığın ankete katılamazsın.'; end if;
  if p_parti is not null and not exists (select 1 from oyun.partiler where id = p_parti and not kapali) then raise exception 'Geçersiz parti.'; end if;
  if exists (select 1 from oyun.ajans_cevap where is_id = k.id and user_id = p.id) then raise exception 'Bu ankete zaten katıldın.'; end if;
  -- ödül: havuz ve kasa yeterliyse, hesap en az N günlükse ve bugün ödül sınırı dolmadıysa
  if k.havuz >= k.odul and k.odul > 0 and p.olusturma < t - g.odul_min_gun * interval '1 day'
     and (select count(*) from oyun.ajans_cevap where user_id = p.id and odul > 0 and zaman > t - interval '24 hours') < g.gunluk_odul_sinir
     and (select kasa from oyun.sirketler where id = k.sirket_id) >= k.odul then
    v_odul := k.odul;
    update oyun.ajans_is set havuz = havuz - v_odul where id = k.id;
    update oyun.sirketler set kasa = kasa - v_odul where id = k.sirket_id;
    update oyun.ajans set hafta_odul = hafta_odul + v_odul where sirket_id = k.sirket_id;
    perform oyun.para_islem(p.id, v_odul, 'odul', format('%s anketine katılım ödülü', (select ad from oyun.sirketler where id = k.sirket_id)), t);
  end if;
  insert into oyun.ajans_cevap(is_id, user_id, parti_id, odul, zaman) values (k.id, p.id, p_parti, v_odul, t);
  return jsonb_build_object('tamam', true, 'odul', v_odul,
    'odulsuz_neden', case when v_odul > 0 or k.odul = 0 then null
      when p.olusturma >= t - g.odul_min_gun * interval '1 day' then format('Katılım ödülü %s günden eski hesaplara verilir.', g.odul_min_gun)
      when k.havuz < k.odul then 'Bu anketin ödül havuzu tükendi.'
      else format('Günde en fazla %s anketten ödül alınabilir.', g.gunluk_odul_sinir) end);
end $$;

-- ---------------------------------------------------------------- 5) şeffaflık
create or replace function public.parti_kasa_defteri(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler; t timestamptz := oyun.simdi();
begin
  select * into pa from oyun.partiler where id = p_parti;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  return jsonb_build_object('id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk, 'kasa', round(pa.kasa), 'gb', oyun.kad(pa.gb),
    'giris_30g', coalesce((select sum(tutar) from oyun.parti_hareket where parti_id = pa.id and tutar > 0 and zaman > t - interval '30 days'), 0),
    'cikis_30g', coalesce((select -sum(tutar) from oyun.parti_hareket where parti_id = pa.id and tutar < 0 and zaman > t - interval '30 days'), 0),
    'turler', coalesce((select jsonb_agg(jsonb_build_object('tur', tur, 'giris', giris, 'cikis', cikis) order by giris + cikis desc) from (
        select tur, sum(greatest(tutar, 0)) giris, -sum(least(tutar, 0)) cikis from oyun.parti_hareket
        where parti_id = pa.id and zaman > t - interval '30 days' group by tur) z), '[]'::jsonb),
    'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'aciklama', h.aciklama, 'tur', h.tur) order by h.zaman desc, h.id desc)
        from (select * from oyun.parti_hareket where parti_id = pa.id order by zaman desc, id desc limit 100) h), '[]'::jsonb),
    'partiler', (select jsonb_agg(jsonb_build_object('id', id, 'ad', ad, 'kisa', kisa) order by ad) from oyun.partiler where not kapali));
end $$;

create or replace function public.yonetim_hediyeleri() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  return jsonb_build_object(
    'toplam', coalesce((select sum(tutar) from oyun.hesap_hareket where tur = 'yonetici' and tutar > 0), 0),
    'kisi', (select count(distinct user_id) from oyun.hesap_hareket where tur = 'yonetici' and tutar > 0),
    'liste', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(h.user_id), 'tutar', h.tutar, 'aciklama', h.aciklama, 'zaman', h.zaman) order by h.zaman desc)
      from (select * from oyun.hesap_hareket where tur = 'yonetici' and tutar > 0 order by zaman desc limit 100) h), '[]'::jsonb),
    'el_koyma', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(m.user_id), 'tutar', m.el_koyulan, 'not', m.karar_not, 'zaman', m.karar_zaman) order by m.karar_zaman desc)
      from (select * from oyun.masak where durum = 'el_koyuldu' order by karar_zaman desc limit 30) m), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------- MASAK paneli (moderatör: "ekonomi")
create or replace function public.admin_masak(p_durum text default 'yeni') returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('ekonomi');
begin
  return jsonb_build_object(
    'sayilar', (select jsonb_object_agg(durum, n) from (select durum, count(*) n from oyun.masak group by durum) z),
    'ayar', (select row_to_json(a) from oyun.guvenlik_ayar a where id = 1),
    'kayitlar', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'tur', m.tur, 'kad', oyun.kad(m.user_id), 'karsi', oyun.kad(m.karsi_id),
        'parti', (select kisa from oyun.partiler where id = m.parti_id), 'tutar', m.tutar, 'aciklama', m.aciklama, 'zaman', m.zaman,
        'durum', m.durum, 'karar_not', m.karar_not, 'karar_veren', oyun.kad(m.karar_veren), 'el_koyulan', m.el_koyulan,
        'para', (select para from oyun.cuzdan where user_id = m.user_id),
        'bagli', (select jsonb_agg(oyun.kad(b)) from oyun.bagli_hesaplar(m.user_id) b),
        'son_gelirler', (select jsonb_agg(jsonb_build_object('tur', h.tur, 'tutar', h.tutar, 'aciklama', h.aciklama, 'zaman', h.zaman) order by h.zaman desc)
           from (select * from oyun.hesap_hareket where user_id = m.user_id and tutar > 0 order by zaman desc limit 8) h)) order by m.zaman desc)
      from (select * from oyun.masak where p_durum is null or durum = p_durum order by zaman desc limit 50) m), '[]'::jsonb));
end $$;

create or replace function public.admin_masak_karar(p_id bigint, p_karar text, p_tutar numeric default null, p_not text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('ekonomi'); m oyun.masak; t timestamptz := oyun.simdi(); v_para numeric; v_al numeric := 0;
begin
  select * into m from oyun.masak where id = p_id for update;
  if m.id is null then raise exception 'Kayıt bulunamadı.'; end if;
  if m.durum <> 'yeni' then raise exception 'Bu kayıt için zaten karar verildi.'; end if;
  if p_karar not in ('temiz','ihtar','el_koy') then raise exception 'Karar temiz, ihtar ya da el_koy olmalı.'; end if;
  if p_karar <> 'temiz' and char_length(coalesce(btrim(p_not), '')) < 10 then raise exception 'İhtar ve el koymada en az 10 karakterlik gerekçe yaz.'; end if;
  if m.user_id is not null then perform oyun.korunan_hedef(p, m.user_id); end if;
  if p_karar = 'el_koy' then
    if m.user_id is null then raise exception 'Bu kayıtta el konulacak kişi yok.'; end if;
    if p_tutar is null or p_tutar <= 0 then raise exception 'El konulacak tutarı yaz.'; end if;
    select para into v_para from oyun.cuzdan where user_id = m.user_id for update;
    v_al := least(round(p_tutar), greatest(0, coalesce(v_para, 0)));
    if v_al > 0 then
      perform oyun.para_islem(m.user_id, -v_al, 'ceza', 'MASAK kararıyla el koyma: ' || left(p_not, 120), t);
      update oyun.ulke set hazine = hazine + v_al / coalesce(oyun.pazar_tl_milyar(), 1000000) where id = 1;
    end if;
    perform oyun.bildir(m.user_id, format('MASAK incelemesi sonucunda %s ₺ paranıza el konuldu ve hazineye aktarıldı. Gerekçe: %s', oyun.tl(v_al), p_not), t);
    perform oyun.olay('adalet', format('MASAK, haksız kazanç incelemesi sonucunda %s''in %s ₺ parasına el koydu.', oyun.kad(m.user_id), oyun.tl(v_al)), null, null, t);
  elsif p_karar = 'ihtar' and m.user_id is not null then
    perform oyun.bildir(m.user_id, format('MASAK ihtarı: %s Tekrarlanırsa paranıza el konulabilir ve hesabınız kapatılabilir.', p_not), t);
  end if;
  update oyun.masak set durum = case p_karar when 'temiz' then 'temiz' when 'ihtar' then 'ihtar' else 'el_koyuldu' end,
    karar_veren = p.id, karar_not = p_not, karar_zaman = t, el_koyulan = nullif(v_al, 0) where id = m.id;
  perform oyun.mod_log(p, 'masak_' || p_karar, oyun.kad(m.user_id), format('#%s %s %s', m.id, m.tur, coalesce(p_not, '')));
  return public.admin_masak('yeni');
end $$;

revoke all on function public.parti_kasa_defteri(bigint), public.yonetim_hediyeleri(), public.admin_masak(text),
  public.admin_masak_karar(bigint, text, numeric, text), public.ajans_anket_cevap(bigint, bigint) from public, anon;
grant execute on function public.parti_kasa_defteri(bigint), public.yonetim_hediyeleri(), public.admin_masak(text),
  public.admin_masak_karar(bigint, text, numeric, text), public.ajans_anket_cevap(bigint, bigint) to authenticated;
revoke all on function oyun.iliskili(uuid, uuid), oyun.iliskili_hata(), oyun.bant_acik(), oyun.pay_bandi(bigint), oyun.masak_ekle(text, uuid, uuid, bigint, numeric, text),
  oyun.masak_cift_kontrol(uuid, uuid, numeric), oyun.mulk_bant(bigint), oyun.tg_borsa_emir_bant(), oyun.tg_borsa_islem(), oyun.tg_ticaret_devir(),
  oyun.tg_sirket_teklif(), oyun.tg_sirket_satilik(), oyun.tg_mulk_ilan(), oyun.tg_emlak_pazarlik(), oyun.tg_hisse_ilan(), oyun.tg_ihale_teklif(),
  oyun.tg_ihale_sonuc(), oyun.tg_ajans_is(), oyun.tg_ajans_cevap(), oyun.tg_masak_gelir(), oyun.tg_parti_harcama() from public, anon, authenticated;
