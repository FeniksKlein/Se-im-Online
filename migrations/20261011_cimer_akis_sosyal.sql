-- Seçim Simülasyonu Online — CİMER (dilekçenin yerine) + Akış sosyal platform (beğen/beğenme anonim, yanıtlar).
-- Kaynak: gelistirici/sql/81_cimer.sql, 82_akis_sosyal.sql. Yalnız ekler; iki kez çalıştırılabilir.
begin;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 81) CİMER (dilekçenin yerine)
--  Vatandaş CİMER'e girer; Cumhurbaşkanlığı'nı, bir bakanlığı ya da bir il belediyesini seçer,
--  başvuru türünü (şikâyet / talep / öneri / bilgi edinme) seçip yazar. Başvuru KİŞİYE değil MAKAMA
--  gider: o makamda bugün kim oturuyorsa o görür ve yanıtlar (makam el değiştirse de bekleyen
--  başvurular yeni sahibine geçer). Bakanlık boşsa Cumhurbaşkanı vekâleten görür (11 numaralı kural).
--  • Başvurular gizlidir: yalnız gönderen ve muhatap makam görür.
--  • Herkesin gördüğü "Kurum karnesi": son 30 günde başvuru, yanıt oranı, ortalama yanıt süresi,
--    memnuniyet. Yanıt süresi 72 saat; geçen başvurular karnede "süresinde yanıtlanmadı" sayılır.
--  • Sınır: 24 saatte 3 başvuru, aynı kuruma 6 saatte 1; küfür süzgeci; susturulan yazamaz.
--  • Eski dilekçe gönderimi kapatılır (veri silinmez); imza kampanyası hedefe ulaşınca oluşan
--    dilekçe ayrıca CİMER'e "toplu başvuru" olarak düşer. Hayat görevlerindeki dilekçe görevleri
--    CİMER başvurularını sayar.
--  Yalnız ekler; oyuncu verisi silinmez.
-- =====================================================================

create table if not exists oyun.cimer_basvuru(
  id          bigserial primary key,
  gonderen    uuid not null references oyun.profiller(id),
  hedef       text not null check (hedef in ('cb','bakanlik','belediye','mv')),
  bakanlik    text,
  il_id       smallint references oyun.iller(id),
  mv_user     uuid,                         -- yalnız imza kampanyasından gelen toplu başvurularda
  kategori    text not null check (kategori in ('sikayet','talep','oneri','bilgi')),
  konu        text not null check (char_length(konu) between 5 and 100),
  metin       text not null check (char_length(metin) between 20 and 2000),
  imza_sayisi int,                          -- toplu başvuru (imza kampanyası)
  zaman       timestamptz not null default now(),
  durum       text not null default 'bekliyor' check (durum in ('bekliyor','inceleniyor','sonuclandi')),
  sonuc       text check (sonuc in ('olumlu','olumsuz','bilgi')),
  cevap       text,
  cevaplayan  uuid,
  cevap_at    timestamptz,
  okundu_at   timestamptz,
  memnun      boolean,
  constraint cimer_hedef_ok check (
    (hedef = 'cb' and bakanlik is null and il_id is null) or
    (hedef = 'bakanlik' and bakanlik is not null and il_id is null) or
    (hedef = 'belediye' and il_id is not null and bakanlik is null) or
    (hedef = 'mv' and mv_user is not null))
);
create index if not exists cimer_gonderen on oyun.cimer_basvuru(gonderen, id desc);
create index if not exists cimer_kurum on oyun.cimer_basvuru(hedef, bakanlik, il_id, id desc);
alter table oyun.cimer_basvuru enable row level security;
revoke all on oyun.cimer_basvuru from public, anon, authenticated;
revoke all on sequence oyun.cimer_basvuru_id_seq from public, anon, authenticated;

-- Kurumun adı
create or replace function oyun.cimer_kurum_ad(b oyun.cimer_basvuru) returns text language sql stable set search_path = '' as $$
  select case b.hedef
    when 'cb' then 'Cumhurbaşkanlığı'
    when 'bakanlik' then coalesce((select ad from oyun.bakanliklar where kod = b.bakanlik), b.bakanlik)
    when 'belediye' then coalesce((select ad from oyun.iller where id = b.il_id), '') || ' Belediyesi'
    else coalesce(oyun.kad(b.mv_user), '') || ' (Milletvekili)' end
$$;

-- Bir başvuruyu bugün kim yanıtlayabilir?
create or replace function oyun.cimer_muhatap(b oyun.cimer_basvuru) returns uuid language sql stable set search_path = '' as $$
  select case b.hedef
    when 'cb' then (select user_id from oyun.makamlar where tur = 'cb' and bit is null order by bas desc limit 1)
    when 'bakanlik' then coalesce(
        (select user_id from oyun.makamlar where tur = 'bakan' and bakanlik = b.bakanlik and bit is null order by bas desc limit 1),
        (select user_id from oyun.makamlar where tur = 'cb' and bit is null order by bas desc limit 1))   -- boş bakanlığa CB vekâlet eder
    when 'belediye' then (select user_id from oyun.makamlar where tur = 'bel' and il_id = b.il_id and bit is null order by bas desc limit 1)
    else (select b.mv_user where exists (select 1 from oyun.makamlar where tur = 'mv' and user_id = b.mv_user and bit is null)) end
$$;

create or replace function oyun.cimer_json(b oyun.cimer_basvuru, ben uuid) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id', b.id, 'kurum', oyun.cimer_kurum_ad(b), 'hedef', b.hedef, 'bakanlik', b.bakanlik, 'il_id', b.il_id,
    'kategori', b.kategori, 'konu', b.konu, 'metin', b.metin, 'imza_sayisi', b.imza_sayisi, 'zaman', b.zaman,
    'durum', b.durum, 'sonuc', b.sonuc, 'cevap', b.cevap, 'cevaplayan', oyun.kad(b.cevaplayan), 'cevaplayan_unvan', oyun.unvan(b.cevaplayan),
    'cevap_at', b.cevap_at, 'memnun', b.memnun,
    'gonderen', oyun.kad(b.gonderen), 'gonderen_il', (select i.ad from oyun.profiller p join oyun.iller i on i.id = p.il_id where p.id = b.gonderen),
    'benim', b.gonderen = ben, 'suresi_gecti', b.durum <> 'sonuclandi' and b.zaman < oyun.simdi() - interval '72 hours',
    'yanitlayabilirim', b.durum <> 'sonuclandi' and oyun.cimer_muhatap(b) = ben)
$$;

-- Başvuru yap
create or replace function public.cimer_basvur(p_hedef text, p_bakanlik text, p_il int, p_kategori text, p_konu text, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.cimer_basvuru; k text; m text; muh uuid;
begin
  if p.susturma_bitis is not null and p.susturma_bitis > t then raise exception 'Hesabın şu anda yazamaz (kural ihlali).'; end if;
  if p_hedef not in ('cb', 'bakanlik', 'belediye') then raise exception 'Kurum seç: Cumhurbaşkanlığı, bir bakanlık ya da bir belediye.'; end if;
  if p_hedef = 'bakanlik' and not exists (select 1 from oyun.bakanliklar where kod = p_bakanlik) then raise exception 'Bakanlık seç.'; end if;
  if p_hedef = 'belediye' and not exists (select 1 from oyun.iller where id = p_il) then raise exception 'Belediye için il seç.'; end if;
  if p_kategori not in ('sikayet', 'talep', 'oneri', 'bilgi') then raise exception 'Başvuru türü seç.'; end if;
  k := btrim(coalesce(p_konu, '')); m := btrim(coalesce(p_metin, ''));
  if char_length(k) not between 5 and 100 then raise exception 'Konu 5–100 karakter olmalı.'; end if;
  if char_length(m) not between 20 and 2000 then raise exception 'Başvuru metni 20–2000 karakter olmalı.'; end if;
  if oyun.kufurlu(k || ' ' || m) then raise exception 'Başvurunda uygunsuz bir ifade var. Hakaret ve küfür yasaktır.'; end if;
  if (select count(*) from oyun.cimer_basvuru where gonderen = p.id and imza_sayisi is null and zaman > t - interval '24 hours') >= 3 then
    raise exception 'CİMER''e 24 saatte en fazla 3 başvuru yapabilirsin.';
  end if;
  if exists (select 1 from oyun.cimer_basvuru where gonderen = p.id and hedef = p_hedef and imza_sayisi is null
               and bakanlik is not distinct from case when p_hedef = 'bakanlik' then p_bakanlik end
               and il_id is not distinct from case when p_hedef = 'belediye' then p_il::smallint end
               and zaman > t - interval '6 hours') then
    raise exception 'Aynı kuruma 6 saatte bir başvurabilirsin.';
  end if;
  insert into oyun.cimer_basvuru(gonderen, hedef, bakanlik, il_id, kategori, konu, metin, zaman)
  values (p.id, p_hedef, case when p_hedef = 'bakanlik' then p_bakanlik end, case when p_hedef = 'belediye' then p_il end, p_kategori, k, m, t)
  returning * into b;
  muh := oyun.cimer_muhatap(b);
  if muh is not null and muh <> p.id then
    perform oyun.bildir(muh, format('CİMER: %s kurumuna yeni %s başvurusu var — %s', oyun.cimer_kurum_ad(b),
      case p_kategori when 'sikayet' then 'şikâyet' when 'talep' then 'talep' when 'oneri' then 'öneri' else 'bilgi edinme' end, k), t);
  end if;
  return jsonb_build_object('tamam', true, 'id', b.id, 'muhatap_var', muh is not null);
end $$;

-- Benim başvurularım + bana (makamıma) gelenler + kurum listesi
create or replace function public.cimer() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'basvurularim', coalesce((select jsonb_agg(oyun.cimer_json(b, p.id) order by b.id desc)
        from (select * from oyun.cimer_basvuru where gonderen = p.id order by id desc limit 50) b), '[]'::jsonb),
    'gelen', coalesce((select jsonb_agg(oyun.cimer_json(b, p.id) order by (b.durum = 'sonuclandi'), b.id desc)
        from (select * from oyun.cimer_basvuru b0 where oyun.cimer_muhatap(b0) = p.id
                and (b0.durum <> 'sonuclandi' or b0.cevap_at > t - interval '7 days') order by id desc limit 100) b), '[]'::jsonb),
    'kurumlar', jsonb_build_object(
       'cb', (select oyun.kad(user_id) from oyun.makamlar where tur = 'cb' and bit is null limit 1),
       'bakanliklar', coalesce((select jsonb_agg(jsonb_build_object('kod', bk.kod, 'ad', bk.ad,
            'bakan', (select oyun.kad(m.user_id) from oyun.makamlar m where m.tur = 'bakan' and m.bakanlik = bk.kod and m.bit is null limit 1)) order by bk.sira)
          from oyun.bakanliklar bk), '[]'::jsonb),
       'belediye_baskani', (select oyun.kad(m.user_id) from oyun.makamlar m where m.tur = 'bel' and m.il_id = p.il_id and m.bit is null limit 1),
       'il_id', p.il_id),
    'bugun_kalan', greatest(0, 3 - (select count(*) from oyun.cimer_basvuru where gonderen = p.id and imza_sayisi is null and zaman > t - interval '24 hours'))
  );
end $$;

-- Makam sahibi yanıtlar
create or replace function public.cimer_yanitla(p_id bigint, p_durum text, p_sonuc text, p_cevap text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.cimer_basvuru; c text := btrim(coalesce(p_cevap, ''));
begin
  select * into b from oyun.cimer_basvuru where id = p_id for update;
  if b.id is null then raise exception 'Başvuru bulunamadı.'; end if;
  if oyun.cimer_muhatap(b) is distinct from p.id then raise exception 'Bu başvuruyu yanıtlama yetkin yok.'; end if;
  if b.durum = 'sonuclandi' then raise exception 'Bu başvuru zaten sonuçlandırıldı.'; end if;
  if p_durum = 'inceleniyor' then
    update oyun.cimer_basvuru set durum = 'inceleniyor', okundu_at = coalesce(okundu_at, t) where id = b.id;
    perform oyun.bildir(b.gonderen, format('CİMER: “%s” başvurun %s tarafından incelemeye alındı.', b.konu, oyun.cimer_kurum_ad(b)), t);
    return jsonb_build_object('tamam', true);
  end if;
  if p_durum <> 'sonuclandi' or p_sonuc not in ('olumlu', 'olumsuz', 'bilgi') then raise exception 'Sonuç seç: olumlu, olumsuz ya da bilgi verildi.'; end if;
  if char_length(c) not between 10 and 2000 then raise exception 'Resmî yanıt 10–2000 karakter olmalı.'; end if;
  if oyun.kufurlu(c) then raise exception 'Yanıtında uygunsuz bir ifade var.'; end if;
  update oyun.cimer_basvuru set durum = 'sonuclandi', sonuc = p_sonuc, cevap = c, cevaplayan = p.id, cevap_at = t, okundu_at = coalesce(okundu_at, t) where id = b.id;
  perform oyun.bildir(b.gonderen, format('CİMER: “%s” başvurun %s tarafından yanıtlandı (%s).', b.konu, oyun.cimer_kurum_ad(b),
    case p_sonuc when 'olumlu' then 'olumlu' when 'olumsuz' then 'olumsuz' else 'bilgi verildi' end), t);
  return jsonb_build_object('tamam', true);
end $$;

-- Gönderen yanıttan memnun mu?
create or replace function public.cimer_degerlendir(p_id bigint, p_memnun boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  update oyun.cimer_basvuru set memnun = p_memnun where id = p_id and gonderen = p.id and durum = 'sonuclandi' and memnun is null;
  if not found then raise exception 'Bu başvuruyu değerlendiremezsin.'; end if;
  return jsonb_build_object('tamam', true);
end $$;

-- Kurum karnesi (herkese açık, kimlik yok): son 30 gün
create or replace function public.cimer_karne() returns jsonb
language sql stable security definer set search_path = '' as $$
  with b as (select * from oyun.cimer_basvuru where zaman > oyun.simdi() - interval '30 days' and hedef <> 'mv'),
  g as (select oyun.cimer_kurum_ad(b) kurum, b.hedef,
          count(*) n, count(*) filter (where durum = 'sonuclandi') yanit,
          count(*) filter (where durum <> 'sonuclandi' and zaman < oyun.simdi() - interval '72 hours') geciken,
          round(avg(extract(epoch from cevap_at - zaman) / 3600) filter (where durum = 'sonuclandi'), 1) ort_saat,
          count(*) filter (where memnun) memnun, count(*) filter (where memnun is not null) degerlendirme
        from b group by 1, 2)
  select coalesce(jsonb_agg(jsonb_build_object('kurum', kurum, 'hedef', hedef, 'basvuru', n, 'yanit', yanit, 'geciken', geciken,
           'ort_saat', ort_saat, 'memnuniyet', case when degerlendirme > 0 then round(memnun * 100.0 / degerlendirme) end)
         order by n desc, kurum), '[]'::jsonb) from g
$$;

-- Eski dilekçe gönderimi kapandı
create or replace function public.sos_dilekce_gonder(p_makam text, p_kad text, p_il int, p_baslik text, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  raise exception 'Dilekçe sistemi kaldırıldı. Şikâyet ve taleplerini CİMER üzerinden ilgili bakanlığa ya da belediyeye ilet.';
end $$;

-- İmza kampanyası hedefe ulaşınca oluşan dilekçe CİMER'e toplu başvuru olarak düşer
create or replace function oyun.tg_dilekce_cimer() returns trigger language plpgsql set search_path = '' as $$
begin
  if new.imza_kamp_id is null then return null; end if;
  insert into oyun.cimer_basvuru(gonderen, hedef, il_id, mv_user, kategori, konu, metin, imza_sayisi, zaman)
  values (new.gonderen,
          case new.makam when 'cb' then 'cb' when 'bel' then 'belediye' else 'mv' end,
          case when new.makam = 'bel' then new.il_id end,
          case when new.makam = 'mv' then new.muhatap end,
          'talep', left(new.baslik, 100), left(rpad(new.metin, 20, '.'), 2000),
          (select count(*) from oyun.sos_imza where kampanya_id = new.imza_kamp_id), new.olusturma);
  return null;
end $$;
do $$ begin
  if to_regclass('oyun.sos_dilekce') is not null then
    drop trigger if exists dilekce_cimer on oyun.sos_dilekce;
    create trigger dilekce_cimer after insert on oyun.sos_dilekce for each row execute function oyun.tg_dilekce_cimer();
  end if;
end $$;

-- Hayat görevleri: dilekçe görevleri artık CİMER başvurularını sayar (sarmalayıcı; canlıdaki sürüm korunur)
do $$ begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'oyun' and p.proname = 'gorev_istatistik'
               and pg_get_functiondef(p.oid) not like '%cimer_gorev_sarmal%') then
    drop function if exists oyun._gorev_istatistik_ham(uuid, timestamptz);
    alter function oyun.gorev_istatistik(uuid, timestamptz) rename to _gorev_istatistik_ham;
  end if;
end $$;
do $do$ begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'oyun' and p.proname = '_gorev_istatistik_ham') then
    execute $w$
create or replace function oyun.gorev_istatistik(p_user uuid, p_bas timestamptz) returns jsonb
language sql stable set search_path = '' as $f$
  -- cimer_gorev_sarmal
  select h || jsonb_build_object(
    'dilekce_gonder', coalesce((h->>'dilekce_gonder')::int, 0)
        + (select count(*) from oyun.cimer_basvuru c where c.gonderen = p_user and c.zaman >= p_bas and c.imza_sayisi is null),
    'dilekce_yanit', coalesce((h->>'dilekce_yanit')::int, 0)
        + (select count(*) from oyun.cimer_basvuru c where c.cevaplayan = p_user and c.cevap_at >= p_bas))
  from (select oyun._gorev_istatistik_ham(p_user, p_bas) h) x
$f$;
    $w$;
  end if;
end $do$;
do $$ begin
  if to_regclass('oyun.gorev_katalog') is not null then
update oyun.gorev_katalog set
  baslik = replace(replace(baslik, 'Resmî dilekçe gönder', 'CİMER''e başvur'), 'Halkın talebini yanıtla', 'CİMER başvurularını yanıtla'),
  aciklama = case when metrik = 'dilekce_gonder' then 'CİMER üzerinden bakanlıklara, belediyelere ya da Cumhurbaşkanlığına başvuru yap. Hedef: ' || hedef || '.'
                  else 'Makam sahibi olarak CİMER başvurularına resmî yanıt ver. Hedef: ' || hedef || '.' end
where metrik in ('dilekce_gonder', 'dilekce_yanit');
  end if;
end $$;

revoke all on function public.cimer_basvur(text, text, int, text, text, text), public.cimer(), public.cimer_yanitla(bigint, text, text, text),
  public.cimer_degerlendir(bigint, boolean), public.cimer_karne() from public, anon;
grant execute on function public.cimer_basvur(text, text, int, text, text, text), public.cimer(), public.cimer_yanitla(bigint, text, text, text),
  public.cimer_degerlendir(bigint, boolean), public.cimer_karne() to authenticated;
revoke all on function oyun.cimer_kurum_ad(oyun.cimer_basvuru), oyun.cimer_muhatap(oyun.cimer_basvuru), oyun.cimer_json(oyun.cimer_basvuru, uuid),
  oyun.tg_dilekce_cimer() from public, anon, authenticated;

-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 82) AKIŞ: SOSYAL PLATFORM (beğen / beğenme, yanıtlar)
--  • Her paylaşımın altında Beğen ve Beğenme var. Yalnız SAYILAR görünür; kimin beğendiği ya da
--    beğenmediği hiçbir işlevde döndürülmez (oyuncu yalnız kendi tepkisini görür).
--  • Bir kişinin tek tepkisi olur: beğenirse beğenmemesi kalkar, tersi de.
--  • Paylaşımların altına yanıt yazılabilir (yanıtlar akışta ayrıca görünmez, paylaşımın altında açılır).
--  78 numaralı modülün üstüne eklenir; mevcut paylaşımlar ve beğeniler korunur.
-- =====================================================================

alter table oyun.akis add column if not exists yanit_id bigint references oyun.akis(id) on delete cascade;
create index if not exists akis_yanitlar on oyun.akis(yanit_id, id) where yanit_id is not null;

create table if not exists oyun.akis_begenmeme(
  akis_id bigint not null references oyun.akis(id) on delete cascade,
  user_id uuid not null,
  zaman   timestamptz not null default now(),
  primary key (akis_id, user_id)
);
alter table oyun.akis_begenmeme enable row level security;
revoke all on oyun.akis_begenmeme from public, anon, authenticated;

create or replace function oyun.akis_json(a oyun.akis, ben uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', a.id, 'kad', pr.kad, 'unvan', oyun.unvan(a.user_id), 'parti', oyun.parti_json(a.parti_id),
           'il', (select ad from oyun.iller where id = a.il_id), 'metin', a.metin, 'zaman', a.zaman, 'yanit_id', a.yanit_id,
           'begeni', (select count(*) from oyun.akis_begeni b where b.akis_id = a.id),
           'begenmeme', (select count(*) from oyun.akis_begenmeme b where b.akis_id = a.id),
           'yanit', (select count(*) from oyun.akis y where y.yanit_id = a.id and not y.gizli),
           'begendim', exists (select 1 from oyun.akis_begeni b where b.akis_id = a.id and b.user_id = ben),
           'begenmedim', exists (select 1 from oyun.akis_begenmeme b where b.akis_id = a.id and b.user_id = ben),
           'benim', a.user_id = ben)
  from oyun.profiller pr where pr.id = a.user_id
$$;

-- Tepki: p_tepki = 'begen' | 'begenme' | null (kaldır). Aynı tepkiye tekrar basmak kaldırır.
create or replace function public.akis_tepki(p_id bigint, p_tepki text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); onceki text;
begin
  if p_tepki is not null and p_tepki not in ('begen', 'begenme') then raise exception 'Geçersiz tepki.'; end if;
  if not exists (select 1 from oyun.akis where id = p_id and not gizli) then raise exception 'Paylaşım bulunamadı.'; end if;
  onceki := case when exists (select 1 from oyun.akis_begeni where akis_id = p_id and user_id = p.id) then 'begen'
                 when exists (select 1 from oyun.akis_begenmeme where akis_id = p_id and user_id = p.id) then 'begenme' end;
  if p_tepki is not null and p_tepki is distinct from onceki
     and (select count(*) from oyun.akis_begeni where user_id = p.id and zaman > t - interval '1 minute')
       + (select count(*) from oyun.akis_begenmeme where user_id = p.id and zaman > t - interval '1 minute') >= 30 then
    raise exception 'Çok hızlı tepki veriyorsun, biraz bekle.';
  end if;
  delete from oyun.akis_begeni where akis_id = p_id and user_id = p.id;
  delete from oyun.akis_begenmeme where akis_id = p_id and user_id = p.id;
  if p_tepki = 'begen' and onceki is distinct from 'begen' then
    insert into oyun.akis_begeni(akis_id, user_id, zaman) values (p_id, p.id, t);
  elsif p_tepki = 'begenme' and onceki is distinct from 'begenme' then
    insert into oyun.akis_begenmeme(akis_id, user_id, zaman) values (p_id, p.id, t);
  end if;
  return jsonb_build_object(
    'begeni', (select count(*) from oyun.akis_begeni where akis_id = p_id),
    'begenmeme', (select count(*) from oyun.akis_begenmeme where akis_id = p_id),
    'begendim', exists (select 1 from oyun.akis_begeni where akis_id = p_id and user_id = p.id),
    'begenmedim', exists (select 1 from oyun.akis_begenmeme where akis_id = p_id and user_id = p.id));
end $$;

-- Eski "beğen" düğmesi de tek tepki kuralına uysun
create or replace function public.akis_begen(p_id bigint) returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select public.akis_tepki(p_id, 'begen')
$$;

-- Yanıt yaz (aynı hız sınırları ve süzgeçler; yanıt sayısı akis_yaz'ın günlük sınırına dahildir)
create or replace function public.akis_yanit_yaz(p_id bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); ana oyun.akis; r jsonb; yeni bigint;
begin
  select * into ana from oyun.akis where id = p_id and not gizli;
  if ana.id is null then raise exception 'Paylaşım bulunamadı.'; end if;
  if ana.yanit_id is not null then select * into ana from oyun.akis where id = ana.yanit_id; end if;   -- yanıta yanıt: ana paylaşıma bağla
  if exists (select 1 from oyun.engellemeler g where (g.engelleyen = ana.user_id and g.engellenen = p.id) or (g.engelleyen = p.id and g.engellenen = ana.user_id)) then
    raise exception 'Bu kullanıcıyla engelleme olduğu için yanıt yazamazsın.';
  end if;
  r := public.akis_yaz(p_metin);
  yeni := (r->>'id')::bigint;
  update oyun.akis set yanit_id = ana.id where id = yeni;
  if ana.user_id <> p.id then
    perform oyun.bildir(ana.user_id, format('%s paylaşımına yanıt verdi: %s', p.kad, left(btrim(p_metin), 80)));
  end if;
  return jsonb_build_object('tamam', true, 'id', yeni);
end $$;

-- Bir paylaşım ve yanıtları
create or replace function public.akis_konu(p_id bigint) returns jsonb
language plpgsql stable security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); a oyun.akis;
begin
  select * into a from oyun.akis where id = p_id and not gizli;
  if a.id is null then raise exception 'Paylaşım bulunamadı.'; end if;
  if a.yanit_id is not null then select * into a from oyun.akis where id = a.yanit_id and not gizli; end if;
  if a.id is null then raise exception 'Paylaşım bulunamadı.'; end if;
  return jsonb_build_object('ana', oyun.akis_json(a, p.id),
    'yanitlar', coalesce((select jsonb_agg(oyun.akis_json(y, p.id) order by y.id) from oyun.akis y
        where y.yanit_id = a.id and not y.gizli
          and not exists (select 1 from oyun.engellemeler g where (g.engelleyen = p.id and g.engellenen = y.user_id) or (g.engelleyen = y.user_id and g.engellenen = p.id))), '[]'::jsonb));
end $$;

-- Akış listesi: yanıtlar ana akışta görünmez
create or replace function public.akis_liste(p_kapsam text default 'herkes', p_etiket text default null, p_onceki bigint default null, p_limit int default 20)
returns jsonb language plpgsql stable security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); et text := nullif(lower(regexp_replace(coalesce(p_etiket, ''), '^#', '')), '');
begin
  if p_kapsam not in ('herkes', 'il', 'parti') then raise exception 'Geçersiz kapsam.'; end if;
  return coalesce((select jsonb_agg(oyun.akis_json(a, p.id) order by a.id desc) from (
    select * from oyun.akis a
     where not a.gizli and a.yanit_id is null and (p_onceki is null or a.id < p_onceki)
       and (p_kapsam <> 'il' or a.il_id = p.il_id) and (p_kapsam <> 'parti' or (p.parti_id is not null and a.parti_id = p.parti_id))
       and (et is null or exists (select 1 from oyun.akis_etiket e where e.akis_id = a.id and e.etiket = et))
       and not exists (select 1 from oyun.engellemeler g where (g.engelleyen = p.id and g.engellenen = a.user_id) or (g.engelleyen = a.user_id and g.engellenen = p.id))
     order by a.id desc limit least(greatest(coalesce(p_limit, 20), 1), 40)) a), '[]'::jsonb);
end $$;

revoke all on function public.akis_tepki(bigint, text), public.akis_yanit_yaz(bigint, text), public.akis_konu(bigint) from public, anon;
grant execute on function public.akis_tepki(bigint, text), public.akis_yanit_yaz(bigint, text), public.akis_konu(bigint) to authenticated;
revoke all on function public.akis_begen(bigint) from public, anon;
grant execute on function public.akis_begen(bigint) to authenticated;
commit;
