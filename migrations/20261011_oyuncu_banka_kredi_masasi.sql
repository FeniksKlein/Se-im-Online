-- 89 · Oyuncu bankalarında kredi masası
-- * Kredi çekmek için o bankada hesap açmak zorunlu (oyun.oyb_hesap)
-- * Banka sahibi kredi paketleri tanımlar: vade (1-30 gün), taksit sayısı, faiz, alt/üst tutar,
--   asgari kredi notu, otomatik onay. Otomatik paketlerde kredi anında, banka kasasının
--   mevduat güvencesi dışında kalan kısmı kadar verilir (oyun.oyb_saglik.kredi_verilebilir).
-- * Banka sahibi hesap sahiplerinden mali bilgi ister, inisiyatif alarak kredi teklif eder.
-- * Çekmeden önce ödeme planı (oyb_kredi_plan); erken kapama, geçen süreye göre faiz + %1 ücret.
-- * Ödemeyene dava/gelir haczi mevcut Adliye icrası (oyb_icra_baslat) ile.
-- Oyuncu verisi silinmez; yalnız tablo/sütun eklenir, izin listeleri genişler.
begin;

-- ---------- tablolar ----------
create table if not exists oyun.oyb_hesap(
  banka_id bigint not null references oyun.sirketler(id),
  user_id uuid not null,
  acilis timestamptz not null default now(),
  kapanis timestamptz,
  primary key (banka_id, user_id));

create table if not exists oyun.oyb_kredi_paket(
  id bigserial primary key,
  banka_id bigint not null references oyun.sirketler(id),
  ad text not null check (char_length(ad) between 3 and 40),
  vade_gun smallint not null check (vade_gun between 1 and 30),
  taksit_sayisi smallint not null check (taksit_sayisi between 1 and 30),
  faiz numeric(6,2) not null check (faiz between 0 and 20),
  min_tutar numeric not null default 1000 check (min_tutar >= 1000),
  max_tutar numeric not null check (max_tutar <= 10000000),
  otomatik boolean not null default true,
  min_not integer not null default 900 check (min_not between 0 and 1900),
  aktif boolean not null default true,
  olusturma timestamptz not null default now(),
  check ((vade_gun * 24) % taksit_sayisi = 0),
  check (max_tutar >= min_tutar));

create table if not exists oyun.oyb_kredi_teklifi(
  id bigserial primary key,
  banka_id bigint not null references oyun.sirketler(id),
  user_id uuid not null,
  tutar numeric not null check (tutar between 1000 and 10000000),
  vade_gun smallint not null check (vade_gun between 1 and 30),
  taksit_sayisi smallint not null check (taksit_sayisi between 1 and 30),
  faiz numeric(6,2) not null check (faiz between 0 and 20),
  mesaj text,
  durum text not null default 'teklif' check (durum in ('teklif','kabul','ret','iptal','suresi')),
  olusturma timestamptz not null default now(),
  son timestamptz not null,
  kredi_id bigint,
  check ((vade_gun * 24) % taksit_sayisi = 0));

create table if not exists oyun.oyb_hesap_bilgi(
  banka_id bigint not null references oyun.sirketler(id),
  user_id uuid not null,
  istenen text[] not null,
  izinli text[] not null default '{}',
  durum text not null default 'talep' check (durum in ('talep','izin','ret')),
  istek_at timestamptz not null default now(),
  cevap_at timestamptz,
  primary key (banka_id, user_id));

revoke all on oyun.oyb_hesap, oyun.oyb_kredi_paket, oyun.oyb_kredi_teklifi, oyun.oyb_hesap_bilgi from public, anon, authenticated;
revoke all on sequence oyun.oyb_kredi_paket_id_seq, oyun.oyb_kredi_teklifi_id_seq from public, anon, authenticated;

alter table oyun.oyb_kredi add column if not exists paket_id bigint;
alter table oyun.oyb_kredi add column if not exists teklif_id bigint;
alter table oyun.oyb_kredi add column if not exists erken_kapama boolean not null default false;
alter table oyun.oyb_kredi add column if not exists erken_indirim numeric not null default 0;

-- izin listeleri yalnız genişler: 1-30 günlük vadeler ve 10 milyon ₺'ye kadar kredi
alter table oyun.oyb_kredi drop constraint if exists oyb_kredi_saat_check;
alter table oyun.oyb_kredi add constraint oyb_kredi_saat_check
  check (saat in (1,3,6,12) or (saat % 24 = 0 and saat between 24 and 720));
alter table oyun.oyb_kredi drop constraint if exists oyb_kredi_anapara_check;
alter table oyun.oyb_kredi add constraint oyb_kredi_anapara_check
  check (anapara >= 1000 and anapara <= 10000000);

-- Mevcut müşterilere hesap: kredisi ya da mevduatı olanların hesabı açılmış sayılır
insert into oyun.oyb_hesap(banka_id, user_id, acilis)
select banka_id, borclu, min(basvuru) from oyun.oyb_kredi group by 1, 2
on conflict do nothing;
insert into oyun.oyb_hesap(banka_id, user_id, acilis)
select banka_id, user_id, min(acilis) from oyun.banka_mevduat group by 1, 2
on conflict do nothing;

-- Kredi risk özeti artık 1-720 saatin hepsini kabul eder (formül zaten vadeyle orantılı)
do $$
declare d text := pg_get_functiondef('oyun.kredi_risk_ozeti(uuid,integer)'::regprocedure);
begin
  if position('p_saat NOT IN (1,3,6,12,24,72,168,336,360,504,672,720)' in d) > 0 then
    execute replace(d, 'p_saat NOT IN (1,3,6,12,24,72,168,336,360,504,672,720)', 'p_saat NOT BETWEEN 1 AND 720');
  end if;
end $$;

-- ---------- yardımcılar ----------
create or replace function oyun.oyb_yonetici(p_banka bigint, u uuid) returns boolean
language sql stable set search_path to '' as $$
  select exists(select 1 from oyun.sirket_ortaklari where sirket_id = p_banka and user_id = u and pay >= 50)
$$;

create or replace function oyun.oyb_hesap_acik(p_banka bigint, u uuid) returns boolean
language sql stable set search_path to '' as $$
  select exists(select 1 from oyun.oyb_hesap where banka_id = p_banka and user_id = u and kapanis is null)
$$;

-- Ödeme planı (taksit tetikleyicisiyle aynı bölüşüm)
create or replace function oyun.oyb_plan(p_tutar numeric, p_vade_gun integer, p_taksit integer, p_faiz numeric, p_bas timestamptz)
returns jsonb language plpgsql stable set search_path to '' as $$
declare toplam numeric := round(p_tutar * (1 + p_faiz / 100)); saat integer := p_vade_gun * 24; n integer := greatest(1, p_taksit);
  liste jsonb := '[]'; od numeric; i integer;
begin
  for i in 1..n loop
    od := case when i = n then toplam - floor(toplam / n) * (n - 1) else floor(toplam / n) end;
    liste := liste || jsonb_build_object('sira', i, 'vade', p_bas + make_interval(hours => saat * i / n), 'tutar', od);
  end loop;
  return jsonb_build_object('anapara', p_tutar, 'faiz_orani', p_faiz, 'faiz_tutari', toplam - p_tutar, 'toplam', toplam,
    'vade_gun', p_vade_gun, 'taksit_sayisi', n, 'taksit_araligi_saat', saat / n, 'son_odeme', p_bas + make_interval(hours => saat), 'taksitler', liste);
end $$;

-- Erken kapama: geçen süre kadar faiz + kalan anaparanın %1'i; hiçbir zaman kalan borçtan fazla değil
create or replace function oyun.oyb_erken_kapama_tutari(k oyun.oyb_kredi, t timestamptz) returns jsonb
language plpgsql stable set search_path to '' as $$
declare gecen numeric; hak_faiz numeric; odenen numeric; ucret numeric; borc numeric;
begin
  if k.durum <> 'aktif' or k.acilis is null or k.vade is null then return null; end if;
  gecen := least(1, greatest(0, extract(epoch from (t - k.acilis)) / greatest(1, extract(epoch from (k.vade - k.acilis)))));
  hak_faiz := round((k.toplam - k.anapara) * gecen);
  odenen := k.toplam - k.kalan;
  ucret := case when t >= k.vade then 0 else round(greatest(0, k.anapara - k.anapara_odendi) * 0.01) end;
  borc := least(k.kalan, greatest(0, k.anapara + hak_faiz - odenen) + ucret);
  return jsonb_build_object('tutar', borc, 'indirim', k.kalan - borc, 'ucret', ucret, 'gecen_oran', round(gecen * 100, 1));
end $$;

-- Borçlunun bu vadedeki limiti
create or replace function oyun.oyb_kredi_limit(u uuid, p_saat integer) returns jsonb
language plpgsql stable set search_path to '' as $$
begin
  return oyun.kredi_risk_ozeti(u, least(720, greatest(1, p_saat)));
end $$;

-- Ortak kredi verme adımı (başvuru satırı aktife çevrilir; taksit tetikleyicisi planı yazar)
create or replace function oyun.oyb_kredi_kullandir(p_kredi bigint, t timestamptz) returns jsonb
language plpgsql set search_path to '' as $$
declare k oyun.oyb_kredi; s oyun.sirketler; r jsonb;
begin
  select * into k from oyun.oyb_kredi where id = p_kredi for update;
  select * into s from oyun.sirketler where id = k.banka_id and aktif and sektor = 'banka' for update;
  if s.id is null then raise exception 'Banka faal değil.'; end if;
  if exists(select 1 from oyun.banka_mevduat where banka_id = s.id and not kapandi and vade <= t) then
    raise exception 'Bankanın gecikmiş mevduat ödemesi var; kredi veremez.'; end if;
  r := oyun.oyb_saglik(s.id);
  if k.anapara > (r->>'kredi_verilebilir')::numeric then
    raise exception 'Bankanın kredi verebileceği para yetersiz (en çok % ₺).', oyun.tl(greatest(0, (r->>'kredi_verilebilir')::numeric)); end if;
  update oyun.sirketler set kasa = kasa - k.anapara where id = s.id and kasa >= k.anapara;
  if not found then raise exception 'Banka kasasında yeterli para yok.'; end if;
  update oyun.oyb_kredi set durum = 'aktif', acilis = t, vade = t + make_interval(hours => k.saat) where id = k.id;
  perform oyun.para_islem(k.borclu, k.anapara, 'oyb_kredi', s.ad || ' kredisi #' || k.id, t);
  insert into oyun.sirket_hareket(sirket_id, tutar, aciklama) values (s.id, 0, 'Kredi #' || k.id || ' kullandırıldı: ' || k.anapara || ' ₺');
  return jsonb_build_object('id', k.id, 'vade', t + make_interval(hours => k.saat));
end $$;

-- Hesap zorunluluğu ve paket/teklif kredilerinin ürün kontrolünden muaf tutulması
create or replace function oyun.oyb_kredi_hesap_kontrol() returns trigger
language plpgsql set search_path to '' as $$
begin
  if not oyun.oyb_hesap_acik(new.banka_id, new.borclu) then
    raise exception 'Kredi çekmek için önce bu bankada hesap açmalısın.';
  end if;
  return new;
end $$;
drop trigger if exists oyb_kredi_hesap on oyun.oyb_kredi;
create trigger oyb_kredi_hesap before insert on oyun.oyb_kredi for each row execute function oyun.oyb_kredi_hesap_kontrol();

create or replace function oyun.oyb_kredi_urun_dogrula() returns trigger
language plpgsql set search_path to '' as $function$
DECLARE ur oyun.oyb_kredi_urun;
BEGIN
 IF new.paket_id IS NOT NULL OR new.teklif_id IS NOT NULL THEN RETURN new; END IF; -- kredi masası: değerler RPC'de belirlendi
 IF new.saat IN (1,3,6,12) THEN RETURN new; END IF; -- legacy short-hour products unaffected
 SELECT * INTO ur FROM oyun.oyb_kredi_urun
 WHERE banka_id=new.banka_id AND saat=new.saat AND aktif;
 IF NOT FOUND THEN RAISE EXCEPTION 'Banka bu kredi vadesini sunmuyor'; END IF;
 new.taksit_sayisi:=ur.taksit_sayisi;
 new.oran:=least(19.50,round(new.oran+ur.ek_faiz,2));
 new.toplam:=round(new.anapara*(1+new.oran/100));
 new.kalan:=new.toplam;
 RETURN new;
END $function$;

-- Mali döküm (izin verilen kapsam kadar)
create or replace function oyun.oyb_mali_dokum(u uuid, izinli text[]) returns jsonb
language plpgsql stable set search_path to '' as $$
declare r jsonb := '{}'; g jsonb := oyun.gelir_hesap(u, oyun.simdi());
begin
  if 'maas' = any(izinli) then r := r || jsonb_build_object('maas', jsonb_build_object('gunluk_net', g->'gunluk_net',
      'saatlik_maas', g#>'{saatlik,maas}', 'saatlik_makam', g#>'{saatlik,makam}')); end if;
  if 'gunluk' = any(izinli) then r := r || jsonb_build_object('gunluk', jsonb_build_object('gelir', g->'gunluk_net'),
      'son_gelirler', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'tur', h.tur, 'aciklama', h.aciklama) order by h.id desc)
        from (select * from oyun.hesap_hareket where user_id = u and tutar > 0 order by id desc limit 15) h), '[]')); end if;
  if 'kira' = any(izinli) then r := r || jsonb_build_object('kira', jsonb_build_object(
      'haftalik', (select coalesce(sum(haftalik_kira), 0) from oyun.yatirim_mulkleri where user_id = u))); end if;
  if 'mulk' = any(izinli) then r := r || jsonb_build_object('mulk', jsonb_build_object(
      'yatirim_gayrimenkulleri', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'tip', m.tip, 'il', i.ad, 'alis_bedeli', m.alis_bedeli, 'haftalik_kira', m.haftalik_kira) order by m.id)
        from oyun.yatirim_mulkleri m left join oyun.iller i on i.id = m.il_id where m.user_id = u), '[]'),
      'diger_gayrimenkuller', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'tip', m.tur, 'il', i.ad, 'alis_bedeli', m.bedel, 'gunluk_getiri', m.gunluk) order by m.id)
        from oyun.mulkler m left join oyun.iller i on i.id = m.il_id where m.user_id = u), '[]'))); end if;
  if 'sirket' = any(izinli) then r := r || jsonb_build_object('sirket', coalesce((select jsonb_agg(jsonb_build_object('ad', s.ad, 'pay', o.pay,
      'sermaye_pay_degeri', round(s.sermaye * o.pay / 100)) order by s.id)
      from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id where o.user_id = u and o.pay > 0), '[]')); end if;
  return r;
end $$;

-- ---------- müşteri RPC'leri ----------
create or replace function public.oyb_hesap_ac(p_banka bigint) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.sirketler;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif;
  if s.id is null then raise exception 'Banka bulunamadı.'; end if;
  if oyun.oyb_hesap_acik(p_banka, u) then raise exception 'Bu bankada zaten hesabın var.'; end if;
  insert into oyun.oyb_hesap(banka_id, user_id, acilis) values (p_banka, u, t)
  on conflict (banka_id, user_id) do update set acilis = t, kapanis = null;
  perform oyun.bildir(o.user_id, format('%s bankana yeni müşteri: %s hesap açtı.', s.ad, oyun.kad(u)), t)
    from oyun.sirket_ortaklari o where o.sirket_id = p_banka and o.pay >= 50 and o.user_id <> u;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.oyb_hesap_kapat(p_banka bigint) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi();
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if exists(select 1 from oyun.oyb_kredi where banka_id = p_banka and borclu = u and durum in ('basvuru','aktif')) then
    raise exception 'Bu bankadaki kredin kapanmadan hesabını kapatamazsın.'; end if;
  if exists(select 1 from oyun.banka_mevduat where banka_id = p_banka and user_id = u and not kapandi) then
    raise exception 'Önce bu bankadaki mevduatını çek.'; end if;
  update oyun.oyb_hesap set kapanis = t where banka_id = p_banka and user_id = u and kapanis is null;
  if not found then raise exception 'Bu bankada açık hesabın yok.'; end if;
  update oyun.oyb_kredi_teklifi set durum = 'iptal' where banka_id = p_banka and user_id = u and durum = 'teklif';
  return jsonb_build_object('tamam', true);
end $$;

-- Kredi masası: müşteri görünümü + (yöneticiyse) banka görünümü
create or replace function public.oyb_kredi_masasi(p_banka bigint) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.sirketler; yon boolean; r jsonb; sag jsonb; notu integer;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif;
  if s.id is null then raise exception 'Banka bulunamadı.'; end if;
  -- süresi dolan teklifler
  update oyun.oyb_kredi_teklifi set durum = 'suresi' where banka_id = p_banka and durum = 'teklif' and son <= t;
  yon := oyun.oyb_yonetici(p_banka, u);
  sag := oyun.oyb_saglik(p_banka);
  select coalesce((select kredi_notu from oyun.banka_musteri where user_id = u), 1100) into notu;
  r := jsonb_build_object(
    'banka', jsonb_build_object('id', s.id, 'ad', s.ad, 'kasa', s.kasa, 'kredi_verilebilir', greatest(0, (sag->>'kredi_verilebilir')::numeric)),
    'yonetebilir', yon,
    'ortak', exists(select 1 from oyun.sirket_ortaklari where sirket_id = p_banka and user_id = u and pay > 0),
    'hesap', (select jsonb_build_object('acilis', h.acilis) from oyun.oyb_hesap h where h.banka_id = p_banka and h.user_id = u and h.kapanis is null),
    'kredi_notu', notu, 'not_ad', oyun.not_ad(notu),
    'baska_kredi', exists(select 1 from oyun.oyb_kredi where borclu = u and durum in ('basvuru','aktif')),
    'paketler', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'ad', p.ad, 'vade_gun', p.vade_gun, 'taksit_sayisi', p.taksit_sayisi,
        'faiz', p.faiz, 'min_tutar', p.min_tutar, 'max_tutar', p.max_tutar, 'otomatik', p.otomatik, 'min_not', p.min_not, 'aktif', p.aktif,
        'limitim', least(p.max_tutar, ((oyun.oyb_kredi_limit(u, p.vade_gun * 24))->>'azami_kredi')::numeric)) order by p.vade_gun, p.id)
      from oyun.oyb_kredi_paket p where p.banka_id = p_banka and (p.aktif or yon)), '[]'),
    'tekliflerim', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tutar', x.tutar, 'vade_gun', x.vade_gun, 'taksit_sayisi', x.taksit_sayisi,
        'faiz', x.faiz, 'mesaj', x.mesaj, 'son', x.son, 'plan', oyun.oyb_plan(x.tutar, x.vade_gun, x.taksit_sayisi, x.faiz, t)) order by x.id desc)
      from oyun.oyb_kredi_teklifi x where x.banka_id = p_banka and x.user_id = u and x.durum = 'teklif'), '[]'),
    'bilgi_talebi', (select jsonb_build_object('istenen', b.istenen, 'izinli', b.izinli, 'durum', b.durum, 'istek_at', b.istek_at)
      from oyun.oyb_hesap_bilgi b where b.banka_id = p_banka and b.user_id = u),
    'kredilerim', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'anapara', k.anapara, 'toplam', k.toplam, 'kalan', k.kalan, 'oran', k.oran,
        'vade_gun', round(k.saat / 24.0, 1), 'durum', case when k.durum = 'aktif' and exists(select 1 from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade < t) then 'gecikmis' else k.durum end,
        'acilis', k.acilis, 'vade', k.vade, 'erken_kapama', oyun.oyb_erken_kapama_tutari(k, t), 'erken_kapandi', k.erken_kapama, 'erken_indirim', k.erken_indirim,
        'icra', (select i.durum from oyun.oyb_icra i where i.kredi_id = k.id),
        'taksitler', coalesce((select jsonb_agg(jsonb_build_object('sira', x.sira, 'vade', x.vade, 'tutar', x.tutar, 'odenen', x.odenen) order by x.sira)
          from oyun.oyb_kredi_taksit x where x.kredi_id = k.id), '[]')) order by k.id desc)
      from (select * from oyun.oyb_kredi where banka_id = p_banka and borclu = u order by id desc limit 10) k), '[]'));
  if yon then
    r := r || jsonb_build_object(
      'saglik', sag,
      'hesaplar', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(h.user_id), 'acilis', h.acilis,
          'kredi_notu', coalesce(bm.kredi_notu, 1100),
          'borc', (select coalesce(sum(k.kalan), 0) from oyun.oyb_kredi k where k.banka_id = p_banka and k.borclu = h.user_id and k.durum = 'aktif'),
          'aktif_kredi', exists(select 1 from oyun.oyb_kredi k where k.borclu = h.user_id and k.durum in ('basvuru','aktif')),
          'bilgi', (select jsonb_build_object('durum', b.durum, 'istenen', b.istenen, 'izinli', b.izinli) from oyun.oyb_hesap_bilgi b where b.banka_id = p_banka and b.user_id = h.user_id),
          'teklif', (select jsonb_build_object('id', x.id, 'tutar', x.tutar, 'son', x.son) from oyun.oyb_kredi_teklifi x where x.banka_id = p_banka and x.user_id = h.user_id and x.durum = 'teklif' limit 1))
          order by h.acilis desc)
        from oyun.oyb_hesap h left join oyun.banka_musteri bm on bm.user_id = h.user_id
        where h.banka_id = p_banka and h.kapanis is null and h.user_id <> u), '[]'),
      'banka_kredileri', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'borclu', oyun.kad(k.borclu), 'anapara', k.anapara, 'toplam', k.toplam,
          'kalan', k.kalan, 'oran', k.oran, 'vade_gun', round(k.saat / 24.0, 1), 'durum', k.durum, 'acilis', k.acilis, 'vade', k.vade,
          'kaynak', case when k.paket_id is not null then 'paket' when k.teklif_id is not null then 'teklif' else 'basvuru' end,
          'geciken', (select coalesce(sum(x.tutar - x.odenen), 0) from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade < t),
          'dava_acilabilir', k.durum = 'aktif' and exists(select 1 from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade + interval '12 hours' <= t)
            and not exists(select 1 from oyun.oyb_icra i where i.kredi_id = k.id),
          'icra', (select jsonb_build_object('id', i.id, 'durum', i.durum, 'tur', i.tur) from oyun.oyb_icra i where i.kredi_id = k.id),
          'risk', case when k.durum = 'basvuru' then oyun.oyb_kredi_limit(k.borclu, k.saat) end) order by (k.durum = 'basvuru') desc, k.id desc)
        from (select * from oyun.oyb_kredi where banka_id = p_banka and durum in ('basvuru','aktif') order by id desc limit 60) k), '[]'),
      'gonderilen_teklifler', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'kad', oyun.kad(x.user_id), 'tutar', x.tutar, 'vade_gun', x.vade_gun,
          'taksit_sayisi', x.taksit_sayisi, 'faiz', x.faiz, 'durum', x.durum, 'son', x.son) order by x.id desc)
        from (select * from oyun.oyb_kredi_teklifi where banka_id = p_banka order by id desc limit 20) x), '[]'));
  end if;
  return r;
end $$;

-- Ödeme planı ve uygunluk (krediyi çekmeden önce)
create or replace function public.oyb_kredi_plan(p_paket bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); p oyun.oyb_kredi_paket; risk jsonb; sag jsonb; engel text; notu integer;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into p from oyun.oyb_kredi_paket where id = p_paket and aktif;
  if p.id is null then raise exception 'Kredi paketi bulunamadı.'; end if;
  if p_tutar is null or p_tutar <> trunc(p_tutar) then raise exception 'Tutarı tam TL olarak gir.'; end if;
  risk := oyun.oyb_kredi_limit(u, p.vade_gun * 24);
  sag := oyun.oyb_saglik(p.banka_id);
  notu := coalesce((risk->>'kredi_notu')::integer, 1100);
  engel := case
    when not oyun.oyb_hesap_acik(p.banka_id, u) then 'Bu bankada hesabın yok; önce hesap aç.'
    when exists(select 1 from oyun.sirket_ortaklari where sirket_id = p.banka_id and user_id = u and pay > 0) then 'Kendi bankandan kredi çekemezsin.'
    when exists(select 1 from oyun.oyb_kredi where borclu = u and durum in ('basvuru','aktif')) then 'Önce diğer oyuncu bankası kredini kapat ya da başvurunun sonucunu bekle.'
    when p_tutar < p.min_tutar or p_tutar > p.max_tutar then format('Bu pakette tutar %s – %s ₺ arasında olmalı.', oyun.tl(p.min_tutar), oyun.tl(p.max_tutar))
    when notu < p.min_not then format('Bu paket en az %s kredi notu istiyor; notun %s.', p.min_not, notu)
    when p_tutar > (risk->>'azami_kredi')::numeric then format('Gelirine göre bu vadede en çok %s ₺ çekebilirsin (%s).', oyun.tl((risk->>'azami_kredi')::numeric), risk->>'neden')
    when p_tutar > (sag->>'kredi_verilebilir')::numeric then format('Bankanın kasası şu an en çok %s ₺ kredi verebilir.', oyun.tl(greatest(0, (sag->>'kredi_verilebilir')::numeric)))
  end;
  return oyun.oyb_plan(p_tutar, p.vade_gun, p.taksit_sayisi, p.faiz, t) || jsonb_build_object(
    'paket', p.ad, 'otomatik', p.otomatik, 'uygun', engel is null, 'engel', engel,
    'limitim', least(p.max_tutar, (risk->>'azami_kredi')::numeric), 'kredi_notu', notu);
end $$;

-- Krediyi çek: otomatik pakette anında, değilse banka sahibinin onayına başvuru
create or replace function public.oyb_kredi_cek(p_paket bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); p oyun.oyb_kredi_paket; plan jsonb; yeni bigint; s oyun.sirketler;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into p from oyun.oyb_kredi_paket where id = p_paket and aktif for share;
  if p.id is null then raise exception 'Kredi paketi bulunamadı.'; end if;
  perform pg_advisory_xact_lock(hashtext('oyb_kredi:' || u::text));
  plan := public.oyb_kredi_plan(p_paket, p_tutar);
  if not (plan->>'uygun')::boolean then raise exception '%', plan->>'engel'; end if;
  select * into s from oyun.sirketler where id = p.banka_id;
  insert into oyun.oyb_kredi(banka_id, borclu, anapara, saat, oran, toplam, kalan, taksit_sayisi, paket_id, basvuru)
  values (p.banka_id, u, p_tutar, p.vade_gun * 24, p.faiz, (plan->>'toplam')::numeric, (plan->>'toplam')::numeric, p.taksit_sayisi, p.id, t)
  returning id into yeni;
  if p.otomatik then
    perform oyun.oyb_kredi_kullandir(yeni, t);
    perform oyun.bildir(o.user_id, format('%s otomatik kredi verdi: %s, %s ₺ (%s gün).', s.ad, oyun.kad(u), oyun.tl(p_tutar), p.vade_gun), t)
      from oyun.sirket_ortaklari o where o.sirket_id = p.banka_id and o.pay >= 50;
    return jsonb_build_object('tamam', true, 'id', yeni, 'durum', 'aktif', 'plan', plan);
  end if;
  perform oyun.bildir(o.user_id, format('%s bankana kredi başvurusu: %s, %s ₺ (%s gün). Kredi masasından onayla ya da reddet.', s.ad, oyun.kad(u), oyun.tl(p_tutar), p.vade_gun), t)
    from oyun.sirket_ortaklari o where o.sirket_id = p.banka_id and o.pay >= 50;
  return jsonb_build_object('tamam', true, 'id', yeni, 'durum', 'basvuru', 'plan', plan);
end $$;

-- Erken kapama
create or replace function public.oyb_kredi_erken_kapat(p_id bigint) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); k oyun.oyb_kredi; e jsonb; tutar numeric; faiz numeric;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  perform 1 from oyun.sirketler s join oyun.oyb_kredi x on x.banka_id = s.id where x.id = p_id for update of s;
  select * into k from oyun.oyb_kredi where id = p_id and borclu = u for update;
  if k.id is null then raise exception 'Kredi bulunamadı.'; end if;
  if k.durum <> 'aktif' then raise exception 'Kredi aktif değil.'; end if;
  e := oyun.oyb_erken_kapama_tutari(k, t);
  tutar := (e->>'tutar')::numeric;
  perform oyun.para_islem(u, -tutar, 'oyb_kredi', 'Kredi #' || k.id || ' erken kapama', t);
  update oyun.sirketler set kasa = kasa + tutar where id = k.banka_id;
  faiz := greatest(0, tutar - greatest(0, k.anapara - k.anapara_odendi));
  update oyun.oyb_kredi set kalan = 0, anapara_odendi = anapara, durum = 'odendi', kapanis = t,
    erken_kapama = true, erken_indirim = (e->>'indirim')::numeric where id = k.id;
  if faiz > 0 then insert into oyun.sirket_hareket(sirket_id, tutar, aciklama) values (k.banka_id, faiz, 'Kredi #' || k.id || ' erken kapama faiz geliri'); end if;
  perform oyun.bildir(o.user_id, format('%s, kredi #%s borcunu erken kapattı (%s ₺).', oyun.kad(u), k.id, oyun.tl(tutar)), t)
    from oyun.sirket_ortaklari o where o.sirket_id = k.banka_id and o.pay >= 50;
  return jsonb_build_object('tamam', true, 'odenen', tutar, 'indirim', (e->>'indirim')::numeric);
end $$;

-- Teklife yanıt (borçlu)
create or replace function public.oyb_kredi_teklif_yanit(p_id bigint, p_kabul boolean) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); x oyun.oyb_kredi_teklifi; yeni bigint; plan jsonb;
begin
  if u is null or p_kabul is null then raise exception 'Oturum ve karar gerekli.'; end if;
  select * into x from oyun.oyb_kredi_teklifi where id = p_id and user_id = u for update;
  if x.id is null then raise exception 'Teklif bulunamadı.'; end if;
  if x.durum <> 'teklif' then raise exception 'Bu teklif artık geçerli değil.'; end if;
  if x.son <= t then update oyun.oyb_kredi_teklifi set durum = 'suresi' where id = x.id; raise exception 'Teklifin süresi dolmuş.'; end if;
  if not p_kabul then
    update oyun.oyb_kredi_teklifi set durum = 'ret' where id = x.id;
    perform oyun.bildir(o.user_id, format('%s kredi teklifini reddetti.', oyun.kad(u)), t) from oyun.sirket_ortaklari o where o.sirket_id = x.banka_id and o.pay >= 50;
    return jsonb_build_object('tamam', true, 'durum', 'ret');
  end if;
  perform pg_advisory_xact_lock(hashtext('oyb_kredi:' || u::text));
  if exists(select 1 from oyun.oyb_kredi where borclu = u and durum in ('basvuru','aktif')) then
    raise exception 'Önce diğer oyuncu bankası kredini kapat.'; end if;
  if exists(select 1 from oyun.sirket_ortaklari where sirket_id = x.banka_id and user_id = u and pay > 0) then
    raise exception 'Kendi bankandan kredi çekemezsin.'; end if;
  plan := oyun.oyb_plan(x.tutar, x.vade_gun, x.taksit_sayisi, x.faiz, t);
  insert into oyun.oyb_kredi(banka_id, borclu, anapara, saat, oran, toplam, kalan, taksit_sayisi, teklif_id, basvuru)
  values (x.banka_id, u, x.tutar, x.vade_gun * 24, x.faiz, (plan->>'toplam')::numeric, (plan->>'toplam')::numeric, x.taksit_sayisi, x.id, t)
  returning id into yeni;
  perform oyun.oyb_kredi_kullandir(yeni, t);
  update oyun.oyb_kredi_teklifi set durum = 'kabul', kredi_id = yeni where id = x.id;
  perform oyun.bildir(o.user_id, format('%s kredi teklifini kabul etti; %s ₺ kullandırıldı.', oyun.kad(u), oyun.tl(x.tutar)), t)
    from oyun.sirket_ortaklari o where o.sirket_id = x.banka_id and o.pay >= 50;
  return jsonb_build_object('tamam', true, 'durum', 'aktif', 'id', yeni, 'plan', plan);
end $$;

create or replace function public.oyb_hesap_bilgi_yanit(p_banka bigint, p_onay boolean, p_kapsam text[] default null) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); b oyun.oyb_hesap_bilgi; a text[];
begin
  if u is null or p_onay is null then raise exception 'Oturum ve karar gerekli.'; end if;
  select * into b from oyun.oyb_hesap_bilgi where banka_id = p_banka and user_id = u for update;
  if b.banka_id is null then raise exception 'Bu bankanın senden bir bilgi talebi yok.'; end if;
  if p_onay then
    select array_agg(distinct v) into a from unnest(coalesce(p_kapsam, b.istenen)) v where v = any(b.istenen);
    if a is null then raise exception 'İzin vereceğin bilgileri seç.'; end if;
  else a := '{}'; end if;
  update oyun.oyb_hesap_bilgi set izinli = a, durum = case when p_onay then 'izin' else 'ret' end, cevap_at = t where banka_id = p_banka and user_id = u;
  perform oyun.bildir(o.user_id, format('%s mali bilgi talebine %s.', oyun.kad(u), case when p_onay then 'izin verdi' else 'izin vermedi' end), t)
    from oyun.sirket_ortaklari o where o.sirket_id = p_banka and o.pay >= 50;
  return jsonb_build_object('tamam', true);
end $$;

-- ---------- banka sahibi RPC'leri ----------
create or replace function public.oyb_paket_kaydet(p_banka bigint, p_id bigint, p_ad text, p_vade_gun integer, p_taksit integer, p_faiz numeric,
  p_min numeric, p_max numeric, p_otomatik boolean, p_min_not integer, p_aktif boolean) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); yeni bigint;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not oyun.oyb_yonetici(p_banka, u) then raise exception 'Bankanın kredi yönetim yetkin yok (en az %%50 hisse).'; end if;
  if not exists(select 1 from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif) then raise exception 'Banka faal değil.'; end if;
  if p_vade_gun is null or p_vade_gun not between 1 and 30 then raise exception 'Vade 1–30 gün olmalı.'; end if;
  if p_taksit is null or p_taksit not between 1 and 30 or (p_vade_gun * 24) % p_taksit <> 0 then
    raise exception 'Taksit sayısı vadeye eşit bölünmeli (örneğin 30 gün için 1, 2, 3, 4, 5, 6, 10, 15, 30).'; end if;
  if p_faiz is null or p_faiz not between 0 and 20 then raise exception 'Faiz %%0 – %%20 arasında olmalı (vadenin tamamı için).'; end if;
  if p_min is null or p_max is null or p_min < 1000 or p_max > 10000000 or p_max < p_min then raise exception 'Tutar aralığı 1.000 – 10.000.000 ₺ içinde olmalı.'; end if;
  if char_length(btrim(coalesce(p_ad, ''))) not between 3 and 40 then raise exception 'Paket adı 3–40 karakter olmalı.'; end if;
  if p_id is null then
    if (select count(*) from oyun.oyb_kredi_paket where banka_id = p_banka) >= 8 then raise exception 'Bir banka en çok 8 kredi paketi tanımlayabilir.'; end if;
    insert into oyun.oyb_kredi_paket(banka_id, ad, vade_gun, taksit_sayisi, faiz, min_tutar, max_tutar, otomatik, min_not, aktif)
    values (p_banka, btrim(p_ad), p_vade_gun, p_taksit, p_faiz, p_min, p_max, coalesce(p_otomatik, true), coalesce(p_min_not, 900), coalesce(p_aktif, true))
    returning id into yeni;
  else
    update oyun.oyb_kredi_paket set ad = btrim(p_ad), vade_gun = p_vade_gun, taksit_sayisi = p_taksit, faiz = p_faiz, min_tutar = p_min, max_tutar = p_max,
      otomatik = coalesce(p_otomatik, true), min_not = coalesce(p_min_not, 900), aktif = coalesce(p_aktif, true)
    where id = p_id and banka_id = p_banka returning id into yeni;
    if yeni is null then raise exception 'Paket bulunamadı.'; end if;
  end if;
  return jsonb_build_object('tamam', true, 'id', yeni);
end $$;

create or replace function public.oyb_hesap_bilgi_iste(p_banka bigint, p_kad text, p_kapsam text[]) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); h uuid; a text[]; ad text;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not oyun.oyb_yonetici(p_banka, u) then raise exception 'Bankanın yönetim yetkin yok.'; end if;
  select id into h from oyun.profiller where kad = p_kad;
  if h is null or not oyun.oyb_hesap_acik(p_banka, h) then raise exception 'Bu oyuncunun bankanda hesabı yok.'; end if;
  select array_agg(distinct v) into a from unnest(p_kapsam) v where v in ('maas','mulk','kira','sirket','gunluk');
  if a is null or cardinality(a) <> cardinality(p_kapsam) then raise exception 'İstenecek bilgileri seç.'; end if;
  if exists(select 1 from oyun.oyb_hesap_bilgi where banka_id = p_banka and user_id = h and durum = 'talep' and istek_at > t - interval '6 hours') then
    raise exception 'Bu oyuncuya 6 saat içinde zaten bilgi talebi gönderdin.'; end if;
  insert into oyun.oyb_hesap_bilgi(banka_id, user_id, istenen, izinli, durum, istek_at, cevap_at) values (p_banka, h, a, '{}', 'talep', t, null)
  on conflict (banka_id, user_id) do update set istenen = excluded.istenen, izinli = '{}', durum = 'talep', istek_at = t, cevap_at = null;
  select s.ad into ad from oyun.sirketler s where s.id = p_banka;
  perform oyun.bildir(h, format('%s senden mali bilgi istiyor (gelir, maaş dökümü, gayrimenkul vb.). Banka şubesindeki kredi masasından izin verebilir ya da reddedebilirsin.', ad), t);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.oyb_hesap_bilgi_dokum(p_banka bigint, p_kad text) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); h uuid; b oyun.oyb_hesap_bilgi;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not oyun.oyb_yonetici(p_banka, u) then raise exception 'Bankanın yönetim yetkin yok.'; end if;
  select id into h from oyun.profiller where kad = p_kad;
  select * into b from oyun.oyb_hesap_bilgi where banka_id = p_banka and user_id = h and durum = 'izin';
  if b.banka_id is null or not oyun.oyb_hesap_acik(p_banka, h) then raise exception 'Oyuncu mali bilgileri için izin vermedi.'; end if;
  return jsonb_build_object('kad', p_kad, 'izinli', b.izinli, 'risk', oyun.oyb_kredi_limit(h, 168), 'dokum', oyun.oyb_mali_dokum(h, b.izinli));
end $$;

create or replace function public.oyb_kredi_teklif_ver(p_banka bigint, p_kad text, p_tutar numeric, p_vade_gun integer, p_taksit integer, p_faiz numeric, p_mesaj text default null) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); h uuid; sag jsonb; yeni bigint; ad text;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not oyun.oyb_yonetici(p_banka, u) then raise exception 'Bankanın kredi yönetim yetkin yok.'; end if;
  select id into h from oyun.profiller where kad = p_kad;
  if h is null or not oyun.oyb_hesap_acik(p_banka, h) then raise exception 'Kredi teklifini yalnız bankanda hesabı olan oyunculara verebilirsin.'; end if;
  if exists(select 1 from oyun.sirket_ortaklari where sirket_id = p_banka and user_id = h and pay > 0) then raise exception 'Banka ortaklarına kredi verilemez.'; end if;
  if p_tutar is null or p_tutar <> trunc(p_tutar) or p_tutar not between 1000 and 10000000 then raise exception 'Tutar 1.000 – 10.000.000 ₺ arasında tam TL olmalı.'; end if;
  if p_vade_gun is null or p_vade_gun not between 1 and 30 then raise exception 'Vade 1–30 gün olmalı.'; end if;
  if p_taksit is null or p_taksit not between 1 and 30 or (p_vade_gun * 24) % p_taksit <> 0 then raise exception 'Taksit sayısı vadeye eşit bölünmeli.'; end if;
  if p_faiz is null or p_faiz not between 0 and 20 then raise exception 'Faiz %%0 – %%20 arasında olmalı.'; end if;
  if char_length(coalesce(p_mesaj, '')) > 300 then raise exception 'Mesaj en çok 300 karakter.'; end if;
  sag := oyun.oyb_saglik(p_banka);
  if p_tutar > (sag->>'kredi_verilebilir')::numeric then
    raise exception 'Bankanın kasası şu an en çok % ₺ kredi verebilir.', oyun.tl(greatest(0, (sag->>'kredi_verilebilir')::numeric)); end if;
  update oyun.oyb_kredi_teklifi set durum = 'iptal' where banka_id = p_banka and user_id = h and durum = 'teklif';
  insert into oyun.oyb_kredi_teklifi(banka_id, user_id, tutar, vade_gun, taksit_sayisi, faiz, mesaj, son, olusturma)
  values (p_banka, h, p_tutar, p_vade_gun, p_taksit, p_faiz, nullif(btrim(coalesce(p_mesaj, '')), ''), t + interval '48 hours', t) returning id into yeni;
  select s.ad into ad from oyun.sirketler s where s.id = p_banka;
  perform oyun.bildir(h, format('%s sana kredi teklif etti: %s ₺, %s gün, %s taksit, faiz %%%s. Ödeme planını banka şubesindeki kredi masasında görüp 48 saat içinde kabul edebilirsin.',
    ad, oyun.tl(p_tutar), p_vade_gun, p_taksit, p_faiz), t);
  return jsonb_build_object('tamam', true, 'id', yeni);
end $$;

create or replace function public.oyb_kredi_teklif_iptal(p_id bigint) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); x oyun.oyb_kredi_teklifi;
begin
  select * into x from oyun.oyb_kredi_teklifi where id = p_id;
  if x.id is null or not oyun.oyb_yonetici(x.banka_id, u) then raise exception 'Teklif bulunamadı.'; end if;
  update oyun.oyb_kredi_teklifi set durum = 'iptal' where id = p_id and durum = 'teklif';
  return jsonb_build_object('tamam', true);
end $$;

-- Elle onay (banka sahibi) de ortak kullandırma adımını kullanır; yeni vadelerle çalışır
create or replace function public.oyb_kredi_karar(p_id bigint, p_onay boolean) returns jsonb
language plpgsql security definer set search_path to '' as $function$
DECLARE u uuid:=auth.uid();k oyun.oyb_kredi;t timestamptz:=oyun.simdi();d jsonb;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 IF p_onay IS NULL THEN RAISE EXCEPTION 'Karar eksik';END IF;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Basvuru bulunamadi';END IF;
 IF NOT oyun.oyb_yonetici(k.banka_id,u) THEN RAISE EXCEPTION 'Bankanin kredi yonetim yetkin yok';END IF;
 PERFORM 1 FROM oyun.sirketler WHERE id=k.banka_id FOR UPDATE;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=p_id FOR UPDATE;
 IF k.durum<>'basvuru' THEN RAISE EXCEPTION 'Basvuru karara baglandi';END IF;
 IF EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=k.banka_id AND user_id=k.borclu AND pay>0)
 THEN RAISE EXCEPTION 'Banka ortaklarina kredi verilemez';END IF;
 IF NOT p_onay THEN
  UPDATE oyun.oyb_kredi SET durum='reddedildi',kapanis=t WHERE id=k.id;
  PERFORM oyun.bildir(k.borclu,'Kredi başvurun banka tarafından reddedildi.',t);
  RETURN jsonb_build_object('tamam',true,'onay',false);
 END IF;
 d:=oyun.oyb_kredi_limit(k.borclu,k.saat);
 IF k.anapara>(d->>'azami_kredi')::numeric
 THEN RAISE EXCEPTION 'Borclunun guncel geliri veya kredi notu yetersiz. Limit % TL.',d->>'azami_kredi';END IF;
 PERFORM oyun.oyb_kredi_kullandir(k.id,t);
 PERFORM oyun.bildir(k.borclu,'Oyuncu bankasi kredin onaylandi. Geri odeme: '||k.toplam||' TL.',t);
 RETURN jsonb_build_object('tamam',true,'onay',true,'vade',t+make_interval(hours=>k.saat));
END $function$;

revoke all on function public.oyb_hesap_ac(bigint), public.oyb_hesap_kapat(bigint), public.oyb_kredi_masasi(bigint), public.oyb_kredi_plan(bigint,numeric),
  public.oyb_kredi_cek(bigint,numeric), public.oyb_kredi_erken_kapat(bigint), public.oyb_kredi_teklif_yanit(bigint,boolean),
  public.oyb_hesap_bilgi_yanit(bigint,boolean,text[]), public.oyb_paket_kaydet(bigint,bigint,text,integer,integer,numeric,numeric,numeric,boolean,integer,boolean),
  public.oyb_hesap_bilgi_iste(bigint,text,text[]), public.oyb_hesap_bilgi_dokum(bigint,text),
  public.oyb_kredi_teklif_ver(bigint,text,numeric,integer,integer,numeric,text), public.oyb_kredi_teklif_iptal(bigint) from public, anon;
grant execute on function public.oyb_hesap_ac(bigint), public.oyb_hesap_kapat(bigint), public.oyb_kredi_masasi(bigint), public.oyb_kredi_plan(bigint,numeric),
  public.oyb_kredi_cek(bigint,numeric), public.oyb_kredi_erken_kapat(bigint), public.oyb_kredi_teklif_yanit(bigint,boolean),
  public.oyb_hesap_bilgi_yanit(bigint,boolean,text[]), public.oyb_paket_kaydet(bigint,bigint,text,integer,integer,numeric,numeric,numeric,boolean,integer,boolean),
  public.oyb_hesap_bilgi_iste(bigint,text,text[]), public.oyb_hesap_bilgi_dokum(bigint,text),
  public.oyb_kredi_teklif_ver(bigint,text,numeric,integer,integer,numeric,text), public.oyb_kredi_teklif_iptal(bigint) to authenticated;
revoke all on function oyun.oyb_kredi_kullandir(bigint,timestamptz), oyun.oyb_mali_dokum(uuid,text[]) from public, anon, authenticated;

commit;
