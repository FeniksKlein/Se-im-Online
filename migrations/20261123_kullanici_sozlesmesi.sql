-- Canlı Supabase migration adı: kullanici_sozlesmesi_20261123
-- DURUM (23.11.2026 08:30): canlıda geri alınan bir işlemde denendi ve bütün denetimler geçti; kalıcı uygulama Ercan'ın onayını bekliyor.
-- Kaynak: gelistirici/sql/zz_20261123_kullanici_sozlesmesi.sql · tekrar çalıştırmak güvenlidir (yeni tablo/işlev + işaretli yama).
begin;

-- 23.11.2026 · Kullanıcı Sözleşmesi onay kaydı (Sürüm 1.0)
-- İstek (Ercan): bundan sonra kayıt olan herkes Kullanıcı Sözleşmesi'ni görsün; kabul eden kayıt olabilsin, etmeyen olamasın.
-- Mevcut oyunculardan (profili olanlar) onay istenmez (Ercan'ın kararı).
--   · İstemci (gelistirici/www/kullanici_sozlesmesi.js): "Hesap oluştur"dan önce tam metin + iki zorunlu kutu
--     (sözleşme, 18 yaş). Kabul cihazda ve signUp hesap bilgisinde tutulur, oturum açılınca buraya yazılır.
--   · Kayıt: oyun_yonetim.sozlesme_onaylari — kullanıcı, sürüm, kaynak (kayit | giris), sunucu saati, istemci saati,
--     uygulama sürümü, IP özeti (oyun.ozet: tuzlanmış SHA-256; ham IP saklanmaz). Hesap silinse de satır kalır:
--     sözleşmenin kurulduğunun delilidir (KVKK m.5/2-c, e). Oyunculara açık değildir.
--   · Sunucu kapısı (/* sozlesme_kapi */): kayit_basvuru_gonder ve profil_olustur kabul kaydı olmayan hesabı reddeder;
--     ANCAK yalnız en düşük uygulama sürümü (oyun.ayarlar.min_uygulama) sözleşme ekranını içeren ilk sürüme
--     (2026.11.23-4) ya da üstüne çıkarıldığında. Böylece mağazadaki eski uygulamalarla kayıt kesilmez; yeni mağaza
--     sürümü yayına girip yönetici panelinden en düşük sürüm yükseltilince kapı kendiliğinden kapanır.
--     Web istemcisi sözleşmeyi hemen zorunlu tutar.
--   · Metin değişirse oyun.sozlesme_surumu() ve istemcideki SOZLESME.surum birlikte artırılır; yeni sürüm yeni
--     kayıtlarda yeniden onay ister (eski onaylar silinmez).
-- Yama yardımcısı oyun._yama (zz_20261121_00_yama.sql) bu dosyadan önce gelmelidir.

create table if not exists oyun_yonetim.sozlesme_onaylari (
  id bigserial primary key,
  user_id uuid not null,
  surum text not null,
  kaynak text not null default 'kayit',
  onay_at timestamptz not null default clock_timestamp(),
  istemci_at timestamptz,
  uygulama text,
  ip_ozet text,
  constraint sozlesme_onaylari_kaynak_ck check (kaynak in ('kayit', 'giris')),
  constraint sozlesme_onaylari_tek unique (user_id, surum)
);
create index if not exists sozlesme_onaylari_zaman_ix on oyun_yonetim.sozlesme_onaylari(onay_at desc);
alter table oyun_yonetim.sozlesme_onaylari enable row level security;
revoke all on oyun_yonetim.sozlesme_onaylari from public, anon, authenticated;
revoke all on sequence oyun_yonetim.sozlesme_onaylari_id_seq from public, anon, authenticated;

-- Güncel sözleşme sürümü (istemcideki SOZLESME.surum ile aynı olmalı)
create or replace function oyun.sozlesme_surumu() returns text
language sql immutable set search_path to '' as $f$ select '1.0'::text $f$;

-- "2026.11.23-4" → {2026,11,23,4}; sayısal karşılaştırma için (istemcideki surumKucuk ile aynı mantık)
create or replace function oyun.surum_dizi(p text) returns integer[]
language sql immutable set search_path to '' as $f$
  select coalesce(array_agg(x::integer order by o), '{}'::integer[])
    from unnest(regexp_split_to_array(coalesce(p, ''), '[^0-9]+')) with ordinality as t(x, o)
   where x <> '' and length(x) <= 9
$f$;

-- Sunucu kapısı ne zaman kapanır: en düşük uygulama sürümü sözleşme ekranlı sürüme ulaşınca
create or replace function oyun.sozlesme_zorunlu() returns boolean
language sql stable set search_path to '' as $f$
  select coalesce(oyun.surum_dizi((select a.min_uygulama from oyun.ayarlar a where a.id = 1))
                  >= oyun.surum_dizi('2026.11.23-4'), false)
$f$;

create or replace function oyun.sozlesme_kabul(u uuid) returns boolean
language sql stable set search_path to '' as $f$
  select exists (select 1 from oyun_yonetim.sozlesme_onaylari s where s.user_id = u and s.surum = oyun.sozlesme_surumu())
$f$;

revoke all on function oyun.sozlesme_surumu() from public;
revoke all on function oyun.surum_dizi(text) from public;
revoke all on function oyun.sozlesme_zorunlu() from public;
revoke all on function oyun.sozlesme_kabul(uuid) from public;

-- Oyuncunun kendi onay durumu (kayıt onayı beklerken de çağrılabilir; oyun.ben() kullanmaz)
create or replace function public.sozlesme_durumum() returns jsonb
language plpgsql stable security definer set search_path to '' as $f$
declare u uuid := auth.uid(); s oyun_yonetim.sozlesme_onaylari;
begin
  if u is null then raise exception 'Önce giriş yap.'; end if;
  select * into s from oyun_yonetim.sozlesme_onaylari where user_id = u and surum = oyun.sozlesme_surumu();
  return jsonb_build_object('surum', oyun.sozlesme_surumu(), 'kabul', s.id is not null, 'onay_at', s.onay_at,
                            'zorunlu', oyun.sozlesme_zorunlu());
end $f$;

-- Onayı kaydet. Tekrar çağrılırsa ilk kayıt korunur (idempotent); sürüm uyuşmazsa reddeder.
create or replace function public.sozlesme_onayla(p_surum text, p_kaynak text default 'kayit',
                                                  p_istemci_at timestamptz default null, p_uygulama text default null)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare u uuid := auth.uid(); s oyun_yonetim.sozlesme_onaylari; t timestamptz := clock_timestamp();
begin
  if u is null then raise exception 'Önce giriş yap.'; end if;
  if coalesce(btrim(p_surum), '') <> oyun.sozlesme_surumu() then
    raise exception 'Kullanıcı Sözleşmesi güncellendi. Uygulamayı yenileyip güncel metni onayla.';
  end if;
  insert into oyun_yonetim.sozlesme_onaylari(user_id, surum, kaynak, onay_at, istemci_at, uygulama, ip_ozet)
  values (u, oyun.sozlesme_surumu(),
          case when p_kaynak = 'giris' then 'giris' else 'kayit' end, t,
          case when p_istemci_at between t - interval '30 days' and t + interval '1 hour' then p_istemci_at end,
          nullif(left(btrim(coalesce(p_uygulama, '')), 40), ''),
          oyun.ozet(oyun.istek_ip()))
  on conflict (user_id, surum) do nothing;
  select * into s from oyun_yonetim.sozlesme_onaylari where user_id = u and surum = oyun.sozlesme_surumu();
  return jsonb_build_object('surum', s.surum, 'kabul', true, 'onay_at', s.onay_at);
end $f$;

revoke all on function public.sozlesme_durumum() from public, anon;
grant execute on function public.sozlesme_durumum() to authenticated;
revoke all on function public.sozlesme_onayla(text, text, timestamptz, text) from public, anon;
grant execute on function public.sozlesme_onayla(text, text, timestamptz, text) to authenticated;

-- Sunucu kapısı: başvuru ve doğrudan profil oluşturma
select oyun._yama('public.kayit_basvuru_gonder(text,integer,text)',
  $d$if u is null then raise exception 'Önce giriş yap.'; end if;$d$,
  $y$if u is null then raise exception 'Önce giriş yap.'; end if;
  /* sozlesme_kapi */ if oyun.sozlesme_zorunlu() and not oyun.sozlesme_kabul(u) then raise exception 'Kayıt için Kullanıcı Sözleşmesi''ni kabul etmen gerekiyor. Uygulamayı güncelleyip yeniden dene.'; end if;$y$,
  '/* sozlesme_kapi */', true);

select oyun._yama('public.profil_olustur(text,integer)',
  $d$raise exception 'Profilin zaten var.'; end if;$d$,
  $y$raise exception 'Profilin zaten var.'; end if;
  /* sozlesme_kapi */ if oyun.sozlesme_zorunlu() and not oyun.sozlesme_kabul(u) then raise exception 'Kayıt için Kullanıcı Sözleşmesi''ni kabul etmen gerekiyor. Uygulamayı güncelleyip yeniden dene.'; end if;$y$,
  '/* sozlesme_kapi */', true);

commit;
