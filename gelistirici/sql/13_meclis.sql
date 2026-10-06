-- =====================================================================
--  13 · TBMM BAŞKANLIK DİVANI VE SİYASİ PARTİ GRUPLARI
--
--  Gerçek usul (Anayasa md. 94, TBMM İçtüzüğü):
--   • Yeni Meclis göreve başlayınca en kıdemli üye Geçici Başkan olarak oturumu yönetir.
--   • TBMM Başkanı: adaylar 24 saat içinde bildirilir; seçim GİZLİ oyla yapılır.
--       1. ve 2. tur: üye tamsayısının (oyunda dolu sandalye) üçte iki çoğunluğu
--       3. tur: salt çoğunluk · 4. tur: 3. turda en çok oy alan iki aday arasında, en çok oy alan seçilir.
--     Meclis Başkanı Genel Kurul'da oy kullanamaz, kanun teklifi veremez, partisinin faaliyetlerine katılamaz.
--   • Meclis'te grup kurmak için 20 milletvekili gerekir (600'de 20). Oyunda eşik dolu sandalyeyle oranlanır (en az 2).
--   • Başkanvekilleri: en büyük 3 grubun her biri bir başkanvekili adayı gösterir; parti grubu kendi vekilleri arasında seçer.
--   • Grup başkanvekilleri: her parti grubu kendi üyeleri arasından seçer (2; sandalyelerin 1/6'sından büyük gruplarda 3).
--     Grup başkanvekili (ya da milletvekili olan genel başkan) kanunlarda "grup kararı" alır: kabul / ret / serbest.
--   • TBMM Başkanı ve oturumu yöneten başkanvekili Genel Kurul'da düzeni sağlar: kürsüden ihtar (1 saat söz yasağı).
-- =====================================================================

alter table oyun.makamlar drop constraint if exists makamlar_tur_check;
alter table oyun.makamlar add constraint makamlar_tur_check check (tur in ('mv','bel','cb','bakan','tbmm','bskv','grup_bskv'));

create table if not exists oyun.meclis_secim(
  id         bigserial primary key,
  mv_secim_id bigint,
  tur        text not null check (tur in ('baskan','grup')),
  parti_id   bigint references oyun.partiler(id) on delete cascade,
  olusturma  timestamptz not null,
  aday_bit   timestamptz not null,
  oy_bit     timestamptz,                 -- grup seçiminin bitişi
  tur_no     int not null default 0,      -- başkan seçiminde içinde bulunulan tur
  tur_bit    timestamptz,
  uzatma     int not null default 0,
  durum      text not null default 'aday' check (durum in ('aday','oylama','bitti')),
  bskv_hakki boolean not null default false,
  grup_bskv_sayi int not null default 2,
  sonuc      text,
  turlar     jsonb not null default '[]'  -- açıklanan tur sonuçları (oy sayıları; kimin kime verdiği gizli)
);
create index if not exists meclis_secim_durum on oyun.meclis_secim(durum);
create table if not exists oyun.meclis_aday(
  secim_id bigint not null references oyun.meclis_secim(id) on delete cascade,
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  gorev    text not null check (gorev in ('baskan','bskv','grup_bskv')),
  zaman    timestamptz not null,
  elendi   boolean not null default false,
  primary key (secim_id, user_id, gorev)
);
create table if not exists oyun.meclis_oy(
  secim_id bigint not null references oyun.meclis_secim(id) on delete cascade,
  tur_no   int not null,
  gorev    text not null,
  secmen   uuid not null,
  aday     uuid not null,
  zaman    timestamptz not null,
  primary key (secim_id, tur_no, gorev, secmen)
);
create table if not exists oyun.grup_kararlari(
  kanun_id bigint not null references oyun.kanunlar(id) on delete cascade,
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  karar    text not null check (karar in ('kabul','ret','serbest')),
  user_id  uuid,
  zaman    timestamptz not null,
  primary key (kanun_id, parti_id)
);
create table if not exists oyun.meclis_ihtar(
  id      bigserial primary key,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  veren   uuid,
  neden   text,
  bas     timestamptz not null,
  bit     timestamptz not null
);

-- ---------------------------------------------------------------------
-- ROLLER (tek görev kuralına eklenenler)
-- ---------------------------------------------------------------------
create or replace function oyun.rol_uyumlu(a text, b text) returns boolean language sql immutable as $$
  select (a = b and a in ('gb','gby')) or (a, b) in (('mv','gby'),('gby','mv'),('gb','cb'),('cb','gb'),
         ('mv','tbmm'),('tbmm','mv'),('mv','bskv'),('bskv','mv'),('mv','grup_bskv'),('grup_bskv','mv'),('gby','grup_bskv'),('grup_bskv','gby'))
$$;
create or replace function oyun.rol_ad(r text) returns text language sql immutable as $$
  select case r when 'mv' then 'milletvekilliği' when 'bel' then 'belediye başkanlığı' when 'cb' then 'cumhurbaşkanlığı'
                when 'bakan' then 'bakanlık' when 'gb' then 'genel başkanlık' when 'gby' then 'genel başkan yardımcılığı'
                when 'tbmm' then 'TBMM Başkanlığı' when 'bskv' then 'TBMM Başkanvekilliği' when 'grup_bskv' then 'grup başkanvekilliği' else r end
$$;
create or replace function oyun.makam_ad(p_tur text, p_il smallint, p_bakanlik text) returns text language sql stable as $$
  select case p_tur when 'mv' then (select ad from oyun.iller where id = p_il) || ' milletvekilliği'
                    when 'bel' then (select ad from oyun.iller where id = p_il) || ' belediye başkanlığı'
                    when 'cb' then 'cumhurbaşkanlığı'
                    when 'tbmm' then 'TBMM Başkanlığı' when 'bskv' then 'TBMM Başkanvekilliği' when 'grup_bskv' then 'grup başkanvekilliği'
                    else coalesce((select ad from oyun.bakanliklar where kod = p_bakanlik), 'bakanlık') end
$$;
create or replace function oyun.unvan(u uuid) returns text language sql stable as $$
  select coalesce(
    (select 'Cumhurbaşkanı' from oyun.makamlar where user_id = u and tur = 'cb' and bit is null limit 1),
    (select 'TBMM Başkanı' from oyun.makamlar where user_id = u and tur = 'tbmm' and bit is null limit 1),
    (select replace(b.ad, 'Bakanlığı', 'Bakanı') from oyun.makamlar m join oyun.bakanliklar b on b.kod = m.bakanlik
       where m.user_id = u and m.tur = 'bakan' and m.bit is null limit 1),
    (select 'TBMM Başkanvekili' from oyun.makamlar where user_id = u and tur = 'bskv' and bit is null limit 1),
    (select pa.kisa || ' Genel Başkanı' from oyun.partiler pa where pa.gb = u and not pa.kapali limit 1),
    (select pa.kisa || ' Grup Başkanvekili' from oyun.makamlar m join oyun.partiler pa on pa.id = m.parti_id where m.user_id = u and m.tur = 'grup_bskv' and m.bit is null limit 1),
    (select i.ad || ' Milletvekili' from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = u and m.tur = 'mv' and m.bit is null limit 1),
    (select i.ad || ' Belediye Başkanı' from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = u and m.tur = 'bel' and m.bit is null limit 1),
    (select pa.kisa || ' Genel Başkan Yardımcısı' from oyun.parti_gby g join oyun.partiler pa on pa.id = g.parti_id where g.user_id = u limit 1))
$$;

create or replace function oyun.grup_esigi(p_dolu int) returns int language sql immutable as $$
  select greatest(2, ceil(p_dolu * 20 / 600.0))::int
$$;
-- Vekilin bugünkü partisi (partisinden istifa eden vekil bağımsız kalır, grubundan çıkar)
create or replace function oyun.aktif_mv_parti(u uuid) returns bigint language sql stable as $$
  select p.parti_id from oyun.profiller p where p.id = u and exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'mv' and m.bit is null)
$$;
create or replace function oyun.tbmm_baskani() returns uuid language sql stable as $$
  select user_id from oyun.makamlar where tur = 'tbmm' and bit is null limit 1
$$;
-- Geçici Başkan: TBMM Başkanı seçilene kadar en kıdemli milletvekili
create or replace function oyun.gecici_baskan() returns uuid language sql stable as $$
  select m.user_id from oyun.makamlar m where m.tur = 'mv' and m.bit is null order by oyun.kidem_puani(m.user_id) desc, m.bas, m.id limit 1
$$;
-- Parti grupları: grup eşiğini geçen partiler, sandalye sayısına göre
create or replace function oyun.gruplar() returns table(parti_id bigint, vekil int, sira int) language sql stable as $$
  with g as (select p.parti_id, count(*)::int vekil from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
             where m.tur = 'mv' and m.bit is null and p.parti_id is not null group by p.parti_id)
  select g.parti_id, g.vekil, (row_number() over (order by g.vekil desc, g.parti_id))::int from g
  where g.vekil >= oyun.grup_esigi((select count(*)::int from oyun.makamlar where tur = 'mv' and bit is null))
$$;

-- ---------------------------------------------------------------------
-- YASAMA DÖNEMİ BAŞLANGICI
-- ---------------------------------------------------------------------
create or replace function oyun.meclis_donem_baslat(p_mv bigint, t timestamptz) returns void language plpgsql as $$
declare m record; g record; dolu int := oyun.dolu_sandalye(); gb uuid;
begin
  for m in select id from oyun.makamlar where tur in ('tbmm','bskv','grup_bskv') and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'donem_bitti');
  end loop;
  update oyun.meclis_secim set durum = 'bitti', sonuc = coalesce(sonuc, 'Yasama dönemi sona erdi.') where durum <> 'bitti';
  insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit) values (p_mv, 'baskan', t, t + interval '24 hours');
  for g in select * from oyun.gruplar() loop
    insert into oyun.meclis_secim(mv_secim_id, tur, parti_id, olusturma, aday_bit, oy_bit, bskv_hakki, grup_bskv_sayi)
    values (p_mv, 'grup', g.parti_id, t, t + interval '24 hours', t + interval '36 hours', g.sira <= 3, case when g.vekil * 6 > dolu then 3 else 2 end);
  end loop;
  gb := oyun.gecici_baskan();
  perform oyun.olay('meclis', format('Yeni yasama dönemi başladı. Geçici Başkan %s. TBMM Başkanlığı ve grup başkanvekilliği adaylıkları 24 saat açık.', coalesce(oyun.kad(gb), '—')), null, null, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.user_id, t, 'Yeni yasama dönemi: TBMM Başkanlığına ve partinin grup görevlerine 24 saat içinde aday olabilirsin (Devlet › Meclis).'
    from oyun.makamlar x where x.tur = 'mv' and x.bit is null;
end $$;

-- Göreve atama (tek görev kuralı: uyumsuz görevler düşer)
create or replace function oyun.meclis_gorev_ata(u uuid, p_tur text, t timestamptz) returns void language plpgsql as $$
declare pid bigint := oyun.aktif_mv_parti(u); pk text;
begin
  if p_tur = 'tbmm' then
    -- Meclis Başkanı partisinin faaliyetlerine katılamaz
    delete from oyun.parti_gby where user_id = u;
    if exists (select 1 from oyun.partiler where gb = u) then
      update oyun.partiler set gb = null where gb = u;
      perform oyun.bildir(u, 'TBMM Başkanı seçildiğin için genel başkanlıktan ayrıldın (Anayasa md. 94: Meclis Başkanı partisinin faaliyetlerine katılamaz).', t);
    end if;
  end if;
  if p_tur = 'bskv' then delete from oyun.parti_gby where user_id = u; end if;
  insert into oyun.makamlar(tur, user_id, parti_id, kaynak, bas) values (p_tur, u, pid, 'secim', t);
  select kisa into pk from oyun.partiler where id = pid;
  perform oyun.bildir(u, format('Tebrikler! %s görevine seçildin.', case p_tur when 'tbmm' then 'TBMM Başkanlığı' when 'bskv' then 'TBMM Başkanvekilliği' else pk || ' Grup Başkanvekilliği' end), t);
end $$;

-- ---------------------------------------------------------------------
-- SAYIM
-- ---------------------------------------------------------------------
create or replace function oyun.meclis_sayim(p_secim bigint, p_tur int, p_gorev text)
returns table(user_id uuid, oy int, kidem numeric) language sql stable as $$
  select a.user_id, (select count(*)::int from oyun.meclis_oy o where o.secim_id = p_secim and o.tur_no = p_tur and o.gorev = p_gorev and o.aday = a.user_id),
         oyun.kidem_puani(a.user_id)
  from oyun.meclis_aday a where a.secim_id = p_secim and a.gorev = p_gorev and not a.elendi
  order by 2 desc, 3 desc
$$;

create or replace function oyun.meclis_tick(t timestamptz) returns void language plpgsql as $$
declare s oyun.meclis_secim; ms oyun.secimler; r record; dolu int; gerek int; ust record; ikinci uuid; n int; dongu int; m record; pk text;
begin
  -- yeni yasama dönemi
  for ms in select * from oyun.secimler x where x.tur = 'mv' and x.durum = 'tamam' and x.goreve_bas <= t and x.goreve_bas > t - interval '20 days'
              and not exists (select 1 from oyun.meclis_secim y where y.mv_secim_id = x.id) order by x.goreve_bas loop
    perform oyun.meclis_donem_baslat(ms.id, ms.goreve_bas);
  end loop;
  -- görev şartı kalmayanlar (vekilliği düşen, partisi değişen)
  for m in select x.* from oyun.makamlar x where x.tur in ('tbmm','bskv','grup_bskv') and x.bit is null
             and (not oyun.aktif_vekil(x.user_id) or (x.tur in ('bskv','grup_bskv') and oyun.aktif_mv_parti(x.user_id) is distinct from x.parti_id)) loop
    perform oyun.makam_bitir(m.id, t, 'gorev_dustu');
    if m.tur = 'tbmm' and not exists (select 1 from oyun.meclis_secim where tur = 'baskan' and durum <> 'bitti') then
      insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit) values (null, 'baskan', t, t + interval '24 hours');
      perform oyun.olay('meclis', 'TBMM Başkanlığı boşaldı. Ara seçim için adaylık 24 saat açık.', null, null, t);
    end if;
  end loop;
  -- TBMM Başkanı seçimi
  for s in select * from oyun.meclis_secim where tur = 'baskan' and durum <> 'bitti' order by id loop
    if s.durum = 'aday' and t >= s.aday_bit then
      if not exists (select 1 from oyun.meclis_aday where secim_id = s.id) then
        if s.uzatma < 2 then
          update oyun.meclis_secim set aday_bit = aday_bit + interval '24 hours', uzatma = uzatma + 1 where id = s.id;
          perform oyun.olay('meclis', 'TBMM Başkanlığı için aday çıkmadı; adaylık süresi 24 saat uzatıldı.', null, null, t);
        else
          update oyun.meclis_secim set durum = 'bitti', sonuc = 'Aday çıkmadı; Geçici Başkan oturumları yönetmeye devam ediyor.' where id = s.id;
        end if;
        continue;
      end if;
      update oyun.meclis_secim set durum = 'oylama', tur_no = 1, tur_bit = aday_bit + interval '12 hours' where id = s.id;
      insert into oyun.bildirimler(user_id, zaman, metin)
        select x.user_id, s.aday_bit, 'TBMM Başkanlığı seçiminin 1. turu başladı. Oy pusulan Devlet › Meclis ekranında; oylama gizli.'
        from oyun.makamlar x where x.tur = 'mv' and x.bit is null;
      select * into s from oyun.meclis_secim where id = s.id;
    end if;
    dongu := 0;
    while s.durum = 'oylama' and t >= s.tur_bit and dongu < 5 loop
      dongu := dongu + 1;
      dolu := oyun.dolu_sandalye();
      gerek := case when s.tur_no <= 2 then ceil(dolu * 2 / 3.0) when s.tur_no = 3 then floor(dolu / 2.0) + 1 else 0 end;
      select * into ust from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x
        where oyun.aktif_vekil(x.user_id) limit 1;
      update oyun.meclis_secim set turlar = turlar || jsonb_build_array(jsonb_build_object('tur', s.tur_no, 'gerek', gerek, 'katilim',
          (select count(*) from oyun.meclis_oy where secim_id = s.id and tur_no = s.tur_no and gorev = 'baskan'),
          'sonuc', (select jsonb_agg(jsonb_build_object('kad', oyun.kad(x.user_id), 'oy', x.oy)) from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x)))
        where id = s.id;
      if ust.user_id is not null and (s.tur_no = 4 or ust.oy >= gerek) then
        perform oyun.meclis_gorev_ata(ust.user_id, 'tbmm', s.tur_bit);
        update oyun.meclis_secim set durum = 'bitti', sonuc = format('%s %s. turda %s oyla TBMM Başkanı seçildi.', oyun.kad(ust.user_id), s.tur_no, ust.oy) where id = s.id;
        perform oyun.olay('meclis', format('%s, %s. turda %s oyla TBMM Başkanı seçildi.', oyun.kad(ust.user_id), s.tur_no, ust.oy), null, oyun.aktif_mv_parti(ust.user_id), s.tur_bit);
        perform oyun.gazete_ekle('atama', format('TBMM Başkanlığına %s seçilmiştir', oyun.kad(ust.user_id)), format('Genel Kurul''un gizli oylamasında %s. turda %s oy.', s.tur_no, ust.oy), null, s.tur_bit);
      elsif ust.user_id is null then
        update oyun.meclis_secim set durum = 'bitti', sonuc = 'Adaylar milletvekilliği sıfatını kaybettiği için seçim sonuçsuz kaldı.' where id = s.id;
      else
        if s.tur_no = 3 then
          -- 4. tur: en çok oy alan iki aday
          update oyun.meclis_aday set elendi = true where secim_id = s.id and gorev = 'baskan'
            and user_id not in (select x.user_id from oyun.meclis_sayim(s.id, 3, 'baskan') x where oyun.aktif_vekil(x.user_id) limit 2);
        end if;
        update oyun.meclis_secim set tur_no = tur_no + 1, tur_bit = tur_bit + interval '12 hours' where id = s.id;
        perform oyun.olay('meclis', format('TBMM Başkanlığı seçiminin %s. turunda gerekli %s oya ulaşılamadı; %s. tura geçildi.', s.tur_no, gerek, s.tur_no + 1), null, null, s.tur_bit);
      end if;
      select * into s from oyun.meclis_secim where id = s.id;
    end loop;
  end loop;
  -- Parti grup seçimleri
  for s in select * from oyun.meclis_secim where tur = 'grup' and durum <> 'bitti' order by id loop
    if s.durum = 'aday' and t >= s.aday_bit then
      update oyun.meclis_secim set durum = 'oylama' where id = s.id;
      s.durum := 'oylama';
    end if;
    if s.durum = 'oylama' and t >= s.oy_bit then
      select kisa into pk from oyun.partiler where id = s.parti_id;
      if s.bskv_hakki then
        select * into ust from oyun.meclis_sayim(s.id, 0, 'bskv') x
          where oyun.aktif_mv_parti(x.user_id) = s.parti_id and oyun.rol_cakisma(x.user_id, 'bskv') is null limit 1;
        if ust.user_id is not null then
          perform oyun.meclis_gorev_ata(ust.user_id, 'bskv', s.oy_bit);
          perform oyun.olay('meclis', format('%s grubu %s''i TBMM Başkanvekili olarak seçti.', pk, oyun.kad(ust.user_id)), null, s.parti_id, s.oy_bit);
        end if;
      end if;
      n := (select count(*) from oyun.meclis_aday a where a.secim_id = s.id and a.gorev = 'grup_bskv');
      for r in select x.* from oyun.meclis_sayim(s.id, 0, 'grup_bskv') x
                where oyun.aktif_mv_parti(x.user_id) = s.parti_id and oyun.rol_cakisma(x.user_id, 'grup_bskv') is null
                  and (n <= s.grup_bskv_sayi or x.oy > 0)
                limit s.grup_bskv_sayi loop
        perform oyun.meclis_gorev_ata(r.user_id, 'grup_bskv', s.oy_bit);
      end loop;
      update oyun.meclis_secim set durum = 'bitti', sonuc = 'Grup seçimi tamamlandı.' where id = s.id;
      perform oyun.olay('meclis', format('%s Meclis grubu başkanvekillerini seçti.', pk), null, s.parti_id, s.oy_bit);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- OYUNCU FONKSİYONLARI
-- ---------------------------------------------------------------------
create or replace function public.meclis_aday_ol(p_secim bigint, p_gorev text, p_aday boolean default true) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.meclis_secim;
begin
  select * into s from oyun.meclis_secim where id = p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
  if s.durum <> 'aday' or t >= s.aday_bit then raise exception 'Adaylık süresi bitti.'; end if;
  if not oyun.aktif_vekil(p.id) then raise exception 'Yalnızca milletvekilleri aday olabilir.'; end if;
  if s.tur = 'baskan' and p_gorev <> 'baskan' then raise exception 'Geçersiz görev.'; end if;
  if s.tur = 'grup' then
    if oyun.aktif_mv_parti(p.id) is distinct from s.parti_id then raise exception 'Yalnızca bu partinin milletvekilleri aday olabilir.'; end if;
    if p_gorev not in ('bskv','grup_bskv') or (p_gorev = 'bskv' and not s.bskv_hakki) then raise exception 'Geçersiz görev.'; end if;
  end if;
  if p_aday then
    insert into oyun.meclis_aday(secim_id, user_id, gorev, zaman) values (s.id, p.id, p_gorev, t) on conflict do nothing;
    if not found then raise exception 'Zaten adaysın.'; end if;
    if p_gorev = 'baskan' then
      perform oyun.olay('meclis', format('%s TBMM Başkanlığına aday oldu.', p.kad), null, p.parti_id, t);
    end if;
  else
    delete from oyun.meclis_aday where secim_id = s.id and user_id = p.id and gorev = p_gorev;
    if not found then raise exception 'Bu göreve aday değilsin.'; end if;
  end if;
  return public.meclis_baskanlik();
end $$;

create or replace function public.meclis_oy(p_secim bigint, p_gorev text, p_aday text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.meclis_secim; a uuid; tn int;
begin
  select * into s from oyun.meclis_secim where id = p_secim;
  if s.id is null or s.durum <> 'oylama' then raise exception 'Bu seçimde şu an oylama yok.'; end if;
  if not oyun.aktif_vekil(p.id) then raise exception 'Yalnızca milletvekilleri oy kullanabilir.'; end if;
  if s.tur = 'baskan' then
    if t >= s.tur_bit then raise exception 'Bu tur sona erdi.'; end if;
    tn := s.tur_no;
  else
    if t >= s.oy_bit then raise exception 'Oylama sona erdi.'; end if;
    if oyun.aktif_mv_parti(p.id) is distinct from s.parti_id then raise exception 'Grup seçiminde yalnızca partinin milletvekilleri oy kullanır.'; end if;
    tn := 0;
  end if;
  select ad.user_id into a from oyun.meclis_aday ad join oyun.profiller pr on pr.id = ad.user_id
   where ad.secim_id = s.id and ad.gorev = p_gorev and not ad.elendi and lower(pr.kad) = lower(btrim(p_aday));
  if a is null then raise exception 'Aday bulunamadı.'; end if;
  insert into oyun.meclis_oy(secim_id, tur_no, gorev, secmen, aday, zaman) values (s.id, tn, p_gorev, p.id, a, t) on conflict do nothing;
  if not found then raise exception 'Bu oylamada oyunu zaten kullandın.'; end if;
  return public.meclis_baskanlik();
end $$;

create or replace function oyun.meclis_secim_json(s oyun.meclis_secim, p oyun.profiller, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_build_object('id', s.id, 'tur', s.tur, 'parti', oyun.parti_json(s.parti_id), 'durum', s.durum, 'aday_bit', s.aday_bit,
    'oy_bit', coalesce(s.oy_bit, s.tur_bit), 'tur_no', s.tur_no, 'tur_bit', s.tur_bit, 'bskv_hakki', s.bskv_hakki, 'grup_bskv_sayi', s.grup_bskv_sayi,
    'sonuc', s.sonuc, 'turlar', s.turlar,
    'gerek', case when s.tur = 'baskan' and s.durum = 'oylama' then
               case when s.tur_no <= 2 then ceil(oyun.dolu_sandalye() * 2 / 3.0) when s.tur_no = 3 then floor(oyun.dolu_sandalye() / 2.0) + 1 else 0 end end,
    'adaylar', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'gorev', a.gorev, 'elendi', a.elendi, 'parti', oyun.parti_json(pr.parti_id),
                   'il', (select i.ad from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = pr.id and m.tur = 'mv' and m.bit is null limit 1),
                   'benim', pr.id = p.id) order by a.gorev, a.zaman)
                 from oyun.meclis_aday a join oyun.profiller pr on pr.id = a.user_id where a.secim_id = s.id), '[]'::jsonb),
    'oylarim', coalesce((select jsonb_agg(o.gorev) from oyun.meclis_oy o where o.secim_id = s.id and o.secmen = p.id
                          and o.tur_no = case when s.tur = 'baskan' then s.tur_no else 0 end), '[]'::jsonb),
    'katilabilir', oyun.aktif_vekil(p.id) and (s.tur = 'baskan' or oyun.aktif_mv_parti(p.id) = s.parti_id))
$$;

-- Meclis Başkanlık Divanı ve parti grupları ekranı
create or replace function public.meclis_baskanlik() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); dolu int := oyun.dolu_sandalye();
begin
  return jsonb_build_object(
    'baskan', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas) from oyun.makamlar m where m.tur = 'tbmm' and m.bit is null limit 1),
    'gecici', case when oyun.tbmm_baskani() is null then oyun.kad(oyun.gecici_baskan()) end,
    'baskanvekilleri', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id)) order by m.bas)
                                 from oyun.makamlar m where m.tur = 'bskv' and m.bit is null), '[]'::jsonb),
    'grup_esigi', oyun.grup_esigi(dolu), 'dolu', dolu,
    'gruplar', coalesce((select jsonb_agg(jsonb_build_object('parti', oyun.parti_json(g.parti_id), 'vekil', g.vekil, 'sira', g.sira,
                   'baskan', case when exists (select 1 from oyun.partiler pa where pa.id = g.parti_id and oyun.aktif_vekil(pa.gb)) then (select oyun.kad(gb) from oyun.partiler where id = g.parti_id) end,
                   'bskv', coalesce((select jsonb_agg(oyun.kad(m.user_id) order by m.bas) from oyun.makamlar m where m.tur = 'grup_bskv' and m.bit is null and m.parti_id = g.parti_id), '[]'::jsonb))
                 order by g.sira) from oyun.gruplar() g), '[]'::jsonb),
    'secimler', coalesce((select jsonb_agg(oyun.meclis_secim_json(s, p, t) order by (s.tur = 'baskan') desc, s.id)
                          from oyun.meclis_secim s where s.durum <> 'bitti' or s.id in (select max(id) from oyun.meclis_secim where tur = 'baskan')), '[]'::jsonb),
    'yetkim', jsonb_build_object(
       'ihtar', exists (select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('tbmm','bskv')) or (oyun.tbmm_baskani() is null and oyun.gecici_baskan() = p.id),
       'grup_karari', oyun.grup_karar_yetkisi(p.id) is not null, 'vekil', oyun.aktif_vekil(p.id)));
end $$;

-- ---------------------------------------------------------------------
-- GRUP KARARI
-- ---------------------------------------------------------------------
create or replace function oyun.grup_karar_yetkisi(u uuid) returns bigint language sql stable as $$
  select pid from (
    select m.parti_id pid from oyun.makamlar m where m.user_id = u and m.tur = 'grup_bskv' and m.bit is null
    union all select pa.id from oyun.partiler pa where pa.gb = u and oyun.aktif_vekil(u) and oyun.aktif_mv_parti(u) = pa.id) x
  where pid in (select g.parti_id from oyun.gruplar() g) limit 1
$$;

create or replace function public.grup_karar(p_kanun bigint, p_karar text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pid bigint := oyun.grup_karar_yetkisi(p.id); k oyun.kanunlar; pk text;
begin
  if pid is null then raise exception 'Grup kararını grup başkanvekilleri ya da milletvekili olan genel başkan alır (partinin Meclis''te grubu olmalı).'; end if;
  if p_karar not in ('kabul','ret','serbest') then raise exception 'Geçersiz karar.'; end if;
  select * into k from oyun.kanunlar where id = p_kanun;
  if k.id is null or k.durum not in ('gorusmede','oylamada','israr') then raise exception 'Bu teklif için grup kararı alınamaz.'; end if;
  insert into oyun.grup_kararlari(kanun_id, parti_id, karar, user_id, zaman) values (k.id, pid, p_karar, p.id, t)
  on conflict (kanun_id, parti_id) do update set karar = excluded.karar, user_id = excluded.user_id, zaman = excluded.zaman;
  select kisa into pk from oyun.partiler where id = pid;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select m.user_id, t, format('%s grup kararı: "%s" için %s.', pk, k.baslik, case p_karar when 'kabul' then 'KABUL oyu' when 'ret' then 'RET oyu' else 'oy serbest' end)
    from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pid and m.user_id <> p.id;
  perform oyun.olay('meclis', format('%s grubu "%s" için %s kararı aldı.', pk, k.baslik, case p_karar when 'kabul' then 'kabul' when 'ret' then 'ret' else 'serbest oy' end), null, pid, t);
  return public.kanun_detay(p_kanun);
end $$;

create or replace function oyun.grup_karar_json(p_kanun bigint, p oyun.profiller) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'liste', coalesce((select jsonb_agg(jsonb_build_object('parti', oyun.parti_json(g.parti_id), 'karar', g.karar, 'kad', oyun.kad(g.user_id))) from oyun.grup_kararlari g where g.kanun_id = p_kanun), '[]'::jsonb),
    'benim_grubum', (select karar from oyun.grup_kararlari where kanun_id = p_kanun and parti_id = oyun.aktif_mv_parti(p.id)),
    'yetkim', oyun.grup_karar_yetkisi(p.id) is not null)
$$;

-- ---------------------------------------------------------------------
-- GENEL KURUL DÜZENİ: İHTAR (1 saat söz yasağı)
-- ---------------------------------------------------------------------
create or replace function oyun.ihtarli(u uuid, t timestamptz) returns timestamptz language sql stable as $$
  select max(bit) from oyun.meclis_ihtar where user_id = u and bit > t
$$;

create or replace function public.meclis_ihtar(p_kad text, p_neden text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller := oyun.profil_bul(p_kad); n text;
begin
  if not (exists (select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('tbmm','bskv'))
          or (oyun.tbmm_baskani() is null and oyun.gecici_baskan() = p.id)) then
    raise exception 'Genel Kurul''da ihtar yetkisi TBMM Başkanı ve başkanvekillerindedir.';
  end if;
  if h.id = p.id then raise exception 'Kendine ihtar veremezsin.'; end if;
  if not oyun.meclis_yazabilir(h.id) then raise exception 'Bu kişinin Genel Kurul''da söz hakkı yok.'; end if;
  n := oyun.metin_temizle(coalesce(p_neden, ''), 200);
  if length(n) < 3 then raise exception 'İhtarın gerekçesini yaz.'; end if;
  insert into oyun.meclis_ihtar(user_id, veren, neden, bas, bit) values (h.id, p.id, n, t, t + interval '1 hour');
  insert into oyun.mesajlar(kanal, user_id, metin, zaman) values ('meclis', p.id, format('[İhtar] Sayın %s, %s. Bir saat süreyle söz verilmeyecektir.', h.kad, n), t);
  perform oyun.bildir(h.id, format('%s sana Genel Kurul''da ihtar verdi: %s. Bir saat Genel Kurul''da söz alamazsın.', p.kad, n), t);
  return jsonb_build_object('tamam', true);
end $$;

-- Görevden ayrılma
create or replace function public.meclis_gorev_birak(p_tur text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar;
begin
  select * into m from oyun.makamlar where user_id = p.id and tur = p_tur and bit is null and tur in ('tbmm','bskv','grup_bskv');
  if m.id is null then raise exception 'Bu görevde değilsin.'; end if;
  perform oyun.makam_bitir(m.id, t, 'istifa');
  perform oyun.olay('meclis', format('%s, %s görevinden ayrıldı.', p.kad, oyun.rol_ad(p_tur)), null, p.parti_id, t);
  if p_tur = 'tbmm' then
    insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit) values (null, 'baskan', t, t + interval '24 hours');
  end if;
  return public.meclis_baskanlik();
end $$;
