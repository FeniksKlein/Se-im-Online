-- 18.11.2026 · KAYYUM ve KAPATMA DAVALARI (oyuncuların kurduğu kurumlar)
-- Kapsam: şirket, dernek, sendika, gazete, TV kanalı, karikatür dergisi, hukuk bürosu.
--   • Siyasi partiler bu usulle kapatılamaz ve partilere kayyum atanamaz (Anayasa m.69): parti kapatma yalnız mevcut
--     Anayasa Mahkemesi kapatma davasıyla olur. Bankalar da kapsam dışıdır (mevduat sahiplerini korumak için; BDDK/TMSF usulü).
-- Usul (çok katı; şüpheden kurum yararlanır):
--   1) Başvuru: Adalet Bakanı (Başsavcılık rolü, tüm kurumlar); İçişleri Bakanı (dernek, sendika); Ticaret Bakanı (şirket, hukuk bürosu).
--      Kanunda sayılan dayanaklardan biri (dolandırıcılık TCK 158, hırsızlık/zimmet TCK 141-155-247, kara para TCK 282,
--      vergi kaçakçılığı VUK 359, halkı kin ve düşmanlığa tahrik TCK 216, anayasal düzene karşı suç TCK 309-316/CMK 133,
--      amaç dışı faaliyet TMK 89, dezenformasyon TCK 217/A) ve SİSTEM KAYDINA DAYALI kanıt zorunlu (mesaj, yayın, eylem,
--      MASAK kaydı, para hareketi, kesinleşmiş dava). Kanıt kurumun sorumlularına (sahip, başkan, kurucu, yönetici, ortak) ait olmalı.
--      Kayyum: en az 2 geçerli kanıt + (kesinleşmiş mahkûmiyet ya da MASAK ihtar/el koyma bulgusu).
--      Kapatma: en az 3 geçerli kanıt + kesinleşmiş mahkûmiyet + (2. mahkûmiyet ya da son 180 günde aynı kuruma kesinleşmiş kayyum).
--      En az bir kanıt dayanağın türüne uymalı (ör. tahrik için mesaj/yayın/eylem; kara para için MASAK/para hareketi).
--   2) Savunma: kurum sorumluları 48 saat içinde savunma verir.
--   3) Yüksek Mahkeme: tarafsız üyeler gerekçeli oy verir (72 saat). Kayyum en az 3 oy ve salt çoğunluk, kapatma en az 3 oy ve 2/3.
--      Eşik dolmazsa başvuru reddedilir. Kapatma istenen davada mahkeme daha hafif olan kayyuma hükmedebilir.
--   4) İstinaf: kurum 48 saat içinde itiraz eder; aktif ve tarafsız 3 oyuncudan istinaf heyeti kurulur (36 saat).
--      Karar ancak en az 2 "onay" ile kesinleşir; aksi hâlde bozulur.
--   5) Uygulama: Kayyum (7/15/30 gün) — kurum kasası emanete alınır; dernek, sendika, gazete, TV, dergide yönetim kayyuma geçer
--      (kayyum kasadan para harcayamaz, kurumu satamaz, kapatamaz); şirket ve hukuk bürosunda faaliyet dondurulur.
--      Süre bitince yönetim ve emanet sahibine döner. Kapatma — kurum kalıcı kapanır, kasası Hazine'ye müsadere edilir (TCK 60).
-- Oyuncu verisi değişmez; yeni tablo/fonksiyon/tetikleyici eklenir.

create table if not exists oyun.kayyum_dava(
  id            bigserial primary key,
  tur           text not null check (tur in ('kayyum','kapatma')),
  kurum_tur     text not null check (kurum_tur in ('sirket','dernek','sendika','gazete','tv','dergi','hukuk_burosu')),
  kurum_id      bigint not null,
  kurum_ad      text not null,
  sorumlular    uuid[] not null default '{}',
  basvuran      uuid not null,
  basvuran_makam text not null,
  dayanak       text not null,
  iddia         text not null,
  kanitlar      jsonb not null default '[]'::jsonb,
  kanit_ozet    jsonb not null default '{}'::jsonb,
  kayyum_kisi   uuid,
  kayyum_gun    integer,
  durum         text not null default 'savunma' check (durum in ('savunma','yargilama','itiraz_suresi','istinaf','kayyum_aktif','uygulandi','sona_erdi','ret','bozuldu','geri_cekildi')),
  zaman         timestamptz not null,
  savunma_son   timestamptz,
  savunma       text,
  savunma_veren uuid,
  savunma_at    timestamptz,
  oylama_son    timestamptz,
  karar         text,
  karar_at      timestamptz,
  itiraz_son    timestamptz,
  itiraz        text,
  itiraz_veren  uuid,
  itiraz_at     timestamptz,
  istinaf_son   timestamptz,
  kesin_at      timestamptz,
  kayyum_bas    timestamptz,
  kayyum_bit    timestamptz,
  emanet        numeric,
  eski_yonetim  uuid,
  sonuc_notu    text
);
create index if not exists kayyum_dava_kurum on oyun.kayyum_dava(kurum_tur, kurum_id, zaman desc);
create index if not exists kayyum_dava_durum on oyun.kayyum_dava(durum, zaman desc);
create index if not exists kayyum_dava_basvuran on oyun.kayyum_dava(basvuran, zaman desc);

create table if not exists oyun.kayyum_oy(
  dava_id bigint not null, uye uuid not null, karar text not null check (karar in ('kabul','kayyum','ret')),
  gerekce text not null, zaman timestamptz not null, primary key (dava_id, uye));
create table if not exists oyun.kayyum_juri(
  dava_id bigint not null, user_id uuid not null, oy text check (oy in ('onay','bozma')), gerekce text, zaman timestamptz,
  atama timestamptz not null, primary key (dava_id, user_id));
create index if not exists kayyum_juri_user on oyun.kayyum_juri(user_id, atama desc);

do $r$
declare t text;
begin
  foreach t in array array['oyun.kayyum_dava','oyun.kayyum_oy','oyun.kayyum_juri'] loop
    execute format('alter table %s enable row level security', t);
    execute format('revoke all on %s from public, anon, authenticated', t);
  end loop;
end $r$;

-- ---------------------------------------------------------------------
-- Kataloglar
-- ---------------------------------------------------------------------
create or replace function oyun.kk_dayanak()
returns table(kod text, ad text, kanun text, kanit_turleri text[], kurumlar text[], sira int)
language sql immutable set search_path to '' as $$
  values
  ('dolandiricilik', 'Nitelikli dolandırıcılık', 'TCK m.158', array['masak','hareket','dava'], array['sirket','dernek','sendika','gazete','tv','dergi','hukuk_burosu'], 1),
  ('hirsizlik', 'Hırsızlık, zimmet ve güveni kötüye kullanma', 'TCK m.141, 155, 247', array['masak','hareket','dava'], array['sirket','dernek','sendika','gazete','tv','dergi','hukuk_burosu'], 2),
  ('karapara', 'Suç gelirlerini aklama (kara para)', 'TCK m.282 · MASAK', array['masak','hareket'], array['sirket','dernek','sendika','gazete','tv','dergi','hukuk_burosu'], 3),
  ('vergi', 'Vergi kaçakçılığı', 'VUK m.359', array['masak','hareket','dava'], array['sirket','gazete','tv','dergi','hukuk_burosu'], 4),
  ('galeyan', 'Halkı kin ve düşmanlığa tahrik, galeyana getirme', 'TCK m.216', array['mesaj','yayin','eylem','dava'], array['sirket','dernek','sendika','gazete','tv','dergi','hukuk_burosu'], 5),
  ('anayasal_duzen', 'Anayasal düzene ve devletin güvenliğine karşı suç', 'TCK m.309-316 · CMK m.133', array['mesaj','yayin','eylem','dava','masak'], array['sirket','dernek','sendika','gazete','tv','dergi','hukuk_burosu'], 6),
  ('amac_disi', 'Kanuna ve kuruluş amacına aykırı faaliyet', 'TMK m.89 · Dernekler Kanunu m.30', array['mesaj','yayin','eylem','dava'], array['dernek','sendika'], 7),
  ('dezenformasyon', 'Halkı yanıltıcı bilgiyi alenen yayma', 'TCK m.217/A', array['yayin','mesaj','dava'], array['gazete','tv','dergi'], 8)
$$;

create or replace function oyun.kk_kurum_tur_ad(t text) returns text
language sql immutable set search_path to '' as $$
  select case t when 'sirket' then 'Şirket' when 'dernek' then 'Dernek' when 'sendika' then 'Sendika' when 'gazete' then 'Gazete'
    when 'tv' then 'TV kanalı' when 'dergi' then 'Dergi' when 'hukuk_burosu' then 'Hukuk bürosu' else t end
$$;

-- Kurum bilgisi: ad, aktiflik, sorumlular (sahip/başkan/kurucu/yönetici/büyük ortaklar), yönetim sütunu, kasa
create or replace function oyun.kk_kurum(p_tur text, p_id bigint) returns jsonb
language plpgsql stable set search_path to '' as $$
declare j jsonb;
begin
  if p_tur = 'sirket' then
    select jsonb_build_object('ad', s.ad, 'aktif', s.aktif, 'banka', s.sektor = 'banka', 'kasa', s.kasa, 'yonetim', s.yonetici,
      'sorumlular', to_jsonb(array(select distinct x from unnest(array[s.kurucu, s.yonetici] ||
          array(select o.user_id from oyun.sirket_ortaklari o where o.sirket_id = s.id order by o.pay desc limit 3)) x where x is not null)))
      into j from oyun.sirketler s where s.id = p_id;
  elsif p_tur = 'dernek' then
    select jsonb_build_object('ad', d.ad, 'aktif', not d.kapali, 'kasa', d.kasa, 'yonetim', d.baskan,
      'sorumlular', to_jsonb(array(select distinct x from unnest(array[d.baskan, d.kurucu]) x where x is not null))) into j from oyun.dernekler d where d.id = p_id;
  elsif p_tur = 'sendika' then
    select jsonb_build_object('ad', d.ad, 'aktif', not d.kapali, 'kasa', d.kasa, 'yonetim', d.baskan,
      'sorumlular', to_jsonb(array(select distinct x from unnest(array[d.baskan, d.kurucu]) x where x is not null))) into j from oyun.sendika d where d.id = p_id;
  elsif p_tur = 'gazete' then
    select jsonb_build_object('ad', g.ad, 'aktif', g.aktif, 'kasa', g.kasa, 'yonetim', g.sahip, 'sorumlular', to_jsonb(array[g.sahip])) into j from oyun.oyuncu_gazeteleri g where g.id = p_id;
  elsif p_tur = 'tv' then
    select jsonb_build_object('ad', g.ad, 'aktif', g.aktif, 'kasa', g.kasa, 'yonetim', g.sahip, 'sorumlular', to_jsonb(array[g.sahip])) into j from oyun.tv_kanal g where g.id = p_id;
  elsif p_tur = 'dergi' then
    select jsonb_build_object('ad', g.ad, 'aktif', g.aktif, 'kasa', g.kasa, 'yonetim', g.sahip, 'sorumlular', to_jsonb(array[g.sahip])) into j from oyun.karikatur_dergi g where g.id = p_id;
  elsif p_tur = 'hukuk_burosu' then
    select jsonb_build_object('ad', h.ad, 'aktif', h.aktif, 'kasa', 0, 'yonetim', h.kurucu, 'sorumlular', to_jsonb(array[h.kurucu])) into j from oyun.hukuk_burolari h where h.id = p_id;
  end if;
  return j;
end $$;

create or replace function oyun.kk_sorumlular(j jsonb) returns uuid[]
language sql immutable set search_path to '' as $$
  select coalesce(array(select (x)::uuid from jsonb_array_elements_text(coalesce(j->'sorumlular','[]'::jsonb)) x), '{}'::uuid[])
$$;

-- Başvuru yetkisi: hangi bakanlık hangi kurum türü için
create or replace function oyun.kk_basvuru_makam(u uuid, p_kurum_tur text) returns text
language sql stable set search_path to '' as $$
  select case
    when oyun.bm_yetki(u, 'adalet') is not null then 'adalet'
    when p_kurum_tur in ('dernek','sendika') and oyun.bm_yetki(u, 'icisleri') is not null then 'icisleri'
    when p_kurum_tur in ('sirket','hukuk_burosu') and oyun.bm_yetki(u, 'ticaret') is not null then 'ticaret'
  end
$$;

-- ---------------------------------------------------------------------
-- Kanıt değerlendirme (yalnız sistem kayıtları; sorumlulara ait olmalı)
-- ---------------------------------------------------------------------
create or replace function oyun.kk_kanit_degerlendir(p_sorumlular uuid[], p_kurum_tur text, p_kurum_id bigint, p_kanitlar jsonb)
returns jsonb language plpgsql stable set search_path to '' as $$
declare k jsonb; tur text; kid bigint; ozet text; ok boolean; guclu text; liste jsonb := '[]'::jsonb; t timestamptz := oyun.simdi();
        r record; gor text[] := '{}'; n int := 0; mah int := 0; mas int := 0; turler text[] := '{}';
begin
  for k in select * from jsonb_array_elements(coalesce(p_kanitlar, '[]'::jsonb)) limit 10 loop
    tur := k->>'tur'; ok := false; guclu := null; ozet := null;
    begin kid := (k->>'id')::bigint; exception when others then kid := null; end;
    if kid is null or tur is null or (tur || ':' || kid) = any(gor) then continue; end if;
    gor := gor || (tur || ':' || kid);
    if tur = 'dava' then
      select * into r from oyun.adliye_davalar d where d.id = kid;
      if r.id is not null then
        ozet := format('Dava #%s · %s · karar: %s%s', r.id, r.tur, coalesce(r.karar, 'yok'), case when r.kesin then ' · kesin' else ' · kesinleşmedi' end);
        ok := r.kesin and r.karar is not null and r.karar not in ('beraat','dusme') and r.af_at is null and coalesce(r.karar_at, r.acilis) > t - interval '90 days'
              and (r.davali = any(p_sorumlular) or (r.davali_kurum_tur = p_kurum_tur and r.davali_kurum_id = p_kurum_id::text));
        if ok then guclu := 'mahkumiyet'; end if;
      end if;
    elsif tur = 'masak' then
      select * into r from oyun.masak m where m.id = kid;
      if r.id is not null then
        ozet := format('MASAK #%s · %s · %s ₺ · %s', r.id, r.tur, oyun.tl(coalesce(r.tutar, 0)), r.durum);
        ok := r.user_id = any(p_sorumlular) and r.durum <> 'temiz' and r.zaman > t - interval '90 days';
        if ok and r.durum in ('ihtar','el_koyuldu') then guclu := 'masak'; end if;
      end if;
    elsif tur = 'mesaj' then
      select * into r from oyun.mesajlar m where m.id = kid;
      if r.id is not null then
        ozet := format('Mesaj #%s · %s · %s: %s', r.id, oyun.mod_kanal_ad(r.kanal), oyun.kad(r.user_id), left(r.metin, 160));
        ok := r.user_id = any(p_sorumlular) and r.zaman > t - interval '60 days';
      end if;
    elsif tur = 'yayin' then
      select * into r from oyun.yayinlar y where y.id = kid;
      if r.id is not null then
        ozet := format('Yayın #%s · %s: %s', r.id, oyun.kad(r.gonderen), left(r.metin, 160));
        ok := r.gonderen = any(p_sorumlular) and r.zaman > t - interval '60 days';
      end if;
    elsif tur = 'eylem' then
      select * into r from oyun.sokak_eylem e where e.id = kid;
      if r.id is not null then
        ozet := format('Eylem #%s · başlatan %s · %s', r.id, oyun.kad(r.baslatan), left(coalesce(r.gerekce, ''), 140));
        ok := r.baslangic > t - interval '60 days' and (r.baslatan = any(p_sorumlular) or (r.org_tur = p_kurum_tur and r.org_id = p_kurum_id));
      end if;
    elsif tur = 'hareket' then
      select * into r from oyun.hesap_hareket h where h.id = kid;
      if r.id is not null then
        ozet := format('Para hareketi #%s · %s · %s ₺ · %s', r.id, oyun.kad(r.user_id), oyun.tl(r.tutar), left(coalesce(r.aciklama, r.tur), 120));
        ok := r.user_id = any(p_sorumlular) and abs(r.tutar) >= 100000 and r.zaman > t - interval '60 days';
      end if;
    else
      continue;
    end if;
    liste := liste || jsonb_build_array(jsonb_build_object('tur', tur, 'id', kid, 'ozet', coalesce(ozet, 'Kayıt bulunamadı'), 'gecerli', ok, 'guclu', guclu));
    if ok then n := n + 1; turler := turler || tur; end if;
    if guclu = 'mahkumiyet' then mah := mah + 1; end if;
    if guclu = 'masak' then mas := mas + 1; end if;
  end loop;
  return jsonb_build_object('liste', liste, 'gecerli', n, 'mahkumiyet', mah, 'masak', mas, 'turler', to_jsonb(turler));
end $$;

-- Mahkeme eşiği (tarafsız üye sayısına göre)
create or replace function oyun.kk_tarafsiz_uyeler(d oyun.kayyum_dava) returns uuid[]
language sql stable set search_path to '' as $$
  select coalesce(array_agg(m.user_id), '{}'::uuid[]) from oyun.mahkeme_uye m join oyun.profiller p on p.id = m.user_id
   where m.user_id is not null and not p.yasakli and m.user_id <> d.basvuran and not (m.user_id = any(d.sorumlular))
     and m.user_id is distinct from d.kayyum_kisi
     and (p.parti_id is null or p.parti_id not in (select q.parti_id from oyun.profiller q where (q.id = any(d.sorumlular) or q.id = d.basvuran) and q.parti_id is not null))
$$;

-- ---------------------------------------------------------------------
-- Uygulama / sona erdirme
-- ---------------------------------------------------------------------
create or replace function oyun.kk_hazine(v numeric) returns void
language sql set search_path to '' as $$
  update oyun.ulke set hazine = hazine + v / coalesce(oyun.pazar_tl_milyar(), 1000000) where id = 1 and v > 0
$$;

create or replace function oyun.kk_uygula(p_id bigint) returns void
language plpgsql set search_path to '' as $$
declare d oyun.kayyum_dava; t timestamptz := oyun.simdi(); kj jsonb; v numeric := 0; u uuid;
begin
  select * into d from oyun.kayyum_dava where id = p_id for update;
  if d.id is null then return; end if;
  perform set_config('oyun.kk_sistem', '1', true);
  kj := oyun.kk_kurum(d.kurum_tur, d.kurum_id);
  if d.karar = 'kapatma' then
    v := coalesce((kj->>'kasa')::numeric, 0);
    if d.kurum_tur = 'sirket' then update oyun.sirketler set kasa = 0, aktif = false, satilik = null where id = d.kurum_id;
    elsif d.kurum_tur = 'dernek' then update oyun.dernekler set kasa = 0, kapali = true where id = d.kurum_id;
    elsif d.kurum_tur = 'sendika' then update oyun.sendika set kasa = 0, kapali = true where id = d.kurum_id;
    elsif d.kurum_tur = 'gazete' then update oyun.oyuncu_gazeteleri set kasa = 0, aktif = false where id = d.kurum_id;
    elsif d.kurum_tur = 'tv' then update oyun.tv_kanal set kasa = 0, aktif = false where id = d.kurum_id;
    elsif d.kurum_tur = 'dergi' then update oyun.karikatur_dergi set kasa = 0, aktif = false where id = d.kurum_id;
    elsif d.kurum_tur = 'hukuk_burosu' then update oyun.hukuk_burolari set aktif = false where id = d.kurum_id; v := 0;
    end if;
    perform oyun.kk_hazine(v);
    update oyun.kayyum_dava set durum = 'uygulandi', kesin_at = coalesce(kesin_at, t), emanet = v,
           sonuc_notu = format('Kurum kapatıldı; kasadaki %s ₺ Hazine''ye müsadere edildi.', oyun.tl(v)) where id = d.id;
    foreach u in array d.sorumlular loop perform oyun.bildir(u, format('Kesinleşmiş mahkeme kararıyla %s (%s) kapatıldı. Kasadaki %s ₺ Hazine''ye geçti. Dosya #%s.', d.kurum_ad, oyun.kk_kurum_tur_ad(d.kurum_tur), oyun.tl(v), d.id), t); end loop;
    perform oyun.olay('adalet', format('Kesinleşmiş kararla %s (%s) kapatıldı. Dayanak: %s.', d.kurum_ad, oyun.kk_kurum_tur_ad(d.kurum_tur), (select ad from oyun.kk_dayanak() where kod = d.dayanak)), null, null, t);
  else
    v := coalesce((kj->>'kasa')::numeric, 0);
    if d.kurum_tur = 'sirket' then update oyun.sirketler set kasa = 0, aktif = false, satilik = null where id = d.kurum_id;
    elsif d.kurum_tur = 'hukuk_burosu' then update oyun.hukuk_burolari set aktif = false where id = d.kurum_id;
    elsif d.kayyum_kisi is null then
      -- kayyum kişisi önerilmemişse faaliyet dondurulur
      if d.kurum_tur = 'dernek' then update oyun.dernekler set kasa = 0 where id = d.kurum_id;
      elsif d.kurum_tur = 'sendika' then update oyun.sendika set kasa = 0 where id = d.kurum_id;
      elsif d.kurum_tur = 'gazete' then update oyun.oyuncu_gazeteleri set kasa = 0, aktif = false where id = d.kurum_id;
      elsif d.kurum_tur = 'tv' then update oyun.tv_kanal set kasa = 0, aktif = false where id = d.kurum_id;
      elsif d.kurum_tur = 'dergi' then update oyun.karikatur_dergi set kasa = 0, aktif = false where id = d.kurum_id;
      end if;
    elsif d.kurum_tur = 'dernek' then update oyun.dernekler set kasa = 0, baskan = d.kayyum_kisi where id = d.kurum_id;
    elsif d.kurum_tur = 'sendika' then update oyun.sendika set kasa = 0, baskan = d.kayyum_kisi where id = d.kurum_id;
    elsif d.kurum_tur = 'gazete' then update oyun.oyuncu_gazeteleri set kasa = 0, sahip = d.kayyum_kisi where id = d.kurum_id;
    elsif d.kurum_tur = 'tv' then update oyun.tv_kanal set kasa = 0, sahip = d.kayyum_kisi where id = d.kurum_id;
    elsif d.kurum_tur = 'dergi' then update oyun.karikatur_dergi set kasa = 0, sahip = d.kayyum_kisi where id = d.kurum_id;
    end if;
    update oyun.kayyum_dava set durum = 'kayyum_aktif', kesin_at = coalesce(kesin_at, t), kayyum_bas = t,
           kayyum_bit = t + make_interval(days => coalesce(kayyum_gun, 15)), emanet = v, eski_yonetim = (kj->>'yonetim')::uuid,
           sonuc_notu = format('Kayyum atandı (%s gün). %s ₺ kurum kasası emanete alındı.', coalesce(kayyum_gun, 15), oyun.tl(v)) where id = d.id;
    foreach u in array d.sorumlular loop perform oyun.bildir(u, format('Kesinleşmiş mahkeme kararıyla %s yönetimine %s gün süreyle kayyum atandı%s. Kurum kasası (%s ₺) emanete alındı; süre bitince size iade edilir. Dosya #%s.',
       d.kurum_ad, coalesce(d.kayyum_gun, 15), case when d.kayyum_kisi is not null and d.kurum_tur not in ('sirket','hukuk_burosu') then ' (' || oyun.kad(d.kayyum_kisi) || ')' else '; faaliyet donduruldu' end, oyun.tl(v), d.id), t); end loop;
    if d.kayyum_kisi is not null then perform oyun.bildir(d.kayyum_kisi, format('Mahkeme kararıyla %s (%s) kurumuna %s gün süreyle kayyum olarak atandınız. Kurumu yönetebilirsiniz; kurum kasasından para harcayamaz, kurumu satamaz ve kapatamazsınız.', d.kurum_ad, oyun.kk_kurum_tur_ad(d.kurum_tur), coalesce(d.kayyum_gun, 15)), t); end if;
    perform oyun.olay('adalet', format('Kesinleşmiş kararla %s (%s) yönetimine %s gün kayyum atandı.', d.kurum_ad, oyun.kk_kurum_tur_ad(d.kurum_tur), coalesce(d.kayyum_gun, 15)), null, null, t);
  end if;
  perform set_config('oyun.kk_sistem', '', true);
end $$;

create or replace function oyun.kk_bitir(p_id bigint) returns void
language plpgsql set search_path to '' as $$
declare d oyun.kayyum_dava; t timestamptz := oyun.simdi(); u uuid; geri boolean := true;
begin
  select * into d from oyun.kayyum_dava where id = p_id for update;
  if d.id is null or d.durum <> 'kayyum_aktif' then return; end if;
  perform set_config('oyun.kk_sistem', '1', true);
  begin
    if d.kurum_tur = 'sirket' then update oyun.sirketler set aktif = true, kasa = kasa + coalesce(d.emanet, 0) where id = d.kurum_id;
    elsif d.kurum_tur = 'hukuk_burosu' then update oyun.hukuk_burolari set aktif = true where id = d.kurum_id;
    elsif d.kurum_tur = 'dernek' then update oyun.dernekler set kasa = kasa + coalesce(d.emanet, 0), baskan = coalesce(d.eski_yonetim, baskan) where id = d.kurum_id;
    elsif d.kurum_tur = 'sendika' then update oyun.sendika set kasa = kasa + coalesce(d.emanet, 0), baskan = coalesce(d.eski_yonetim, baskan) where id = d.kurum_id;
    elsif d.kurum_tur = 'gazete' then update oyun.oyuncu_gazeteleri set kasa = kasa + coalesce(d.emanet, 0), sahip = coalesce(d.eski_yonetim, sahip), aktif = true where id = d.kurum_id;
    elsif d.kurum_tur = 'tv' then update oyun.tv_kanal set kasa = kasa + coalesce(d.emanet, 0), sahip = coalesce(d.eski_yonetim, sahip), aktif = true where id = d.kurum_id;
    elsif d.kurum_tur = 'dergi' then update oyun.karikatur_dergi set kasa = kasa + coalesce(d.emanet, 0), sahip = coalesce(d.eski_yonetim, sahip), aktif = true where id = d.kurum_id;
    end if;
  exception when unique_violation then
    -- Sahip bu sürede aynı türde yeni kurum açtıysa iade edilemez: kurum kapalı kalır, emanet ve kasa sahibine ödenir
    geri := false;
    if d.eski_yonetim is not null then perform oyun.para_islem(d.eski_yonetim, coalesce(d.emanet, 0), 'iade', format('Kayyum sona erdi (dosya #%s): emanet iadesi', d.id), t); end if;
    if d.kurum_tur = 'gazete' then update oyun.oyuncu_gazeteleri set aktif = false where id = d.kurum_id;
    elsif d.kurum_tur = 'dergi' then update oyun.karikatur_dergi set aktif = false where id = d.kurum_id; end if;
  end;
  update oyun.kayyum_dava set durum = 'sona_erdi', sonuc_notu = coalesce(sonuc_notu, '') || case when geri then ' Kayyum süresi doldu; yönetim ve emanet iade edildi.' else ' Kayyum süresi doldu; kurum iade edilemediği için emanet sahibine ödendi.' end where id = d.id;
  foreach u in array d.sorumlular loop perform oyun.bildir(u, format('%s üzerindeki kayyum süresi doldu; yönetim ve emanetteki %s ₺ iade edildi (dosya #%s).', d.kurum_ad, oyun.tl(coalesce(d.emanet, 0)), d.id), t); end loop;
  if d.kayyum_kisi is not null then perform oyun.bildir(d.kayyum_kisi, format('%s kurumundaki kayyumluk göreviniz sona erdi.', d.kurum_ad), t); end if;
  perform set_config('oyun.kk_sistem', '', true);
end $$;

-- Kayyum altındaki kuruma koruma: kayyum kasadan harcayamaz; kimse yönetimi değiştiremez, kurumu satamaz/kapatamaz
create or replace function oyun.tg_kayyum_koruma() returns trigger
language plpgsql set search_path to '' as $$
declare kt text; d oyun.kayyum_dava; o jsonb := to_jsonb(old); n jsonb := to_jsonb(new);
begin
  if auth.uid() is null or coalesce(current_setting('oyun.kk_sistem', true), '') = '1' then return new; end if;
  kt := case tg_table_name when 'sirketler' then 'sirket' when 'dernekler' then 'dernek' when 'sendika' then 'sendika' when 'oyuncu_gazeteleri' then 'gazete'
                           when 'tv_kanal' then 'tv' when 'karikatur_dergi' then 'dergi' when 'hukuk_burolari' then 'hukuk_burosu' end;
  select * into d from oyun.kayyum_dava where kurum_tur = kt and kurum_id = old.id and durum = 'kayyum_aktif' limit 1;
  if d.id is null then return new; end if;
  if (o->'sahip') is distinct from (n->'sahip') or (o->'baskan') is distinct from (n->'baskan') or (o->'kurucu') is distinct from (n->'kurucu')
     or (o->'aktif') is distinct from (n->'aktif') or (o->'kapali') is distinct from (n->'kapali')
     or ((n->>'satilik') is not null and (o->'satilik') is distinct from (n->'satilik')) then
    raise exception 'Bu kurum mahkeme kararıyla kayyum yönetiminde (dosya #%); yönetimi değiştirilemez, satılamaz ya da kapatılamaz.', d.id;
  end if;
  if auth.uid() = d.kayyum_kisi and coalesce((n->>'kasa')::numeric, 0) < coalesce((o->>'kasa')::numeric, 0) then
    raise exception 'Kayyum kurum kasasından para harcayamaz (dosya #%).', d.id;
  end if;
  return new;
end $$;
do $tg$
declare t text;
begin
  foreach t in array array['sirketler','dernekler','sendika','oyuncu_gazeteleri','tv_kanal','karikatur_dergi','hukuk_burolari'] loop
    if to_regclass('oyun.' || t) is not null then
      execute format('drop trigger if exists kayyum_koruma on oyun.%I', t);
      execute format('create trigger kayyum_koruma before update on oyun.%I for each row execute function oyun.tg_kayyum_koruma()', t);
    end if;
  end loop;
end $tg$;

-- ---------------------------------------------------------------------
-- Karar değerlendirme ve zamanlayıcı
-- ---------------------------------------------------------------------
create or replace function oyun.kk_degerlendir(p_id bigint, p_son boolean) returns void
language plpgsql set search_path to '' as $$
declare d oyun.kayyum_dava; t timestamptz := oyun.simdi(); e int; ka int; ky int; re int; es_ky int; es_kp int; v_karar text; u uuid; kalan int;
begin
  select * into d from oyun.kayyum_dava where id = p_id for update;
  if d.id is null or d.durum <> 'yargilama' then return; end if;
  e := cardinality(oyun.kk_tarafsiz_uyeler(d));
  select count(*) filter (where o.karar = 'kabul'), count(*) filter (where o.karar = 'kayyum'), count(*) filter (where o.karar = 'ret')
    into ka, ky, re from oyun.kayyum_oy o where o.dava_id = d.id and o.uye = any(oyun.kk_tarafsiz_uyeler(d));
  es_ky := greatest(3, floor(e / 2.0)::int + 1);
  es_kp := greatest(3, ceil(e * 2 / 3.0)::int);
  kalan := e - ka - ky - re;
  if d.tur = 'kapatma' and ka >= es_kp then v_karar := 'kapatma';
  elsif d.tur = 'kapatma' and (ka + ky) >= es_ky and (p_son or ka + kalan < es_kp) then v_karar := 'kayyum';
  elsif d.tur = 'kayyum' and ka >= es_ky then v_karar := 'kayyum';
  elsif p_son or (ka + ky + kalan) < es_ky then v_karar := 'ret';
  end if;
  if v_karar is null then return; end if;
  if v_karar = 'ret' then
    update oyun.kayyum_dava set durum = 'ret', karar = 'ret', karar_at = t,
           sonuc_notu = format('Yüksek Mahkeme gerekli çoğunluğa ulaşmadı (tarafsız üye %s, kabul %s, kayyum %s, ret %s). Başvuru reddedildi.', e, ka, ky, re) where id = d.id;
    perform oyun.bildir(d.basvuran, format('%s hakkındaki %s başvurunuz (#%s) reddedildi: gerekli mahkeme çoğunluğu oluşmadı.', d.kurum_ad, d.tur, d.id), t);
    foreach u in array d.sorumlular loop perform oyun.bildir(u, format('%s hakkındaki %s başvurusu (#%s) reddedildi.', d.kurum_ad, d.tur, d.id), t); end loop;
  else
    update oyun.kayyum_dava set durum = 'itiraz_suresi', karar = v_karar, karar_at = t, itiraz_son = t + interval '48 hours' where id = d.id;
    foreach u in array d.sorumlular loop perform oyun.bildir(u, format('Yüksek Mahkeme %s hakkında %s kararı verdi (#%s). Karar kesin değildir: 48 saat içinde istinafa başvurabilirsiniz (Adliye › Kayyum ve kapatma).', d.kurum_ad, case v_karar when 'kapatma' then 'KAPATMA' else 'KAYYUM' end, d.id), t); end loop;
    perform oyun.bildir(d.basvuran, format('%s hakkında %s kararı çıktı (#%s); itiraz süresi 48 saat.', d.kurum_ad, v_karar, d.id), t);
  end if;
end $$;

create or replace function oyun.kk_juri_sec(p_id bigint) returns int
language plpgsql set search_path to '' as $$
declare d oyun.kayyum_dava; t timestamptz := oyun.simdi(); n int := 0; r record;
begin
  select * into d from oyun.kayyum_dava where id = p_id;
  for r in select p.id from oyun.profiller p
            where not p.yasakli and p.son_gorulme > t - interval '24 hours' and p.olusturma < t - interval '14 days'
              and p.id <> d.basvuran and not (p.id = any(d.sorumlular)) and p.id is distinct from d.kayyum_kisi
              and not oyun.mahkeme_uyesi_mi(p.id)
              and not exists (select 1 from oyun.moderatorler m where m.user_id = p.id) and not p.yonetici
              and (p.parti_id is null or p.parti_id not in (select q.parti_id from oyun.profiller q where (q.id = any(d.sorumlular) or q.id = d.basvuran) and q.parti_id is not null))
              and (select count(*) from oyun.kayyum_juri j join oyun.kayyum_dava x on x.id = j.dava_id where j.user_id = p.id and x.durum = 'istinaf') < 2
            order by random() limit 3 loop
    insert into oyun.kayyum_juri(dava_id, user_id, atama) values (d.id, r.id, t) on conflict do nothing;
    perform oyun.bildir(r.id, format('İSTİNAF HEYETİ GÖREVİ: %s (%s) hakkındaki %s kararını inceleyeceksiniz (dosya #%s). 36 saat içinde "onay" ya da "bozma" oyu verin: Adliye › Kayyum ve kapatma.', d.kurum_ad, oyun.kk_kurum_tur_ad(d.kurum_tur), d.karar, d.id), t);
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function oyun.kk_istinaf_degerlendir(p_id bigint, p_son boolean) returns void
language plpgsql set search_path to '' as $$
declare d oyun.kayyum_dava; t timestamptz := oyun.simdi(); onay int; boz int; u uuid;
begin
  select * into d from oyun.kayyum_dava where id = p_id for update;
  if d.id is null or d.durum <> 'istinaf' then return; end if;
  select count(*) filter (where oy = 'onay'), count(*) filter (where oy = 'bozma') into onay, boz from oyun.kayyum_juri where dava_id = d.id;
  if onay >= 2 then
    update oyun.kayyum_dava set kesin_at = t where id = d.id;
    perform oyun.kk_uygula(d.id);
  elsif boz >= 2 or p_son then
    update oyun.kayyum_dava set durum = 'bozuldu', sonuc_notu = format('İstinaf heyeti kararı onaylamadı (onay %s, bozma %s). Karar bozuldu; kurum hakkında işlem yapılmaz.', onay, boz) where id = d.id;
    foreach u in array d.sorumlular loop perform oyun.bildir(u, format('İstinaf heyeti %s hakkındaki %s kararını BOZDU (#%s). Kurumunuz hakkında işlem yapılmayacak.', d.kurum_ad, d.karar, d.id), t); end loop;
    perform oyun.bildir(d.basvuran, format('%s hakkındaki %s kararı istinafta bozuldu (#%s).', d.kurum_ad, d.karar, d.id), t);
  end if;
end $$;

create or replace function oyun.kayyum_tick() returns int
language plpgsql set search_path to '' as $$
declare r record; t timestamptz := oyun.simdi(); n int := 0;
begin
  for r in select id, durum from oyun.kayyum_dava
            where (durum = 'savunma' and savunma_son <= t) or (durum = 'yargilama' and oylama_son <= t)
               or (durum = 'itiraz_suresi' and itiraz_son <= t) or (durum = 'istinaf' and istinaf_son <= t)
               or (durum = 'kayyum_aktif' and kayyum_bit <= t)
            order by zaman limit 100 loop
    begin
      if r.durum = 'savunma' then
        update oyun.kayyum_dava set durum = 'yargilama', oylama_son = t + interval '72 hours' where id = r.id;
        perform oyun.bildir(m, format('Yüksek Mahkeme: kayyum/kapatma dosyası #%s oylamada (72 saat). Adliye › Kayyum ve kapatma.', r.id), t)
          from unnest(oyun.kk_tarafsiz_uyeler((select x from oyun.kayyum_dava x where x.id = r.id))) m;
      elsif r.durum = 'yargilama' then perform oyun.kk_degerlendir(r.id, true);
      elsif r.durum = 'itiraz_suresi' then
        update oyun.kayyum_dava set kesin_at = t where id = r.id;
        perform oyun.kk_uygula(r.id);
      elsif r.durum = 'istinaf' then perform oyun.kk_istinaf_degerlendir(r.id, true);
      elsif r.durum = 'kayyum_aktif' then perform oyun.kk_bitir(r.id);
      end if;
      n := n + 1;
    exception when others then
      update oyun.kayyum_dava set sonuc_notu = left(coalesce(sonuc_notu, '') || ' [zamanlayıcı hatası: ' || sqlerrm || ']', 1000) where id = r.id;
    end;
  end loop;
  return n;
end $$;
insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif)
select 'kayyum_dava', 'select oyun.kayyum_tick()', 5, 1, 62, true
where to_regclass('oyun.zamanlayici_adim') is not null and not exists (select 1 from oyun.zamanlayici_adim where adim = 'kayyum_dava');

-- ---------------------------------------------------------------------
-- RPC'ler
-- ---------------------------------------------------------------------
create or replace function public.kk_kurum_ara(p_tur text, p_ara text default null)
returns jsonb language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare a text := '%' || coalesce(nullif(btrim(p_ara), ''), '') || '%';
begin
  if auth.uid() is null then raise exception 'Giriş yapmalısınız'; end if;
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id', id, 'ad', ad, 'sahip', oyun.kad(sahip)) x from (
      select s.id, s.ad, coalesce(s.yonetici, s.kurucu) sahip from oyun.sirketler s where p_tur = 'sirket' and s.aktif and s.sektor <> 'banka' and s.ad ilike a
      union all select d.id, d.ad, d.baskan from oyun.dernekler d where p_tur = 'dernek' and not d.kapali and d.ad ilike a
      union all select d.id, d.ad, d.baskan from oyun.sendika d where p_tur = 'sendika' and not d.kapali and d.ad ilike a
      union all select g.id, g.ad, g.sahip from oyun.oyuncu_gazeteleri g where p_tur = 'gazete' and g.aktif and g.ad ilike a
      union all select g.id, g.ad, g.sahip from oyun.tv_kanal g where p_tur = 'tv' and g.aktif and g.ad ilike a
      union all select g.id, g.ad, g.sahip from oyun.karikatur_dergi g where p_tur = 'dergi' and g.aktif and g.ad ilike a
      union all select h.id, h.ad, h.kurucu from oyun.hukuk_burolari h where p_tur = 'hukuk_burosu' and h.aktif and h.ad ilike a
    ) z order by ad limit 25) q), '[]'::jsonb);
end $$;

create or replace function public.kk_kanit_adaylari(p_kurum_tur text, p_kurum_id bigint)
returns jsonb language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); kj jsonb; s uuid[]; t timestamptz := oyun.simdi();
begin
  if oyun.kk_basvuru_makam(u, p_kurum_tur) is null then raise exception 'Kanıt aramayı yalnız başvuru yetkisi olan bakanlar yapabilir.'; end if;
  kj := oyun.kk_kurum(p_kurum_tur, p_kurum_id);
  if kj is null then raise exception 'Kurum bulunamadı.'; end if;
  s := oyun.kk_sorumlular(kj);
  return jsonb_build_object('kurum', kj->>'ad', 'sorumlular', (select jsonb_agg(oyun.kad(x)) from unnest(s) x),
    'dava', coalesce((select jsonb_agg(jsonb_build_object('tur','dava','id',d.id,'ozet',format('Dava #%s · %s · %s · karar: %s', d.id, oyun.kad(d.davali), d.tur, d.karar),'guclu',true) order by d.id desc)
        from (select * from oyun.adliye_davalar d where d.kesin and d.karar is not null and d.karar not in ('beraat','dusme') and d.af_at is null
               and coalesce(d.karar_at, d.acilis) > t - interval '90 days' and (d.davali = any(s) or (d.davali_kurum_tur = p_kurum_tur and d.davali_kurum_id = p_kurum_id::text)) order by d.id desc limit 10) d), '[]'::jsonb),
    'masak', coalesce((select jsonb_agg(jsonb_build_object('tur','masak','id',m.id,'ozet',format('MASAK #%s · %s · %s · %s ₺ · %s', m.id, oyun.kad(m.user_id), m.tur, oyun.tl(coalesce(m.tutar,0)), m.durum),'guclu',m.durum in ('ihtar','el_koyuldu')) order by m.id desc)
        from (select * from oyun.masak m where m.user_id = any(s) and m.durum <> 'temiz' and m.zaman > t - interval '90 days' order by m.id desc limit 10) m), '[]'::jsonb),
    'eylem', coalesce((select jsonb_agg(jsonb_build_object('tur','eylem','id',e.id,'ozet',format('Eylem #%s · %s · %s', e.id, oyun.kad(e.baslatan), left(coalesce(e.gerekce,''),120))) order by e.id desc)
        from (select * from oyun.sokak_eylem e where e.baslangic > t - interval '60 days' and (e.baslatan = any(s) or (e.org_tur = p_kurum_tur and e.org_id = p_kurum_id)) order by e.id desc limit 10) e), '[]'::jsonb),
    'yayin', coalesce((select jsonb_agg(jsonb_build_object('tur','yayin','id',y.id,'ozet',format('Yayın #%s · %s: %s', y.id, oyun.kad(y.gonderen), left(y.metin,140)))) order by y.id desc)
        from (select * from oyun.yayinlar y where y.gonderen = any(s) and y.zaman > t - interval '60 days' order by y.id desc limit 10) y), '[]'::jsonb),
    'mesaj', coalesce((select jsonb_agg(jsonb_build_object('tur','mesaj','id',m.id,'ozet',format('Mesaj #%s · %s · %s: %s', m.id, oyun.mod_kanal_ad(m.kanal), oyun.kad(m.user_id), left(m.metin,140))) order by m.id desc)
        from (select * from oyun.mesajlar m where m.user_id = any(s) and m.zaman > t - interval '60 days' and oyun.mod_kanal_acik(m.kanal) order by m.id desc limit 15) m), '[]'::jsonb),
    'hareket', coalesce((select jsonb_agg(jsonb_build_object('tur','hareket','id',h.id,'ozet',format('Para #%s · %s · %s ₺ · %s', h.id, oyun.kad(h.user_id), oyun.tl(h.tutar), left(coalesce(h.aciklama,h.tur),90))) order by h.id desc)
        from (select * from oyun.hesap_hareket h where h.user_id = any(s) and abs(h.tutar) >= 100000 and h.zaman > t - interval '60 days' order by abs(h.tutar) desc limit 10) h), '[]'::jsonb));
end $$;

create or replace function public.kk_basvuru(p_tur text, p_kurum_tur text, p_kurum_id bigint, p_dayanak text, p_iddia text, p_kanitlar jsonb,
                                             p_kayyum_kad text default null, p_kayyum_gun integer default 15)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); mk text := oyun.kk_basvuru_makam(auth.uid(), p_kurum_tur); t timestamptz := oyun.simdi();
        kj jsonb; s uuid[]; dy record; kv jsonb; m text := btrim(coalesce(p_iddia, '')); kk oyun.profiller; v_id bigint; x uuid;
begin
  if u is null then raise exception 'Giriş yapmalısınız'; end if;
  if mk is null then raise exception 'Başvuru yetkisi: Adalet Bakanı (tüm kurumlar), İçişleri Bakanı (dernek, sendika), Ticaret Bakanı (şirket, hukuk bürosu).'; end if;
  if p_tur not in ('kayyum','kapatma') then raise exception 'Başvuru türü kayyum ya da kapatma olmalı.'; end if;
  kj := oyun.kk_kurum(p_kurum_tur, p_kurum_id);
  if kj is null then raise exception 'Kurum bulunamadı.'; end if;
  if not coalesce((kj->>'aktif')::boolean, false) then raise exception 'Kurum zaten kapalı ya da faaliyette değil.'; end if;
  if coalesce((kj->>'banka')::boolean, false) then raise exception 'Bankalar bu usulle kapatılamaz ve kayyuma devredilemez (mevduat sahiplerini korumak için BDDK/TMSF usulü geçerlidir).'; end if;
  s := oyun.kk_sorumlular(kj);
  if u = any(s) then raise exception 'Kendi kurumunuz hakkında başvuru yapamazsınız.'; end if;
  select * into dy from oyun.kk_dayanak() z where z.kod = p_dayanak;
  if dy.kod is null or not (p_kurum_tur = any(dy.kurumlar)) then raise exception 'Bu kurum türü için geçerli bir hukuki dayanak seçin.'; end if;
  if char_length(m) < 100 or char_length(m) > 8000 then raise exception 'İddianame 100-8000 karakter olmalı: olay, tarih, kişiler ve suçun unsurları açıkça yazılmalı.'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('kk:' || p_kurum_tur || ':' || p_kurum_id));
  if exists (select 1 from oyun.kayyum_dava where kurum_tur = p_kurum_tur and kurum_id = p_kurum_id and durum in ('savunma','yargilama','itiraz_suresi','istinaf','kayyum_aktif')) then
    raise exception 'Bu kurum hakkında süren bir dava ya da kayyum var.'; end if;
  if exists (select 1 from oyun.kayyum_dava where kurum_tur = p_kurum_tur and kurum_id = p_kurum_id and durum in ('ret','bozuldu') and coalesce(karar_at, zaman) > t - interval '14 days') then
    raise exception 'Bu kurum hakkındaki son başvuru 14 gün içinde reddedildi ya da bozuldu; yeni başvuru için beklemelisiniz.'; end if;
  if (select count(*) from oyun.kayyum_dava where basvuran = u and zaman > t - interval '24 hours') >= 2 then raise exception 'Bir günde en fazla 2 kayyum/kapatma başvurusu yapılabilir.'; end if;
  kv := oyun.kk_kanit_degerlendir(s, p_kurum_tur, p_kurum_id, p_kanitlar);
  if p_tur = 'kayyum' then
    if (kv->>'gecerli')::int < 2 then raise exception 'Kayyum için en az 2 geçerli kanıt gerekir (şu an %). Kanıtlar kurum sorumlularına ait ve süresi içinde olmalı.', kv->>'gecerli'; end if;
    if (kv->>'mahkumiyet')::int < 1 and (kv->>'masak')::int < 1 then raise exception 'Kayyum için kesinleşmiş bir mahkûmiyet ya da MASAK ihtar/el koyma bulgusu şarttır.'; end if;
  else
    if (kv->>'gecerli')::int < 3 then raise exception 'Kapatma için en az 3 geçerli kanıt gerekir (şu an %).', kv->>'gecerli'; end if;
    if (kv->>'mahkumiyet')::int < 1 then raise exception 'Kapatma için kurum ya da sorumluları hakkında kesinleşmiş mahkûmiyet şarttır.'; end if;
    if (kv->>'mahkumiyet')::int < 2 and not exists (select 1 from oyun.kayyum_dava where kurum_tur = p_kurum_tur and kurum_id = p_kurum_id and kesin_at > t - interval '180 days' and karar = 'kayyum') then
      raise exception 'Kapatma için ya ikinci bir kesinleşmiş mahkûmiyet ya da son 180 günde bu kuruma verilmiş kesinleşmiş kayyum kararı gerekir.'; end if;
  end if;
  if not exists (select 1 from jsonb_array_elements_text(kv->'turler') z where z = any(dy.kanit_turleri)) then
    raise exception '"%" dayanağı için kanıtlardan en az biri şu türde olmalı: %.', dy.ad, array_to_string(dy.kanit_turleri, ', '); end if;
  if p_tur = 'kayyum' and p_kayyum_gun not in (7, 15, 30) then raise exception 'Kayyum süresi 7, 15 ya da 30 gün olmalı.'; end if;
  if nullif(btrim(coalesce(p_kayyum_kad, '')), '') is not null then
    select * into kk from oyun.profiller where lower(kad) = lower(btrim(p_kayyum_kad)) and not yasakli;
    if kk.id is null then raise exception 'Kayyum olarak önerilen oyuncu bulunamadı.'; end if;
    if kk.id = u or kk.id = any(s) then raise exception 'Başvuran ya da kurum sorumlusu kayyum olamaz.'; end if;
    if kk.olusturma > t - interval '14 days' then raise exception 'Kayyum en az 14 günlük hesap olmalı.'; end if;
    if oyun.mahkeme_uyesi_mi(kk.id) then raise exception 'Yüksek Mahkeme üyesi kayyum olamaz.'; end if;
    if kk.parti_id is not null and kk.parti_id in (select q.parti_id from oyun.profiller q where q.id = any(s) and q.parti_id is not null) then raise exception 'Kurum sorumlusuyla aynı partiden kayyum atanamaz.'; end if;
    if (p_kurum_tur = 'gazete' and exists (select 1 from oyun.oyuncu_gazeteleri where sahip = kk.id and aktif))
       or (p_kurum_tur = 'dergi' and exists (select 1 from oyun.karikatur_dergi where sahip = kk.id and aktif)) then
      raise exception 'Önerilen kayyumun zaten kendi % kurumu var.', oyun.kk_kurum_tur_ad(p_kurum_tur); end if;
  elsif p_tur = 'kayyum' and p_kurum_tur not in ('sirket','hukuk_burosu') then
    raise exception 'Kayyum olarak atanacak oyuncuyu yazın.';
  end if;
  insert into oyun.kayyum_dava(tur, kurum_tur, kurum_id, kurum_ad, sorumlular, basvuran, basvuran_makam, dayanak, iddia, kanitlar, kanit_ozet,
                               kayyum_kisi, kayyum_gun, zaman, savunma_son)
  values (p_tur, p_kurum_tur, p_kurum_id, kj->>'ad', s, u, mk, dy.kod, m, kv->'liste', kv - 'liste', kk.id,
          case when p_tur = 'kayyum' then p_kayyum_gun else coalesce(p_kayyum_gun, 15) end, t, t + interval '48 hours')
  returning id into v_id;
  foreach x in array s loop
    perform oyun.bildir(x, format('%s, %s (%s) hakkında %s davası açtı (#%s). Dayanak: %s (%s). 48 saat içinde savunma verin: Adliye › Kayyum ve kapatma.',
      (select ad from oyun.bakanliklar where kod = mk), kj->>'ad', oyun.kk_kurum_tur_ad(p_kurum_tur), case p_tur when 'kapatma' then 'KAPATMA' else 'KAYYUM' end, v_id, dy.ad, dy.kanun), t);
  end loop;
  perform oyun.olay('adalet', format('%s, %s (%s) hakkında %s davası açtı. Dayanak: %s.', (select ad from oyun.bakanliklar where kod = mk), kj->>'ad',
          oyun.kk_kurum_tur_ad(p_kurum_tur), case p_tur when 'kapatma' then 'kapatma' else 'kayyum' end, dy.ad), null, null, t);
  return jsonb_build_object('tamam', true, 'id', v_id, 'kanit', kv - 'liste');
end $$;

create or replace function public.kk_savunma(p_id bigint, p_metin text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); d oyun.kayyum_dava; t timestamptz := oyun.simdi(); m text := btrim(coalesce(p_metin, ''));
begin
  select * into d from oyun.kayyum_dava where id = p_id for update;
  if d.id is null or not (u = any(d.sorumlular)) then raise exception 'Bu dosyada savunma hakkınız yok.'; end if;
  if d.durum <> 'savunma' then raise exception 'Savunma aşaması kapandı.'; end if;
  if char_length(m) < 50 or char_length(m) > 8000 then raise exception 'Savunma 50-8000 karakter olmalı.'; end if;
  update oyun.kayyum_dava set savunma = m, savunma_veren = u, savunma_at = t, durum = 'yargilama', oylama_son = t + interval '72 hours' where id = d.id;
  perform oyun.bildir(mm, format('Yüksek Mahkeme: kayyum/kapatma dosyası #%s savunma geldi, oylamada (72 saat).', d.id), t) from unnest(oyun.kk_tarafsiz_uyeler(d)) mm;
  perform oyun.bildir(d.basvuran, format('#%s numaralı dosyada savunma verildi; dosya Yüksek Mahkeme oylamasında.', d.id), t);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.kk_oy(p_id bigint, p_karar text, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); d oyun.kayyum_dava; t timestamptz := oyun.simdi(); g text := btrim(coalesce(p_gerekce, ''));
begin
  select * into d from oyun.kayyum_dava where id = p_id;
  if d.id is null or d.durum <> 'yargilama' then raise exception 'Bu dosya oylamada değil.'; end if;
  if not oyun.mahkeme_uyesi_mi(u) then raise exception 'Yalnız Yüksek Mahkeme üyeleri oy verir.'; end if;
  if not (u = any(oyun.kk_tarafsiz_uyeler(d))) then raise exception 'Taraflarla bağlantınız (aynı parti, taraf ya da kayyum adayı) olduğu için bu dosyada oy veremezsiniz.'; end if;
  if p_karar not in ('kabul','kayyum','ret') or (p_karar = 'kayyum' and d.tur <> 'kapatma') then raise exception 'Geçersiz karar.'; end if;
  if char_length(g) < 50 or char_length(g) > 5000 then raise exception 'Gerekçeli oy 50-5000 karakter olmalı (kanıtları tek tek değerlendirin).'; end if;
  insert into oyun.kayyum_oy(dava_id, uye, karar, gerekce, zaman) values (d.id, u, p_karar, g, t)
  on conflict (dava_id, uye) do update set karar = excluded.karar, gerekce = excluded.gerekce, zaman = excluded.zaman;
  perform oyun.kk_degerlendir(d.id, false);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.kk_itiraz(p_id bigint, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); d oyun.kayyum_dava; t timestamptz := oyun.simdi(); g text := btrim(coalesce(p_gerekce, '')); n int;
begin
  select * into d from oyun.kayyum_dava where id = p_id for update;
  if d.id is null or not (u = any(d.sorumlular)) then raise exception 'Bu dosyada itiraz hakkınız yok.'; end if;
  if d.durum <> 'itiraz_suresi' or d.itiraz_son <= t then raise exception 'İtiraz süresi içinde değil.'; end if;
  if char_length(g) < 50 or char_length(g) > 8000 then raise exception 'İstinaf dilekçesi 50-8000 karakter olmalı.'; end if;
  update oyun.kayyum_dava set durum = 'istinaf', itiraz = g, itiraz_veren = u, itiraz_at = t, istinaf_son = t + interval '36 hours' where id = d.id;
  n := oyun.kk_juri_sec(d.id);
  if n = 0 then perform oyun.kk_istinaf_degerlendir(d.id, true); end if;
  perform oyun.bildir(d.basvuran, format('#%s numaralı dosyada istinafa başvuruldu; %s kişilik istinaf heyeti kuruldu.', d.id, n), t);
  return jsonb_build_object('tamam', true, 'heyet', n);
end $$;

create or replace function public.kk_juri_oy(p_id bigint, p_oy text, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); d oyun.kayyum_dava; t timestamptz := oyun.simdi(); g text := btrim(coalesce(p_gerekce, ''));
begin
  select * into d from oyun.kayyum_dava where id = p_id;
  if d.id is null or d.durum <> 'istinaf' then raise exception 'Bu dosya istinafta değil.'; end if;
  if not exists (select 1 from oyun.kayyum_juri where dava_id = d.id and user_id = u) then raise exception 'Bu dosyanın istinaf heyetinde değilsiniz.'; end if;
  if p_oy not in ('onay','bozma') then raise exception 'Oy onay ya da bozma olmalı.'; end if;
  if char_length(g) < 20 or char_length(g) > 3000 then raise exception 'Gerekçe 20-3000 karakter olmalı.'; end if;
  update oyun.kayyum_juri set oy = p_oy, gerekce = g, zaman = t where dava_id = d.id and user_id = u;
  perform oyun.kk_istinaf_degerlendir(d.id, false);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.kk_geri_cek(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); d oyun.kayyum_dava; x uuid;
begin
  select * into d from oyun.kayyum_dava where id = p_id for update;
  if d.id is null or d.basvuran <> u then raise exception 'Yalnız başvuruyu yapan geri çekebilir.'; end if;
  if d.durum not in ('savunma','yargilama') then raise exception 'Bu aşamada başvuru geri çekilemez.'; end if;
  update oyun.kayyum_dava set durum = 'geri_cekildi', karar_at = oyun.simdi() where id = d.id;
  foreach x in array d.sorumlular loop perform oyun.bildir(x, format('%s hakkındaki başvuru (#%s) geri çekildi.', d.kurum_ad, d.id), oyun.simdi()); end loop;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function oyun.kk_json(d oyun.kayyum_dava, u uuid, detay boolean) returns jsonb
language sql stable set search_path to '' as $$
  select jsonb_build_object('id', d.id, 'tur', d.tur, 'kurum_tur', d.kurum_tur, 'kurum_tur_ad', oyun.kk_kurum_tur_ad(d.kurum_tur), 'kurum_id', d.kurum_id, 'kurum_ad', d.kurum_ad,
    'sorumlular', (select jsonb_agg(oyun.kad(x)) from unnest(d.sorumlular) x), 'basvuran', oyun.kad(d.basvuran),
    'makam', (select ad from oyun.bakanliklar where kod = d.basvuran_makam), 'dayanak', d.dayanak,
    'dayanak_ad', (select ad || ' (' || kanun || ')' from oyun.kk_dayanak() where kod = d.dayanak), 'durum', d.durum, 'zaman', d.zaman,
    'savunma_son', d.savunma_son, 'oylama_son', d.oylama_son, 'itiraz_son', d.itiraz_son, 'istinaf_son', d.istinaf_son,
    'karar', d.karar, 'karar_at', d.karar_at, 'kesin_at', d.kesin_at, 'kayyum', oyun.kad(d.kayyum_kisi), 'kayyum_gun', d.kayyum_gun,
    'kayyum_bas', d.kayyum_bas, 'kayyum_bit', d.kayyum_bit, 'sonuc_notu', d.sonuc_notu, 'kanit_ozet', d.kanit_ozet,
    'benim_kurumum', u = any(d.sorumlular), 'basvuran_benim', d.basvuran = u,
    'oy_hakkim', d.durum = 'yargilama' and u = any(oyun.kk_tarafsiz_uyeler(d)),
    'oyum', (select karar from oyun.kayyum_oy where dava_id = d.id and uye = u),
    'juri_mi', exists (select 1 from oyun.kayyum_juri where dava_id = d.id and user_id = u),
    'juri_oyum', (select oy from oyun.kayyum_juri where dava_id = d.id and user_id = u),
    'oy_sayim', (select jsonb_build_object('kabul', count(*) filter (where karar = 'kabul'), 'kayyum', count(*) filter (where karar = 'kayyum'), 'ret', count(*) filter (where karar = 'ret')) from oyun.kayyum_oy where dava_id = d.id),
    'tarafsiz_uye', cardinality(oyun.kk_tarafsiz_uyeler(d)),
    'juri_sayim', (select jsonb_build_object('onay', count(*) filter (where oy = 'onay'), 'bozma', count(*) filter (where oy = 'bozma'), 'heyet', count(*)) from oyun.kayyum_juri where dava_id = d.id))
  || case when detay then jsonb_build_object('iddia', d.iddia, 'kanitlar', d.kanitlar, 'savunma', d.savunma, 'savunma_veren', oyun.kad(d.savunma_veren), 'savunma_at', d.savunma_at,
       'itiraz', d.itiraz, 'itiraz_at', d.itiraz_at,
       'oylar', case when d.durum not in ('savunma','yargilama') or oyun.mahkeme_uyesi_mi(u) then
          (select coalesce(jsonb_agg(jsonb_build_object('uye', oyun.kad(o.uye), 'karar', o.karar, 'gerekce', o.gerekce, 'zaman', o.zaman) order by o.zaman), '[]'::jsonb) from oyun.kayyum_oy o where o.dava_id = d.id) end,
       'juri_gerekceler', case when d.durum not in ('istinaf') then
          (select coalesce(jsonb_agg(jsonb_build_object('oy', j.oy, 'gerekce', j.gerekce) order by j.zaman), '[]'::jsonb) from oyun.kayyum_juri j where j.dava_id = d.id and j.oy is not null) end)
     else '{}'::jsonb end
$$;

create or replace function public.kk_davalar()
returns jsonb language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Giriş yapmalısınız'; end if;
  return jsonb_build_object(
    'yetki', jsonb_build_object('adalet', oyun.bm_yetki(u, 'adalet') is not null, 'icisleri', oyun.bm_yetki(u, 'icisleri') is not null,
               'ticaret', oyun.bm_yetki(u, 'ticaret') is not null, 'mahkeme', oyun.mahkeme_uyesi_mi(u)),
    'dayanaklar', (select jsonb_agg(jsonb_build_object('kod', kod, 'ad', ad, 'kanun', kanun, 'kanit_turleri', to_jsonb(kanit_turleri), 'kurumlar', to_jsonb(kurumlar)) order by sira) from oyun.kk_dayanak()),
    'davalar', coalesce((select jsonb_agg(oyun.kk_json(d, u, false) order by (d.durum in ('savunma','yargilama','itiraz_suresi','istinaf','kayyum_aktif')) desc, d.zaman desc)
        from (select * from oyun.kayyum_dava x where x.durum in ('savunma','yargilama','itiraz_suresi','istinaf','kayyum_aktif') or x.zaman > oyun.simdi() - interval '60 days'
               or u = any(x.sorumlular) or x.basvuran = u or exists (select 1 from oyun.kayyum_juri j where j.dava_id = x.id and j.user_id = u)
              order by x.zaman desc limit 80) d), '[]'::jsonb));
end $$;

create or replace function public.kk_dava(p_id bigint)
returns jsonb language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare d oyun.kayyum_dava;
begin
  if auth.uid() is null then raise exception 'Giriş yapmalısınız'; end if;
  select * into d from oyun.kayyum_dava where id = p_id;
  if d.id is null then raise exception 'Dosya bulunamadı.'; end if;
  return oyun.kk_json(d, auth.uid(), true);
end $$;

do $g$
declare f text;
begin
  foreach f in array array['public.kk_kurum_ara(text,text)','public.kk_kanit_adaylari(text,bigint)','public.kk_basvuru(text,text,bigint,text,text,jsonb,text,integer)',
    'public.kk_savunma(bigint,text)','public.kk_oy(bigint,text,text)','public.kk_itiraz(bigint,text)','public.kk_juri_oy(bigint,text,text)',
    'public.kk_geri_cek(bigint)','public.kk_davalar()','public.kk_dava(bigint)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array['oyun.kayyum_tick()','oyun.kk_uygula(bigint)','oyun.kk_bitir(bigint)','oyun.kk_juri_sec(bigint)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $g$;
