-- 26.11.2026 · MESAJ SAKLAMA SÜRESİ — eski sohbet ve özel mesajlar kendiliğinden silinir (sürüm 2026.11.26-4)
-- Karar (Ercan): "Mesajlar belli bir tarihten sonra silinsin" → süre 30 gün; kapsam: kanal sohbetleri
--   (Türkiye/genel, parti, il kahvesi, parti yönetimi, özel gruplar, Yardım Masası) + oyuncular arası özel mesajlar.
--   Kürsü paylaşımları ve TV yorumları SİLİNMEZ.
-- Hiçbir zaman silinmeyenler (kanıt ve kayıt):
--   • şikâyet edilmiş mesajlar (oyun.sikayetler tur 'mesaj' / 'ozel', kayit_id) — şikâyetin durumu ne olursa olsun;
--   • moderasyonun gizlediği (gizli), işaretlediği (mod_isaret) ya da yönetim adına yazılmış (gorevli) mesajlar;
--   • moderasyon içerik arşivinde kaydı olanlar (oyun.mod_icerik_arsiv.kayit_id);
--   • resmî oturum kanalları (meclis, grup, divan, kabine — tutanak niteliğinde);
--   • sabitlenmiş mesajlar (oyun.sohbet_sabit, 26.11.2026 — sabitleme kaldırılınca normal süreye döner).
-- Süre Süper Yönetici Portalı › Hesap › "Sohbet mesajı saklama süresi" ayarından değişir (7–365 gün).
-- Çalışma: her gece 04.40 (TSİ) pg_cron 'mesaj-saklama'; 5.000'lik partilerle, tur başına en çok 60 parti
--   (300 bin satır; kalan ertesi gece). Tepkiler (mesaj_tepki) de birlikte silinir. Tekrar çalıştırmak güvenlidir.
-- Alıntılanan mesaj silinmişse sohbet_oku/mesaj_alinti alıntıyı göstermez (null döner); ekran bozulmaz.

alter table oyun.ayarlar add column if not exists mesaj_saklama_gun integer not null default 30;
do $c$ begin
  alter table oyun.ayarlar add constraint ayarlar_mesaj_saklama_gun_aralik check (mesaj_saklama_gun between 7 and 365);
exception when duplicate_object then null;
end $c$;

create index if not exists mesajlar_zaman on oyun.mesajlar (zaman);
create index if not exists ozel_zaman on oyun.ozel (zaman);

insert into oyun.yp_ayar_katalog (anahtar, grup, baslik, aciklama, tur, birim, en_az, en_cok, en_uzun, risk, etki, tablo, sutun, satir, sira, aktif) values
  ('ayarlar.mesaj_saklama_gun', 'hesap', 'Sohbet mesajı saklama süresi', 'Kanal sohbetleri (Türkiye, parti, il, gruplar, Yardım Masası) ve özel mesajlar bu kadar gün sonra kalıcı silinir. Şikâyet edilen, moderasyonun gizlediği/işaretlediği mesajlar ve resmî oturum kanalları silinmez. Kürsü etkilenmez.', 'tamsayi', 'gün', 7, 365, null, 'yuksek', 'Her gece 04.40''ta; silinen geri gelmez.', 'oyun.ayarlar', 'mesaj_saklama_gun', null, 30, true)
on conflict (anahtar) do nothing;

create or replace function oyun.mesaj_saklama_temizle(p_parti integer default 5000, p_en_cok integer default 60)
returns text language plpgsql security definer set search_path = '' as $f$
declare
  gun integer := greatest(coalesce((select a.mesaj_saklama_gun from oyun.ayarlar a where a.id = 1), 30), 7);
  sinir timestamptz := now() - make_interval(days => gun);
  n integer; turlar integer := 0; kanal_sil bigint := 0; ozel_sil bigint := 0; ids bigint[];
begin
  -- Aynı anda iki temizlik çalışmasın
  if not pg_try_advisory_xact_lock(hashtext('oyun.mesaj_saklama_temizle')) then return 'zaten çalışıyor'; end if;

  -- 1) Kanal sohbetleri
  loop
    exit when turlar >= p_en_cok;
    select array_agg(m.id) into ids from (
      select m.id from oyun.mesajlar m
       where m.zaman < sinir
         and not m.gizli and not m.gorevli and coalesce(cardinality(m.mod_isaret), 0) = 0
         and split_part(m.kanal, ':', 1) not in ('meclis', 'grup', 'divan', 'kabine')
         and not exists (select 1 from oyun.sikayetler s where s.tur = 'mesaj' and s.kayit_id = m.id)
         and not exists (select 1 from oyun.sohbet_sabit sb where sb.mesaj_id = m.id)
         and not exists (select 1 from oyun.mod_icerik_arsiv a where a.kayit_id = m.id and coalesce(a.tur, '') in ('', 'mesaj', 'sohbet', 'kanal'))
       order by m.zaman
       limit p_parti) m;
    exit when ids is null;
    delete from oyun.mesaj_tepki t where t.tur = 'kanal' and t.mesaj_id = any(ids);
    delete from oyun.mesajlar m where m.id = any(ids);
    get diagnostics n = row_count;
    kanal_sil := kanal_sil + n; turlar := turlar + 1;
    exit when n < p_parti;
  end loop;

  -- 2) Özel mesajlar
  loop
    exit when turlar >= p_en_cok;
    select array_agg(o.id) into ids from (
      select o.id from oyun.ozel o
       where o.zaman < sinir and not o.gizli
         and not exists (select 1 from oyun.sikayetler s where s.tur = 'ozel' and s.kayit_id = o.id)
         and not exists (select 1 from oyun.mod_icerik_arsiv a where a.kayit_id = o.id and coalesce(a.tur, '') = 'ozel')
       order by o.zaman
       limit p_parti) o;
    exit when ids is null;
    delete from oyun.mesaj_tepki t where t.tur = 'ozel' and t.mesaj_id = any(ids);
    delete from oyun.ozel o where o.id = any(ids);
    get diagnostics n = row_count;
    ozel_sil := ozel_sil + n; turlar := turlar + 1;
    exit when n < p_parti;
  end loop;

  return format('saklama %s gün · sınır %s · silinen kanal mesajı %s · özel mesaj %s%s', gun,
    to_char(sinir at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'), kanal_sil, ozel_sil,
    case when turlar >= p_en_cok then ' · sınıra ulaşıldı, kalan ertesi gece' else '' end);
end $f$;

revoke all on function oyun.mesaj_saklama_temizle(integer, integer) from public, anon, authenticated;

do $zaman$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if not exists (select 1 from cron.job where jobname = 'mesaj-saklama') then
      -- 01:40 UTC = 04:40 Türkiye saati (en sakin saat)
      perform cron.schedule('mesaj-saklama', '40 1 * * *', 'select oyun.mesaj_saklama_temizle()');
    end if;
  end if;
exception when others then
  raise notice 'mesaj saklama zamanlanamadı: %', sqlerrm;
end $zaman$;
