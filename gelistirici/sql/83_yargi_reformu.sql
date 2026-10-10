-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 83) YARGI REFORMU
--  1. Yüksek Mahkeme 3 üyelidir: 1. üye (mahkeme başkanı) Cumhurbaşkanınca atanır, 2. ve 3. üyeyi Meclis seçer.
--     Kararlar oy çokluğuyla (3 üyede 2 oy) verilir. Koltuk dolu değilse görevdeki üyelerin çoğunluğu yeter.
--  2. Bağımsızlık: yargıç partisiz olmalı, seçilmiş/atanmış makamı olmamalı; görev süresi 30 gün, bu sürede
--     yalnız Meclis'in 3/5 oyuyla görevden alınır. Görevdeyken partiye giremez, aday olamaz, makam alamaz.
--  3. Süre: savunma süresi bitince mahkemenin 72 saati vardır; karar çıkmazsa dava düşer (harç iade).
--  4. İstinaf: kaybeden taraf 24 saat içinde bir kez itiraz eder; davayla ilgisi olmayan partilerden kurayla
--     seçilen 3 milletvekili (yetmezse aktif oyuncu) 48 saatte "onayla / boz" der.
--     Ağır cezalar (para, adaylık yasağı, vekilliğin düşmesi, parti cezası) karar KESİNLEŞİNCE uygulanır.
--  5. Dava harcı: davacı peşin öder; kazanırsa geri alır ve harcı davalı öder; kaybederse harç hazineye kalır.
--  6. Kararlar Akış'a #Adliye etiketiyle düşer (beğen/beğenme ile tartışılır) ve Gündem'e yazılır.
--  7. Yeni cezalar: 10.000 / 50.000 ₺ para cezası, 30 gün adaylık yasağı; partiye 25.000 ₺ hazine yardımı kesintisi.
--  8. Anayasa Mahkemesi: Meclis'te grubu (vekili) olan bir partinin genel başkanı, son 10 günde yürürlüğe giren
--     bir kanunu iptal için başvurabilir; mahkeme iptal ederse kanunun etkisi geri alınır.
--  Yalnız ekler; eski kararlar kesinleşmiş sayılır.
-- =====================================================================

-- ---------- Ayarlar ----------
create table if not exists oyun.mahkeme_ayar(
  id boolean primary key default true check (id),
  gorev_gun int not null default 30,
  karar_saat int not null default 72,
  istinaf_saat int not null default 24,
  juri_saat int not null default 48,
  harc numeric not null default 5000,
  aym_gun int not null default 10
);
insert into oyun.mahkeme_ayar(id) values (true) on conflict do nothing;

-- ---------- Üyeler ----------
create table if not exists oyun.mahkeme_uye(
  sira      smallint primary key check (sira between 1 and 3),
  user_id   uuid references oyun.profiller(id),
  kaynak    text not null check (kaynak in ('cb','meclis')),
  atayan    uuid,
  bas       timestamptz,
  gorev_bit timestamptz,
  bos_since timestamptz default now()
);
insert into oyun.mahkeme_uye(sira, kaynak) values (1,'cb'),(2,'meclis'),(3,'meclis') on conflict do nothing;
-- Görevdeki eski Yüksek Yargıç 1. üye (mahkeme başkanı) olur
update oyun.mahkeme_uye u set user_id = m.hakim, atayan = m.atayan, bas = coalesce(m.atama_at, now()),
       gorev_bit = coalesce(m.atama_at, now()) + make_interval(days => (select gorev_gun from oyun.mahkeme_ayar)), bos_since = null
  from oyun.adliye_makam m where u.sira = 1 and u.user_id is null and m.id = 1 and m.hakim is not null;

create table if not exists oyun.mahkeme_meclis_oy(
  sira  smallint not null check (sira in (2,3)),
  vekil uuid not null,
  aday  uuid not null,
  zaman timestamptz not null default now(),
  primary key (sira, vekil)
);
create table if not exists oyun.mahkeme_azil(
  id          bigserial primary key,
  sira        smallint not null,
  uye         uuid not null,
  teklif_eden uuid not null,
  gerekce     text not null check (char_length(gerekce) between 20 and 1000),
  bas         timestamptz not null,
  bit         timestamptz not null,
  durum       text not null default 'acik' check (durum in ('acik','kabul','ret'))
);
create unique index if not exists mahkeme_azil_tek on oyun.mahkeme_azil(uye) where durum = 'acik';
create table if not exists oyun.mahkeme_azil_oy(
  azil_id bigint not null references oyun.mahkeme_azil(id) on delete cascade,
  vekil   uuid not null,
  oy      text not null check (oy in ('kabul','ret')),
  zaman   timestamptz not null default now(),
  primary key (azil_id, vekil)
);

-- ---------- Davalar: yeni alanlar ----------
alter table oyun.adliye_davalar add column if not exists kesin boolean not null default true;
alter table oyun.adliye_davalar add column if not exists karar_son timestamptz;
alter table oyun.adliye_davalar add column if not exists istinaf_son timestamptz;
alter table oyun.adliye_davalar add column if not exists harc numeric not null default 0;
alter table oyun.adliye_davalar add column if not exists harc_durum text;
alter table oyun.adliye_davalar add column if not exists ceza_uygulandi boolean not null default false;
alter table oyun.adliye_davalar add column if not exists ilk_karar text;
alter table oyun.adliye_davalar drop constraint if exists adliye_davalar_karar_check;
alter table oyun.adliye_davalar add constraint adliye_davalar_karar_check check (karar in
  ('beraat','uyari','sustur_1s','sustur_1g','sustur_1h','vekillik_dusur','para_10b','para_50b','aday_yasagi','parti_para','dusme'));
alter table oyun.profiller add column if not exists adaylik_yasagi_bitis timestamptz;

create table if not exists oyun.adliye_karar_oy(
  dava_id bigint not null references oyun.adliye_davalar(id) on delete cascade,
  uye     uuid not null,
  karar   text not null,
  gerekce text not null,
  zaman   timestamptz not null default now(),
  primary key (dava_id, uye)
);
create table if not exists oyun.adliye_istinaf(
  dava_id   bigint primary key references oyun.adliye_davalar(id) on delete cascade,
  basvuran  uuid not null,
  gerekce   text not null check (char_length(gerekce) between 20 and 1500),
  bas       timestamptz not null,
  bit       timestamptz not null,
  durum     text not null default 'acik' check (durum in ('acik','onaylandi','bozuldu'))
);
create table if not exists oyun.adliye_juri(
  dava_id bigint not null references oyun.adliye_istinaf(dava_id) on delete cascade,
  user_id uuid not null,
  oy      text check (oy in ('onay','boz')),
  gerekce text,
  zaman   timestamptz,
  primary key (dava_id, user_id)
);

-- ---------- Anayasa Mahkemesi ----------
alter table oyun.kanunlar drop constraint if exists kanunlar_durum_check;
alter table oyun.kanunlar add constraint kanunlar_durum_check
  check (durum in ('gorusmede','oylamada','cb_onayinda','israr','yururlukte','ret','dustu','kaduk','geri_cekildi','halkoylamasinda','aym_iptal'));
create table if not exists oyun.aym_basvuru(
  id        bigserial primary key,
  kanun_id  bigint not null references oyun.kanunlar(id),
  parti_id  bigint not null references oyun.partiler(id),
  basvuran  uuid not null,
  gerekce   text not null check (char_length(gerekce) between 30 and 2000),
  gorus     text,
  gorus_veren uuid,
  bas       timestamptz not null,
  karar_son timestamptz not null,
  durum     text not null default 'acik' check (durum in ('acik','iptal','ret','dustu')),
  karar_gerekce text,
  karar_at  timestamptz,
  hakim     uuid
);
create unique index if not exists aym_tek_acik on oyun.aym_basvuru(kanun_id) where durum = 'acik';
create table if not exists oyun.aym_oy(
  basvuru_id bigint not null references oyun.aym_basvuru(id) on delete cascade,
  uye     uuid not null,
  karar   text not null check (karar in ('iptal','ret')),
  gerekce text not null,
  zaman   timestamptz not null default now(),
  primary key (basvuru_id, uye)
);

do $$ declare t text; begin
  foreach t in array array['mahkeme_ayar','mahkeme_uye','mahkeme_meclis_oy','mahkeme_azil','mahkeme_azil_oy','adliye_karar_oy','adliye_istinaf','adliye_juri','aym_basvuru','aym_oy'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
end $$;

-- =====================================================================
--  Yardımcılar
-- =====================================================================
create or replace function oyun.mahkeme_uyesi_mi(u uuid) returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.mahkeme_uye where user_id = u)
$$;
create or replace function oyun.mahkeme_uyeleri() returns uuid[] language sql stable set search_path = '' as $$
  select coalesce(array_agg(user_id order by sira), '{}') from oyun.mahkeme_uye where user_id is not null
$$;
-- Bir davada oy verebilecek üyeler (taraf olanlar hariç)
create or replace function oyun.dava_heyeti(d oyun.adliye_davalar) returns uuid[] language sql stable set search_path = '' as $$
  select coalesce(array_agg(user_id order by sira), '{}') from oyun.mahkeme_uye
   where user_id is not null and user_id is distinct from d.davaci and user_id is distinct from d.davali
$$;
create or replace function oyun.cogunluk(n int) returns int language sql immutable as $$ select greatest(1, n / 2 + 1) $$;

-- Yargıç adayı uygun mu?
create or replace function oyun.yargic_uygunluk(u uuid) returns text language sql stable set search_path = '' as $$
  select case
    when not exists (select 1 from oyun.profiller where id = u and not yasakli) then 'Oyuncu bulunamadı.'
    when exists (select 1 from oyun.profiller where id = u and parti_id is not null) then 'Yargıç adayı bir partiye üye olmamalı; önce partisinden ayrılmalı.'
    when exists (select 1 from oyun.makamlar where user_id = u and bit is null) then 'Yargıç adayı başka bir makamda görevli olmamalı.'
    when exists (select 1 from oyun.mahkeme_uye where user_id = u) then 'Bu oyuncu zaten Yüksek Mahkeme üyesi.'
    else null end
$$;

-- Üyeyi koltuğa oturt / koltuktan indir (eski adliye_makam.hakim alanı 1. üyeyi gösterir)
create or replace function oyun.mahkeme_oturt(p_sira smallint, u uuid, p_atayan uuid, t timestamptz) returns void language plpgsql set search_path = '' as $$
begin
  update oyun.mahkeme_uye set user_id = u, atayan = p_atayan, bas = t,
         gorev_bit = t + make_interval(days => (select gorev_gun from oyun.mahkeme_ayar)), bos_since = null where sira = p_sira;
  if p_sira = 1 then update oyun.adliye_makam set hakim = u, atayan = p_atayan, atama_at = t, degistirme_at = t where id = 1; end if;
  delete from oyun.mahkeme_meclis_oy where sira = p_sira;
  insert into oyun.adliye_atama_kayit(yapan, eski, yeni, gerekce, zaman)
  values (coalesce(p_atayan, u), null, u, case when p_sira = 1 then 'Cumhurbaşkanı ataması (mahkeme başkanı)' else 'Meclis seçimi (' || p_sira || '. üye)' end, t);
  perform oyun.bildir(u, format('Yüksek Mahkeme %s. üyesi oldun. Görev süren %s gün; bu sürede partiye giremez, aday olamaz, başka makam alamazsın.',
                                 p_sira, (select gorev_gun from oyun.mahkeme_ayar)), t);
  perform oyun.olay('adliye', format('%s Yüksek Mahkeme %s. üyesi oldu (%s).', oyun.kad(u), p_sira,
                                      case when p_sira = 1 then 'Cumhurbaşkanı ataması' else 'Meclis seçimi' end), null, null, t);
end $$;
create or replace function oyun.mahkeme_indir(p_sira smallint, p_yapan uuid, p_gerekce text, t timestamptz) returns void language plpgsql set search_path = '' as $$
declare u uuid;
begin
  select user_id into u from oyun.mahkeme_uye where sira = p_sira for update;
  if u is null then return; end if;
  update oyun.mahkeme_uye set user_id = null, atayan = null, bas = null, gorev_bit = null, bos_since = t where sira = p_sira;
  if p_sira = 1 then update oyun.adliye_makam set hakim = null, atama_at = null, degistirme_at = t where id = 1; end if;
  update oyun.mahkeme_azil set durum = 'ret' where uye = u and durum = 'acik' and p_gerekce not like 'Meclis%';
  insert into oyun.adliye_atama_kayit(yapan, eski, yeni, gerekce, zaman) values (coalesce(p_yapan, u), u, null, p_gerekce, t);
  perform oyun.bildir(u, 'Yüksek Mahkeme üyeliğin sona erdi: ' || p_gerekce, t);
  perform oyun.olay('adliye', format('%s Yüksek Mahkeme üyeliğinden ayrıldı: %s', oyun.kad(u), p_gerekce), null, null, t);
end $$;

-- Bağımsızlık tetikleyicileri
create or replace function oyun.tg_yargic_parti() returns trigger language plpgsql set search_path = '' as $$
begin
  if new.parti_id is not null and new.parti_id is distinct from old.parti_id and oyun.mahkeme_uyesi_mi(new.id) then
    raise exception 'Yüksek Mahkeme üyeleri görev süresince bir partiye üye olamaz.';
  end if;
  return new;
end $$;
drop trigger if exists yargic_parti on oyun.profiller;
create trigger yargic_parti before update of parti_id on oyun.profiller for each row execute function oyun.tg_yargic_parti();

create or replace function oyun.tg_yargic_makam() returns trigger language plpgsql set search_path = '' as $$
begin
  if new.bit is null and oyun.mahkeme_uyesi_mi(new.user_id) then
    raise exception 'Yüksek Mahkeme üyeleri görev süresince başka bir makamda görev alamaz.';
  end if;
  return new;
end $$;
drop trigger if exists yargic_makam on oyun.makamlar;
create trigger yargic_makam before insert on oyun.makamlar for each row execute function oyun.tg_yargic_makam();

create or replace function oyun.tg_aday_yasak() returns trigger language plpgsql set search_path = '' as $$
declare b timestamptz;
begin
  if oyun.mahkeme_uyesi_mi(new.user_id) then raise exception 'Yüksek Mahkeme üyeleri görev süresince aday olamaz.'; end if;
  select adaylik_yasagi_bitis into b from oyun.profiller where id = new.user_id;
  if b is not null and b > oyun.simdi() then
    raise exception 'Mahkeme kararıyla % tarihine kadar aday olamazsın.', to_char(b at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI');
  end if;
  return new;
end $$;
drop trigger if exists aday_yasak on oyun.adaylar;
create trigger aday_yasak before insert on oyun.adaylar for each row execute function oyun.tg_aday_yasak();

-- Akış'a ve Gündem'e yaz
create or replace function oyun.adliye_duyur(u uuid, p_metin text, p_etiketler text[], t timestamptz) returns void language plpgsql set search_path = '' as $$
declare yid bigint; e text; m text := left(p_metin, 280);
begin
  perform oyun.olay('adliye', p_metin, null, null, t);
  if to_regclass('oyun.akis') is null or u is null then return; end if;
  insert into oyun.akis(user_id, metin, zaman, il_id, parti_id)
  select u, m, t, p.il_id, p.parti_id from oyun.profiller p where p.id = u returning id into yid;
  if yid is null then return; end if;
  foreach e in array p_etiketler loop
    insert into oyun.akis_etiket(akis_id, etiket, zaman, user_id) values (yid, e, t, u) on conflict do nothing;
  end loop;
end $$;

-- Para cezası / harç tahsili: elde olan kadar alınır
create or replace function oyun.adliye_tahsil(u uuid, p_tutar numeric, p_aciklama text, t timestamptz) returns numeric language plpgsql set search_path = '' as $$
declare var numeric; al numeric;
begin
  if u is null or p_tutar <= 0 then return 0; end if;
  perform oyun.cuzdanim(u);
  select para into var from oyun.cuzdan where user_id = u for update;
  al := least(coalesce(var, 0), p_tutar);
  if al > 0 then perform oyun.para_islem(u, -al, 'adliye', p_aciklama, t); end if;
  return al;
end $$;

-- Hafif cezalar ilk kararda, ağır cezalar kesinleşince uygulanır
create or replace function oyun.adliye_hafif_ceza(d oyun.adliye_davalar, t timestamptz) returns timestamptz language plpgsql set search_path = '' as $$
declare bitis timestamptz;
begin
  if d.karar in ('sustur_1s','sustur_1g','sustur_1h') and d.davali is not null then
    bitis := t + case d.karar when 'sustur_1s' then interval '1 hour' when 'sustur_1g' then interval '1 day' else interval '7 days' end;
    update oyun.profiller set adliye_susturma_bitis = greatest(coalesce(adliye_susturma_bitis, t), bitis) where id = d.davali;
  end if;
  return bitis;
end $$;
create or replace function oyun.adliye_susturma_yenile(u uuid, t timestamptz) returns void language sql set search_path = '' as $$
  update oyun.profiller set adliye_susturma_bitis = (select max(ceza_bitis) from oyun.adliye_davalar
     where davali = u and durum = 'karar' and af_at is null and karar in ('sustur_1s','sustur_1g','sustur_1h') and ceza_bitis > t)
  where id = u
$$;

-- Karar kesinleşir: ağır ceza + harç hesabı
create or replace function oyun.adliye_kesinlestir(p_dava bigint, t timestamptz) returns void language plpgsql set search_path = '' as $$
declare d oyun.adliye_davalar; mv bigint; alinan numeric; gb uuid; davaci_kazandi boolean;
begin
  select * into d from oyun.adliye_davalar where id = p_dava for update;
  if d.id is null or d.kesin then return; end if;
  if not d.ceza_uygulandi and d.af_at is null then
    if d.karar = 'vekillik_dusur' and d.davali is not null then
      select id into mv from oyun.makamlar where user_id = d.davali and tur = 'mv' and bit is null order by bas desc limit 1;
      if mv is not null then
        update oyun.makamlar set bit = t, bitis_neden = 'Adliye #' || d.id || ' kararı' where user_id = d.davali and bit is null and tur in ('mv','tbmm','bskv','grup_bskv');
      end if;
    elsif d.karar in ('para_10b','para_50b') then
      alinan := oyun.adliye_tahsil(d.davali, case d.karar when 'para_10b' then 10000 else 50000 end, 'Adliye #' || d.id || ' para cezası', t);
    elsif d.karar = 'aday_yasagi' then
      update oyun.profiller set adaylik_yasagi_bitis = greatest(coalesce(adaylik_yasagi_bitis, t), t + interval '30 days') where id = d.davali;
    elsif d.karar = 'parti_para' and d.davali_parti is not null then
      update oyun.partiler set kasa = kasa - least(kasa, 25000) where id = d.davali_parti;
    end if;
  end if;
  -- harç: davacı kazandıysa iade + davalıdan tahsil; kaybettiyse hazineye kalır; düşmede iade
  davaci_kazandi := d.karar not in ('beraat','dusme');
  if d.harc > 0 and d.harc_durum = 'yatirildi' then
    if d.karar = 'dusme' or davaci_kazandi then
      perform oyun.para_islem(d.davaci, d.harc, 'adliye', 'Adliye #' || d.id || ' harç iadesi', t);
    end if;
    if davaci_kazandi then
      if d.davali is not null then perform oyun.adliye_tahsil(d.davali, d.harc, 'Adliye #' || d.id || ' yargılama harcı', t);
      elsif d.davali_parti is not null then update oyun.partiler set kasa = kasa - least(kasa, d.harc) where id = d.davali_parti; end if;
    end if;
  end if;
  update oyun.adliye_davalar set kesin = true, ceza_uygulandi = true, mv_makam_id = coalesce(mv, mv_makam_id),
         harc_durum = case when harc > 0 then case when karar = 'dusme' or davaci_kazandi then 'iade' else 'hazine' end end
   where id = d.id;
  perform oyun.bildir(x.id, format('Adliye #%s kararı kesinleşti: %s.', d.id, d.karar), t)
    from (select d.davaci id union select d.davali where d.davali is not null) x;
end $$;

-- Heyet oylarını say; çoğunluk varsa ilk derece kararı ver
create or replace function oyun.adliye_oy_say(p_dava bigint, t timestamptz) returns boolean language plpgsql set search_path = '' as $$
declare d oyun.adliye_davalar; heyet uuid[]; r record; bitis timestamptz; v_hakim uuid; v_ger text;
begin
  select * into d from oyun.adliye_davalar where id = p_dava for update;
  if d.durum <> 'acik' then return false; end if;
  heyet := oyun.dava_heyeti(d);
  if cardinality(heyet) = 0 then return false; end if;
  select o.karar, count(*) n, min(o.zaman) ilk into r from oyun.adliye_karar_oy o
   where o.dava_id = d.id and o.uye = any(heyet) group by o.karar order by count(*) desc, min(o.zaman) limit 1;
  if r.karar is null or r.n < oyun.cogunluk(cardinality(heyet)) then return false; end if;
  select o.uye, o.gerekce into v_hakim, v_ger from oyun.adliye_karar_oy o where o.dava_id = d.id and o.karar = r.karar and o.uye = any(heyet) order by o.zaman limit 1;
  update oyun.adliye_davalar set durum = 'karar', karar = r.karar, ilk_karar = r.karar, gerekce = v_ger, hakim = v_hakim, karar_at = t,
         kesin = false, istinaf_son = t + make_interval(hours => (select istinaf_saat from oyun.mahkeme_ayar))
   where id = d.id returning * into d;
  bitis := oyun.adliye_hafif_ceza(d, t);
  update oyun.adliye_davalar set ceza_bitis = bitis where id = d.id;
  perform oyun.bildir(x.id, format('Adliye #%s: mahkeme kararını verdi (%s). %s saat içinde istinafa başvurabilirsin.', d.id, r.karar,
                                   (select istinaf_saat from oyun.mahkeme_ayar)), t)
    from (select d.davaci id union select d.davali where d.davali is not null) x;
  perform oyun.adliye_duyur(v_hakim, format('Yüksek Mahkeme kararı #%s: %s → %s davasında karar "%s" (%s/%s oy). İstinaf yolu açık. #Adliye',
     d.id, coalesce((select kisa from oyun.partiler where id = d.davaci_parti), oyun.kad(d.davaci)),
     coalesce(oyun.kad(d.davali), (select kisa from oyun.partiler where id = d.davali_parti)), r.karar, r.n, cardinality(heyet)), array['adliye'], t);
  return true;
end $$;

-- =====================================================================
--  Davalar: açma (harçlı), heyet oyu (eski karar_ver bunu kullanır), istinaf, jüri
-- =====================================================================
create or replace function public.adliye_dava_ac(p_hedef_tur text,p_hedef text,p_tur text,p_iddia text,p_delil text default '',p_davaci_parti bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); u oyun.profiller; hedef_parti bigint; t timestamptz:=oyun.simdi(); yeni bigint; h numeric := (select harc from oyun.mahkeme_ayar);
begin
 if p_tur not in('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger') then raise exception 'Dava türü geçersiz.'; end if;
 if char_length(trim(coalesce(p_iddia,''))) not between 20 and 1600 then raise exception 'Dava açıklaması 20–1600 karakter olmalı.'; end if;
 if char_length(coalesce(p_delil,''))>1600 then raise exception 'Delil açıklaması 1600 karakteri aşamaz.'; end if;
 if p_hedef_tur='oyuncu' then
  select * into u from oyun.profiller where lower(kad)=lower(trim(p_hedef)) and not yasakli;
  if u.id is null then raise exception 'Davalı oyuncu bulunamadı.'; end if;
  if u.id=p.id then raise exception 'Kendinize dava açamazsınız.'; end if;
 elsif p_hedef_tur='parti' then
  begin hedef_parti:=p_hedef::bigint; exception when invalid_text_representation then raise exception 'Geçersiz parti.'; end;
  if not exists(select 1 from oyun.partiler where id=hedef_parti and not kapali) then raise exception 'Parti bulunamadı.'; end if;
 else raise exception 'Davalı türü geçersiz.'; end if;
 if p_davaci_parti is not null and not exists(
  select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id
  where pa.id=p_davaci_parti and not pa.kapali and (pa.gb=p.id or (s.user_id=p.id and p.parti_id=pa.id))
 ) then raise exception 'Parti adına dava açmak için genel başkan veya sözcü olmalısınız.'; end if;
 if hedef_parti is not null and hedef_parti=p_davaci_parti then raise exception 'Bir parti kendisine dava açamaz.'; end if;
 if (select count(*) from oyun.adliye_davalar where davaci=p.id and durum='acik')>=3 then raise exception 'En fazla üç açık davanız olabilir.'; end if;
 if exists(select 1 from oyun.adliye_davalar where davaci=p.id and acilis>t-interval '10 minutes') then raise exception 'Yeni dava için 10 dakika bekleyin.'; end if;
 if h > 0 then perform oyun.para_islem(p.id, -h, 'adliye', 'Dava harcı', t); end if;
 insert into oyun.adliye_davalar(davaci,davaci_parti,davali,davali_parti,tur,iddia,delil,acilis,savunma_son,karar_son,harc,harc_durum,kesin)
 values(p.id,p_davaci_parti,u.id,hedef_parti,p_tur,trim(p_iddia),coalesce(p_delil,''),t,t+interval '6 hours',
        t+interval '6 hours'+make_interval(hours=>(select karar_saat from oyun.mahkeme_ayar)),h,case when h>0 then 'yatirildi' end,false) returning id into yeni;
 if u.id is not null then insert into oyun.bildirimler(user_id,zaman,metin) values(u.id,t,'#'||yeni||' numaralı davada hakkınızda iddia var. Adliye''den 6 saat içinde savunma yapın.'); end if;
 if hedef_parti is not null then
  insert into oyun.bildirimler(user_id,zaman,metin)
  select distinct z.id,t,'#'||yeni||' numaralı davada partiniz davalıdır. Savunma Adliye''de.'
  from (select gb as id from oyun.partiler where id=hedef_parti union select user_id from oyun.parti_sozcu where parti_id=hedef_parti) z
  where z.id is not null;
 end if;
 insert into oyun.bildirimler(user_id,zaman,metin)
 select m.user_id,t,'Yüksek Mahkeme: #'||yeni||' numaralı yeni dava dosyası açıldı.' from oyun.mahkeme_uye m where m.user_id is not null and m.user_id<>p.id and m.user_id is distinct from u.id;
 return jsonb_build_object('tamam',true,'id',yeni,'harc',h);
end $$;

create or replace function public.adliye_oy_ver(p_dava bigint, p_karar text, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); d oyun.adliye_davalar; t timestamptz := oyun.simdi(); karar_cikti boolean;
begin
  if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalnız Yüksek Mahkeme üyeleri oy verebilir.'; end if;
  select * into d from oyun.adliye_davalar where id = p_dava;
  if d.id is null or d.durum <> 'acik' then raise exception 'Açık bir dava bulunamadı.'; end if;
  if d.davaci = p.id or d.davali = p.id then raise exception 'Yargıç kendi davasında oy kullanamaz.'; end if;
  if not d.savunma_geldi and t < d.savunma_son then raise exception 'Savunma süresinin dolmasını bekleyin.'; end if;
  if p_karar not in ('beraat','uyari','sustur_1s','sustur_1g','sustur_1h','vekillik_dusur','para_10b','para_50b','aday_yasagi','parti_para') then raise exception 'Geçersiz karar.'; end if;
  if d.davali is null and p_karar not in ('beraat','uyari','parti_para') then raise exception 'Partiye yalnız beraat, uyarı veya hazine yardımı kesintisi verilebilir.'; end if;
  if d.davali is not null and p_karar = 'parti_para' then raise exception 'Hazine yardımı kesintisi yalnız partilere verilir.'; end if;
  if p_karar = 'vekillik_dusur' and not exists (select 1 from oyun.makamlar where user_id = d.davali and tur = 'mv' and bit is null) then
    raise exception 'Davalının aktif milletvekilliği yok.';
  end if;
  if char_length(trim(coalesce(p_gerekce, ''))) not between 20 and 2000 then raise exception 'Gerekçeli oy 20–2000 karakter olmalı.'; end if;
  insert into oyun.adliye_karar_oy(dava_id, uye, karar, gerekce, zaman) values (d.id, p.id, p_karar, trim(p_gerekce), t)
  on conflict (dava_id, uye) do update set karar = excluded.karar, gerekce = excluded.gerekce, zaman = excluded.zaman;
  karar_cikti := oyun.adliye_oy_say(d.id, t);
  return jsonb_build_object('tamam', true, 'karar_cikti', karar_cikti);
end $$;

-- Eski "karar ver" düğmesi artık heyet oyu verir
create or replace function public.adliye_karar_ver(p_dava bigint, p_karar text, p_gerekce text) returns jsonb
language sql security definer set search_path = '' as $$ select public.adliye_oy_ver(p_dava, p_karar, p_gerekce) $$;

-- İstinaf: kaybeden taraf
create or replace function public.adliye_istinaf(p_dava bigint, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); d oyun.adliye_davalar; t timestamptz := oyun.simdi(); yetkili boolean; r record; n int := 0; juri_bit timestamptz;
begin
  select * into d from oyun.adliye_davalar where id = p_dava for update;
  if d.id is null or d.durum <> 'karar' or d.kesin then raise exception 'Bu karar istinafa açık değil.'; end if;
  if t > d.istinaf_son then raise exception 'İstinaf süresi doldu.'; end if;
  if exists (select 1 from oyun.adliye_istinaf where dava_id = d.id) then raise exception 'Bu karara zaten istinaf başvurusu yapıldı.'; end if;
  if d.karar = 'beraat' then
    yetkili := d.davaci = p.id or (d.davaci_parti is not null and exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id
                 where pa.id = d.davaci_parti and (pa.gb = p.id or s.user_id = p.id)));
  else
    yetkili := d.davali = p.id or (d.davali_parti is not null and exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id
                 where pa.id = d.davali_parti and (pa.gb = p.id or s.user_id = p.id)));
  end if;
  if not yetkili then raise exception 'İstinafa yalnız kararı kaybeden taraf başvurabilir.'; end if;
  if char_length(trim(coalesce(p_gerekce, ''))) not between 20 and 1500 then raise exception 'İstinaf gerekçesi 20–1500 karakter olmalı.'; end if;
  juri_bit := t + make_interval(hours => (select juri_saat from oyun.mahkeme_ayar));
  insert into oyun.adliye_istinaf(dava_id, basvuran, gerekce, bas, bit) values (d.id, p.id, trim(p_gerekce), t, juri_bit);
  -- Kura: davayla ilgisi olmayan partilerin aktif vekilleri; yetmezse son 7 günde görülen tarafsız oyuncular
  for r in
    select x.id from (
      select pr.id, 0 o, random() rnd from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
       where m.tur = 'mv' and m.bit is null and not pr.yasakli
      union all
      select pr.id, 1, random() from oyun.profiller pr where not pr.yasakli and pr.son_gorulme > t - interval '7 days') x
    join oyun.profiller q on q.id = x.id
    where x.id is distinct from d.davaci and x.id is distinct from d.davali and not oyun.mahkeme_uyesi_mi(x.id)
      and not exists (select 1 from oyun.makamlar cbm where cbm.user_id = x.id and cbm.tur = 'cb' and cbm.bit is null)
      and (q.parti_id is null or (q.parti_id is distinct from d.davaci_parti and q.parti_id is distinct from d.davali_parti
           and q.parti_id is distinct from (select parti_id from oyun.profiller where id = d.davaci)
           and q.parti_id is distinct from (select parti_id from oyun.profiller where id = d.davali)))
    group by x.id order by min(x.o), min(x.rnd) limit 3
  loop
    insert into oyun.adliye_juri(dava_id, user_id) values (d.id, r.id) on conflict do nothing;
    perform oyun.bildir(r.id, format('Kura ile Adliye #%s istinaf jürisine seçildin. %s saat içinde kararı onayla ya da boz.', d.id,
                                     (select juri_saat from oyun.mahkeme_ayar)), t);
    n := n + 1;
  end loop;
  if n = 0 then
    delete from oyun.adliye_istinaf where dava_id = d.id;
    raise exception 'Şu anda tarafsız jüri oluşturulamadı; daha sonra tekrar dene.';
  end if;
  update oyun.adliye_davalar set istinaf_son = juri_bit where id = d.id;
  perform oyun.olay('adliye', format('Adliye #%s kararı istinafa taşındı; %s kişilik jüri kurayla belirlendi.', d.id, n), null, null, t);
  return jsonb_build_object('tamam', true, 'juri', n);
end $$;

create or replace function oyun.adliye_istinaf_sonuc(p_dava bigint, t timestamptz) returns void language plpgsql set search_path = '' as $$
declare i oyun.adliye_istinaf; onay int; boz int; toplam int; d oyun.adliye_davalar;
begin
  select * into i from oyun.adliye_istinaf where dava_id = p_dava for update;
  if i.dava_id is null or i.durum <> 'acik' then return; end if;
  select count(*) filter (where oy = 'onay'), count(*) filter (where oy = 'boz'), count(*) into onay, boz, toplam from oyun.adliye_juri where dava_id = p_dava;
  -- erken bitiş: çoğunluk belli olduysa; yoksa süre bitince
  if not (onay >= oyun.cogunluk(toplam) or boz >= oyun.cogunluk(toplam) or t >= i.bit) then return; end if;
  select * into d from oyun.adliye_davalar where id = p_dava for update;
  if boz > onay then
    update oyun.adliye_istinaf set durum = 'bozuldu' where dava_id = p_dava;
    -- bozma: beraat bozulursa davalı uyarı alır (davacı kazanır); ceza bozulursa beraat
    update oyun.adliye_davalar set karar = case when d.karar = 'beraat' then 'uyari' else 'beraat' end, ceza_bitis = null where id = p_dava;
    if d.davali is not null then perform oyun.adliye_susturma_yenile(d.davali, t); end if;
    perform oyun.adliye_duyur((select user_id from oyun.adliye_juri where dava_id = p_dava and oy = 'boz' order by zaman limit 1),
      format('İstinaf jürisi Adliye #%s kararını BOZDU (%s boz / %s onay). #Adliye', p_dava, boz, onay), array['adliye'], t);
  else
    update oyun.adliye_istinaf set durum = 'onaylandi' where dava_id = p_dava;
    perform oyun.olay('adliye', format('İstinaf jürisi Adliye #%s kararını onayladı (%s onay / %s boz).', p_dava, onay, boz), null, null, t);
  end if;
  perform oyun.adliye_kesinlestir(p_dava, t);
end $$;

create or replace function public.adliye_juri_oy(p_dava bigint, p_oy text, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); i oyun.adliye_istinaf;
begin
  if p_oy not in ('onay','boz') then raise exception 'Onayla ya da boz.'; end if;
  select * into i from oyun.adliye_istinaf where dava_id = p_dava;
  if i.dava_id is null or i.durum <> 'acik' or t >= i.bit then raise exception 'Bu istinaf oylaması açık değil.'; end if;
  update oyun.adliye_juri set oy = p_oy, gerekce = nullif(left(trim(coalesce(p_gerekce, '')), 800), ''), zaman = t
   where dava_id = p_dava and user_id = p.id and oy is null;
  if not found then raise exception 'Bu davanın jürisinde değilsin ya da oyunu zaten verdin.'; end if;
  perform oyun.adliye_istinaf_sonuc(p_dava, t);
  return jsonb_build_object('tamam', true);
end $$;

-- =====================================================================
--  Üyelik: CB ataması (1. üye), Meclis seçimi (2–3), görevden alma (Meclis 3/5), istifa
-- =====================================================================
create or replace function public.adliye_hakim_ata(p_kad text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); u oyun.profiller; t timestamptz:=oyun.simdi(); engel text;
begin
 if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null) then raise exception 'Mahkeme başkanını yalnız Cumhurbaşkanı atayabilir.'; end if;
 if exists(select 1 from oyun.mahkeme_uye where sira=1 and user_id is not null) then
   raise exception 'Mahkeme başkanının görev süresi dolmadan yeni atama yapılamaz. Görevden alma yalnız Meclis''in 3/5 oyuyla olur.'; end if;
 select * into u from oyun.profiller where lower(kad)=lower(trim(p_kad)) and not yasakli;
 if u.id is null then raise exception 'Kullanıcı bulunamadı.'; end if;
 if u.id=p.id then raise exception 'Cumhurbaşkanı kendisini atayamaz.'; end if;
 engel := oyun.yargic_uygunluk(u.id);
 if engel is not null then raise exception '%', engel; end if;
 perform oyun.mahkeme_oturt(1::smallint, u.id, p.id, t);
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.adliye_hakim_al(p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 raise exception 'Yargı bağımsızlığı: Cumhurbaşkanı yargıcı görevden alamaz. Görevden alma, Meclis''te 3/5 oyla olur (Adliye > Yüksek Mahkeme > Görevden alma teklifi).';
end $$;

create or replace function public.adliye_hakim_istifa() returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); s smallint; t timestamptz:=oyun.simdi();
begin
 select sira into s from oyun.mahkeme_uye where user_id=p.id;
 if s is null then raise exception 'Yalnız görevdeki Yüksek Mahkeme üyeleri istifa edebilir.'; end if;
 perform oyun.mahkeme_indir(s, p.id, 'Kendi isteğiyle istifa etti.', t);
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.mahkeme_meclis_oy(p_sira int, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u oyun.profiller; engel text; n int;
begin
  if p_sira not in (2,3) then raise exception 'Meclis yalnız 2. ve 3. üyeyi seçer.'; end if;
  if not exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'mv' and bit is null) then raise exception 'Yalnız milletvekilleri oy verebilir.'; end if;
  if exists (select 1 from oyun.mahkeme_uye where sira = p_sira and user_id is not null) then raise exception 'Bu koltuk dolu.'; end if;
  select * into u from oyun.profiller where lower(kad) = lower(trim(coalesce(p_kad, ''))) and not yasakli;
  if u.id is null then raise exception 'Aday bulunamadı.'; end if;
  engel := oyun.yargic_uygunluk(u.id);
  if engel is not null then raise exception '%', engel; end if;
  insert into oyun.mahkeme_meclis_oy(sira, vekil, aday, zaman) values (p_sira, p.id, u.id, t)
  on conflict (sira, vekil) do update set aday = excluded.aday, zaman = excluded.zaman;
  select count(*) into n from oyun.mahkeme_meclis_oy where sira = p_sira and aday = u.id
     and exists (select 1 from oyun.makamlar m where m.user_id = vekil and m.tur = 'mv' and m.bit is null);
  if n >= oyun.salt_cogunluk() then perform oyun.mahkeme_oturt(p_sira::smallint, u.id, null, t); end if;
  return jsonb_build_object('tamam', true, 'oy', n, 'gerekli', oyun.salt_cogunluk(), 'secildi', n >= oyun.salt_cogunluk());
end $$;

create or replace function public.mahkeme_azil_teklif(p_sira int, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u uuid; yeni bigint;
begin
  if not exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'mv' and bit is null) then raise exception 'Görevden alma teklifini yalnız milletvekilleri verebilir.'; end if;
  select user_id into u from oyun.mahkeme_uye where sira = p_sira;
  if u is null then raise exception 'Bu koltukta üye yok.'; end if;
  if exists (select 1 from oyun.mahkeme_azil where uye = u and durum = 'acik') then raise exception 'Bu üye için zaten açık bir teklif var.'; end if;
  if exists (select 1 from oyun.mahkeme_azil where teklif_eden = p.id and bas > t - interval '24 hours') then raise exception 'Günde bir görevden alma teklifi verebilirsin.'; end if;
  if char_length(trim(coalesce(p_gerekce, ''))) not between 20 and 1000 then raise exception 'Gerekçe 20–1000 karakter olmalı.'; end if;
  insert into oyun.mahkeme_azil(sira, uye, teklif_eden, gerekce, bas, bit) values (p_sira, u, p.id, trim(p_gerekce), t, t + interval '48 hours') returning id into yeni;
  insert into oyun.mahkeme_azil_oy(azil_id, vekil, oy, zaman) values (yeni, p.id, 'kabul', t);
  perform oyun.bildir(u, 'Meclis''te Yüksek Mahkeme üyeliğinden görevden alınman için teklif verildi. 3/5 oy gerekir.', t);
  perform oyun.olay('meclis', format('%s, Yüksek Mahkeme üyesi %s için görevden alma teklifi verdi (3/5 oy gerekli).', p.kad, oyun.kad(u)), null, null, t);
  return jsonb_build_object('tamam', true, 'id', yeni);
end $$;

create or replace function oyun.mahkeme_azil_gerekli() returns int language sql stable set search_path = '' as $$
  select greatest(1, ceil(oyun.aktif_vekil_sayi() * 3 / 5.0)::int)
$$;
create or replace function oyun.mahkeme_azil_say(p_id bigint, t timestamptz) returns void language plpgsql set search_path = '' as $$
declare a oyun.mahkeme_azil; kabul int; ret int; aktif int := oyun.aktif_vekil_sayi(); gerek int := oyun.mahkeme_azil_gerekli();
begin
  select * into a from oyun.mahkeme_azil where id = p_id for update;
  if a.id is null or a.durum <> 'acik' then return; end if;
  select count(*) filter (where o.oy = 'kabul'), count(*) filter (where o.oy = 'ret') into kabul, ret
    from oyun.mahkeme_azil_oy o join oyun.makamlar m on m.user_id = o.vekil and m.tur = 'mv' and m.bit is null where o.azil_id = p_id;
  if kabul >= gerek then
    update oyun.mahkeme_azil set durum = 'kabul' where id = p_id;
    if exists (select 1 from oyun.mahkeme_uye where sira = a.sira and user_id = a.uye) then
      perform oyun.mahkeme_indir(a.sira, a.teklif_eden, format('Meclis 3/5 oyla görevden aldı (%s kabul).', kabul), t);
    end if;
  elsif t >= a.bit or ret > aktif - gerek then
    update oyun.mahkeme_azil set durum = 'ret' where id = p_id;
    perform oyun.olay('meclis', format('Yüksek Mahkeme üyesi %s hakkındaki görevden alma teklifi reddedildi (%s kabul, %s gerekli).', oyun.kad(a.uye), kabul, gerek), null, null, t);
  end if;
end $$;
create or replace function public.mahkeme_azil_oy(p_id bigint, p_oy text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if p_oy not in ('kabul','ret') then raise exception 'Kabul ya da ret.'; end if;
  if not exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'mv' and bit is null) then raise exception 'Yalnız milletvekilleri oy verebilir.'; end if;
  if not exists (select 1 from oyun.mahkeme_azil where id = p_id and durum = 'acik' and bit > t) then raise exception 'Oylama açık değil.'; end if;
  insert into oyun.mahkeme_azil_oy(azil_id, vekil, oy, zaman) values (p_id, p.id, p_oy, t)
  on conflict (azil_id, vekil) do update set oy = excluded.oy, zaman = excluded.zaman;
  perform oyun.mahkeme_azil_say(p_id, t);
  return jsonb_build_object('tamam', true);
end $$;

-- =====================================================================
--  Anayasa Mahkemesi
-- =====================================================================
create or replace function oyun.kanun_iptal_et(p_kanun bigint, t timestamptz) returns text language plpgsql set search_path = '' as $$
declare k oyun.kanunlar; yeni_var boolean; onceki numeric; val numeric; kod text; geri text := 'Kanun yürürlükten kalktı.';
begin
  select * into k from oyun.kanunlar where id = p_kanun for update;
  if k.id is null or k.durum <> 'yururlukte' then return null; end if;
  if k.tur = 'butce' and k.veri ? 'onceki' then
    select exists (select 1 from oyun.kanunlar x where x.tur = 'butce' and x.durum = 'yururlukte' and x.sonuc_at > k.sonuc_at) into yeni_var;
    if not yeni_var then
      update oyun.ulke set vergi_alt = (k.veri->'onceki'->>'vergi_alt')::numeric, vergi_ust = (k.veri->'onceki'->>'vergi_ust')::numeric,
             belediye_payi = (k.veri->'onceki'->>'belediye_payi')::numeric, parti_yardim = (k.veri->'onceki'->>'parti_yardim')::numeric,
             vergi = (k.veri->'onceki'->>'vergi')::numeric where id = 1;
      geri := 'Bütçe kanunundan önceki vergi, belediye payı ve parti yardımı geri geldi.';
    end if;
  elsif k.tur = 'secim' then
    select exists (select 1 from oyun.kanunlar x where x.tur = 'secim' and x.durum = 'yururlukte' and x.sonuc_at > k.sonuc_at) into yeni_var;
    if not yeni_var then
      select (x.veri->>'baraj')::numeric into onceki from oyun.kanunlar x
       where x.tur = 'secim' and x.durum = 'yururlukte' and x.id <> k.id and x.sonuc_at < k.sonuc_at order by x.sonuc_at desc limit 1;
      update oyun.ayarlar set baraj = coalesce(onceki, 7) where id = 1;
      update oyun.ulke set bekleyen_baraj = null where id = 1 and bekleyen_baraj = (k.veri->>'baraj')::numeric;
      geri := format('Seçim barajı %%%s olarak geri döndü.', coalesce(onceki, 7));
    end if;
  elsif k.tur = 'duzenleme' then
    if exists (select 1 from oyun.duzenlemeler where kaynak = 'kanun' and ref_id = k.id) then
      delete from oyun.duzenlemeler where kaynak = 'kanun' and ref_id = k.id;
      geri := 'Kanunun koyduğu kural kaldırıldı; varsayılan kural geçerli.';
    end if;
  elsif k.veri ? 'ekonomi_yasa' and k.veri ? 'onceki_deger' then
    kod := k.veri->>'ekonomi_yasa'; onceki := (k.veri->>'onceki_deger')::numeric; val := (k.veri->>'deger')::numeric;
    select exists (select 1 from oyun.kanunlar x where x.durum = 'yururlukte' and x.veri->>'ekonomi_yasa' = kod and x.sonuc_at > k.sonuc_at) into yeni_var;
    if not yeni_var and to_regclass('oyun.yasa_ekonomi_ayar') is not null then
      execute 'update oyun.yasa_ekonomi_ayar set deger = $1, guncelleme = $2 where kod = $3' using onceki, t, kod;
      if kod = 'belediye_payi' then update oyun.ulke set belediye_payi = onceki where id = 1;
      elsif kod = 'parti_yardim_carpan' then update oyun.ulke set parti_yardim = round(parti_yardim * onceki / greatest(val, 1)) where id = 1; end if;
      geri := format('Ekonomi yasası öncesindeki değer (%s) geri geldi.', onceki);
    end if;
  end if;
  update oyun.kanunlar set durum = 'aym_iptal', sonuc_metin = coalesce(sonuc_metin, '') || ' · Anayasa Mahkemesi iptal etti.' where id = k.id;
  return geri;
end $$;

create or replace function public.aym_basvur(p_kanun bigint, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; pid bigint; yeni bigint;
begin
  select id into pid from oyun.partiler where gb = p.id and not kapali;
  if pid is null then raise exception 'Anayasa Mahkemesine yalnız parti genel başkanları başvurabilir.'; end if;
  if not exists (select 1 from oyun.makamlar where tur = 'mv' and bit is null and parti_id = pid) then raise exception 'Başvuru için partinin Meclis''te en az bir milletvekili olmalı.'; end if;
  select * into k from oyun.kanunlar where id = p_kanun;
  if k.id is null or k.durum <> 'yururlukte' then raise exception 'Yalnız yürürlükteki kanunlar için başvurulabilir.'; end if;
  if k.tur in ('anayasa','iptal') then raise exception 'Anayasa değişiklikleri ve kararname iptal kanunları Anayasa Mahkemesine götürülemez.'; end if;
  if k.sonuc_at < t - make_interval(days => (select aym_gun from oyun.mahkeme_ayar)) then raise exception 'Başvuru süresi (yürürlükten sonra % gün) doldu.', (select aym_gun from oyun.mahkeme_ayar); end if;
  if k.teklif_parti = pid then raise exception 'Kendi partinizin teklif ettiği kanuna başvuramazsınız.'; end if;
  if exists (select 1 from oyun.aym_basvuru where kanun_id = k.id and durum = 'acik') then raise exception 'Bu kanun için zaten açık bir başvuru var.'; end if;
  if exists (select 1 from oyun.aym_basvuru where kanun_id = k.id and parti_id = pid) then raise exception 'Partiniz bu kanun için zaten başvurdu.'; end if;
  if char_length(trim(coalesce(p_gerekce, ''))) not between 30 and 2000 then raise exception 'Başvuru gerekçesi 30–2000 karakter olmalı.'; end if;
  insert into oyun.aym_basvuru(kanun_id, parti_id, basvuran, gerekce, bas, karar_son)
  values (k.id, pid, p.id, trim(p_gerekce), t, t + make_interval(hours => 6 + (select karar_saat from oyun.mahkeme_ayar))) returning id into yeni;
  perform oyun.bildir(k.teklif_eden, format('"%s" kanunun için Anayasa Mahkemesine iptal başvurusu yapıldı. 6 saat içinde görüş bildirebilirsin.', k.baslik), t);
  perform oyun.bildir(m.user_id, format('Anayasa Mahkemesi: "%s" kanunu için iptal başvurusu var.', k.baslik), t) from oyun.mahkeme_uye m where m.user_id is not null;
  perform oyun.adliye_duyur(p.id, format('%s, "%s" kanununun iptali için Anayasa Mahkemesine başvurdu. #AnayasaMahkemesi #Adliye',
                                         (select kisa from oyun.partiler where id = pid), left(k.baslik, 120)), array['anayasamahkemesi','adliye'], t);
  return jsonb_build_object('tamam', true, 'id', yeni);
end $$;

create or replace function public.aym_gorus(p_id bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); b oyun.aym_basvuru; k oyun.kanunlar;
begin
  select * into b from oyun.aym_basvuru where id = p_id for update;
  if b.id is null or b.durum <> 'acik' then raise exception 'Başvuru açık değil.'; end if;
  select * into k from oyun.kanunlar where id = b.kanun_id;
  if not (k.teklif_eden = p.id or exists (select 1 from oyun.partiler where id = k.teklif_parti and gb = p.id)) then
    raise exception 'Görüşü kanunu teklif eden ya da partisinin genel başkanı bildirir.';
  end if;
  if char_length(trim(coalesce(p_metin, ''))) not between 20 and 2000 then raise exception 'Görüş 20–2000 karakter olmalı.'; end if;
  update oyun.aym_basvuru set gorus = trim(p_metin), gorus_veren = p.id where id = b.id;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function oyun.aym_oy_say(p_id bigint, t timestamptz) returns boolean language plpgsql set search_path = '' as $$
declare b oyun.aym_basvuru; heyet uuid[] := oyun.mahkeme_uyeleri(); r record; v_hakim uuid; v_ger text; sonuc text; k oyun.kanunlar;
begin
  select * into b from oyun.aym_basvuru where id = p_id for update;
  if b.durum <> 'acik' or cardinality(heyet) = 0 then return false; end if;
  select o.karar, count(*) n into r from oyun.aym_oy o where o.basvuru_id = p_id and o.uye = any(heyet) group by o.karar order by count(*) desc, min(o.zaman) limit 1;
  if r.karar is null or r.n < oyun.cogunluk(cardinality(heyet)) then return false; end if;
  select o.uye, o.gerekce into v_hakim, v_ger from oyun.aym_oy o where o.basvuru_id = p_id and o.karar = r.karar order by o.zaman limit 1;
  select * into k from oyun.kanunlar where id = b.kanun_id;
  if r.karar = 'iptal' then sonuc := oyun.kanun_iptal_et(b.kanun_id, t); end if;
  update oyun.aym_basvuru set durum = r.karar, karar_gerekce = v_ger, karar_at = t, hakim = v_hakim where id = p_id;
  perform oyun.adliye_duyur(v_hakim, format('Anayasa Mahkemesi "%s" kanunu hakkındaki başvuruyu %s (%s/%s oy). %s #AnayasaMahkemesi',
     left(k.baslik, 100), case when r.karar = 'iptal' then 'kabul etti, kanunu İPTAL etti' else 'reddetti' end, r.n, cardinality(heyet), coalesce(sonuc, '')),
     array['anayasamahkemesi','adliye'], t);
  perform oyun.bildir(x, format('Anayasa Mahkemesi "%s" başvurusunu %s.', k.baslik, case when r.karar = 'iptal' then 'kabul etti; kanun iptal edildi' else 'reddetti' end), t)
    from unnest(array[b.basvuran, k.teklif_eden]) x;
  return true;
end $$;

create or replace function public.aym_oy_ver(p_id bigint, p_karar text, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.aym_basvuru;
begin
  if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalnız Yüksek Mahkeme üyeleri oy verebilir.'; end if;
  if p_karar not in ('iptal','ret') then raise exception 'İptal ya da ret.'; end if;
  select * into b from oyun.aym_basvuru where id = p_id;
  if b.id is null or b.durum <> 'acik' then raise exception 'Başvuru açık değil.'; end if;
  if b.gorus is null and t < b.bas + interval '6 hours' then raise exception 'Kanun sahibinin görüş süresi (6 saat) dolmadan oy verilemez.'; end if;
  if char_length(trim(coalesce(p_gerekce, ''))) not between 20 and 2000 then raise exception 'Gerekçeli oy 20–2000 karakter olmalı.'; end if;
  insert into oyun.aym_oy(basvuru_id, uye, karar, gerekce, zaman) values (p_id, p.id, p_karar, trim(p_gerekce), t)
  on conflict (basvuru_id, uye) do update set karar = excluded.karar, gerekce = excluded.gerekce, zaman = excluded.zaman;
  return jsonb_build_object('tamam', true, 'karar_cikti', oyun.aym_oy_say(p_id, t));
end $$;

-- =====================================================================
--  Zamanlayıcı: görev süreleri, Meclis koltukları, karar süresi, istinaf, kesinleşme, azil, AYM
-- =====================================================================
create or replace function oyun.mahkeme_tick() returns integer language plpgsql set search_path = '' as $$
declare t timestamptz := oyun.simdi(); r record; n int := 0; a oyun.mahkeme_ayar;
begin
  if not pg_try_advisory_xact_lock(424245) then return 0; end if;
  select * into a from oyun.mahkeme_ayar;
  -- 1) görev süresi dolan üyeler
  for r in select * from oyun.mahkeme_uye where user_id is not null and gorev_bit <= t loop
    perform oyun.mahkeme_indir(r.sira, null, 'Görev süresi doldu.', t); n := n + 1;
  end loop;
  -- 2) Meclis koltuğu 72 saattir boşsa en çok oy alan (en az 3 vekil) seçilir
  for r in
    select u.sira, o.aday, count(*) c from oyun.mahkeme_uye u join oyun.mahkeme_meclis_oy o on o.sira = u.sira
     join oyun.makamlar m on m.user_id = o.vekil and m.tur = 'mv' and m.bit is null
     where u.user_id is null and u.kaynak = 'meclis' and u.bos_since <= t - interval '72 hours'
     group by u.sira, o.aday having count(*) >= 3 order by u.sira, count(*) desc, min(o.zaman)
  loop
    if exists (select 1 from oyun.mahkeme_uye where sira = r.sira and user_id is null) and oyun.yargic_uygunluk(r.aday) is null then
      perform oyun.mahkeme_oturt(r.sira, r.aday, null, t); n := n + 1;
    end if;
  end loop;
  -- 3) karar süresi: hiç üye yoksa süre işlemez; varsa süresi dolan dava düşer
  for r in select id from oyun.adliye_davalar where durum = 'acik' and karar_son is not null and karar_son <= t loop
    if cardinality(oyun.mahkeme_uyeleri()) = 0 then
      update oyun.adliye_davalar set karar_son = t + make_interval(hours => a.karar_saat) where id = r.id;
    else
      update oyun.adliye_davalar set durum = 'karar', karar = 'dusme', ilk_karar = 'dusme', karar_at = t, kesin = false,
             gerekce = 'Mahkeme süresi içinde karar veremediği için dava zamanaşımından düştü; harç iade edildi.' where id = r.id;
      perform oyun.adliye_kesinlestir(r.id, t);
      perform oyun.olay('adliye', format('Adliye #%s süresinde karara bağlanmadığı için düştü.', r.id), null, null, t);
      n := n + 1;
    end if;
  end loop;
  -- 4) istinaf jürisi süresi
  for r in select dava_id from oyun.adliye_istinaf where durum = 'acik' and bit <= t loop
    perform oyun.adliye_istinaf_sonuc(r.dava_id, t); n := n + 1;
  end loop;
  -- 5) istinafa gidilmeyen kararlar kesinleşir
  for r in select d.id from oyun.adliye_davalar d where d.durum = 'karar' and not d.kesin and d.istinaf_son <= t
              and not exists (select 1 from oyun.adliye_istinaf i where i.dava_id = d.id) loop
    perform oyun.adliye_kesinlestir(r.id, t); n := n + 1;
  end loop;
  -- 6) görevden alma oylamaları
  for r in select id from oyun.mahkeme_azil where durum = 'acik' and bit <= t loop perform oyun.mahkeme_azil_say(r.id, t); end loop;
  -- 7) AYM: süresinde karar çıkmazsa başvuru düşer (kanun yürürlükte kalır)
  for r in select id from oyun.aym_basvuru where durum = 'acik' and karar_son <= t loop
    if cardinality(oyun.mahkeme_uyeleri()) = 0 then
      update oyun.aym_basvuru set karar_son = t + make_interval(hours => a.karar_saat) where id = r.id;
    else
      update oyun.aym_basvuru set durum = 'dustu', karar_at = t, karar_gerekce = 'Süresinde karar çıkmadığı için başvuru düştü; kanun yürürlükte.' where id = r.id;
    end if;
  end loop;
  return n;
end $$;

-- Mevcut açık davalar yeni düzene alınır
update oyun.adliye_davalar set karar_son = coalesce(karar_son, greatest(savunma_son, now()) + interval '72 hours'), kesin = false where durum = 'acik' and karar_son is null;

-- =====================================================================
--  Okuma: Yüksek Mahkeme durumu ve dava ayrıntıları
-- =====================================================================
create or replace function public.adliye_mahkeme() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); vekil boolean;
begin
  vekil := exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'mv' and bit is null);
  return jsonb_build_object(
    'ayar', (select to_jsonb(a) - 'id' from oyun.mahkeme_ayar a),
    'uyeler', (select jsonb_agg(jsonb_build_object('sira', u.sira, 'kaynak', u.kaynak, 'kad', oyun.kad(u.user_id), 'bas', u.bas, 'gorev_bit', u.gorev_bit,
         'bos_since', u.bos_since, 'benim', u.user_id = p.id,
         'adaylar', case when u.user_id is null and u.kaynak = 'meclis' then coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(x.aday), 'oy', x.n) order by x.n desc)
              from (select o.aday, count(*) n from oyun.mahkeme_meclis_oy o join oyun.makamlar m on m.user_id = o.vekil and m.tur = 'mv' and m.bit is null
                    where o.sira = u.sira group by o.aday) x), '[]'::jsonb) end,
         'oyum', (select oyun.kad(o.aday) from oyun.mahkeme_meclis_oy o where o.sira = u.sira and o.vekil = p.id),
         'azil', (select jsonb_build_object('id', z.id, 'teklif_eden', oyun.kad(z.teklif_eden), 'gerekce', z.gerekce, 'bit', z.bit,
                    'kabul', (select count(*) from oyun.mahkeme_azil_oy o where o.azil_id = z.id and o.oy = 'kabul'),
                    'ret', (select count(*) from oyun.mahkeme_azil_oy o where o.azil_id = z.id and o.oy = 'ret'),
                    'oyum', (select o.oy from oyun.mahkeme_azil_oy o where o.azil_id = z.id and o.vekil = p.id))
                  from oyun.mahkeme_azil z where z.uye = u.user_id and z.durum = 'acik' limit 1)) order by u.sira) from oyun.mahkeme_uye u),
    'salt_cogunluk', oyun.salt_cogunluk(), 'azil_gerekli', oyun.mahkeme_azil_gerekli(),
    'vekil_miyim', vekil, 'uye_miyim', oyun.mahkeme_uyesi_mi(p.id),
    'cb_miyim', exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null),
    'yargic_olabilir', oyun.yargic_uygunluk(p.id) is null,
    'juri_gorevlerim', coalesce((select jsonb_agg(jsonb_build_object('dava_id', j.dava_id, 'bit', i.bit, 'oyum', j.oy)) from oyun.adliye_juri j
        join oyun.adliye_istinaf i on i.dava_id = j.dava_id where j.user_id = p.id and i.durum = 'acik'), '[]'::jsonb),
    'aym', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'kanun_id', b.kanun_id, 'kanun', k.baslik, 'kanun_no', k.no, 'kanun_tur', k.tur,
        'parti', (select kisa from oyun.partiler where id = b.parti_id), 'basvuran', oyun.kad(b.basvuran), 'gerekce', b.gerekce,
        'gorus', b.gorus, 'gorus_veren', oyun.kad(b.gorus_veren), 'bas', b.bas, 'karar_son', b.karar_son, 'durum', b.durum,
        'karar_gerekce', b.karar_gerekce, 'karar_at', b.karar_at, 'hakim', oyun.kad(b.hakim),
        'oy_sayi', (select count(*) from oyun.aym_oy o where o.basvuru_id = b.id),
        'oyum', (select o.karar from oyun.aym_oy o where o.basvuru_id = b.id and o.uye = p.id),
        'gorus_verebilirim', b.durum = 'acik' and (k.teklif_eden = p.id or exists (select 1 from oyun.partiler where id = k.teklif_parti and gb = p.id)),
        'oylar', case when b.durum <> 'acik' then (select jsonb_agg(jsonb_build_object('uye', oyun.kad(o.uye), 'karar', o.karar, 'gerekce', o.gerekce) order by o.zaman)
                  from oyun.aym_oy o where o.basvuru_id = b.id) end) order by b.id desc)
        from (select * from oyun.aym_basvuru order by id desc limit 30) b join oyun.kanunlar k on k.id = b.kanun_id), '[]'::jsonb),
    'aym_kanunlar', case when exists (select 1 from oyun.partiler pa where pa.gb = p.id and not pa.kapali
                                        and exists (select 1 from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pa.id))
      then coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'no', k.no, 'baslik', k.baslik, 'tur', k.tur, 'sonuc_at', k.sonuc_at) order by k.sonuc_at desc)
        from oyun.kanunlar k where k.durum = 'yururlukte' and k.tur not in ('anayasa','iptal')
          and k.sonuc_at >= t - make_interval(days => (select aym_gun from oyun.mahkeme_ayar))
          and k.teklif_parti is distinct from (select id from oyun.partiler where gb = p.id and not kapali limit 1)
          and not exists (select 1 from oyun.aym_basvuru b where b.kanun_id = k.id and b.durum = 'acik')), '[]'::jsonb) end
  );
end $$;

create or replace function public.adliye_dava_ek(p_dava bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); d oyun.adliye_davalar; i oyun.adliye_istinaf; heyet uuid[];
begin
  select * into d from oyun.adliye_davalar where id = p_dava;
  if d.id is null then raise exception 'Dava bulunamadı.'; end if;
  select * into i from oyun.adliye_istinaf where dava_id = p_dava;
  heyet := oyun.dava_heyeti(d);
  return jsonb_build_object(
    'kesin', d.kesin, 'karar_son', d.karar_son, 'istinaf_son', d.istinaf_son, 'harc', d.harc, 'harc_durum', d.harc_durum, 'ilk_karar', d.ilk_karar,
    'heyet_sayi', cardinality(heyet), 'gerekli', oyun.cogunluk(cardinality(heyet)),
    'oy_sayi', (select count(*) from oyun.adliye_karar_oy o where o.dava_id = d.id and o.uye = any(heyet)),
    'oyum', (select jsonb_build_object('karar', o.karar, 'gerekce', o.gerekce) from oyun.adliye_karar_oy o where o.dava_id = d.id and o.uye = p.id),
    'oy_verebilirim', d.durum = 'acik' and p.id = any(heyet),
    -- oylar karar çıkana kadar gizli; sonra herkes görür (karşı oy dahil)
    'oylar', case when d.durum = 'karar' then (select jsonb_agg(jsonb_build_object('uye', oyun.kad(o.uye), 'karar', o.karar, 'gerekce', o.gerekce) order by o.zaman)
               from oyun.adliye_karar_oy o where o.dava_id = d.id) end,
    'istinaf', case when i.dava_id is not null then jsonb_build_object('basvuran', oyun.kad(i.basvuran), 'gerekce', i.gerekce, 'bas', i.bas, 'bit', i.bit, 'durum', i.durum,
        'onay', (select count(*) from oyun.adliye_juri j where j.dava_id = d.id and j.oy = 'onay'),
        'boz', (select count(*) from oyun.adliye_juri j where j.dava_id = d.id and j.oy = 'boz'),
        'juri_sayi', (select count(*) from oyun.adliye_juri j where j.dava_id = d.id),
        'juri', case when i.durum <> 'acik' then (select jsonb_agg(jsonb_build_object('kad', oyun.kad(j.user_id), 'oy', j.oy, 'gerekce', j.gerekce)) from oyun.adliye_juri j where j.dava_id = d.id) end,
        'juri_miyim', exists (select 1 from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = p.id),
        'juri_oyum', (select j.oy from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = p.id)) end,
    'istinaf_hakkim', d.durum = 'karar' and not d.kesin and i.dava_id is null and oyun.simdi() < d.istinaf_son and (
        (d.karar = 'beraat' and (d.davaci = p.id or exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id where pa.id = d.davaci_parti and (pa.gb = p.id or s.user_id = p.id))))
     or (d.karar not in ('beraat','dusme') and (d.davali = p.id or exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id where pa.id = d.davali_parti and (pa.gb = p.id or s.user_id = p.id))))));
end $$;

-- =====================================================================
--  Yetkiler ve zamanlayıcı
-- =====================================================================
do $$ declare f text; begin
  foreach f in array array['adliye_oy_ver(bigint,text,text)','adliye_istinaf(bigint,text)','adliye_juri_oy(bigint,text,text)',
    'mahkeme_meclis_oy(integer,text)','mahkeme_azil_teklif(integer,text)','mahkeme_azil_oy(bigint,text)',
    'aym_basvur(bigint,text)','aym_gorus(bigint,text)','aym_oy_ver(bigint,text,text)','adliye_mahkeme()','adliye_dava_ek(bigint)',
    'adliye_karar_ver(bigint,text,text)','adliye_hakim_ata(text)','adliye_hakim_al(text)','adliye_hakim_istifa()',
    'adliye_dava_ac(text,text,text,text,text,bigint)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
revoke all on function oyun.mahkeme_tick(), oyun.adliye_kesinlestir(bigint, timestamptz), oyun.adliye_oy_say(bigint, timestamptz),
  oyun.adliye_istinaf_sonuc(bigint, timestamptz), oyun.kanun_iptal_et(bigint, timestamptz), oyun.aym_oy_say(bigint, timestamptz),
  oyun.mahkeme_oturt(smallint, uuid, uuid, timestamptz), oyun.mahkeme_indir(smallint, uuid, text, timestamptz),
  oyun.adliye_tahsil(uuid, numeric, text, timestamptz), oyun.adliye_duyur(uuid, text, text[], timestamptz) from public, anon, authenticated;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'yuksek-mahkeme';
    perform cron.schedule('yuksek-mahkeme', '*/5 * * * *', 'select oyun.mahkeme_tick()');
  end if;
end $$;
