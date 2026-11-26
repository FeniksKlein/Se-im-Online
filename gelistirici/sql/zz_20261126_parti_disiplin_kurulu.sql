-- 26.11.2026 · PARTİLERDE MYK + SEÇİLMİŞ DİSİPLİN KURULU (sürüm 2026.11.26-9)
--
-- İstek (Ercan): "Partilere MYK, disiplin kurulu getir. İhraç etmek çok zor; mantıklı ve adil bir çözüm bul." → "Uygula".
-- Eski sistem: genel başkan / hukuk GBY sevk eder, BÜTÜN üyeler 72 saat oy verir, ihraç için üye tamsayısının
-- çoğunluğu gerekir (379 üyeli partide 190 "evet") → pratikte imkânsız.
--
-- Gerçek dayanak: 2820 sayılı SPK — merkez disiplin kurulu en az 7 üye (m.17), kesin ihraç istemiyle sevki
-- MYK yapar, kararı disiplin kurulu verir, kesin çıkarmaya karşı mahkemeye itiraz (m.57). Milletvekilinin
-- disiplin işi ortak disiplin kurulunda görülür. Oyun temposu için süreler kısaltılmıştır (OYUN KURALI).
--
-- AKIŞ
--   1) MYK (genel başkan + genel başkan yardımcıları; parti "yönetim" sohbeti ile aynı kişiler) bir üyeyi
--      gerekçe + kanıt + ceza istemiyle önerir. MYK 24 saatte salt çoğunlukla sevk eder (tek kişilik MYK'da
--      genel başkan tek başına). İsteğe bağlı tedbir: dosya sürerken parti sohbetine yazamaz.
--   2) Savunma: 48 saat (savunma gelince hemen kurula geçer).
--   3) Kurul kararı: 72 saat. Kurul = seçilmiş Disiplin Kurulu (7 asil + 3 yedek). Kurul henüz seçilmemişse
--      ya da 5'ten az asil kaldıysa dosya için kurayla 3 asil + 2 yedek (son 3 günde aktif, MYK dışı üyeler).
--      Hedef milletvekiliyse partinin Meclis grubundan kurayla 2 vekil eklenir (ortak disiplin kurulu).
--      Toplantı yeter sayısı üyelerin 2/3'ü; geçici/kesin çıkarma için kurul TAMSAYISININ salt çoğunluğu,
--      uyarı/kınama için oy verenlerin çoğunluğu. Kurul istenenden ağır ceza veremez.
--      Süre dolunca yeter sayı yoksa oy vermeyenlerin yerine yedekler 24 saat ek süreyle girer; yine yoksa dosya düşer.
--   4) İtiraz: geçici/kesin çıkarmaya 72 saat içinde bir kez, 25.000 ₺ harçla. Heyet kurayla 3 kişi
--      (Yüksek Mahkeme üyeleri, yetmezse oyun yönetimi; o partinin üyesi olamaz; adları gizli). 72 saat.
--      İtiraz kabul edilirse ceza kalkar, ihraç edilen partiye geri döner, harç iade edilir. Heyet oy vermezse
--      karar kesinleşir ama harç iade edilir. Karar kesindir; istinaf yoktur.
--
-- ADALET KİLİTLERİ
--   • Kurultay kilidi: partinin kurultayının adaylık başlangıcından sonuçtan 1 saat sonrasına kadar yeni öneri/sevk
--     yok; tedbir ve geçici çıkarma bu sürede sohbet yasağı doğurmaz; çıkarma kararı kurultay sonrasına (+24 saat) kalır.
--   • Olağanüstü kurultay imza kampanyası açıkken kampanyayı açan ve imza verenler disipline önerilemez.
--   • Haftalık sınır: bir partide 7 günde en çok max(2, üyelerin %5'i) kesin ihraç istemli dosya.
--   • Genel başkan disipline sevk edilemez (değiştirmenin yolu kurultay). Bir üyenin aynı anda tek açık dosyası olur.
--   • Kesin ihraç: üyelik biter, 30 gün aynı partiye dönemez (başka partiye geçebilir). Milletvekilliği düşmez.
--
-- DİSİPLİN KURULU SEÇİMİ (her kurultaydan sonra kendiliğinden; ilk kez bu güncellemeyle hemen)
--   Adaylık 48 saat → oylama 24 saat. Aday: partide en az 3 gündür üye, hesabı en az 3 günlük, MYK ve il başkanı değil.
--   Her üye TEK oy verir; en çok oy alan 7 asil, sonraki 3 yedek (tek oy → azınlık da kurulda temsil edilir).
--   Aday çıkmazsa 7 gün sonra yeniden açılır.
--   Seçimlerin kendiliğinden açılması oyun.ayarlar.pdk_secim_acik ile açılır (mobil sürüm yayına girene kadar kapalı;
--   o zamana kadar dosyalar kurayla kurulan kurulda görülür).
--
-- ESKİ UYGULAMA: disiplin_baslat / disiplin_durum / disiplin_oyla korunur. Eski ekranda sevk düğmesi MYK'ya
-- görünür ve yeni akışı başlatır; "İhraç edilsin / edilmesin" düğmesi MYK üyesinde MYK oyu, kurul üyesinde kurul
-- oyu olur (evet = istenen ceza, hayır = beraat). Diğer üyelere "karar kurulun" uyarısı döner.
-- Eski sistemde açık kalan oylama eski kuralla biter.

set local check_function_bodies = off;

-- ---------------------------------------------------------------- tablolar
create table if not exists oyun.pdk_secim(
  id bigserial primary key,
  parti_id bigint not null,
  bas timestamptz not null default now(),
  aday_bit timestamptz not null,
  oy_bit timestamptz not null,
  durum text not null default 'aday' check (durum in ('aday','oy','tamam','iptal')),
  neden text,
  sonuc jsonb
);
create unique index if not exists pdk_secim_acik on oyun.pdk_secim(parti_id) where durum in ('aday','oy');
create index if not exists pdk_secim_parti on oyun.pdk_secim(parti_id, id desc);

create table if not exists oyun.pdk_aday(
  secim_id bigint not null references oyun.pdk_secim(id) on delete cascade,
  user_id uuid not null,
  tanitim text,
  zaman timestamptz not null default now(),
  primary key (secim_id, user_id)
);
create table if not exists oyun.pdk_secim_oy(
  secim_id bigint not null references oyun.pdk_secim(id) on delete cascade,
  user_id uuid not null,
  aday uuid not null,
  zaman timestamptz not null default now(),
  primary key (secim_id, user_id)
);
create table if not exists oyun.pdk_uye(
  id bigserial primary key,
  parti_id bigint not null,
  user_id uuid not null,
  tur text not null check (tur in ('asil','yedek')),
  sira int not null,
  oy int not null default 0,
  secim_id bigint,
  bas timestamptz not null default now(),
  bit timestamptz
);
create index if not exists pdk_uye_aktif on oyun.pdk_uye(parti_id, tur, sira) where bit is null;
create index if not exists pdk_uye_kisi on oyun.pdk_uye(user_id) where bit is null;

create table if not exists oyun.pdk_dosya(
  id bigserial primary key,
  parti_id bigint not null,
  hedef uuid not null,
  oneren uuid not null,
  sebep text not null,
  gerekce text not null,
  kanit text,
  istem text not null check (istem in ('uyari','kinama','gecici','kesin')),
  gecici_gun int check (gecici_gun between 3 and 14),
  tedbir boolean not null default false,
  durum text not null default 'myk' check (durum in ('myk','myk_ret','savunma','kurul','karar','itiraz','kesin','dustu')),
  bas timestamptz not null default now(),
  myk_son timestamptz,
  myk_n int not null default 1,
  sevk_at timestamptz,
  savunma_son timestamptz,
  savunma text,
  savunma_at timestamptz,
  karar_son timestamptz,
  uzatildi boolean not null default false,
  ertelendi int not null default 0,
  heyet uuid[] not null default '{}',
  yedek uuid[] not null default '{}',
  heyet_tur text,
  sonuc text check (sonuc in ('beraat','uyari','kinama','gecici','kesin')),
  sonuc_at timestamptz,
  sonuc_ozet jsonb,
  ceza_bit timestamptz,
  itiraz_son timestamptz,
  itiraz_gerekce text,
  itiraz_at timestamptz,
  itiraz_heyet uuid[] not null default '{}',
  itiraz_karar_son timestamptz,
  itiraz_sonuc text check (itiraz_sonuc in ('onay','iptal')),
  itiraz_harc numeric not null default 0,
  kapandi timestamptz
);
create index if not exists pdk_dosya_parti on oyun.pdk_dosya(parti_id, id desc);
create index if not exists pdk_dosya_hedef on oyun.pdk_dosya(hedef, id desc);
create index if not exists pdk_dosya_acik on oyun.pdk_dosya(durum) where durum in ('myk','savunma','kurul','karar','itiraz');
create unique index if not exists pdk_dosya_tek_acik on oyun.pdk_dosya(parti_id, hedef) where durum in ('myk','savunma','kurul');

create table if not exists oyun.pdk_oy(
  dosya_id bigint not null references oyun.pdk_dosya(id) on delete cascade,
  asama text not null check (asama in ('myk','kurul','itiraz')),
  user_id uuid not null,
  oy text not null,
  gerekce text,
  zaman timestamptz not null default now(),
  primary key (dosya_id, asama, user_id)
);

create table if not exists oyun.pdk_yasak(
  user_id uuid not null,
  parti_id bigint not null,
  bit timestamptz not null,
  dosya_id bigint,
  primary key (user_id, parti_id)
);

alter table oyun.pdk_secim enable row level security;
alter table oyun.pdk_aday enable row level security;
alter table oyun.pdk_secim_oy enable row level security;
alter table oyun.pdk_uye enable row level security;
alter table oyun.pdk_dosya enable row level security;
alter table oyun.pdk_oy enable row level security;
alter table oyun.pdk_yasak enable row level security;
revoke all on oyun.pdk_secim, oyun.pdk_aday, oyun.pdk_secim_oy, oyun.pdk_uye, oyun.pdk_dosya, oyun.pdk_oy, oyun.pdk_yasak
  from public, anon, authenticated;

-- ---------------------------------------------------------------- sabitler ve küçük yardımcılar
create or replace function oyun.pdk_s(k text) returns numeric language sql immutable set search_path = '' as $$
  select case k
    when 'myk_saat' then 24 when 'savunma_saat' then 48 when 'kurul_saat' then 72 when 'ek_saat' then 24
    when 'itiraz_saat' then 72 when 'itiraz_karar_saat' then 72 when 'itiraz_harc' then 25000
    when 'yasak_gun' then 30 when 'aday_saat' then 48 when 'oy_saat' then 24 when 'asil' then 7 when 'yedek' then 3
    when 'kura_asil' then 3 when 'kura_yedek' then 2 when 'kurul_alt' then 5 when 'kidem_gun' then 3
    when 'hafta_oran' then 0.05 when 'hafta_min' then 2 when 'yeniden_gun' then 7 when 'acik_dosya_sinir' then 25
  end
$$;

create or replace function oyun.pdk_seviye(s text) returns int language sql immutable set search_path = '' as $$
  select case s when 'beraat' then 0 when 'uyari' then 1 when 'kinama' then 2 when 'gecici' then 3 when 'kesin' then 4 end
$$;
create or replace function oyun.pdk_seviye_ad(l int) returns text language sql immutable set search_path = '' as $$
  select (array['beraat','uyari','kinama','gecici','kesin'])[l + 1]
$$;
create or replace function oyun.pdk_ceza_ad(s text) returns text language sql immutable set search_path = '' as $$
  select case s when 'beraat' then 'Beraat (ceza verilmedi)' when 'uyari' then 'Uyarı' when 'kinama' then 'Kınama'
    when 'gecici' then 'Geçici çıkarma' when 'kesin' then 'Kesin ihraç' else s end
$$;
create or replace function oyun.pdk_sebepler() returns jsonb language sql immutable set search_path = '' as $$
  select '[{"kod":"rakip_propaganda","ad":"Başka parti ya da aday lehine propaganda / oy çağrısı"},
           {"kod":"parti_aleyhi","ad":"Partiyi kamuoyu önünde küçük düşürme, karalama"},
           {"kod":"karar_ihlali","ad":"Parti organlarının kararlarına aykırı davranma"},
           {"kod":"mali_zarar","ad":"Parti kasasını ya da varlığını zarara uğratma"},
           {"kod":"gizlilik","ad":"Parti içi yazışma ve kararları izinsiz ifşa"},
           {"kod":"hakaret","ad":"Parti içinde ağır hakaret, tehdit, düzeni bozma"},
           {"kod":"secim_hilesi","ad":"Parti içi seçimde hile / çoklu hesap"},
           {"kod":"diger","ad":"Tüzüğe aykırı diğer davranış"}]'::jsonb
$$;
create or replace function oyun.pdk_tarih(t timestamptz) returns text language sql stable set search_path = '' as $$
  select to_char(t at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')
$$;

-- MYK: genel başkan + genel başkan yardımcıları (o partinin üyesi olarak)
create or replace function oyun.pdk_myk(p_parti bigint) returns uuid[] language sql stable set search_path = '' as $$
  select coalesce(array_agg(distinct x.u), '{}'::uuid[]) from (
    select pa.gb u from oyun.partiler pa join oyun.profiller p on p.id = pa.gb and p.parti_id = pa.id
     where pa.id = p_parti and not pa.kapali
    union
    select g.user_id from oyun.parti_gby g join oyun.profiller p on p.id = g.user_id and p.parti_id = g.parti_id
     where g.parti_id = p_parti) x
  where x.u is not null
$$;

-- Kurultay kilidi: partinin kurultayı (adaylık başından sonuçtan 1 saat sonrasına) sürüyorsa bitiş zamanı
create or replace function oyun.pdk_kilit(p_parti bigint, t timestamptz) returns timestamptz language sql stable set search_path = '' as $$
  select max(s.sonuc_at) + interval '1 hour' from oyun.secimler s
   where s.tur = 'kurultay' and (s.hedef_parti_id = p_parti or s.hedef_parti_id is null)
     and s.basvuru_bas <= t and s.sonuc_at + interval '1 hour' > t
     and s.sonuc_at > t - interval '2 days'
$$;

-- Üye askıda mı (tedbir ya da geçici çıkarma); askıdaysa bitiş zamanı. Kurultay kilidinde askı işlemez.
create or replace function oyun.pdk_askida(u uuid, p_parti bigint, t timestamptz) returns timestamptz language sql stable set search_path = '' as $$
  select case when oyun.pdk_kilit(p_parti, t) is not null then null else (
    select max(case when d.durum in ('savunma','kurul') and d.tedbir then coalesce(d.karar_son, d.savunma_son + interval '72 hours')
                    when d.sonuc = 'gecici' and d.ceza_bit > t and d.durum in ('karar','itiraz','kesin') then d.ceza_bit end)
      from oyun.pdk_dosya d
     where d.hedef = u and d.parti_id = p_parti
       and ((d.durum in ('savunma','kurul') and d.tedbir) or (d.sonuc = 'gecici' and d.ceza_bit > t))) end
$$;

-- İsteğe bağlı kısa metin (boşsa null; metin_temizle boş metinde hata verir)
create or replace function oyun.pdk_istege(p text, n int) returns text language plpgsql set search_path = 'oyun','public','pg_temp' as $$
begin
  if p is null or btrim(p) = '' then return null; end if;
  return oyun.metin_temizle(left(btrim(p), n), n);
end $$;

-- Kurul seçimlerinin kendiliğinden açılması (mobil sürüm yayına girince portaldan / SQL'den açılır)
alter table oyun.ayarlar add column if not exists pdk_secim_acik boolean not null default false;

create or replace function oyun.pdk_toplu_bildir(p_kisiler uuid[], p_metin text, t timestamptz) returns void
language sql set search_path = '' as $$
  insert into oyun.bildirimler(user_id, zaman, metin)
  select distinct x, t, p_metin from unnest(p_kisiler) x where x is not null
$$;

-- ---------------------------------------------------------------- tetikleyiciler
create or replace function oyun.pdk_mesaj_tg() returns trigger language plpgsql set search_path = 'oyun','public','pg_temp' as $$
declare b timestamptz; pid bigint;
begin
  if coalesce(new.gorevli, false) or new.kanal !~ '^parti:[0-9]{1,18}$' then return new; end if;
  if not exists (select 1 from oyun.pdk_dosya d where d.hedef = new.user_id
                   and ((d.durum in ('savunma','kurul') and d.tedbir) or (d.sonuc = 'gecici' and d.ceza_bit > now()))) then
    return new;
  end if;
  pid := substr(new.kanal, 7)::bigint;
  b := oyun.pdk_askida(new.user_id, pid, oyun.simdi());
  if b is not null then
    raise exception 'Hakkındaki parti disiplin tedbiri / geçici çıkarma cezası nedeniyle % tarihine kadar parti sohbetine yazamazsın.', oyun.pdk_tarih(b);
  end if;
  return new;
end $$;
drop trigger if exists pdk_mesaj_tg on oyun.mesajlar;
create trigger pdk_mesaj_tg before insert on oyun.mesajlar
  for each row when (new.kanal like 'parti:%') execute function oyun.pdk_mesaj_tg();

create or replace function oyun.pdk_katil_tg() returns trigger language plpgsql set search_path = 'oyun','public','pg_temp' as $$
declare b timestamptz;
begin
  select y.bit into b from oyun.pdk_yasak y where y.user_id = new.id and y.parti_id = new.parti_id and y.bit > now();
  if b is not null then
    raise exception 'Bu partiden disiplin kararıyla ihraç edildin; % tarihine kadar yeniden üye olamazsın. Başka bir partiye katılabilirsin.', oyun.pdk_tarih(b);
  end if;
  return new;
end $$;
drop trigger if exists pdk_katil_tg on oyun.profiller;
create trigger pdk_katil_tg before update of parti_id on oyun.profiller
  for each row when (new.parti_id is not null and new.parti_id is distinct from old.parti_id)
  execute function oyun.pdk_katil_tg();

-- ---------------------------------------------------------------- kurul (heyet) kurma
create or replace function oyun.pdk_heyet_kur(p_parti bigint, p_hedef uuid, p_oneren uuid, t timestamptz,
  out heyet uuid[], out yedek uuid[], out tur text)
language plpgsql set search_path = 'oyun','public','pg_temp' as $$
declare myk uuid[] := oyun.pdk_myk(p_parti); ek uuid[];
begin
  select coalesce(array_agg(k.user_id order by k.sira), '{}') into heyet
    from oyun.pdk_uye k join oyun.profiller p on p.id = k.user_id and p.parti_id = k.parti_id
   where k.parti_id = p_parti and k.bit is null and k.tur = 'asil'
     and k.user_id <> p_hedef and k.user_id <> p_oneren and not (k.user_id = any(myk));
  if cardinality(heyet) >= oyun.pdk_s('kurul_alt') then
    tur := 'kurul';
    select coalesce(array_agg(k.user_id order by k.sira), '{}') into yedek
      from oyun.pdk_uye k join oyun.profiller p on p.id = k.user_id and p.parti_id = k.parti_id
     where k.parti_id = p_parti and k.bit is null and k.tur = 'yedek'
       and k.user_id <> p_hedef and k.user_id <> p_oneren and not (k.user_id = any(myk));
  else
    tur := 'kura';
    select coalesce(array_agg(z.id), '{}') into ek from (
      select p.id from oyun.profiller p
       where p.parti_id = p_parti and p.id <> p_hedef and p.id <> p_oneren and not (p.id = any(myk))
         and not coalesce(p.yasakli, false) and coalesce(p.engel_bitis, '-infinity') <= t
         and p.son_gorulme > t - interval '3 days'
         and p.olusturma <= t - make_interval(days => oyun.pdk_s('kidem_gun')::int)
         and coalesce(p.parti_at, p.olusturma) <= t - make_interval(days => oyun.pdk_s('kidem_gun')::int)
         and oyun.pdk_askida(p.id, p_parti, t) is null
       order by random()
       limit (oyun.pdk_s('kura_asil') + oyun.pdk_s('kura_yedek'))::int) z;
    if cardinality(ek) < oyun.pdk_s('kura_asil') then
      raise exception 'Disiplin kurulu kurulamadı: partide kurayla görevlendirilecek yeterli aktif üye yok (en az % gerekir). Disiplin Kurulu seçildiğinde dosya açılabilir.', oyun.pdk_s('kura_asil');
    end if;
    heyet := ek[1:oyun.pdk_s('kura_asil')::int];
    yedek := coalesce(ek[oyun.pdk_s('kura_asil')::int + 1:], '{}');
  end if;
  -- Milletvekili hakkında: partinin Meclis grubundan kurayla 2 vekil (ortak disiplin kurulu)
  if oyun.aktif_vekil(p_hedef) then
    select coalesce(array_agg(z.id), '{}') into ek from (
      select p.id from oyun.profiller p
       where p.parti_id = p_parti and p.id <> p_hedef and p.id <> p_oneren and not (p.id = any(myk))
         and not (p.id = any(heyet)) and not (p.id = any(yedek)) and oyun.aktif_vekil(p.id)
       order by random() limit 2) z;
    heyet := heyet || ek;
  end if;
end $$;

-- ---------------------------------------------------------------- MYK aşaması
create or replace function oyun.pdk_myk_kapat(p_id bigint, t timestamptz, p_zorla boolean) returns text
language plpgsql set search_path = 'oyun','public','pg_temp' as $$
declare d oyun.pdk_dosya; myk uuid[]; ev int; hy int; salt int; h record; k timestamptz;
begin
  select * into d from oyun.pdk_dosya where id = p_id for update;
  if d.id is null or d.durum <> 'myk' then return coalesce(d.durum, 'yok'); end if;
  myk := array_remove(oyun.pdk_myk(d.parti_id), d.hedef);
  select count(*) filter (where oy = 'evet'), count(*) filter (where oy = 'hayir') into ev, hy
    from oyun.pdk_oy where dosya_id = d.id and asama = 'myk' and user_id = any(myk);
  salt := d.myk_n / 2 + 1;
  if ev >= salt then
    k := oyun.pdk_kilit(d.parti_id, t);
    if k is not null then
      update oyun.pdk_dosya set myk_son = greatest(myk_son, k + interval '24 hours') where id = d.id;
      return 'bekle';
    end if;
    if not exists (select 1 from oyun.profiller where id = d.hedef and parti_id = d.parti_id) then
      update oyun.pdk_dosya set durum = 'dustu', kapandi = t, sonuc_ozet = jsonb_build_object('neden', 'Hedef üye partiden ayrıldı.') where id = d.id;
      return 'dustu';
    end if;
    begin
      select * into h from oyun.pdk_heyet_kur(d.parti_id, d.hedef, d.oneren, t);
    exception when others then
      if not p_zorla then raise; end if;
      update oyun.pdk_dosya set durum = 'dustu', kapandi = t, sonuc_ozet = jsonb_build_object('neden', sqlerrm) where id = d.id;
      return 'dustu';
    end;
    update oyun.pdk_dosya set durum = 'savunma', sevk_at = t,
      savunma_son = t + make_interval(hours => oyun.pdk_s('savunma_saat')::int),
      heyet = h.heyet, yedek = h.yedek, heyet_tur = h.tur
     where id = d.id;
    perform oyun.bildir(d.hedef, '⚖️ ' || (select kisa from oyun.partiler where id = d.parti_id) || ' MYK seni Disiplin Kurulu''na sevk etti (istem: '
      || oyun.pdk_ceza_ad(d.istem) || '). ' || oyun.pdk_tarih(t + make_interval(hours => oyun.pdk_s('savunma_saat')::int))
      || ' tarihine kadar Parti › Disiplin Kurulu ekranından savunmanı yazabilirsin.'
      || case when d.tedbir then ' Tedbir kararı nedeniyle dosya sürerken parti sohbetine yazamazsın.' else '' end, t);
    perform oyun.pdk_toplu_bildir(h.heyet, '⚖️ Disiplin Kurulu''nda görev: ' || oyun.kad(d.hedef) || ' hakkında yeni dosya. Savunma süresinden sonra '
      || oyun.pdk_s('kurul_saat') || ' saat içinde Parti › Disiplin Kurulu ekranından oyunu kullan.', t);
    perform oyun.olay('parti', oyun.kad(d.hedef) || ' MYK kararıyla Disiplin Kurulu''na sevk edildi (istem: ' || oyun.pdk_ceza_ad(d.istem) || ').', null, d.parti_id, t);
    return 'sevk';
  end if;
  if hy > d.myk_n - salt or p_zorla then
    update oyun.pdk_dosya set durum = 'myk_ret', kapandi = t,
      sonuc_ozet = jsonb_build_object('neden', 'MYK''da salt çoğunluk sağlanmadı.', 'evet', ev, 'hayir', hy, 'myk', d.myk_n)
     where id = d.id;
    perform oyun.pdk_toplu_bildir(myk, '⚖️ ' || oyun.kad(d.hedef) || ' hakkındaki disiplin önerisi MYK''da salt çoğunluğu bulamadı ve düştü.', t);
    return 'ret';
  end if;
  return 'bekle';
end $$;

-- ---------------------------------------------------------------- kurul kararı
create or replace function oyun.pdk_kurul_sonuc(p_id bigint, t timestamptz, p_zorla boolean) returns text
language plpgsql set search_path = 'oyun','public','pg_temp' as $$
declare d oyun.pdk_dosya; n int; nisap int; salt int; verdi int; lim int; L int; c int; res text := 'beraat';
  verenler uuid[]; vermeyen uuid[]; m int; k timestamptz; pk text; myk uuid[];
begin
  select * into d from oyun.pdk_dosya where id = p_id for update;
  if d.id is null or d.durum <> 'kurul' then return coalesce(d.durum, 'yok'); end if;
  n := cardinality(d.heyet);
  nisap := ceil(2 * n / 3.0)::int;
  salt := n / 2 + 1;
  select coalesce(array_agg(user_id), '{}') into verenler from oyun.pdk_oy
   where dosya_id = d.id and asama = 'kurul' and user_id = any(d.heyet);
  verdi := cardinality(verenler);
  if not p_zorla and verdi < n then return 'bekle'; end if;

  if verdi < nisap then
    if not d.uzatildi and cardinality(d.yedek) > 0 then
      vermeyen := array(select x from unnest(d.heyet) x where not (x = any(verenler)));
      m := least(cardinality(vermeyen), cardinality(d.yedek));
      update oyun.pdk_dosya set
        heyet = verenler || d.yedek[1:m] || coalesce(vermeyen[m + 1:], '{}'),
        yedek = coalesce(d.yedek[m + 1:], '{}'),
        uzatildi = true,
        karar_son = t + make_interval(hours => oyun.pdk_s('ek_saat')::int)
       where id = d.id;
      perform oyun.pdk_toplu_bildir(d.yedek[1:m], '⚖️ Yedek Disiplin Kurulu üyesi olarak göreve çağrıldın: ' || oyun.kad(d.hedef)
        || ' dosyasında ' || oyun.pdk_s('ek_saat') || ' saat içinde Parti › Disiplin Kurulu ekranından oyunu kullan.', t);
      return 'yedek';
    end if;
    update oyun.pdk_dosya set durum = 'dustu', kapandi = t,
      sonuc_ozet = jsonb_build_object('neden', 'Kurulda toplantı yeter sayısı sağlanamadı.', 'oy_veren', verdi, 'kurul', n, 'yeter', nisap)
     where id = d.id;
    perform oyun.bildir(d.hedef, '⚖️ Hakkındaki disiplin dosyası, kurulda yeter sayı sağlanamadığı için düştü. Ceza verilmedi.', t);
    perform oyun.pdk_toplu_bildir(oyun.pdk_myk(d.parti_id), '⚖️ ' || oyun.kad(d.hedef) || ' dosyası kurulda yeter sayı sağlanamadığı için düştü.', t);
    return 'dustu';
  end if;

  lim := oyun.pdk_seviye(d.istem);
  for L in reverse lim..1 loop
    select count(*) into c from oyun.pdk_oy
     where dosya_id = d.id and asama = 'kurul' and user_id = any(d.heyet) and oyun.pdk_seviye(oy) >= L;
    if (L >= 3 and c >= salt) or (L < 3 and c >= verdi / 2 + 1) then
      res := oyun.pdk_seviye_ad(L); exit;
    end if;
  end loop;

  -- Kurultay kilidi: çıkarma kararı kurultaydan sonraya kalır
  if oyun.pdk_seviye(res) >= 3 then
    k := oyun.pdk_kilit(d.parti_id, t);
    if k is not null then
      update oyun.pdk_dosya set karar_son = k + interval '24 hours', ertelendi = ertelendi + 1 where id = d.id;
      return 'ertelendi';
    end if;
  end if;

  pk := (select kisa from oyun.partiler where id = d.parti_id);
  update oyun.pdk_dosya set
    sonuc = res, sonuc_at = t,
    sonuc_ozet = jsonb_build_object('oy_veren', verdi, 'kurul', n, 'yeter', nisap, 'salt', salt,
      'dagilim', (select jsonb_object_agg(oy, c2) from (select oy, count(*) c2 from oyun.pdk_oy
                    where dosya_id = d.id and asama = 'kurul' and user_id = any(d.heyet) group by oy) q)),
    ceza_bit = case when res = 'gecici' then t + make_interval(days => coalesce(d.gecici_gun, 7)) end,
    durum = case when res in ('gecici','kesin') then 'karar' else 'kesin' end,
    itiraz_son = case when res in ('gecici','kesin') then t + make_interval(hours => oyun.pdk_s('itiraz_saat')::int) end,
    kapandi = case when res in ('gecici','kesin') then null else t end
   where id = d.id;

  if res = 'kesin' then
    if exists (select 1 from oyun.profiller where id = d.hedef and parti_id = d.parti_id)
       and not exists (select 1 from oyun.partiler where id = d.parti_id and gb = d.hedef) then
      perform oyun._ayril(d.hedef, t);
    end if;
    insert into oyun.pdk_yasak(user_id, parti_id, bit, dosya_id)
    values (d.hedef, d.parti_id, t + make_interval(days => oyun.pdk_s('yasak_gun')::int), d.id)
    on conflict (user_id, parti_id) do update set bit = excluded.bit, dosya_id = excluded.dosya_id;
  end if;

  perform oyun.bildir(d.hedef, '⚖️ ' || pk || ' Disiplin Kurulu kararı: ' || oyun.pdk_ceza_ad(res)
    || case when res = 'gecici' then ' (' || coalesce(d.gecici_gun, 7) || ' gün; bu sürede parti sohbetine yazamazsın)' else '' end
    || case when res = 'kesin' then '. Partiden ihraç edildin; ' || oyun.pdk_s('yasak_gun') || ' gün bu partiye dönemezsin' else '' end
    || case when res in ('gecici','kesin') then '. ' || oyun.pdk_tarih(t + make_interval(hours => oyun.pdk_s('itiraz_saat')::int))
         || ' tarihine kadar bir kez itiraz edebilirsin (harç ' || oyun.tl(oyun.pdk_s('itiraz_harc')) || ', kabul edilirse iade).' else '.' end, t);
  myk := oyun.pdk_myk(d.parti_id);
  perform oyun.pdk_toplu_bildir(myk, '⚖️ Disiplin Kurulu ' || oyun.kad(d.hedef) || ' hakkında karar verdi: ' || oyun.pdk_ceza_ad(res) || '.', t);
  if res <> 'beraat' then
    perform oyun.olay('parti', pk || ' Disiplin Kurulu: ' || oyun.kad(d.hedef) || ' — ' || oyun.pdk_ceza_ad(res) || '.', null, d.parti_id, t);
  end if;
  return res;
end $$;

-- ---------------------------------------------------------------- itiraz kararı
create or replace function oyun.pdk_itiraz_sonuc(p_id bigint, t timestamptz, p_zorla boolean) returns text
language plpgsql set search_path = 'oyun','public','pg_temp' as $$
declare d oyun.pdk_dosya; n int; i int; o int; salt int; res text; iade boolean := false; pk text;
begin
  select * into d from oyun.pdk_dosya where id = p_id for update;
  if d.id is null or d.durum <> 'itiraz' then return coalesce(d.durum, 'yok'); end if;
  n := cardinality(d.itiraz_heyet);
  salt := n / 2 + 1;
  select count(*) filter (where oy = 'iptal'), count(*) filter (where oy = 'onay') into i, o
    from oyun.pdk_oy where dosya_id = d.id and asama = 'itiraz' and user_id = any(d.itiraz_heyet);
  if not p_zorla and i < salt and o < salt and i + o < n then return 'bekle'; end if;
  res := case when i > o then 'iptal' else 'onay' end;
  iade := res = 'iptal' or (i + o) = 0;
  pk := (select kisa from oyun.partiler where id = d.parti_id);
  update oyun.pdk_dosya set durum = 'kesin', itiraz_sonuc = res, kapandi = t,
    sonuc_ozet = coalesce(sonuc_ozet, '{}') || jsonb_build_object('itiraz', jsonb_build_object('iptal', i, 'onay', o, 'heyet', n, 'iade', iade)),
    ceza_bit = case when res = 'iptal' and sonuc = 'gecici' then least(ceza_bit, t) else ceza_bit end
   where id = d.id;
  if res = 'iptal' and d.sonuc = 'kesin' then
    delete from oyun.pdk_yasak where user_id = d.hedef and parti_id = d.parti_id;
    if exists (select 1 from oyun.profiller where id = d.hedef and parti_id is null)
       and exists (select 1 from oyun.partiler where id = d.parti_id and not kapali) then
      update oyun.profiller set parti_id = d.parti_id, parti_at = t where id = d.hedef;
    end if;
  end if;
  if iade and d.itiraz_harc > 0 then
    perform oyun.para_islem(d.hedef, d.itiraz_harc, 'parti_disiplin_harc_iade', pk || ' disiplin itirazı harç iadesi', t, 0);
  end if;
  perform oyun.bildir(d.hedef, '⚖️ Disiplin itirazın sonuçlandı: ' ||
    case when res = 'iptal' then 'KABUL — ' || oyun.pdk_ceza_ad(d.sonuc) || ' kararı kaldırıldı'
         || case when d.sonuc = 'kesin' then '; üyeliğin geri verildi (başka partideysen yasağın kalktı)' else '' end
      else 'RED — karar kesinleşti' || case when (i + o) = 0 then ' (heyet süresinde oy vermediği için; harcın iade edildi)' else '' end end || '.', t);
  perform oyun.pdk_toplu_bildir(oyun.pdk_myk(d.parti_id), '⚖️ ' || oyun.kad(d.hedef) || ' disiplin itirazı: '
    || case when res = 'iptal' then 'kabul edildi, karar kaldırıldı.' else 'reddedildi, karar kesinleşti.' end, t);
  if res = 'iptal' then
    perform oyun.olay('parti', pk || ': ' || oyun.kad(d.hedef) || ' hakkındaki ' || oyun.pdk_ceza_ad(d.sonuc) || ' kararı itiraz üzerine kaldırıldı.', null, d.parti_id, t);
  end if;
  return res;
end $$;

-- ---------------------------------------------------------------- Disiplin Kurulu seçimi
create or replace function oyun.pdk_aday_uygun(u uuid, p_parti bigint, t timestamptz) returns text
language sql stable set search_path = '' as $$
  select case
    when p.id is null or p.parti_id is distinct from p_parti then 'Bu partinin üyesi değilsin.'
    when u = any(oyun.pdk_myk(p_parti)) then 'Genel başkan ve genel başkan yardımcıları (MYK) Disiplin Kurulu''na aday olamaz.'
    when exists (select 1 from oyun.parti_teskilat_gorev g where g.user_id = u and g.parti_id = p_parti and g.aktif) then 'Parti il başkanları Disiplin Kurulu''na aday olamaz.'
    when p.olusturma > t - make_interval(days => oyun.pdk_s('kidem_gun')::int) then 'Aday olmak için hesabın en az ' || oyun.pdk_s('kidem_gun') || ' günlük olmalı.'
    when coalesce(p.parti_at, p.olusturma) > t - make_interval(days => oyun.pdk_s('kidem_gun')::int) then 'Aday olmak için en az ' || oyun.pdk_s('kidem_gun') || ' gündür partinin üyesi olmalısın.'
    when oyun.pdk_askida(u, p_parti, t) is not null then 'Hakkında disiplin tedbiri / cezası varken aday olamazsın.'
  end
  from (select 1) z left join oyun.profiller p on p.id = u
$$;

create or replace function oyun.pdk_secmen_uygun(u uuid, p_parti bigint, t timestamptz) returns text
language sql stable set search_path = '' as $$
  select case
    when p.id is null or p.parti_id is distinct from p_parti then 'Bu partinin üyesi değilsin.'
    when p.olusturma > t - make_interval(days => oyun.pdk_s('kidem_gun')::int) then 'Oy kullanmak için hesabın en az ' || oyun.pdk_s('kidem_gun') || ' günlük olmalı.'
    when oyun.pdk_askida(u, p_parti, t) is not null then 'Hakkında disiplin tedbiri / cezası varken oy kullanamazsın.'
  end
  from (select 1) z left join oyun.profiller p on p.id = u
$$;

create or replace function oyun.pdk_secim_ac(p_parti bigint, t timestamptz, p_neden text) returns bigint
language plpgsql set search_path = 'oyun','public','pg_temp' as $$
declare sid bigint; pk text;
begin
  insert into oyun.pdk_secim(parti_id, bas, aday_bit, oy_bit, neden)
  values (p_parti, t, t + make_interval(hours => oyun.pdk_s('aday_saat')::int),
          t + make_interval(hours => (oyun.pdk_s('aday_saat') + oyun.pdk_s('oy_saat'))::int), p_neden)
  on conflict do nothing
  returning id into sid;
  if sid is null then return null; end if;
  pk := (select kisa from oyun.partiler where id = p_parti);
  insert into oyun.bildirimler(user_id, zaman, metin)
  select p.id, t, '🗳️ ' || pk || ' Disiplin Kurulu seçimi başladı. ' || oyun.pdk_tarih(t + make_interval(hours => oyun.pdk_s('aday_saat')::int))
    || ' tarihine kadar Parti › Disiplin Kurulu ekranından aday olabilirsin; sonra ' || oyun.pdk_s('oy_saat') || ' saat oylama. Her üye tek oy verir; en çok oy alan 7 kişi asil, sonraki 3 kişi yedek üye olur.'
  from oyun.profiller p where p.parti_id = p_parti;
  perform oyun.olay('parti', pk || ' Disiplin Kurulu seçimi başladı (adaylık ' || oyun.pdk_s('aday_saat') || ' saat).', null, p_parti, t);
  return sid;
end $$;

create or replace function oyun.pdk_secim_tick(t timestamptz) returns jsonb
language plpgsql set search_path = 'oyun','public','pg_temp' as $$
declare r record; n_ac int := 0; n_oy int := 0; n_bit int := 0; pk text; secilen uuid[];
begin
  -- 1) yeni seçim: hiç seçim yapılmamış parti / kurultay sonrası / başarısız seçimden 7 gün sonra
  for r in
    select pa.id from oyun.partiler pa
     where coalesce((select a.pdk_secim_acik from oyun.ayarlar a where a.id = 1), false)
       and not pa.kapali
       and exists (select 1 from oyun.profiller p where p.parti_id = pa.id)
       and not exists (select 1 from oyun.pdk_secim s where s.parti_id = pa.id and s.durum in ('aday','oy'))
       and oyun.pdk_kilit(pa.id, t) is null
       and (
         not exists (select 1 from oyun.pdk_secim s where s.parti_id = pa.id)
         or exists (select 1 from oyun.secimler k where k.tur = 'kurultay' and k.durum = 'tamam'
                      and (k.hedef_parti_id = pa.id or k.hedef_parti_id is null)
                      and k.sonuc_at <= t and k.sonuc_at > t - interval '7 days'
                      and k.sonuc_at > (select max(s.bas) from oyun.pdk_secim s where s.parti_id = pa.id))
         or ((select count(*) from oyun.pdk_uye u join oyun.profiller p on p.id = u.user_id and p.parti_id = u.parti_id
               where u.parti_id = pa.id and u.bit is null and u.tur = 'asil') < oyun.pdk_s('kurul_alt')
             and (select max(s.bas) from oyun.pdk_secim s where s.parti_id = pa.id) < t - make_interval(days => oyun.pdk_s('yeniden_gun')::int))
       )
     order by pa.id limit 20
  loop
    begin
      if oyun.pdk_secim_ac(r.id, t, 'otomatik') is not null then n_ac := n_ac + 1; end if;
    exception when others then raise warning 'pdk_secim_ac %: %', r.id, sqlerrm;
    end;
  end loop;

  -- 2) adaylık bitti → oylama (aday yoksa iptal)
  for r in select * from oyun.pdk_secim where durum = 'aday' and aday_bit <= t order by id limit 50 loop
    begin
      pk := (select kisa from oyun.partiler where id = r.parti_id);
      delete from oyun.pdk_aday a where a.secim_id = r.id and oyun.pdk_aday_uygun(a.user_id, r.parti_id, t) is not null;
      if not exists (select 1 from oyun.pdk_aday where secim_id = r.id) then
        update oyun.pdk_secim set durum = 'iptal', sonuc = jsonb_build_object('neden', 'Aday çıkmadı') where id = r.id;
        perform oyun.olay('parti', pk || ' Disiplin Kurulu seçimine aday çıkmadı; ' || oyun.pdk_s('yeniden_gun') || ' gün sonra yeniden açılacak.', null, r.parti_id, t);
      else
        update oyun.pdk_secim set durum = 'oy', oy_bit = greatest(oy_bit, t + interval '12 hours') where id = r.id;
        insert into oyun.bildirimler(user_id, zaman, metin)
        select p.id, t, '🗳️ ' || pk || ' Disiplin Kurulu seçiminde oylama başladı (' || (select count(*) from oyun.pdk_aday where secim_id = r.id)
          || ' aday). Tek oyunu Parti › Disiplin Kurulu ekranından ver.'
        from oyun.profiller p where p.parti_id = r.parti_id;
        n_oy := n_oy + 1;
      end if;
    exception when others then raise warning 'pdk_secim_oy %: %', r.id, sqlerrm;
    end;
  end loop;

  -- 3) oylama bitti → kurul oluşur
  for r in select * from oyun.pdk_secim where durum = 'oy' and oy_bit <= t order by id limit 50 loop
    begin
      pk := (select kisa from oyun.partiler where id = r.parti_id);
      update oyun.pdk_uye set bit = t where parti_id = r.parti_id and bit is null;
      with sayim as (
        select a.user_id, a.zaman, (select count(*) from oyun.pdk_secim_oy o where o.secim_id = r.id and o.aday = a.user_id) oy
          from oyun.pdk_aday a where a.secim_id = r.id and oyun.pdk_aday_uygun(a.user_id, r.parti_id, t) is null),
      sira as (select user_id, oy, row_number() over (order by oy desc, zaman asc) s from sayim where oy > 0)
      insert into oyun.pdk_uye(parti_id, user_id, tur, sira, oy, secim_id, bas)
      select r.parti_id, user_id, case when s <= oyun.pdk_s('asil') then 'asil' else 'yedek' end, s, oy, r.id, t
        from sira where s <= oyun.pdk_s('asil') + oyun.pdk_s('yedek');
      select coalesce(array_agg(user_id), '{}') into secilen from oyun.pdk_uye where secim_id = r.id and bit is null;
      update oyun.pdk_secim set durum = 'tamam', sonuc = jsonb_build_object(
        'oy', (select count(*) from oyun.pdk_secim_oy where secim_id = r.id),
        'uyeler', (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(user_id), 'tur', tur, 'oy', oy) order by sira), '[]')
                     from oyun.pdk_uye where secim_id = r.id))
       where id = r.id;
      perform oyun.pdk_toplu_bildir(secilen, '⚖️ ' || pk || ' Disiplin Kurulu''na seçildin. Dosyalar Parti › Disiplin Kurulu ekranında; tarafsız ve gerekçeli karar ver.', t);
      perform oyun.olay('parti', pk || ' Disiplin Kurulu seçildi: ' || coalesce((select string_agg(oyun.kad(user_id), ', ' order by sira)
        from oyun.pdk_uye where secim_id = r.id and tur = 'asil'), '—') || '.', null, r.parti_id, t);
      n_bit := n_bit + 1;
    exception when others then raise warning 'pdk_secim_bit %: %', r.id, sqlerrm;
    end;
  end loop;
  return jsonb_build_object('acilan', n_ac, 'oylama', n_oy, 'biten', n_bit);
end $$;

-- ---------------------------------------------------------------- zamanlayıcı
create or replace function oyun.pdk_tick() returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare t timestamptz := oyun.simdi(); r record; s jsonb;
begin
  if not pg_try_advisory_xact_lock(77250031) then return jsonb_build_object('atlandi', true); end if;
  for r in select id from oyun.pdk_dosya where durum = 'myk' and myk_son <= t order by id limit 200 loop
    begin perform oyun.pdk_myk_kapat(r.id, t, true);
    exception when others then raise warning 'pdk myk %: %', r.id, sqlerrm; end;
  end loop;
  for r in select id, heyet, hedef from oyun.pdk_dosya where durum = 'savunma' and savunma_son <= t order by id limit 200 loop
    update oyun.pdk_dosya set durum = 'kurul', karar_son = t + make_interval(hours => oyun.pdk_s('kurul_saat')::int) where id = r.id;
    perform oyun.pdk_toplu_bildir(r.heyet, '⚖️ ' || oyun.kad(r.hedef) || ' dosyasında savunma süresi doldu; kurul oylaması açıldı (' || oyun.pdk_s('kurul_saat') || ' saat).', t);
  end loop;
  for r in select id from oyun.pdk_dosya where durum = 'kurul' and karar_son <= t order by id limit 200 loop
    begin perform oyun.pdk_kurul_sonuc(r.id, t, true);
    exception when others then raise warning 'pdk kurul %: %', r.id, sqlerrm; end;
  end loop;
  update oyun.pdk_dosya set durum = 'kesin', kapandi = t where durum = 'karar' and itiraz_son <= t;
  for r in select id from oyun.pdk_dosya where durum = 'itiraz' and itiraz_karar_son <= t order by id limit 200 loop
    begin perform oyun.pdk_itiraz_sonuc(r.id, t, true);
    exception when others then raise warning 'pdk itiraz %: %', r.id, sqlerrm; end;
  end loop;
  s := oyun.pdk_secim_tick(t);
  begin perform oyun.disiplin_sonuclandir();
  exception when others then raise warning 'eski disiplin: %', sqlerrm; end;
  return s;
end $$;

-- ---------------------------------------------------------------- dosya JSON'u (ekran için)
create or replace function oyun.pdk_dosya_json(d oyun.pdk_dosya, u uuid, t timestamptz) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', d.id, 'hedef', oyun.kad(d.hedef), 'hedef_ad', (select ad_soyad from oyun.profiller where id = d.hedef),
    'sebep', d.sebep, 'sebep_ad', (select x->>'ad' from jsonb_array_elements(oyun.pdk_sebepler()) x where x->>'kod' = d.sebep),
    'gerekce', d.gerekce, 'kanit', d.kanit, 'istem', d.istem, 'istem_ad', oyun.pdk_ceza_ad(d.istem), 'gecici_gun', d.gecici_gun,
    'tedbir', d.tedbir, 'durum', d.durum, 'bas', d.bas, 'myk_son', d.myk_son, 'myk_n', d.myk_n,
    'myk_evet', (select count(*) from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'myk' and o.oy = 'evet'),
    'myk_hayir', (select count(*) from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'myk' and o.oy = 'hayir'),
    'savunma_son', d.savunma_son, 'savunma', d.savunma, 'savunma_at', d.savunma_at,
    'karar_son', d.karar_son, 'uzatildi', d.uzatildi, 'ertelendi', d.ertelendi, 'heyet_tur', d.heyet_tur,
    'heyet_n', cardinality(d.heyet), 'yedek_n', cardinality(d.yedek),
    'kurul_oy_veren', (select count(*) from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'kurul' and o.user_id = any(d.heyet)),
    'sonuc', d.sonuc, 'sonuc_ad', oyun.pdk_ceza_ad(d.sonuc), 'sonuc_at', d.sonuc_at, 'sonuc_ozet', d.sonuc_ozet, 'ceza_bit', d.ceza_bit,
    'itiraz_son', d.itiraz_son, 'itiraz_gerekce', d.itiraz_gerekce, 'itiraz_at', d.itiraz_at,
    'itiraz_karar_son', d.itiraz_karar_son, 'itiraz_sonuc', d.itiraz_sonuc, 'itiraz_n', cardinality(d.itiraz_heyet),
    'itiraz_oy_veren', (select count(*) from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'itiraz'),
    'ben', jsonb_build_object(
      'hedef', d.hedef = u,
      'myk_oy', (select oy from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'myk' and o.user_id = u),
      'myk_oyabilir', d.durum = 'myk' and u <> d.hedef and u = any(oyun.pdk_myk(d.parti_id)),
      'heyette', u = any(d.heyet), 'yedekte', u = any(d.yedek),
      'kurul_oy', (select oy from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'kurul' and o.user_id = u),
      'kurul_oyabilir', d.durum = 'kurul' and u = any(d.heyet),
      'savunabilir', d.durum = 'savunma' and d.hedef = u,
      'itiraz_edebilir', d.durum = 'karar' and d.hedef = u and d.itiraz_son > t,
      'itiraz_heyetinde', u = any(d.itiraz_heyet),
      'itiraz_oy', (select oy from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'itiraz' and o.user_id = u),
      'itiraz_oyabilir', d.durum = 'itiraz' and u = any(d.itiraz_heyet)))
$$;

-- ---------------------------------------------------------------- RPC: ekran
create or replace function public.pdk_panel(p_parti bigint default null) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pid bigint := coalesce(p_parti, p.parti_id);
  pa oyun.partiler; myk uuid[]; sec oyun.pdk_secim; uye int; kota int; kul int;
begin
  select * into pa from oyun.partiler where id = pid;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  if p.parti_id is distinct from pid and not coalesce(p.yonetici, false) then
    raise exception 'Disiplin Kurulu ekranını yalnız partinin üyeleri görebilir.';
  end if;
  myk := oyun.pdk_myk(pid);
  select * into sec from oyun.pdk_secim where parti_id = pid order by id desc limit 1;
  select count(*) into uye from oyun.profiller where parti_id = pid;
  kota := greatest(oyun.pdk_s('hafta_min'), ceil(uye * oyun.pdk_s('hafta_oran')))::int;
  select count(*) into kul from oyun.pdk_dosya where parti_id = pid and istem = 'kesin' and bas > t - interval '7 days' and durum <> 'myk_ret';
  return jsonb_build_object(
    'parti', jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'ad', pa.ad, 'renk', pa.renk, 'uye', uye),
    'ben', jsonb_build_object('myk', p.id = any(myk), 'gb', pa.gb = p.id, 'uye', p.parti_id = pid,
       'kurul', (select tur from oyun.pdk_uye where parti_id = pid and user_id = p.id and bit is null limit 1),
       'askida', oyun.pdk_askida(p.id, pid, t)),
    'myk', (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(x), 'ad', pr.ad_soyad,
              'gorev', case when x = pa.gb then 'Genel Başkan' else coalesce(nullif(btrim(g.gorev), '') || ' ', '') || 'Genel Başkan Yardımcısı' end)
              order by (x = pa.gb) desc, g.gorev), '[]')
            from unnest(myk) x join oyun.profiller pr on pr.id = x left join oyun.parti_gby g on g.parti_id = pid and g.user_id = x),
    'kurul', (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(k.user_id), 'ad', pr.ad_soyad, 'tur', k.tur, 'sira', k.sira, 'oy', k.oy) order by k.sira), '[]')
              from oyun.pdk_uye k join oyun.profiller pr on pr.id = k.user_id and pr.parti_id = k.parti_id
             where k.parti_id = pid and k.bit is null),
    'secim', case when sec.id is null then null else jsonb_build_object(
       'id', sec.id, 'durum', sec.durum, 'bas', sec.bas, 'aday_bit', sec.aday_bit, 'oy_bit', sec.oy_bit, 'sonuc', sec.sonuc,
       'adaylar', (select coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(a.user_id), 'ad', pr.ad_soyad, 'tanitim', a.tanitim,
                     'oy', case when sec.durum = 'tamam' then (select count(*) from oyun.pdk_secim_oy o where o.secim_id = sec.id and o.aday = a.user_id) end)
                     order by a.zaman), '[]')
                   from oyun.pdk_aday a join oyun.profiller pr on pr.id = a.user_id where a.secim_id = sec.id),
       'aday_sayisi', (select count(*) from oyun.pdk_aday where secim_id = sec.id),
       'oy_sayisi', (select count(*) from oyun.pdk_secim_oy where secim_id = sec.id),
       'aday_miyim', exists (select 1 from oyun.pdk_aday where secim_id = sec.id and user_id = p.id),
       'aday_engel', case when sec.durum = 'aday' then oyun.pdk_aday_uygun(p.id, pid, t) end,
       'oyum', (select oyun.kad(o.aday) from oyun.pdk_secim_oy o where o.secim_id = sec.id and o.user_id = p.id),
       'oy_engel', case when sec.durum = 'oy' then oyun.pdk_secmen_uygun(p.id, pid, t) end) end,
    'kilit', oyun.pdk_kilit(pid, t),
    'kota', jsonb_build_object('sinir', kota, 'kullanilan', kul),
    'sebepler', oyun.pdk_sebepler(),
    'kurallar', jsonb_build_object('myk_saat', oyun.pdk_s('myk_saat'), 'savunma_saat', oyun.pdk_s('savunma_saat'),
       'kurul_saat', oyun.pdk_s('kurul_saat'), 'ek_saat', oyun.pdk_s('ek_saat'), 'itiraz_saat', oyun.pdk_s('itiraz_saat'),
       'itiraz_harc', oyun.pdk_s('itiraz_harc'), 'yasak_gun', oyun.pdk_s('yasak_gun')),
    'dosyalar', (select coalesce(jsonb_agg(oyun.pdk_dosya_json(d, p.id, t) order by d.id desc), '[]')
                 from oyun.pdk_dosya d where d.id in (select id from oyun.pdk_dosya where parti_id = pid order by id desc limit 40)),
    'zaman', t);
end $$;

-- Partisi değişse bile kişinin kendi dosyaları ve itiraz heyeti görevleri
create or replace function public.pdk_benim() returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'dosyalarim', (select coalesce(jsonb_agg(oyun.pdk_dosya_json(d, p.id, t) || jsonb_build_object('parti', (select kisa from oyun.partiler where id = d.parti_id)) order by d.id desc), '[]')
                   from oyun.pdk_dosya d where d.id in (select id from oyun.pdk_dosya where hedef = p.id and durum not in ('myk','myk_ret') order by id desc limit 10)),
    'itiraz_gorevlerim', (select coalesce(jsonb_agg(oyun.pdk_dosya_json(d, p.id, t) || jsonb_build_object('parti', (select kisa from oyun.partiler where id = d.parti_id)) order by d.id desc), '[]')
                   from oyun.pdk_dosya d where d.id in (select id from oyun.pdk_dosya where p.id = any(itiraz_heyet) and (durum = 'itiraz' or kapandi > t - interval '3 days') order by id desc limit 20)),
    'zaman', t);
end $$;

-- ---------------------------------------------------------------- RPC: MYK önerisi
create or replace function public.pdk_oner(p_hedef text, p_sebep text, p_istem text, p_gecici_gun int, p_tedbir boolean,
  p_gerekce text, p_kanit text) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pid bigint := p.parti_id; myk uuid[];
  v_hedef uuid; g text := btrim(coalesce(p_gerekce, '')); kn text := btrim(coalesce(p_kanit, '')); k timestamptz;
  did bigint; uye int; kota int; kul int; q text := btrim(coalesce(p_hedef, ''));
begin
  if pid is null then raise exception 'Bir partinin üyesi değilsin.'; end if;
  perform pg_advisory_xact_lock(hashtext('pdk_oner'), pid::int);
  myk := oyun.pdk_myk(pid);
  if not (p.id = any(myk)) then raise exception 'Disipline öneriyi yalnız MYK (genel başkan ve genel başkan yardımcıları) yapabilir.'; end if;
  k := oyun.pdk_kilit(pid, t);
  if k is not null then raise exception 'Kurultay süreci devam ediyor; % tarihine kadar disiplin önerisi yapılamaz (adalet kilidi).', oyun.pdk_tarih(k); end if;
  -- hedef: kullanıcı adı ya da ad soyad (partide tek eşleşme)
  select id into v_hedef from oyun.profiller where parti_id = pid and lower(kad) = lower(q);
  if v_hedef is null then
    if (select count(*) from oyun.profiller where parti_id = pid and lower(btrim(ad_soyad)) = lower(q)) = 1 then
      select id into v_hedef from oyun.profiller where parti_id = pid and lower(btrim(ad_soyad)) = lower(q);
    end if;
  end if;
  if v_hedef is null then raise exception 'Bu partide "%" adlı üye bulunamadı.', q; end if;
  if v_hedef = p.id then raise exception 'Kendini disipline öneremezsin.'; end if;
  if exists (select 1 from oyun.partiler where id = pid and gb = v_hedef) then
    raise exception 'Genel başkan disipline sevk edilemez; genel başkanı değiştirmenin yolu kurultaydır.';
  end if;
  if exists (select 1 from oyun.pdk_dosya where parti_id = pid and hedef = v_hedef and durum in ('myk','savunma','kurul')) then
    raise exception 'Bu üye hakkında zaten açık bir disiplin dosyası var.';
  end if;
  if exists (select 1 from oyun.sos_parti_imza s where s.parti_id = pid and s.durum = 'acik'
              and (s.acan = v_hedef or exists (select 1 from oyun.sos_parti_imzaci i where i.kampanya_id = s.id and i.user_id = v_hedef))) then
    raise exception 'Olağanüstü kurultay imza kampanyası açıkken kampanyayı açan ve imza veren üyeler disipline önerilemez.';
  end if;
  if not exists (select 1 from jsonb_array_elements(oyun.pdk_sebepler()) x where x->>'kod' = p_sebep) then raise exception 'Geçersiz disiplin sebebi.'; end if;
  if p_istem not in ('uyari','kinama','gecici','kesin') then raise exception 'Geçersiz ceza istemi.'; end if;
  if p_istem = 'gecici' and (p_gecici_gun is null or p_gecici_gun not between 3 and 14) then raise exception 'Geçici çıkarma süresi 3-14 gün olmalı.'; end if;
  if char_length(g) not between 10 and 2000 then raise exception 'Gerekçe 10-2000 karakter olmalı.'; end if;
  if char_length(kn) < 5 then raise exception 'Kanıt yazmalısın (mesaj alıntısı, paylaşım, tarih/saat ya da olay açıklaması).'; end if;
  if (select count(*) from oyun.pdk_dosya where parti_id = pid and durum in ('myk','savunma','kurul')) >= oyun.pdk_s('acik_dosya_sinir') then
    raise exception 'Partide aynı anda en çok % açık disiplin dosyası olabilir.', oyun.pdk_s('acik_dosya_sinir');
  end if;
  if p_istem = 'kesin' then
    select count(*) into uye from oyun.profiller where parti_id = pid;
    kota := greatest(oyun.pdk_s('hafta_min'), ceil(uye * oyun.pdk_s('hafta_oran')))::int;
    select count(*) into kul from oyun.pdk_dosya where parti_id = pid and istem = 'kesin' and bas > t - interval '7 days' and durum <> 'myk_ret';
    if kul >= kota then
      raise exception 'Toplu tasfiyeye karşı haftalık sınır: bu partide 7 günde en çok % kesin ihraç istemli dosya açılabilir (dolu).', kota;
    end if;
  end if;
  insert into oyun.pdk_dosya(parti_id, hedef, oneren, sebep, gerekce, kanit, istem, gecici_gun, tedbir, bas, myk_son, myk_n)
  values (pid, v_hedef, p.id, p_sebep, oyun.metin_temizle(g, 2000), oyun.metin_temizle(left(kn, 1000), 1000), p_istem,
          case when p_istem = 'gecici' then p_gecici_gun end, coalesce(p_tedbir, false), t,
          t + make_interval(hours => oyun.pdk_s('myk_saat')::int), greatest(cardinality(array_remove(myk, v_hedef)), 1))
  returning id into did;
  insert into oyun.pdk_oy(dosya_id, asama, user_id, oy, zaman) values (did, 'myk', p.id, 'evet', t);
  perform oyun.pdk_toplu_bildir(array_remove(array_remove(myk, p.id), v_hedef), '⚖️ MYK''da oylama: ' || oyun.kad(p.id) || ', ' || oyun.kad(v_hedef)
    || ' için disiplin önerdi (istem: ' || oyun.pdk_ceza_ad(p_istem) || '). ' || oyun.pdk_s('myk_saat') || ' saat içinde Parti › Disiplin Kurulu ekranından oyunu ver.', t);
  perform oyun.pdk_myk_kapat(did, t, false);
  return public.pdk_panel(pid);
end $$;

create or replace function public.pdk_myk_oy(p_dosya bigint, p_oy text) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.pdk_dosya;
begin
  if p_oy not in ('evet','hayir') then raise exception 'Geçersiz oy.'; end if;
  select * into d from oyun.pdk_dosya where id = p_dosya for update;
  if d.id is null or d.durum <> 'myk' then raise exception 'Bu dosyada MYK oylaması kapalı.'; end if;
  if d.hedef = p.id or not (p.id = any(oyun.pdk_myk(d.parti_id))) then raise exception 'Bu oylamada yalnız MYK üyeleri oy kullanabilir.'; end if;
  insert into oyun.pdk_oy(dosya_id, asama, user_id, oy, zaman) values (d.id, 'myk', p.id, p_oy, t)
  on conflict (dosya_id, asama, user_id) do update set oy = excluded.oy, zaman = excluded.zaman;
  perform oyun.pdk_myk_kapat(d.id, t, false);
  return public.pdk_panel(d.parti_id);
end $$;

create or replace function public.pdk_savunma(p_dosya bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.pdk_dosya; m text := btrim(coalesce(p_metin, ''));
begin
  select * into d from oyun.pdk_dosya where id = p_dosya for update;
  if d.id is null or d.hedef <> p.id then raise exception 'Bu dosyada savunma yapamazsın.'; end if;
  if d.durum <> 'savunma' then raise exception 'Savunma süresi kapandı.'; end if;
  if char_length(m) not between 10 and 3000 then raise exception 'Savunma 10-3000 karakter olmalı.'; end if;
  update oyun.pdk_dosya set savunma = oyun.metin_temizle(m, 3000), savunma_at = t, durum = 'kurul',
    karar_son = t + make_interval(hours => oyun.pdk_s('kurul_saat')::int) where id = d.id;
  perform oyun.pdk_toplu_bildir(d.heyet, '⚖️ ' || oyun.kad(d.hedef) || ' savunmasını verdi; kurul oylaması açıldı (' || oyun.pdk_s('kurul_saat') || ' saat).', t);
  if p.parti_id = d.parti_id then return public.pdk_panel(d.parti_id); end if;
  return public.pdk_benim();
end $$;

create or replace function public.pdk_kurul_oy(p_dosya bigint, p_oy text, p_gerekce text default null) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.pdk_dosya;
begin
  if oyun.pdk_seviye(p_oy) is null then raise exception 'Geçersiz oy.'; end if;
  select * into d from oyun.pdk_dosya where id = p_dosya for update;
  if d.id is null or d.durum <> 'kurul' then raise exception 'Bu dosyada kurul oylaması açık değil.'; end if;
  if not (p.id = any(d.heyet)) or p.parti_id is distinct from d.parti_id then raise exception 'Bu dosyada yalnız görevli kurul üyeleri oy kullanabilir.'; end if;
  if oyun.pdk_seviye(p_oy) > oyun.pdk_seviye(d.istem) then
    raise exception 'Kurul, MYK''nın istediğinden (%) ağır ceza veremez.', oyun.pdk_ceza_ad(d.istem);
  end if;
  insert into oyun.pdk_oy(dosya_id, asama, user_id, oy, gerekce, zaman)
  values (d.id, 'kurul', p.id, p_oy, oyun.pdk_istege(p_gerekce, 500), t)
  on conflict (dosya_id, asama, user_id) do update set oy = excluded.oy, gerekce = excluded.gerekce, zaman = excluded.zaman;
  perform oyun.pdk_kurul_sonuc(d.id, t, false);
  return public.pdk_panel(d.parti_id);
end $$;

create or replace function public.pdk_itiraz(p_dosya bigint, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.pdk_dosya; g text := btrim(coalesce(p_gerekce, ''));
  v_heyet uuid[]; ek uuid[]; harc numeric := oyun.pdk_s('itiraz_harc');
begin
  select * into d from oyun.pdk_dosya where id = p_dosya for update;
  if d.id is null or d.hedef <> p.id then raise exception 'Bu karara yalnız hakkında karar verilen üye itiraz edebilir.'; end if;
  if d.durum <> 'karar' or d.itiraz_son <= t then raise exception 'İtiraz süresi kapandı ya da bu karara itiraz edilemez.'; end if;
  if char_length(g) not between 20 and 2000 then raise exception 'İtiraz gerekçesi 20-2000 karakter olmalı.'; end if;
  -- Heyet: Yüksek Mahkeme üyeleri, yetmezse oyun yönetimi; o partinin üyesi olamaz
  select coalesce(array_agg(z.u), '{}') into v_heyet from (
    select m.user_id u from oyun.mahkeme_uye m join oyun.profiller pr on pr.id = m.user_id
     where m.user_id is not null and (m.gorev_bit is null or m.gorev_bit > t)
       and pr.parti_id is distinct from d.parti_id and m.user_id <> d.hedef
     order by random() limit 3) z;
  if cardinality(v_heyet) < 3 then
    select coalesce(array_agg(z.u), '{}') into ek from (
      select md.user_id u from oyun.moderatorler md join oyun.profiller pr on pr.id = md.user_id
       where pr.parti_id is distinct from d.parti_id and md.user_id <> d.hedef and not (md.user_id = any(v_heyet))
       order by random() limit 3 - cardinality(v_heyet)) z;
    v_heyet := v_heyet || ek;
  end if;
  if cardinality(v_heyet) = 0 then raise exception 'İtiraz heyeti kurulamadı; lütfen Yönetime Yaz''dan başvur.'; end if;
  perform oyun.para_islem(p.id, -harc, 'parti_disiplin_harc', (select kisa from oyun.partiler where id = d.parti_id) || ' disiplin kararına itiraz harcı', t, 0);
  update oyun.pdk_dosya set durum = 'itiraz', itiraz_gerekce = oyun.metin_temizle(g, 2000), itiraz_at = t, itiraz_heyet = v_heyet,
    itiraz_harc = harc, itiraz_karar_son = t + make_interval(hours => oyun.pdk_s('itiraz_karar_saat')::int) where id = d.id;
  perform oyun.pdk_toplu_bildir(v_heyet, '⚖️ Parti disiplin itiraz heyetine kurayla seçildin (' || (select kisa from oyun.partiler where id = d.parti_id)
    || ' · ' || oyun.kad(d.hedef) || ', ' || oyun.pdk_ceza_ad(d.sonuc) || '). ' || oyun.pdk_s('itiraz_karar_saat') || ' saat içinde Adliye › Parti Disiplin İtirazları ekranından karar ver. Adın taraflara gösterilmez.', t);
  return public.pdk_benim();
end $$;

create or replace function public.pdk_itiraz_oy(p_dosya bigint, p_oy text, p_gerekce text default null) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.pdk_dosya;
begin
  if p_oy not in ('onay','iptal') then raise exception 'Geçersiz oy.'; end if;
  select * into d from oyun.pdk_dosya where id = p_dosya for update;
  if d.id is null or d.durum <> 'itiraz' or not (p.id = any(d.itiraz_heyet)) then raise exception 'Bu itirazda oy kullanamazsın.'; end if;
  insert into oyun.pdk_oy(dosya_id, asama, user_id, oy, gerekce, zaman)
  values (d.id, 'itiraz', p.id, p_oy, oyun.pdk_istege(p_gerekce, 500), t)
  on conflict (dosya_id, asama, user_id) do update set oy = excluded.oy, gerekce = excluded.gerekce, zaman = excluded.zaman;
  perform oyun.pdk_itiraz_sonuc(d.id, t, false);
  return public.pdk_benim();
end $$;

-- ---------------------------------------------------------------- RPC: kurul seçimi
create or replace function public.pdk_aday_ol(p_tanitim text default null) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.pdk_secim; e text;
begin
  select * into s from oyun.pdk_secim where parti_id = p.parti_id and durum = 'aday' for update;
  if s.id is null then raise exception 'Partinde şu an Disiplin Kurulu adaylığı açık değil.'; end if;
  e := oyun.pdk_aday_uygun(p.id, p.parti_id, t);
  if e is not null then raise exception '%', e; end if;
  insert into oyun.pdk_aday(secim_id, user_id, tanitim, zaman)
  values (s.id, p.id, oyun.pdk_istege(p_tanitim, 400), t)
  on conflict (secim_id, user_id) do update set tanitim = excluded.tanitim;
  return public.pdk_panel(p.parti_id);
end $$;

create or replace function public.pdk_aday_cekil() returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim();
begin
  delete from oyun.pdk_aday a using oyun.pdk_secim s
   where a.secim_id = s.id and s.parti_id = p.parti_id and s.durum = 'aday' and a.user_id = p.id;
  return public.pdk_panel(p.parti_id);
end $$;

create or replace function public.pdk_secim_oy(p_aday text) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.pdk_secim; e text; a uuid;
begin
  select * into s from oyun.pdk_secim where parti_id = p.parti_id and durum = 'oy';
  if s.id is null or s.oy_bit <= t then raise exception 'Partinde şu an Disiplin Kurulu oylaması açık değil.'; end if;
  e := oyun.pdk_secmen_uygun(p.id, p.parti_id, t);
  if e is not null then raise exception '%', e; end if;
  select x.user_id into a from oyun.pdk_aday x join oyun.profiller pr on pr.id = x.user_id
   where x.secim_id = s.id and lower(pr.kad) = lower(btrim(coalesce(p_aday, '')));
  if a is null then raise exception 'Aday bulunamadı.'; end if;
  insert into oyun.pdk_secim_oy(secim_id, user_id, aday, zaman) values (s.id, p.id, a, t)
  on conflict (secim_id, user_id) do update set aday = excluded.aday, zaman = excluded.zaman;
  return public.pdk_panel(p.parti_id);
end $$;

-- ---------------------------------------------------------------- ESKİ UYGULAMA UYUMU
-- disiplin_baslat: yeni akışı başlatır (istem kesin ihraç, sebep "diğer", kanıt gerekçede)
create or replace function public.disiplin_baslat(p_hedef text, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare p oyun.profiller := oyun.profilim();
begin
  perform public.pdk_oner(p_hedef, 'diger', 'kesin', null, false, p_gerekce, 'Eski uygulamadan sevk; kanıt gerekçede yazılıdır.');
  return public.disiplin_durum(p.parti_id);
end $$;

create or replace function public.disiplin_durum(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi();
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  perform oyun.disiplin_sonuclandir();
  return jsonb_build_object(
    'gb_miyim', u = any(oyun.pdk_myk(p_parti)),
    'uye_miyim', exists (select 1 from oyun.profiller where id = u and parti_id = p_parti),
    'kayitlar', coalesce((select jsonb_agg(x.j order by x.s desc) from (
       select d.bas s, jsonb_build_object('id', -d.id, 'hedef', oyun.kad(d.hedef),
         'gerekce', '[' || case d.durum when 'myk' then 'MYK oylamasında' when 'savunma' then 'Savunma bekleniyor' when 'kurul' then 'Disiplin Kurulu''nda'
            when 'karar' then 'Karar: ' || oyun.pdk_ceza_ad(d.sonuc) || ' (itiraz süresi)' when 'itiraz' then 'İtiraz incelemesinde'
            when 'kesin' then 'Kesin karar: ' || oyun.pdk_ceza_ad(d.sonuc) when 'dustu' then 'Dosya düştü' else 'MYK reddetti' end
            || ' · istem: ' || oyun.pdk_ceza_ad(d.istem) || '] ' || d.gerekce || ' — Yeni sistem: MYK sevk eder, seçilmiş Disiplin Kurulu karar verir. Ayrıntı için uygulamayı güncelle.',
         'bas', d.bas, 'bit', coalesce(case d.durum when 'myk' then d.myk_son when 'savunma' then d.savunma_son when 'kurul' then d.karar_son
                                           when 'karar' then d.itiraz_son when 'itiraz' then d.itiraz_karar_son end, d.kapandi, d.sonuc_at, d.bas),
         'uyeler', case when d.durum = 'myk' then d.myk_n else cardinality(d.heyet) end,
         'durum', case when d.durum in ('myk','savunma','kurul','karar','itiraz') then 'oylamada' when d.sonuc = 'kesin' and coalesce(d.itiraz_sonuc, 'onay') = 'onay' then 'ihrac' else 'ret' end,
         'evet', case when d.durum = 'myk' then (select count(*) from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'myk' and o.oy = 'evet')
                      else (select count(*) from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'kurul' and oyun.pdk_seviye(o.oy) >= 3) end,
         'hayir', case when d.durum = 'myk' then (select count(*) from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'myk' and o.oy = 'hayir')
                       else (select count(*) from oyun.pdk_oy o where o.dosya_id = d.id and o.asama = 'kurul' and oyun.pdk_seviye(o.oy) < 3) end,
         'oyum', (select case when oyun.pdk_seviye(o.oy) >= 3 or o.oy = 'evet' then 'evet' else 'hayir' end from oyun.pdk_oy o
                   where o.dosya_id = d.id and o.user_id = u and o.asama = case when d.durum = 'myk' then 'myk' else 'kurul' end)) j
         from (select * from oyun.pdk_dosya where parti_id = p_parti order by id desc limit 30) d
       union all
       select d.bas, jsonb_build_object('id', d.id, 'hedef', oyun.kad(d.hedef), 'gerekce', d.gerekce, 'bas', d.bas, 'bit', d.bit, 'uyeler', d.uyeler, 'durum', d.durum,
         'evet', (select count(*) from oyun.parti_disiplin_oy o where o.id = d.id and o.oy = 'evet'),
         'hayir', (select count(*) from oyun.parti_disiplin_oy o where o.id = d.id and o.oy = 'hayir'),
         'oyum', (select oy from oyun.parti_disiplin_oy o where o.id = d.id and o.user_id = u))
         from (select * from oyun.parti_disiplin where parti_id = p_parti order by id desc limit 10) d) x), '[]'::jsonb));
end $$;

-- Negatif id = yeni sistem dosyası. MYK üyesinde MYK oyu, kurul üyesinde kurul oyu (evet = istem, hayır = beraat).
create or replace function public.disiplin_oyla(p_id bigint, p_oy text) returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare u uuid := auth.uid(); d oyun.parti_disiplin%rowtype; y oyun.pdk_dosya;
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  if p_oy not in ('evet','hayir') then raise exception 'Geçersiz oy'; end if;
  if p_id < 0 then
    select * into y from oyun.pdk_dosya where id = -p_id;
    if y.id is null then raise exception 'Dosya bulunamadı.'; end if;
    if y.durum = 'myk' and u = any(oyun.pdk_myk(y.parti_id)) and u <> y.hedef then
      perform public.pdk_myk_oy(y.id, p_oy);
    elsif y.durum = 'kurul' and u = any(y.heyet) then
      perform public.pdk_kurul_oy(y.id, case when p_oy = 'evet' then y.istem else 'beraat' end, null);
    else
      raise exception 'Bu dosyada üyeler oy kullanmaz: sevki MYK yapar, kararı seçilmiş Disiplin Kurulu verir. Savunma, aday olma ve ayrıntılar için uygulamayı güncelle.';
    end if;
    return public.disiplin_durum(y.parti_id);
  end if;
  perform oyun.disiplin_sonuclandir();
  select * into d from oyun.parti_disiplin where id = p_id for update;
  if d.id is null or d.durum <> 'oylamada' or d.bit <= now() then raise exception 'Oylama kapalı'; end if;
  if d.hedef = u or not exists (select 1 from oyun.profiller where id = u and parti_id = d.parti_id)
    then raise exception 'Yalnızca hedef dışındaki parti üyeleri oy kullanabilir'; end if;
  insert into oyun.parti_disiplin_oy(id, user_id, oy) values (p_id, u, p_oy)
  on conflict (id, user_id) do update set oy = excluded.oy, zaman = now();
  return public.disiplin_durum(d.parti_id);
end $$;

-- ---------------------------------------------------------------- izinler
revoke all on function oyun.pdk_tick(), oyun.pdk_secim_tick(timestamptz), oyun.pdk_myk_kapat(bigint, timestamptz, boolean),
  oyun.pdk_kurul_sonuc(bigint, timestamptz, boolean), oyun.pdk_itiraz_sonuc(bigint, timestamptz, boolean),
  oyun.pdk_secim_ac(bigint, timestamptz, text), oyun.pdk_heyet_kur(bigint, uuid, uuid, timestamptz),
  oyun.pdk_toplu_bildir(uuid[], text, timestamptz), oyun.pdk_dosya_json(oyun.pdk_dosya, uuid, timestamptz),
  oyun.pdk_istege(text, int), oyun.pdk_mesaj_tg(), oyun.pdk_katil_tg()
  from public, anon, authenticated;
revoke all on function public.pdk_panel(bigint), public.pdk_benim(), public.pdk_oner(text, text, text, int, boolean, text, text),
  public.pdk_myk_oy(bigint, text), public.pdk_savunma(bigint, text), public.pdk_kurul_oy(bigint, text, text),
  public.pdk_itiraz(bigint, text), public.pdk_itiraz_oy(bigint, text, text), public.pdk_aday_ol(text), public.pdk_aday_cekil(),
  public.pdk_secim_oy(text) from public, anon;
grant execute on function public.pdk_panel(bigint), public.pdk_benim(), public.pdk_oner(text, text, text, int, boolean, text, text),
  public.pdk_myk_oy(bigint, text), public.pdk_savunma(bigint, text), public.pdk_kurul_oy(bigint, text, text),
  public.pdk_itiraz(bigint, text), public.pdk_itiraz_oy(bigint, text, text), public.pdk_aday_ol(text), public.pdk_aday_cekil(),
  public.pdk_secim_oy(text), public.disiplin_baslat(text, text), public.disiplin_durum(bigint), public.disiplin_oyla(bigint, text)
  to authenticated;

do $$ begin
  if to_regnamespace('cron') is not null then
    perform cron.unschedule(jobid) from cron.job where jobname = 'parti-disiplin';
    perform cron.schedule('parti-disiplin', '*/5 * * * *', 'select oyun.pdk_tick()');
  end if;
end $$;
