-- 26.11.2026 · YENİ OYUNCU REHBERİ (ONBOARDING) — sürüm 2026.11.26-3
-- İstek (Ercan, Yönetime Yaz'dan gelen oyuncu önerisi üzerine): "Oyuna ilk girişte oyuncu yönlendirilmeli,
--   başlangıçta kısa ve doğal bir onboarding olsun. İlk giren oyuncu için oyun aşırı karışık. Her şeyi görüyor
--   ama hiçbir şey bilmiyor." → "ekle".
-- Bu dosya (oyuncu verisi değişmez; yalnız sütun/işlev/dizin eklenir; tekrar çalıştırmak güvenlidir):
--   1) oyun.profiller.rehber (jsonb): karşılama görüldü mü, hangi ekran ipuçları kapatıldı, ödül alındı mı.
--      Hesaba bağlı tutulur; oyuncu telefon değiştirse de ipuçları yeniden çıkmaz.
--   2) public.ilk_adimlar() yeniden yazıldı:
--      • 14 günden eski hesaplarda ağır denetimler HİÇ çalışmaz (bu işlev Gündem'de dakikada bir çağrılıyor;
--        25.11 ölçümünde 222 bin çağrı × 25 ms ≈ 94 dk işlemci). Yeni hesaplarda da dizinlerle hızlanır.
--      • Adımlara "neden" açıklaması ve yeni adım "İlk ek işini tamamla" eklendi. Eski uygulama aynı alanları
--        (kod/ad/tamam/not, yeni, bitti) okumaya devam eder; yeni alanları görmezden gelir.
--      • Karşılama kartı metinleri (uygulama_ayar, herkese açık değil) yalnız yeni oyunculara döner;
--        Süper Yönetici Portalı › Ayarlar › Genel'den kod yazmadan değiştirilebilir.
--      'otomatik': karşılama turu ve ekran ipuçları kendiliğinden açılsın mı (ayarlar.rehber_bas'tan sonra açılan hesap).
--   3) public.rehber_isaretle(p_anahtar): karşılama/ipucu/kart kapatma kaydı.
--   4) public.rehber_odul_al(): ilk 6 adımı (oy hariç) bitiren yeni oyuncuya TEK SEFERLİK başlangıç ödülü.
--      Tutar oyun.ayarlar.rehber_odul (varsayılan 5.000 ₺ = başlangıç parasının çeyreği); portaldan değişir, 0 = kapalı.
--      Çift ödeme kilidi: profiller.rehber->'odul' koşullu güncelleme (aynı anda iki istek gelse de bir kez öder).
--   5) public.sohbet_oku 'yeni' alanı (son 7 günde katılan oyuncu) → sohbette "Yeni" rozeti.
--      sohbet_oku'nun kaynağı zz_20261125_yuk_hizlandirma.sql'dedir (listenin sonunda); alan orada da eklendi.
-- Ekranlar: gelistirici/www/rehber.js.

alter table oyun.profiller add column if not exists rehber jsonb not null default '{}'::jsonb;
alter table oyun.ayarlar add column if not exists rehber_odul numeric not null default 5000;
-- Karşılama ve otomatik ekran ipuçları yalnız bu andan SONRA açılan hesaplarda kendiliğinden açılır
-- (sütun eklendiği an mevcut satıra yazılır; mevcut oyuncular turu görmez, ? düğmesi ve İlk Adımlar kartı herkese açık).
alter table oyun.ayarlar add column if not exists rehber_bas timestamptz not null default now();

-- ilk_adimlar / ilk_uc_gorev denetimleri için dizinler (eskiden mesajlar ve oylar tablosu baştan sona taranıyordu)
create index if not exists mesajlar_il_kahve_kullanici on oyun.mesajlar (user_id) where kanal like 'il:%';
create index if not exists oylar_secmen on oyun.oylar (secmen);

-- Karşılama kartı metinleri (yalnız yoksa eklenir; portaldan yapılan düzenleme ezilmez). Biçim: "Başlık | açıklama"
insert into oyun.uygulama_ayar (anahtar, deger, aciklama, herkese_acik) values
  ('rehber_kart_1', to_jsonb('Türkiye''yi oyuncular yönetiyor | Burada bot yok. Cumhurbaşkanından belediye başkanına, vekilden bakana kadar her makamda gerçek bir oyuncu oturuyor. Sen de o koltuklardan birine aday olabilirsin.'::text), 'Yeni oyuncu karşılaması · 1. kart (Başlık | açıklama)', false),
  ('rehber_kart_2', to_jsonb('Para ve kıdem nasıl kazanılır? | Her gün maaşını topla (+1 kıdem), günde 5 ek iş yap, mitinglere katıl, oyunu kullan. Kıdem arttıkça maaşın yükselir; parti ve şirket kurma, adaylık hakları açılır.'::text), 'Yeni oyuncu karşılaması · 2. kart (Başlık | açıklama)', false),
  ('rehber_kart_3', to_jsonb('Her ay seçim var | Belediye seçimi, kurultay ve genel seçim her ay döner. Önce adaylık başvurusu, sonra ön seçim, sonra sandık. Takvimi Gündem''in en üstünde görürsün.'::text), 'Yeni oyuncu karşılaması · 3. kart (Başlık | açıklama)', false),
  ('rehber_kart_4', to_jsonb('İlk hedefin | Gündem''deki "İlk adımların" listesini bitir: maaşını topla, kendini tanıt, bir partiye katıl. Hepsini bitirince başlangıç ödülün cüzdanına yatar. Takıldığın her ekranda sağ üstteki ? düğmesine bas.'::text), 'Yeni oyuncu karşılaması · 4. kart (Başlık | açıklama)', false)
on conflict (anahtar) do nothing;

-- Süper Yönetici Portalı ayar kataloğu (yoksa eklenir)
insert into oyun.yp_ayar_katalog (anahtar, grup, baslik, aciklama, tur, birim, en_az, en_cok, en_uzun, risk, etki, tablo, sutun, satir, sira, aktif) values
  ('ayarlar.rehber_odul', 'ekonomi', 'Yeni oyuncu rehberi ödülü', 'İlk adımları bitiren yeni oyuncuya bir kez verilen başlangıç ödülü. 0 yazarsan ödül kapanır.', 'para', '₺', 0, 50000, null, 'orta', 'Hemen: ödülü henüz almamış oyuncularda.', 'oyun.ayarlar', 'rehber_odul', null, 12, true),
  ('uygulama.rehber_kart_1', 'genel', 'Karşılama kartı 1', 'Yeni oyuncunun ilk girişte gördüğü kart. Biçim: Başlık | açıklama', 'metin', null, null, null, 300, 'dusuk', 'Yeni oyuncularda hemen.', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"rehber_kart_1"}'::jsonb, 21, true),
  ('uygulama.rehber_kart_2', 'genel', 'Karşılama kartı 2', 'Yeni oyuncunun ilk girişte gördüğü kart. Biçim: Başlık | açıklama', 'metin', null, null, null, 300, 'dusuk', 'Yeni oyuncularda hemen.', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"rehber_kart_2"}'::jsonb, 22, true),
  ('uygulama.rehber_kart_3', 'genel', 'Karşılama kartı 3', 'Yeni oyuncunun ilk girişte gördüğü kart. Biçim: Başlık | açıklama', 'metin', null, null, null, 300, 'dusuk', 'Yeni oyuncularda hemen.', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"rehber_kart_3"}'::jsonb, 23, true),
  ('uygulama.rehber_kart_4', 'genel', 'Karşılama kartı 4', 'Yeni oyuncunun ilk girişte gördüğü kart. Biçim: Başlık | açıklama', 'metin', null, null, null, 300, 'dusuk', 'Yeni oyuncularda hemen.', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"rehber_kart_4"}'::jsonb, 24, true)
on conflict (anahtar) do nothing;

-- Ödül için gereken çekirdek adımlar (oy hariç: seçim takvimine bağlı, herkes 14 günde sandığa denk gelmeyebilir)
create or replace function oyun.rehber_durum(p oyun.profiller, t timestamptz)
returns jsonb language plpgsql stable security definer set search_path = '' as $f$
declare d jsonb := oyun.ilk_uc_gorev(p); u text; ek boolean; anket boolean; oy boolean; adimlar jsonb;
begin
  u := coalesce(oyun.uyari(p, t), oyun.ilk_uc_gorev_engel(p));
  ek := exists (select 1 from oyun.ek_is_kayit k where k.user_id = p.id and k.odendi_at is not null);
  anket := exists (select 1 from oyun.haftalik_anket_oy a where a.user_id = p.id);
  oy := exists (select 1 from oyun.oylar o where o.secmen = p.id);
  adimlar := jsonb_build_array(
    jsonb_build_object('kod','maas','ad','İlk maaşını topla','tamam',(d->>'maas')::boolean,'cekirdek',true,
      'neden','Her gün maaşını topla: para ve +1 kıdem kazanırsın. Kıdem; oy, adaylık ve kuruluş haklarını açar.'),
    jsonb_build_object('kod','kimlik','ad','Portreni ve kısa biyografini hazırla','tamam',(d->>'kimlik')::boolean,'cekirdek',true,
      'neden','Diğer oyuncular seni portren ve biyografinle tanır. İlk oyunu kullanmak için gerekir.'),
    jsonb_build_object('kod','sohbet','ad','İl kahvesinde kendini tanıt','tamam',(d->>'kahve')::boolean,'cekirdek',true,
      'neden','Sohbet › İl kahvesi, ilindeki oyuncuların buluşma yeri. Bir selam yaz; ilk oy hakkı için son başlangıç görevi.'),
    jsonb_build_object('kod','parti','ad','Bir partiye katıl','tamam',p.parti_id is not null,'cekirdek',true,
      'neden','Parti üyeleri kurultayda genel başkanı seçer, ön seçimde aday sıralamasını belirler. Partini sonra değiştirebilirsin.'),
    jsonb_build_object('kod','ek_is','ad','İlk ek işini tamamla','tamam',ek,'cekirdek',true,
      'neden','Günde 5 ek iş hakkın var, gece 00.00''da yenilenir. İşi başlat, süre dolunca ücretini al.'),
    jsonb_build_object('kod','anket','ad','Haftalık siyasi ankete katıl','tamam',anket,'cekirdek',true,
      'neden','Her hafta hangi partiyi desteklediğini söyle; sonuçlar herkese açık yayınlanır.'),
    jsonb_build_object('kod','oy','ad','İlk oyunu kullan','tamam',oy,'cekirdek',false,'not',u,
      'neden','Sandık açıkken Gündem''deki seçim kartından oy verirsin. Ödül için şart değil; ilk seçimini kaçırma.'));
  return jsonb_build_object('adimlar', adimlar, 'engel', u, 'oy_gorevleri', d,
    'cekirdek_bitti', not exists (select 1 from jsonb_array_elements(adimlar) x where (x->>'cekirdek')::boolean and not (x->>'tamam')::boolean),
    'bitti', not exists (select 1 from jsonb_array_elements(adimlar) x where not (x->>'tamam')::boolean));
end $f$;

create or replace function public.ilk_adimlar() returns jsonb
language plpgsql security definer set search_path = '' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); r jsonb; s jsonb; odul numeric;
begin
  r := coalesce(p.rehber, '{}'::jsonb);
  -- 14 günden eski hesap: hiçbir tablo taranmaz (Gündem bu işlevi dakikada bir çağırır)
  if p.olusturma <= t - interval '14 days' then
    return jsonb_build_object('yeni', false, 'bitti', true, 'adimlar', '[]'::jsonb, 'rehber', r);
  end if;
  s := oyun.rehber_durum(p, t);
  odul := greatest(coalesce((select a.rehber_odul from oyun.ayarlar a where a.id = 1), 0), 0);
  return s || jsonb_build_object(
    'yeni', true, 'rehber', r, 'secmen_karti', (s->>'engel') is null,
    'otomatik', p.olusturma >= coalesce((select a.rehber_bas from oyun.ayarlar a where a.id = 1), '-infinity'::timestamptz),
    'katilim', p.olusturma, 'bitis', p.olusturma + interval '14 days',
    'odul', odul, 'odul_alindi', r ? 'odul', 'odul_hazir', odul > 0 and not (r ? 'odul') and (s->>'cekirdek_bitti')::boolean,
    'metinler', coalesce((select jsonb_agg(u.deger order by u.anahtar) from oyun.uygulama_ayar u
                          where u.anahtar in ('rehber_kart_1','rehber_kart_2','rehber_kart_3','rehber_kart_4')
                            and jsonb_typeof(u.deger) = 'string' and btrim(u.deger #>> '{}') <> ''), '[]'::jsonb));
end $f$;

create or replace function public.rehber_isaretle(p_anahtar text) returns jsonb
language plpgsql security definer set search_path = '' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a text := lower(btrim(coalesce(p_anahtar, ''))); r jsonb;
begin
  r := coalesce(p.rehber, '{}'::jsonb);
  if a in ('karsilama', 'kart_gizle') then
    r := r || jsonb_build_object(a, t);
  elsif a = 'kart_goster' then
    r := r - 'kart_gizle';
  elsif a = 'ipucu_sifirla' then
    r := (r - 'ipucu') - 'karsilama';
  elsif a ~ '^ipucu:[a-z_]{2,24}$' then
    a := substr(a, 7);
    if not coalesce(r->'ipucu', '[]'::jsonb) ? a then
      if jsonb_array_length(coalesce(r->'ipucu', '[]'::jsonb)) >= 40 then raise exception 'Çok fazla ipucu kaydı.'; end if;
      r := jsonb_set(r, '{ipucu}', coalesce(r->'ipucu', '[]'::jsonb) || to_jsonb(a));
    end if;
  else
    raise exception 'Geçersiz rehber işlemi.';
  end if;
  update oyun.profiller set rehber = r where id = p.id and rehber is distinct from r;
  return r;
end $f$;

create or replace function public.rehber_odul_al() returns jsonb
language plpgsql security definer set search_path = '' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s jsonb; odul numeric;
begin
  if p.olusturma <= t - interval '14 days' then raise exception 'Yeni oyuncu rehberi ödülü hesabın ilk 14 gününde alınabilir.'; end if;
  if coalesce(p.rehber, '{}'::jsonb) ? 'odul' then raise exception 'Başlangıç ödülünü zaten aldın.'; end if;
  odul := greatest(coalesce((select a.rehber_odul from oyun.ayarlar a where a.id = 1), 0), 0);
  if odul <= 0 then raise exception 'Başlangıç ödülü şu an verilmiyor.'; end if;
  s := oyun.rehber_durum(p, t);
  if not (s->>'cekirdek_bitti')::boolean then raise exception 'Önce ilk adımları tamamla (oy kullanmak hariç).'; end if;
  -- Çift ödeme kilidi: yalnız ödül kaydı yoksa güncellenir
  update oyun.profiller set rehber = coalesce(rehber, '{}'::jsonb) || jsonb_build_object('odul', t, 'odul_tutar', odul)
   where id = p.id and not (coalesce(rehber, '{}'::jsonb) ? 'odul');
  if not found then raise exception 'Başlangıç ödülünü zaten aldın.'; end if;
  perform oyun.para_islem(p.id, odul, 'rehber_odul', 'Yeni oyuncu rehberi · başlangıç ödülü', t);
  return jsonb_build_object('odul', odul, 'para', (select c.para from oyun.cuzdan c where c.user_id = p.id));
end $f$;

do $g$
declare f text;
begin
  foreach f in array array['ilk_adimlar()', 'rehber_isaretle(text)', 'rehber_odul_al()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  revoke all on function oyun.rehber_durum(oyun.profiller, timestamptz) from public, anon, authenticated;
end $g$;

-- sohbet_oku: 'yeni' alanı (kaynak: gelistirici/sql/zz_20261125_yuk_hizlandirma.sql)
create or replace function public.sohbet_oku(p_kanal text, p_once bigint DEFAULT NULL::bigint, p_sonra bigint DEFAULT NULL::bigint)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare p oyun.profiller := oyun.profilim(); k text; liste jsonb; son bigint; v_t timestamptz := oyun.simdi(); v_eng uuid[];
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  -- engellenenler bir kez okunur; saat bir kez alınır (her mesaj için ayrı sorgu yok)
  v_eng := array(select g.engellenen from oyun.engellemeler g where g.engelleyen = p.id);
  if p_sonra is null then
    -- kanalın son 40 mesajı dizinden doğrudan okunur (tüm kanal taranıp sıralanmaz)
    select coalesce(jsonb_agg(jsonb_build_object('id', x.id,
              'kad', case when x.gorevli then oyun.mod_imza(pr) else coalesce(pr.kad, '(silinmiş)') end,
              'metin', x.metin, 'zaman', x.zaman,
              'parti', case when x.gorevli then null else oyun.parti_json(pr.parti_id) end,
              'unvan', case when x.gorevli then 'Oyun Yönetimi' else oyun.unvan(x.user_id) end,
              'benim', x.user_id = p.id, 'gorevli', x.gorevli,
              'yeni', coalesce(not x.gorevli and pr.olusturma > v_t - interval '7 days', false),
              'yanit', case when x.yanit_id is not null then oyun.mesaj_alinti(p, x.yanit_id) end) order by x.id), '[]'::jsonb)
      into liste
    from (
      select * from oyun.mesajlar m
      where m.kanal = k and not m.gizli and m.zaman <= v_t and (m.gorevli or coalesce(m.user_id <> all (v_eng), true))
        and (p_once is null or m.id < p_once)
      order by m.id desc
      limit 40
    ) x left join oyun.profiller pr on pr.id = x.user_id;
  else
    select coalesce(jsonb_agg(jsonb_build_object('id', x.id,
              'kad', case when x.gorevli then oyun.mod_imza(pr) else coalesce(pr.kad, '(silinmiş)') end,
              'metin', x.metin, 'zaman', x.zaman,
              'parti', case when x.gorevli then null else oyun.parti_json(pr.parti_id) end,
              'unvan', case when x.gorevli then 'Oyun Yönetimi' else oyun.unvan(x.user_id) end,
              'benim', x.user_id = p.id, 'gorevli', x.gorevli,
              'yeni', coalesce(not x.gorevli and pr.olusturma > v_t - interval '7 days', false),
              'yanit', case when x.yanit_id is not null then oyun.mesaj_alinti(p, x.yanit_id) end) order by x.id), '[]'::jsonb)
      into liste
    from (
      select * from oyun.mesajlar m
      where m.kanal = k and not m.gizli and m.zaman <= v_t and (m.gorevli or coalesce(m.user_id <> all (v_eng), true))
        and m.id > p_sonra and (p_once is null or m.id < p_once)
      order by m.id
      limit 100
    ) x left join oyun.profiller pr on pr.id = x.user_id;
  end if;
  if p_once is null then
    select max(id) into son from oyun.mesajlar where kanal = k and not gizli and zaman <= v_t;
    if son is not null then
      insert into oyun.kanal_okuma(user_id, kanal, son_id) values (p.id, k, son)
      on conflict (user_id, kanal) do update set son_id = greatest(oyun.kanal_okuma.son_id, excluded.son_id)
        where oyun.kanal_okuma.son_id is distinct from greatest(oyun.kanal_okuma.son_id, excluded.son_id);
    end if;
  end if;
  return jsonb_build_object('kanal', p_kanal, 'mesajlar', liste, 'yazabilir', oyun.kanal_yazabilir(p, p_kanal),
    'baslik', oyun.kanal_baslik(p, p_kanal), 'sinyal', 'sohbet:' || k,
    'gorevli_yazabilir', k = 'yardim' and oyun.yardim_gorevli_mi(p), 'resmi_yazabilir', oyun.sohbet_resmi_yazabilir(p, k), 'kanal_kod', k);
end $function$;
