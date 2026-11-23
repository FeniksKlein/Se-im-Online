-- 23.11.2026 · YÖNETİM: MEDYA VE YAYIN DENETİMİ (sürüm 2026.11.23-11)
-- İstek (Ercan): "İçerik moderatörlerinin Kürsü'nün yanında gazete ve TV'lere vs. de müdahale yetkisi olsun, tanımla."
--
-- Canlı veritabanında "kurum denetimi" çekirdeği (oyun.mkd_*, public.mod_kurum_*, public.mod_icerik_kaldir/geri_yukle,
-- oyun.mod_kurum_durdurma, oyun.mod_icerik_arsiv) kurulmuştu ama istemciye bağlanmamıştı: ekranı yoktu ve
-- yayın durdurmayı uygulayan tetikleyiciler takılmamıştı (durdurma kâğıt üstünde kalıyordu). Bu dosya onu tamamlar:
--   1. Tetikleyiciler: yayın durdurulan kurum yeni gazete yazısı, dergi sayısı, TV programı (ve canlıya geçiş),
--      kitap, dernek eylemi/bildirisi, sendika bildirisi, parti açıklaması, parti mitingi, pano reklamı ve
--      kurum adına Kürsü paylaşımı yapamaz. Zamanlayıcı (oturumsuz) işler etkilenmez.
--   2. Yeni içerik türleri: gazete köşe yorumu ve TV yorumu da kaldırılıp arşive alınabilir, geri yüklenebilir.
--   3. public.mod_medya_akis: bütün medya türlerinden son yayınlar tek akışta (tür filtresi + arama).
--   4. public.mod_medya_kaldir / mod_medya_geri_yukle: tek giriş noktası (pano reklamı dahil).
--   5. RPC yüzeyi: çekirdek fonksiyonlar 159 izin listesine de eklendi (tam kurulumda kapanmasınlar).
-- Yetki: 'sikayet' (İçerik Masası + Oyuncu Masası) ve oyun kurucusu. Şirket (yayınevi) durdurmada MASAK ('ekonomi') da yetkili.
-- Kurallar (çekirdekte): gerekçe zorunlu; sorumlu oyuncuya bildirim; yöneticinin/moderatörün kurumuna işlem yok;
-- durdurma tek imzayla en çok 3 gün, ikinci imzayla en çok 30 gün (parti her zaman iki imza, en çok 7 gün);
-- sandık açıkken tek imza geçmez; kalıcı kapatma mahkeme kararı ya da kurucuyla olur.

-- Çekirdek tablolar (canlıda var; temiz kurulum için)
create table if not exists oyun.mod_icerik_arsiv (
  id bigserial primary key, tur text not null, kayit_id bigint not null, kurum_tur text, kurum_id bigint, baslik text, sahip uuid,
  veri jsonb not null, kaldiran uuid not null, gerekce text not null, zaman timestamptz not null,
  geri_zaman timestamptz, geri_alan uuid, geri_not text
);
create unique index if not exists mod_icerik_arsiv_tek on oyun.mod_icerik_arsiv (tur, kayit_id) where geri_zaman is null and tur <> 'kurum_ad';
create index if not exists mod_icerik_arsiv_kurum on oyun.mod_icerik_arsiv (kurum_tur, kurum_id, id desc);
create table if not exists oyun.mod_kurum_durdurma (
  id bigserial primary key,
  kurum_tur text not null check (kurum_tur in ('gazete','dergi','tv','dernek','sendika','parti','sirket')),
  kurum_id bigint not null, kurum_ad text not null, sorumlular uuid[] not null default '{}'::uuid[],
  talep_zaman timestamptz not null, baslangic timestamptz, bitis timestamptz, istenen_saat numeric,
  onay text not null default 'yok' check (onay in ('yok','bekliyor','onaylandi','reddedildi')),
  veren uuid not null, veren_yonetici boolean not null default false, onaylayan uuid, onay_zaman timestamptz, onay_not text,
  birim text, gerekce text not null, kanit text, kalkis timestamptz, kaldiran uuid, kalkis_not text
);
create index if not exists mod_kurum_durdurma_kurum on oyun.mod_kurum_durdurma (kurum_tur, kurum_id) where kalkis is null;
create index if not exists mod_kurum_durdurma_veren on oyun.mod_kurum_durdurma (veren, talep_zaman desc);
create index if not exists mod_kurum_durdurma_zaman on oyun.mod_kurum_durdurma (talep_zaman desc);
alter table oyun.mod_icerik_arsiv enable row level security;
alter table oyun.mod_kurum_durdurma enable row level security;
revoke all on oyun.mod_icerik_arsiv, oyun.mod_kurum_durdurma from public, anon, authenticated;

-- Arşiv türleri yalnız genişler: köşe yorumu ve TV yorumu
alter table oyun.mod_icerik_arsiv drop constraint if exists mod_icerik_arsiv_tur_check;
alter table oyun.mod_icerik_arsiv add constraint mod_icerik_arsiv_tur_check check (tur in
  ('gazete_yazi','dergi_sayi','kitap','dernek_eylem','sendika_bildiri','parti_aciklama','kurum_ad','kose_yorum','tv_yorum'));

-- ---------------------------------------------------------------------
-- 1. Durdurmayı uygulayan tetikleyiciler
-- ---------------------------------------------------------------------
-- Planlı TV programının durdurma süresince canlıya geçmesini de engeller (yalnız oyuncu oturumuyla yapılan geçiş).
create or replace function oyun.tg_kurum_durdurma_tv_canli() returns trigger
language plpgsql set search_path to '' as $f$
declare d oyun.mod_kurum_durdurma;
begin
  if auth.uid() is null or coalesce(current_setting('oyun.mkd_sistem', true), '') = '1' then return new; end if;
  if new.durum is distinct from 'canli' or old.durum is not distinct from 'canli' then return new; end if;
  d := oyun.kurum_durdurma_aktif('tv', new.kanal_id);
  if d.id is null then return new; end if;
  raise exception '% (TV kanalı) için yayınlar oyun yönetimi kararıyla % tarihine kadar durduruldu. Gerekçe: % İtiraz için Yönetime Yaz''ı kullan.',
    d.kurum_ad, to_char(d.bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'), d.gerekce using errcode = 'P0001';
end $f$;
revoke all on function oyun.tg_kurum_durdurma_tv_canli() from public, anon, authenticated;

do $tg$
begin
  if to_regprocedure('oyun.tg_kurum_durdurma()') is null or to_regprocedure('oyun.kurum_durdurma_aktif(text,bigint)') is null then
    raise notice 'Kurum denetimi çekirdeği bu veritabanında yok; durdurma tetikleyicileri atlandı.';
    return;
  end if;
  drop trigger if exists trg_kurum_durdurma on oyun.gazete_yayinlari;
  create trigger trg_kurum_durdurma before insert on oyun.gazete_yayinlari for each row execute function oyun.tg_kurum_durdurma('gazete', 'gazete_id');
  drop trigger if exists trg_kurum_durdurma on oyun.karikatur_sayi;
  create trigger trg_kurum_durdurma before insert on oyun.karikatur_sayi for each row execute function oyun.tg_kurum_durdurma('dergi', 'dergi_id');
  drop trigger if exists trg_kurum_durdurma on oyun.tv_program;
  create trigger trg_kurum_durdurma before insert on oyun.tv_program for each row execute function oyun.tg_kurum_durdurma('tv', 'kanal_id');
  drop trigger if exists trg_kurum_durdurma_canli on oyun.tv_program;
  create trigger trg_kurum_durdurma_canli before update of durum on oyun.tv_program for each row execute function oyun.tg_kurum_durdurma_tv_canli();
  drop trigger if exists trg_kurum_durdurma on oyun.dernek_eylem;
  create trigger trg_kurum_durdurma before insert on oyun.dernek_eylem for each row execute function oyun.tg_kurum_durdurma('dernek', 'dernek_id');
  drop trigger if exists trg_kurum_durdurma on oyun.sendika_bildiri;
  create trigger trg_kurum_durdurma before insert on oyun.sendika_bildiri for each row execute function oyun.tg_kurum_durdurma('sendika', 'sendika_id');
  drop trigger if exists trg_kurum_durdurma on oyun.parti_aciklamalar;
  create trigger trg_kurum_durdurma before insert on oyun.parti_aciklamalar for each row execute function oyun.tg_kurum_durdurma('parti', 'parti_id');
  drop trigger if exists trg_kurum_durdurma on oyun.mitingler;
  create trigger trg_kurum_durdurma before insert on oyun.mitingler for each row execute function oyun.tg_kurum_durdurma();
  drop trigger if exists trg_kurum_durdurma on oyun.pano_yayin;
  create trigger trg_kurum_durdurma before insert on oyun.pano_yayin for each row execute function oyun.tg_kurum_durdurma();
  drop trigger if exists trg_kurum_durdurma on oyun.uc_kitap;
  create trigger trg_kurum_durdurma before insert or update of durum, stok on oyun.uc_kitap for each row execute function oyun.tg_kurum_durdurma();
  drop trigger if exists trg_kurum_durdurma on oyun.akis;
  create trigger trg_kurum_durdurma before insert or update of kurum_tur, kurum_id on oyun.akis for each row execute function oyun.tg_kurum_durdurma();
end
$tg$;

-- ---------------------------------------------------------------------
-- 2-4. Medya akışı, kaldırma ve geri yükleme
-- ---------------------------------------------------------------------
create or replace function oyun.mmd_tur_ad(k text) returns text
language sql immutable set search_path to '' as $f$
  select case k when 'gazete_yazi' then 'Gazete yazısı' when 'kose_yorum' then 'Gazete yorumu' when 'dergi_sayi' then 'Dergi sayısı'
    when 'kitap' then 'Kitap' when 'dernek_eylem' then 'Dernek açıklaması' when 'sendika_bildiri' then 'Sendika bildirisi'
    when 'parti_aciklama' then 'Parti açıklaması' when 'tv_yorum' then 'TV yorumu' when 'pano' then 'Pano reklamı' else k end
$f$;
revoke all on function oyun.mmd_tur_ad(text) from public, anon, authenticated;

create or replace function oyun.mmd_kaldirildi(p_tur text, p_id bigint) returns boolean
language sql stable set search_path to '' as $f$
  select exists (select 1 from oyun.mod_icerik_arsiv a where a.tur = p_tur and a.kayit_id = p_id and a.geri_zaman is null)
$f$;
revoke all on function oyun.mmd_kaldirildi(text, bigint) from public, anon, authenticated;

-- Son yayınlar. Her tür kendi birincil anahtarıyla geriye doğru sınırlı okunur (binlerce oyuncuda da hafif).
create or replace function public.mod_medya_akis(p_tur text default null, p_ara text default null) returns jsonb
language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); n int := case when nullif(p_tur, '') is null then 12 else 50 end;
  a text := nullif(btrim(coalesce(p_ara, '')), ''); q text; t timestamptz := oyun.simdi(); sinir timestamptz := oyun.simdi() - interval '14 days';
  r jsonb := '[]'::jsonb; tr text := nullif(p_tur, '');
begin
  if a is not null then q := '%' || replace(replace(left(a, 60), '%', ''), '_', '') || '%'; end if;
  if tr is not null and tr not in ('gazete_yazi','kose_yorum','dergi_sayi','kitap','dernek_eylem','sendika_bildiri','parti_aciklama','tv_yorum','pano') then
    raise exception 'İçerik türü geçersiz.';
  end if;
  if tr is null or tr = 'gazete_yazi' then
    r := r || coalesce((select jsonb_agg(x) from (select jsonb_build_object('tur', 'gazete_yazi', 'id', y.id, 'baslik', y.baslik, 'metin', left(y.metin, 600),
        'etiket', y.tur, 'yazar', oyun.kad(y.yazar), 'kurum_tur', 'gazete', 'kurum_id', g.id, 'kurum', g.ad, 'zaman', y.zaman,
        'kaldirildi', oyun.mmd_kaldirildi('gazete_yazi', y.id)) x
      from oyun.gazete_yayinlari y join oyun.oyuncu_gazeteleri g on g.id = y.gazete_id
      where y.zaman > sinir and (q is null or y.baslik ilike q or y.metin ilike q or g.ad ilike q) order by y.id desc limit n) z), '[]'::jsonb);
  end if;
  if tr is null or tr = 'kose_yorum' then
    r := r || coalesce((select jsonb_agg(x) from (select jsonb_build_object('tur', 'kose_yorum', 'id', c.id, 'baslik', 'Yorum · ' || left(y.baslik, 70), 'metin', left(c.metin, 600),
        'yazar', oyun.kad(c.user_id), 'kurum_tur', 'gazete', 'kurum_id', g.id, 'kurum', g.ad, 'zaman', c.zaman, 'kaldirildi', c.silindi) x
      from oyun.gazete_kose_yorum c join oyun.gazete_yayinlari y on y.id = c.yayin_id join oyun.oyuncu_gazeteleri g on g.id = y.gazete_id
      where c.zaman > sinir and (q is null or c.metin ilike q) order by c.id desc limit n) z), '[]'::jsonb);
  end if;
  if tr is null or tr = 'dergi_sayi' then
    r := r || coalesce((select jsonb_agg(x) from (select jsonb_build_object('tur', 'dergi_sayi', 'id', s.id, 'baslik', format('Sayı %s · %s', s.no, s.baslik),
        'metin', left((select string_agg(concat_ws(' · ', nullif(e->>'baslik', ''), nullif(e->>'sol', ''), nullif(e->>'orta', ''), nullif(e->>'sag', ''),
                 nullif(e->>'karakter1', ''), nullif(e->>'karakter2', ''), nullif(e->>'karakter3', '')), E'\n') from jsonb_array_elements(s.sayfalar) e), 600),
        'yazar', oyun.kad(d.sahip), 'kurum_tur', 'dergi', 'kurum_id', d.id, 'kurum', d.ad, 'zaman', s.yayin, 'kaldirildi', oyun.mmd_kaldirildi('dergi_sayi', s.id)) x
      from oyun.karikatur_sayi s join oyun.karikatur_dergi d on d.id = s.dergi_id
      where s.yayin > sinir and (q is null or s.baslik ilike q or d.ad ilike q or s.sayfalar::text ilike q) order by s.id desc limit n) z), '[]'::jsonb);
  end if;
  if tr is null or tr = 'kitap' then
    r := r || coalesce((select jsonb_agg(x) from (select jsonb_build_object('tur', 'kitap', 'id', k.id, 'baslik', k.baslik,
        'metin', left(coalesce(nullif(k.ozet, '') || E'\n\n', '') || coalesce(k.icerik, ''), 600), 'etiket', k.durum,
        'yazar', oyun.kad(k.yazar), 'kurum_tur', 'sirket', 'kurum_id', s.id, 'kurum', s.ad, 'zaman', coalesce(k.yayin, k.olusturma),
        'kaldirildi', oyun.mmd_kaldirildi('kitap', k.id)) x
      from oyun.uc_kitap k join oyun.sirketler s on s.id = k.yayinevi
      where k.durum in ('teklif', 'yayinda') and (q is null or k.baslik ilike q or k.ozet ilike q or k.icerik ilike q) order by k.id desc limit n) z), '[]'::jsonb);
  end if;
  if tr is null or tr = 'dernek_eylem' then
    r := r || coalesce((select jsonb_agg(x) from (select jsonb_build_object('tur', 'dernek_eylem', 'id', e.id, 'baslik', e.baslik, 'metin', left(e.metin, 600), 'etiket', e.tur,
        'yazar', oyun.kad(e.yazan), 'kurum_tur', 'dernek', 'kurum_id', d.id, 'kurum', d.ad, 'zaman', e.zaman, 'kaldirildi', e.silindi) x
      from oyun.dernek_eylem e join oyun.dernekler d on d.id = e.dernek_id
      where e.zaman > sinir and (q is null or e.baslik ilike q or e.metin ilike q or d.ad ilike q) order by e.id desc limit n) z), '[]'::jsonb);
  end if;
  if tr is null or tr = 'sendika_bildiri' then
    r := r || coalesce((select jsonb_agg(x) from (select jsonb_build_object('tur', 'sendika_bildiri', 'id', b.id, 'baslik', b.baslik, 'metin', left(b.metin, 600), 'etiket', b.tur,
        'yazar', oyun.kad(b.yazar), 'kurum_tur', 'sendika', 'kurum_id', s.id, 'kurum', s.ad, 'zaman', b.zaman, 'kaldirildi', b.silindi) x
      from oyun.sendika_bildiri b join oyun.sendika s on s.id = b.sendika_id
      where b.zaman > sinir and (q is null or b.baslik ilike q or b.metin ilike q or s.ad ilike q) order by b.id desc limit n) z), '[]'::jsonb);
  end if;
  if tr is null or tr = 'parti_aciklama' then
    r := r || coalesce((select jsonb_agg(x) from (select jsonb_build_object('tur', 'parti_aciklama', 'id', c.id, 'baslik', c.baslik, 'metin', left(c.metin, 600), 'etiket', c.rol,
        'yazar', oyun.kad(c.yazar), 'kurum_tur', 'parti', 'kurum_id', pa.id, 'kurum', pa.ad, 'zaman', c.zaman, 'kaldirildi', c.silindi) x
      from oyun.parti_aciklamalar c join oyun.partiler pa on pa.id = c.parti_id
      where c.zaman > sinir and (q is null or c.baslik ilike q or c.metin ilike q or pa.ad ilike q) order by c.id desc limit n) z), '[]'::jsonb);
  end if;
  if tr is null or tr = 'tv_yorum' then
    r := r || coalesce((select jsonb_agg(x) from (select jsonb_build_object('tur', 'tv_yorum', 'id', y.id, 'baslik', 'Yorum · ' || left(pr.baslik, 70), 'metin', left(y.metin, 600),
        'yazar', oyun.kad(y.user_id), 'kurum_tur', 'tv', 'kurum_id', k.id, 'kurum', k.ad, 'zaman', y.zaman, 'kaldirildi', coalesce(y.gizli, false)) x
      from oyun.tv_yorum y join oyun.tv_program pr on pr.id = y.program_id join oyun.tv_kanal k on k.id = pr.kanal_id
      where y.zaman > sinir and (q is null or y.metin ilike q) order by y.id desc limit n) z), '[]'::jsonb);
  end if;
  if tr is null or tr = 'pano' then
    r := r || coalesce((select jsonb_agg(x) from (select jsonb_build_object('tur', 'pano', 'id', y.id, 'baslik', coalesce(y.afis_ad, 'Afiş'),
        'metin', left((select string_agg(v, ' · ') from jsonb_each_text(case when jsonb_typeof(y.tasarim) = 'object' then y.tasarim else '{}'::jsonb end) e(k, v)
                       where char_length(v) between 1 and 300 and v !~ '^(#|rgb|https?:|data:|[0-9.]+$)'), 600),
        'etiket', case when y.kapsam = 'ulke' then 'ülke geneli' else 'il' end,
        'yazar', oyun.kad(y.odeyen), 'kurum_tur', case when y.sahip_tur = 'oyuncu' then null else y.sahip_tur end,
        'kurum_id', case when y.sahip_tur = 'oyuncu' then null else y.sahip_id end, 'kurum', y.sahip_ad, 'zaman', y.bas, 'kaldirildi', false) x
      from oyun.pano_yayin y
      where y.durum = 'aktif' and (q is null or y.afis_ad ilike q or y.sahip_ad ilike q or y.tasarim::text ilike q) order by y.id desc limit n) z), '[]'::jsonb);
  end if;
  return jsonb_build_object('liste', coalesce((select jsonb_agg(e order by (e->>'zaman')::timestamptz desc nulls last) from jsonb_array_elements(r) e), '[]'::jsonb),
    'tur', tr, 'ara', a, 'zaman', t);
end $f$;

create or replace function public.mod_medya_kaldir(p_tur text, p_id bigint, p_gerekce text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); g text := btrim(coalesce(p_gerekce, ''));
  c oyun.gazete_kose_yorum; y oyun.tv_yorum; pr oyun.tv_program; v_kt text; v_kid bigint; v_kurum text; v_baslik text; v_sahip uuid; v_id bigint; v_r jsonb;
begin
  if p_tur in ('gazete_yazi','dergi_sayi','kitap','dernek_eylem','sendika_bildiri','parti_aciklama') then
    return public.mod_icerik_kaldir(p_tur, p_id, p_gerekce);
  end if;
  if char_length(g) < 10 or char_length(g) > 300 then raise exception 'Gerekçe 10-300 karakter olmalı (içerik sahibi görür).'; end if;
  if p_tur = 'pano' then
    select odeyen into v_sahip from oyun.pano_yayin where id = p_id;
    if v_sahip is not null and v_sahip <> p.id then perform oyun.korunan_hedef_ceza(p, v_sahip); end if;
    v_r :=public.pano_kaldir(p_id, g, false);
    perform oyun.mod_log(p, 'pano_kaldir', (select oyun.kad(odeyen) from oyun.pano_yayin where id = p_id),
      format('#%s "%s" · %s', p_id, (select left(coalesce(afis_ad, 'Afiş'), 60) from oyun.pano_yayin where id = p_id), left(g, 150)));
    return v_r;
  end if;
  if oyun.mmd_kaldirildi(p_tur, p_id) then raise exception 'Bu içerik zaten kaldırılmış.'; end if;
  if p_tur = 'kose_yorum' then
    select * into c from oyun.gazete_kose_yorum where id = p_id for update;
    if c.id is null or c.silindi then raise exception 'Yorum bulunamadı ya da zaten silinmiş.'; end if;
    v_sahip := c.user_id; v_baslik := left(c.metin, 80); v_kt := 'gazete';
    select g2.id, g2.ad into v_kid, v_kurum from oyun.gazete_yayinlari y2 join oyun.oyuncu_gazeteleri g2 on g2.id = y2.gazete_id where y2.id = c.yayin_id;
  elsif p_tur = 'tv_yorum' then
    select * into y from oyun.tv_yorum where id = p_id for update;
    if y.id is null or coalesce(y.gizli, false) then raise exception 'Yorum bulunamadı ya da zaten kaldırılmış.'; end if;
    select * into pr from oyun.tv_program where id = y.program_id;
    v_sahip := y.user_id; v_baslik := left(y.metin, 80); v_kt := 'tv'; v_kid := pr.kanal_id;
    select ad into v_kurum from oyun.tv_kanal where id = pr.kanal_id;
  else
    raise exception 'İçerik türü geçersiz.';
  end if;
  if v_sahip = p.id and not coalesce(p.yonetici, false) then raise exception 'Kendi içeriğine işlem yapamazsın; başka bir görevli karar vermeli.'; end if;
  perform oyun.korunan_hedef_ceza(p, v_sahip);
  if p_tur = 'kose_yorum' then
    update oyun.gazete_kose_yorum set silindi = true where id = c.id;
  else
    update oyun.tv_yorum set gizli = true where id = y.id;
    update oyun.tv_program set ekrandaki = null where id = pr.id and ekrandaki = y.id;
  end if;
  insert into oyun.mod_icerik_arsiv(tur, kayit_id, kurum_tur, kurum_id, baslik, sahip, veri, kaldiran, gerekce, zaman)
  values (p_tur, p_id, v_kt, v_kid, v_baslik, v_sahip, jsonb_build_object('metin', coalesce(c.metin, y.metin)), p.id, g, t) returning id into v_id;
  perform oyun.bildir(v_sahip, format('%s yayından kaldırıldı (%s): "%s". Sebep: %s (%s) İtiraz için Ben › Yönetime Yaz.',
    oyun.mmd_tur_ad(p_tur), coalesce(v_kurum, ''), left(v_baslik, 60), g, oyun.mod_imza(p)), t);
  perform oyun.mod_log(p, 'icerik_kaldir', oyun.kad(v_sahip), format('#%s %s · %s · "%s" · %s', v_id, oyun.mmd_tur_ad(p_tur), coalesce(v_kurum, ''), left(v_baslik, 60), left(g, 120)));
  return jsonb_build_object('tamam', true, 'arsiv', v_id);
end $f$;

create or replace function public.mod_medya_geri_yukle(p_arsiv bigint, p_not text default null) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); a oyun.mod_icerik_arsiv;
begin
  select * into a from oyun.mod_icerik_arsiv where id = p_arsiv;
  if a.id is null then raise exception 'Arşiv kaydı bulunamadı.'; end if;
  if a.geri_zaman is null then
    if a.tur = 'kose_yorum' then update oyun.gazete_kose_yorum set silindi = false where id = a.kayit_id;
    elsif a.tur = 'tv_yorum' then update oyun.tv_yorum set gizli = false where id = a.kayit_id;
    end if;
  end if;
  -- yetki, tarafsızlık, kayıt ve bildirimler çekirdekte (hata verirse yukarıdaki geri alma da geri döner)
  return public.mod_icerik_geri_yukle(p_arsiv, p_not);
end $f$;

revoke all on function public.mod_medya_akis(text, text), public.mod_medya_kaldir(text, bigint, text), public.mod_medya_geri_yukle(bigint, text) from public, anon;
grant execute on function public.mod_medya_akis(text, text), public.mod_medya_kaldir(text, bigint, text), public.mod_medya_geri_yukle(bigint, text) to authenticated;

-- Çekirdek kurum denetimi RPC'leri istemciye açık (canlıda var olanlar; yoksa atlanır)
do $g$
declare f text;
begin
  foreach f in array array['public.mod_kurum_ara(text,text)', 'public.mod_kurum_dosya(text,bigint)', 'public.mod_kurum_durdur(text,bigint,numeric,text,text)',
    'public.mod_kurum_durdurma_kaldir(bigint,text)', 'public.mod_kurum_durdurma_karar(bigint,boolean,text)', 'public.mod_kurum_durdurmalar()',
    'public.mod_kurum_ad_duzelt(text,bigint,text,text)', 'public.mod_icerik_kaldir(text,bigint,text)', 'public.mod_icerik_geri_yukle(bigint,text)'] loop
    if to_regprocedure(f) is not null then
      execute format('revoke all on function %s from public, anon', f);
      execute format('grant execute on function %s to authenticated', f);
    end if;
  end loop;
end
$g$;
