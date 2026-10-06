-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 8) 3. AŞAMA
--  Belediye projeleri · seçim bildirgesi (vaat) · rozetler ·
--  yönetici paneli · push bildirim kuyruğu ve cihaz kaydı
-- =====================================================================

alter table oyun.ayarlar add column if not exists push_aktif boolean not null default false;
alter table oyun.ayarlar add column if not exists push_url   text;   -- https://<proje>.supabase.co/functions/v1/push-gonder
alter table oyun.ayarlar add column if not exists push_gizli text;   -- sunucu fonksiyonuyla paylaşılan gizli anahtar

-- =====================================================================
--  BELEDİYE
--  Gelir (günlük): ilin taban geliri (0,02 + 0,004 × vekil sayısı milyar ₺) × fiyat düzeyi
--                  × gelişmişlik (0,5 + gelişim/100) × (öz gelir + kanundaki belediye payı) × (1 + kent vergisi/10)
--  Gider (günlük): açık hizmetlerin işletme gideri + hemşehri desteği
--  Belediye başkanı: kent vergisini (%0-5) ve hemşehri desteğini belirler, hizmet açar/kapar, yatırım yapar.
--  Kasa eksiye düşecekse hizmetler kapanır (en pahalıdan başlayarak) ve başkana bildirim gider.
-- =====================================================================
create table if not exists oyun.belediye_hizmetleri(
  kod text primary key, ad text not null, aciklama text not null,
  oran numeric not null,          -- günlük işletme gideri: ilin taban gelirinin bu oranı
  etki jsonb not null,            -- oyuncu etkileri [{tur, deger}]
  sira int not null
);
insert into oyun.belediye_hizmetleri(kod, ad, aciklama, oran, etki, sira) values
 ('lokanta','Kent lokantası','Uygun fiyatlı sıcak yemek: ildeki herkesin geçim masrafı %15 düşer.',0.12,'[{"tur":"gecim","deger":15}]',1),
 ('ulasim','Ücretsiz toplu ulaşım','Otobüs ve metro bedava: geçim masrafı %10 düşer, bu ile/bu ilden taşınmak yarı fiyat.',0.10,'[{"tur":"gecim","deger":10},{"tur":"tasinma","deger":50}]',2),
 ('kira','Sosyal konut ve kira yardımı','Kira desteği ve uygun konut: geçim masrafı %20 düşer.',0.18,'[{"tur":"gecim","deger":20}]',3),
 ('istihdam','Belediye istihdam ofisi','İş ve meslek eşleştirme: ildeki maaşlar %10 artar.',0.15,'[{"tur":"ucret","deger":10}]',4)
on conflict (kod) do update set ad = excluded.ad, aciklama = excluded.aciklama, oran = excluded.oran, etki = excluded.etki, sira = excluded.sira;

create table if not exists oyun.belediye_yatirimlari(
  kod text primary key, ad text not null, aciklama text not null,
  gun numeric not null, bekleme_saat int not null, gelisim numeric not null, memnuniyet numeric not null, sira int not null
);
insert into oyun.belediye_yatirimlari(kod, ad, aciklama, gun, bekleme_saat, gelisim, memnuniyet, sira) values
 ('altyapi','Yol ve altyapı yenileme','Su, kanalizasyon, asfalt: ilin gelişmişliği kalıcı +4 (maaşlar ve belediye geliri artar).',8,72,4,1,1),
 ('rayli','Raylı sistem hattı','Tramvay ya da metro: ilin gelişmişliği kalıcı +10.',20,168,10,3,2)
on conflict (kod) do update set ad = excluded.ad, aciklama = excluded.aciklama, gun = excluded.gun, bekleme_saat = excluded.bekleme_saat,
  gelisim = excluded.gelisim, memnuniyet = excluded.memnuniyet, sira = excluded.sira;

create table if not exists oyun.il_hizmet(
  il_id smallint not null references oyun.iller(id), kod text not null references oyun.belediye_hizmetleri(kod),
  acilis timestamptz not null, primary key (il_id, kod)
);
create table if not exists oyun.belediye_proje_kayit(
  id bigserial primary key, kod text not null, il_id smallint not null, baskan uuid not null, zaman timestamptz not null, maliyet numeric not null
);
create index if not exists bel_proje_il on oyun.belediye_proje_kayit(il_id, zaman desc);
drop function if exists public.belediye_proje(text);
drop table if exists oyun.belediye_projeleri cascade;  -- eski bel_maliyet() da gider

create or replace function oyun.il_sakin(p_il smallint, t timestamptz) returns int language sql stable as $$
  select count(*)::int from oyun.profiller where il_id = p_il and not yasakli and son_gorulme > t - interval '3 days'
$$;
create or replace function oyun.hizmet_gider(p_il smallint, p_kod text) returns numeric language sql stable as $$
  select round(h.oran * oyun.il_gunluk_gelir(i.mv) * u.endeks, 4)
  from oyun.belediye_hizmetleri h, oyun.iller i, oyun.ulke u where h.kod = p_kod and i.id = p_il and u.id = 1
$$;
-- Hemşehri desteğinin günlük bütçe yükü: tutar × ildeki yardım alan hane (5 milyon × vekil payı)
create or replace function oyun.hemsehri_gider(p_il smallint, p_tutar numeric) returns numeric language sql stable as $$
  select round(p_tutar * oyun.nufus('il_hane') * i.mv / 600 / 1e9, 4) from oyun.iller i where i.id = p_il
$$;
create or replace function oyun.il_gider(p_il smallint) returns numeric language sql stable as $$
  select coalesce((select sum(oyun.hizmet_gider(p_il, h.kod)) from oyun.il_hizmet h where h.il_id = p_il), 0)
       + oyun.hemsehri_gider(p_il, (select hemsehri from oyun.il_durum where il_id = p_il))
$$;
-- Belediyenin harcayabileceği günlük alan: günlük net + kasanın 30'da biri
create or replace function oyun.il_mali_alan(p_il smallint) returns numeric language sql stable as $$
  select round(greatest(0, oyun.il_gelir(p_il) - oyun.il_gider(p_il)) + greatest(0, d.kasa) / 30, 4) from oyun.il_durum d where d.il_id = p_il
$$;

-- Her gece: gelir girer, gider düşer; para yetmezse hizmetler kapanır
create or replace function oyun.belediye_gunluk(t timestamptz) returns void language plpgsql as $$
declare r record; h record; v_kasa numeric; bas uuid;
begin
  for r in select d.il_id, i.ad, i.mv from oyun.il_durum d join oyun.iller i on i.id = d.il_id loop
    update oyun.il_durum set kasa = least(60 * oyun.il_gelir(r.il_id), coalesce(kasa, 0) + oyun.il_gelir(r.il_id)) - oyun.il_gider(r.il_id)
     where il_id = r.il_id returning kasa into v_kasa;
    if v_kasa < 0 then
      bas := (select user_id from oyun.makamlar where tur = 'bel' and il_id = r.il_id and bit is null limit 1);
      update oyun.il_durum set hemsehri = 0 where il_id = r.il_id and hemsehri > 0;
      for h in select k.kod, b.ad from oyun.il_hizmet k join oyun.belediye_hizmetleri b on b.kod = k.kod
               where k.il_id = r.il_id order by b.oran desc loop
        exit when (select kasa from oyun.il_durum where il_id = r.il_id) >= 0;
        delete from oyun.il_hizmet where il_id = r.il_id and kod = h.kod;
        update oyun.il_durum set kasa = kasa + oyun.hizmet_gider(r.il_id, h.kod) where il_id = r.il_id;
        perform oyun.olay('belediye', format('%s Belediyesi kasası yetmediği için %s hizmetini kapattı.', r.ad, h.ad), r.il_id, null, t);
      end loop;
      if bas is not null then perform oyun.bildir(bas, 'Belediye kasası eksiye düştü: hemşehri desteği durduruldu, gerekirse hizmetler kapatıldı.', t); end if;
      update oyun.il_durum set kasa = greatest(kasa, 0) where il_id = r.il_id;
    end if;
  end loop;
  -- gelişmişlik yatırım almazsa yavaşça ortalamaya döner; memnuniyet hizmetlere, desteğe ve vergiye göre şekillenir
  update oyun.il_durum d set gelisim = gelisim + (50 - gelisim) * 0.01,
    memnuniyet = oyun.sinir(memnuniyet + (50 + 4 * (select count(*) from oyun.il_hizmet ih where ih.il_id = d.il_id) + least(10, hemsehri / 30)
                                          - kent_vergisi * 2 - oyun.il_duz(d.il_id, 'emlak') / 30 - memnuniyet) * 0.05, 0, 100);
end $$;

create or replace function oyun.il_hizmet_json(p_il smallint, t timestamptz) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(x order by x ->> 'sira'), '[]'::jsonb) from (
    select jsonb_build_object('sira', '1' || b.sira, 'kaynak', b.ad, 'kod', b.kod, 'tur', 'belediye', 'bas', h.acilis, 'etkiler', b.etki) x
      from oyun.il_hizmet h join oyun.belediye_hizmetleri b on b.kod = h.kod where h.il_id = p_il
    union all
    select jsonb_build_object('sira', '2', 'kaynak', e.kaynak_ad, 'kod', e.kaynak_kod, 'tur', 'bakanlik', 'bit', max(e.bit),
                              'etkiler', jsonb_agg(jsonb_build_object('tur', e.tur, 'deger', e.deger)))
      from oyun.etkiler e where e.il_id = p_il and e.bas <= t and e.bit > t group by e.kaynak_ad, e.kaynak_kod
  ) y
$$;

create or replace function public.belediye_paneli() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar; i oyun.iller; d oyun.il_durum;
begin
  select * into m from oyun.makamlar where user_id = p.id and tur = 'bel' and bit is null;
  if m.id is null then return null; end if;
  select * into i from oyun.iller where id = m.il_id;
  select * into d from oyun.il_durum where il_id = m.il_id;
  return jsonb_build_object('il_id', i.id, 'il_ad', i.ad, 'kasa', round(d.kasa, 3),
    'gelir', oyun.il_gelir(i.id), 'gider', oyun.il_gider(i.id), 'mali_alan', oyun.il_mali_alan(i.id),
    'taban', round(oyun.il_gunluk_gelir(i.mv), 3),
    'gelisim', round(d.gelisim, 1), 'memnuniyet', round(d.memnuniyet, 1), 'il_carpan', oyun.il_carpan(i.id),
    'kent_vergisi', d.kent_vergisi, 'hemsehri', d.hemsehri, 'hemsehri_birim', oyun.hemsehri_gider(i.id, 1),
    'ayar_hazir', case when d.son_ayar > t - interval '24 hours' then d.son_ayar + interval '24 hours' end,
    'sakin', (select count(*) from oyun.profiller where il_id = i.id and not yasakli), 'aktif_sakin', oyun.il_sakin(i.id, t),
    'maas', round(oyun.makam_maasi('bel', i.id)),
    'vaatler', oyun.vaat_listesi_makam(m.id),
    'kurallar', oyun.il_kurallar_json(i.id, t),
    'hizmetler', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad, 'aciklama', b.aciklama, 'etki', b.etki,
                    'gider', oyun.hizmet_gider(i.id, b.kod), 'acik', h.il_id is not null, 'acilis', h.acilis) order by b.sira)
                  from oyun.belediye_hizmetleri b left join oyun.il_hizmet h on h.il_id = i.id and h.kod = b.kod),
    'yatirimlar', (select jsonb_agg(jsonb_build_object('kod', y.kod, 'ad', y.ad, 'aciklama', y.aciklama, 'gelisim', y.gelisim, 'tur', y.tur, 'memnuniyet', y.memnuniyet, 'bekleme_saat', y.bekleme_saat,
                    'maliyet', round(y.gun * oyun.il_gunluk_gelir(i.mv) * (select endeks from oyun.ulke where id = 1), 3), 'gun', y.gun,
                    'hazir', (select max(k.zaman) + make_interval(hours => y.bekleme_saat) from oyun.belediye_proje_kayit k where k.kod = y.kod and k.il_id = i.id))
                  order by y.sira) from oyun.belediye_yatirimlari y),
    'son', coalesce((select jsonb_agg(jsonb_build_object('ad', k.ad, 'zaman', k.zaman, 'baskan', oyun.kad(k.baskan)) order by k.zaman desc)
                     from (select x.*, coalesce(b.ad, y.ad) ad from oyun.belediye_proje_kayit x
                           left join oyun.belediye_hizmetleri b on b.kod = x.kod left join oyun.belediye_yatirimlari y on y.kod = x.kod
                           where x.il_id = i.id order by x.zaman desc limit 10) k), '[]'::jsonb));
end $$;

create or replace function oyun.baskan_zorunlu(p oyun.profiller) returns oyun.makamlar language plpgsql as $$
declare m oyun.makamlar;
begin
  select * into m from oyun.makamlar where user_id = p.id and tur = 'bel' and bit is null;
  if m.id is null then raise exception 'Bu yetki yalnızca görevdeki il belediye başkanlarındadır.'; end if;
  return m;
end $$;

-- Hizmet aç / kapat. Açmak için kasada en az 3 günlük işletme gideri olmalı.
create or replace function public.belediye_hizmet(p_kod text, p_acik boolean) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar := oyun.baskan_zorunlu(p); b oyun.belediye_hizmetleri; ilad text; gider numeric;
begin
  select * into b from oyun.belediye_hizmetleri where kod = p_kod;
  if b.kod is null then raise exception 'Hizmet bulunamadı.'; end if;
  select ad into ilad from oyun.iller where id = m.il_id;
  if p_acik then
    if exists (select 1 from oyun.il_hizmet where il_id = m.il_id and kod = b.kod) then raise exception 'Bu hizmet zaten açık.'; end if;
    gider := oyun.hizmet_gider(m.il_id, b.kod);
    if (select kasa from oyun.il_durum where il_id = m.il_id) < 3 * gider then
      raise exception 'Açmak için kasada en az 3 günlük işletme gideri (% milyar ₺) olmalı.', round(3 * gider, 3);
    end if;
    insert into oyun.il_hizmet(il_id, kod, acilis) values (m.il_id, b.kod, t);
    insert into oyun.belediye_proje_kayit(kod, il_id, baskan, zaman, maliyet) values (b.kod, m.il_id, p.id, t, gider);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select x.id, t, format('%s Belediyesi %s hizmetini başlattı. %s', ilad, b.ad, b.aciklama)
      from oyun.profiller x where x.il_id = m.il_id and x.id <> p.id and not x.yasakli;
    perform oyun.olay('belediye', format('%s Belediye Başkanı %s: %s hizmeti başladı.', ilad, p.kad, b.ad), m.il_id, p.parti_id, t);
  else
    delete from oyun.il_hizmet where il_id = m.il_id and kod = b.kod;
    if not found then raise exception 'Bu hizmet zaten kapalı.'; end if;
    perform oyun.olay('belediye', format('%s Belediye Başkanı %s, %s hizmetini kapattı.', ilad, p.kad, b.ad), m.il_id, p.parti_id, t);
  end if;
  return public.belediye_paneli();
end $$;

create or replace function public.belediye_yatirim(p_kod text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar := oyun.baskan_zorunlu(p); y oyun.belediye_yatirimlari;
        maliyet numeric; son timestamptz; v_kasa numeric; ilad text;
begin
  select * into y from oyun.belediye_yatirimlari where kod = p_kod;
  if y.kod is null then raise exception 'Yatırım bulunamadı.'; end if;
  select ad into ilad from oyun.iller where id = m.il_id;
  maliyet := round(y.gun * oyun.il_gunluk_gelir((select mv from oyun.iller where id = m.il_id)) * (select endeks from oyun.ulke where id = 1), 3);
  select max(zaman) into son from oyun.belediye_proje_kayit where kod = y.kod and il_id = m.il_id;
  if son is not null and son + make_interval(hours => y.bekleme_saat) > t then
    raise exception 'Bu yatırım % tarihinden sonra tekrar yapılabilir.', to_char((son + make_interval(hours => y.bekleme_saat)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  select kasa into v_kasa from oyun.il_durum where il_id = m.il_id for update;
  if v_kasa < maliyet then raise exception 'Belediye kasasında yeterli para yok (% milyar ₺ gerekli, kasada % var).', maliyet, round(v_kasa, 3); end if;
  update oyun.il_durum set kasa = kasa - maliyet, gelisim = oyun.sinir(gelisim + y.gelisim, 0, 100),
    memnuniyet = oyun.sinir(memnuniyet + y.memnuniyet, 0, 100) where il_id = m.il_id;
  insert into oyun.belediye_proje_kayit(kod, il_id, baskan, zaman, maliyet) values (y.kod, m.il_id, p.id, t, maliyet);
  perform oyun.olay('belediye', format('%s Belediye Başkanı %s: %s.', ilad, p.kad, y.ad), m.il_id, p.parti_id, t);
  return public.belediye_paneli();
end $$;

-- Kent vergisi (%0-5) ve hemşehri desteği (0-1.000 ₺/gün); 24 saatte bir değiştirilebilir
create or replace function public.belediye_ayar(p_kent_vergisi numeric, p_hemsehri numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar := oyun.baskan_zorunlu(p); d oyun.il_durum; ilad text;
        kv numeric := round(coalesce(p_kent_vergisi, -1), 1); hs numeric := round(coalesce(p_hemsehri, -1));
begin
  select * into d from oyun.il_durum where il_id = m.il_id for update;
  select ad into ilad from oyun.iller where id = m.il_id;
  if kv not between 0 and 5 then raise exception 'Kent vergisi %%0-%%5 arasında olmalı.'; end if;
  if hs not between 0 and 1000 then raise exception 'Hemşehri desteği günlük 0-1.000 ₺ arasında olmalı.'; end if;
  if kv = d.kent_vergisi and hs = d.hemsehri then raise exception 'Değişiklik yok.'; end if;
  if d.son_ayar is not null and d.son_ayar > t - interval '24 hours' then
    raise exception 'Kent vergisi ve hemşehri desteği 24 saatte bir değiştirilebilir (sonraki: %).', to_char((d.son_ayar + interval '24 hours') at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  if hs > d.hemsehri and d.kasa < 3 * oyun.hemsehri_gider(m.il_id, hs) then
    raise exception 'Bu desteği vermek için kasada en az 3 günlük gideri (% milyar ₺) olmalı.', round(3 * oyun.hemsehri_gider(m.il_id, hs), 3);
  end if;
  update oyun.il_durum set kent_vergisi = kv, hemsehri = hs, son_ayar = t where il_id = m.il_id;
  perform oyun.olay('belediye', format('%s Belediye Başkanı %s: kent vergisi %%%s, hemşehri desteği günlük %s ₺.', ilad, p.kad, kv, hs), m.il_id, p.parti_id, t);
  if hs > d.hemsehri then
    insert into oyun.bildirimler(user_id, zaman, metin)
      select x.id, t, format('%s Belediyesi hemşehri desteğini günlük %s ₺ yaptı. Her gün ilk toplamada cüzdanına yatar.', ilad, hs)
      from oyun.profiller x where x.il_id = m.il_id and x.id <> p.id and not x.yasakli;
  end if;
  return public.belediye_paneli();
end $$;

-- =====================================================================
--  ROZETLER + oyuncu kartı (05'teki tanımın yerine geçer)
-- =====================================================================
create or replace function oyun.rozetler(u uuid) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(r order by r ->> 'sira'), '[]'::jsonb) from (
    select jsonb_build_object('sira', '01', 'ad', 'Cumhurbaşkanı', 'aciklama', 'Cumhurbaşkanlığı yaptı') r where exists (select 1 from oyun.makamlar where user_id = u and tur = 'cb')
    union all select jsonb_build_object('sira', '02', 'ad', 'Bakan', 'aciklama', 'Kabinede görev aldı') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'bakan')
    union all select jsonb_build_object('sira', '03', 'ad', 'Genel Başkan', 'aciklama', 'Bir partinin genel başkanı oldu')
      where exists (select 1 from oyun.partiler where gb = u) or exists (select 1 from oyun.kazananlar k join oyun.secimler s on s.id = k.secim_id where k.user_id = u and s.tur = 'kurultay')
    union all select jsonb_build_object('sira', '04', 'ad', 'Milletvekili', 'aciklama', 'Meclis''e girdi') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv')
    union all select jsonb_build_object('sira', '05', 'ad', 'Belediye Başkanı', 'aciklama', 'Bir ili yönetti') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'bel')
    union all select jsonb_build_object('sira', '06', 'ad', 'Kanun Yapıcı', 'aciklama', 'Teklifi yasalaştı') where exists (select 1 from oyun.kanunlar where teklif_eden = u and durum = 'yururlukte')
    union all select jsonb_build_object('sira', '07', 'ad', 'Parti Kurucusu', 'aciklama', 'Yeni bir parti kurdu') where exists (select 1 from oyun.partiler where kurucu = u)
    union all select jsonb_build_object('sira', '08', 'ad', 'Hatip', 'aciklama', '10+ propaganda yayını') where (select count(*) from oyun.yayinlar where gonderen = u) >= 10
    union all select jsonb_build_object('sira', '09', 'ad', 'Demokrasi Emektarı', 'aciklama', '20+ seçimde oy kullandı') where (select count(*) from oyun.oylar where secmen = u) >= 20
    union all select jsonb_build_object('sira', '10', 'ad', 'Sandık Neferi', 'aciklama', 'İlk oyunu kullandı') where (select count(*) from oyun.oylar where secmen = u) between 1 and 19
  ) x
$$;

create or replace function public.oyuncu_kart(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_kad);
  return jsonb_build_object('kad', h.kad, 'il_ad', (select ad from oyun.iller where id = h.il_id), 'il_id', h.il_id,
    'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id), 'katilim', h.olusturma,
    'ben', h.id = p.id, 'engelledim', oyun.engelli(p.id, h.id), 'rozetler', oyun.rozetler(h.id),
    'karneler', oyun.karneler(h.id), 'statu', oyun.statu_json(h.id), 'itibar', oyun.itibar_json(h.id),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('makam', oyun.makam_ad(m.tur, m.il_id, m.bakanlik), 'bas', m.bas, 'bit', m.bit) order by m.bas desc)
                        from (select * from oyun.makamlar where user_id = h.id order by bas desc limit 20) m), '[]'::jsonb));
end $$;

-- =====================================================================
--  YÖNETİCİ PANELİ
--  İlk yönetici SQL ile atanır:  update oyun.profiller set yonetici = true where kad = 'KullaniciAdin';
-- =====================================================================
create or replace function oyun.yonetici_zorunlu() returns oyun.profiller language plpgsql as $$
declare p oyun.profiller := oyun.profilim();
begin
  if not p.yonetici then raise exception 'Bu ekran yalnızca oyun yöneticileri içindir.'; end if;
  return p;
end $$;

create or replace function oyun.hesap_kapat(u uuid, t timestamptz) returns void language plpgsql as $$
declare m record;
begin
  update oyun.profiller set yasakli = true where id = u;
  for m in select id from oyun.makamlar where user_id = u and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'hesap_kapatildi');
  end loop;
  perform oyun._ayril(u, t);
  update oyun.mesajlar set gizli = true where user_id = u;
  update oyun.yayinlar set gizli = true where gonderen = u;
  delete from oyun.cihazlar where user_id = u;
end $$;

create or replace function public.admin_ozet() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'oyuncu', (select count(*) from oyun.profiller where not yasakli),
    'aktif24', (select count(*) from oyun.profiller where son_gorulme > t - interval '24 hours'),
    'yeni24', (select count(*) from oyun.profiller where olusturma > t - interval '24 hours'),
    'mesaj24', (select count(*) from oyun.mesajlar where zaman > t - interval '24 hours'),
    'sikayet', (select count(distinct (tur, kayit_id, hedef_user)) from oyun.sikayetler where durum = 'yeni'),
    'susturulmus', (select count(*) from oyun.profiller where susturma_bitis > t),
    'yasakli', (select count(*) from oyun.profiller where yasakli),
    'cihaz', (select count(*) from oyun.cihazlar),
    'push_bekleyen', (select count(*) from oyun.push_kuyruk where gonderildi is null and deneme < 3),
    'min_hesap_gun', (select min_hesap_gun from oyun.ayarlar where id = 1),
    'push_aktif', (select push_aktif from oyun.ayarlar where id = 1));
end $$;

create or replace function public.admin_sikayetler(p_durum text default 'yeni') returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu();
begin
  return coalesce((select jsonb_agg(x order by x ->> 'ilk' desc) from (
    select jsonb_build_object('tur', s.tur, 'kayit_id', s.kayit_id, 'hedef', oyun.kad(s.hedef_user),
      'sayi', count(distinct s.sikayetci), 'nedenler', jsonb_agg(distinct s.neden), 'ilk', min(s.zaman),
      'icerik', case s.tur when 'mesaj' then (select metin from oyun.mesajlar where id = s.kayit_id)
                           when 'yayin' then (select metin from oyun.yayinlar where id = s.kayit_id)
                           when 'ozel' then (select metin from oyun.ozel where id = s.kayit_id) end,
      'gizli', case s.tur when 'mesaj' then (select gizli from oyun.mesajlar where id = s.kayit_id)
                          when 'yayin' then (select gizli from oyun.yayinlar where id = s.kayit_id)
                          when 'ozel' then (select gizli from oyun.ozel where id = s.kayit_id) end,
      'hedef_susturma', (select susturma_bitis from oyun.profiller where id = s.hedef_user),
      'hedef_sikayet_toplam', (select count(*) from oyun.sikayetler z where z.hedef_user = s.hedef_user)) x
    from oyun.sikayetler s where s.durum = p_durum
    group by s.tur, s.kayit_id, s.hedef_user limit 100) q), '[]'::jsonb);
end $$;

-- p_islem: yok_say | gizle | gizle_sustur1 | gizle_sustur7 | kapat (hesabı kapat)
create or replace function public.admin_sikayet_karar(p_tur text, p_kayit bigint, p_hedef_kad text, p_islem text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_hedef_kad);
  if p_islem not in ('yok_say','gizle','gizle_sustur1','gizle_sustur7','kapat') then raise exception 'Geçersiz işlem.'; end if;
  if p_islem = 'yok_say' then
    if p_tur = 'mesaj' then update oyun.mesajlar set gizli = false where id = p_kayit;
    elsif p_tur = 'yayin' then update oyun.yayinlar set gizli = false where id = p_kayit; end if;
  else
    if p_tur = 'mesaj' then update oyun.mesajlar set gizli = true where id = p_kayit;
    elsif p_tur = 'yayin' then update oyun.yayinlar set gizli = true where id = p_kayit;
    elsif p_tur = 'ozel' then update oyun.ozel set gizli = true where id = p_kayit; end if;
  end if;
  if p_islem = 'gizle_sustur1' then update oyun.profiller set susturma_bitis = t + interval '1 day' where id = h.id; end if;
  if p_islem = 'gizle_sustur7' then update oyun.profiller set susturma_bitis = t + interval '7 days' where id = h.id; end if;
  if p_islem = 'kapat' then perform oyun.hesap_kapat(h.id, t); end if;
  if p_islem in ('gizle_sustur1','gizle_sustur7') then
    perform oyun.bildir(h.id, 'Topluluk kurallarını ihlal eden bir içeriğin kaldırıldı ve hesabın bir süre mesaj gönderemeyecek.', t);
  end if;
  update oyun.sikayetler set durum = 'incelendi' where tur = p_tur and kayit_id = coalesce(p_kayit, 0) and hedef_user = h.id;
  return public.admin_sikayetler('yeni');
end $$;

create or replace function public.admin_oyuncu(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); h oyun.profiller; t timestamptz := oyun.simdi();
begin
  h := oyun.profil_bul(p_kad);
  return jsonb_build_object('kad', h.kad, 'eposta', (select email from auth.users where id = h.id),
    'il', (select ad from oyun.iller where id = h.il_id), 'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id),
    'olusturma', h.olusturma, 'son_gorulme', h.son_gorulme, 'yasakli', h.yasakli, 'yonetici', h.yonetici,
    'susturma_bitis', case when h.susturma_bitis > t then h.susturma_bitis end,
    'sikayet', (select count(*) from oyun.sikayetler where hedef_user = h.id),
    'son_mesajlar', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'kanal', m.kanal, 'metin', m.metin, 'zaman', m.zaman, 'gizli', m.gizli) order by m.id desc)
                              from (select * from oyun.mesajlar where user_id = h.id order by id desc limit 15) m), '[]'::jsonb));
end $$;

-- p_islem: sustur1 | sustur7 | susturma_kaldir | kapat | ac
create or replace function public.admin_islem(p_kad text, p_islem text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Kendi hesabına işlem yapamazsın.'; end if;
  if p_islem = 'sustur1' then update oyun.profiller set susturma_bitis = t + interval '1 day' where id = h.id;
  elsif p_islem = 'sustur7' then update oyun.profiller set susturma_bitis = t + interval '7 days' where id = h.id;
  elsif p_islem = 'susturma_kaldir' then update oyun.profiller set susturma_bitis = null where id = h.id;
  elsif p_islem = 'kapat' then perform oyun.hesap_kapat(h.id, t);
  elsif p_islem = 'ac' then update oyun.profiller set yasakli = false where id = h.id;
  else raise exception 'Geçersiz işlem.'; end if;
  return public.admin_oyuncu(p_kad);
end $$;

create or replace function public.admin_duyuru(p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi(); m text;
begin
  m := oyun.metin_temizle(p_metin, 600);
  insert into oyun.yayinlar(tur, gonderen, metin, zaman, unvan) values ('sistem', p.id, m, t, 'Oyun Yönetimi');
  return jsonb_build_object('tamam', true, 'kitle', (select count(*) from oyun.profiller where not yasakli));
end $$;

create or replace function public.admin_ayar(p_min_hesap_gun int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu();
begin
  if p_min_hesap_gun not between 0 and 30 then raise exception 'Hesap yaşı 0-30 gün olmalı.'; end if;
  update oyun.ayarlar set min_hesap_gun = p_min_hesap_gun where id = 1;
  return public.admin_ozet();
end $$;

-- =====================================================================
--  PUSH BİLDİRİMLERİ
--  Uygulama, telefonun Firebase anahtarını (token) kaydeder ve Firebase "konu"larına abone olur:
--    s_tum, s_parti_<id>               seçim hatırlatmaları
--    p_tum, p_il_<plaka>, p_parti_<id> propaganda yayınları
--    duyuru                            oyun yönetimi duyuruları
--  Kişisel bildirimler ve özel mesajlar doğrudan kişinin cihazlarına gider.
--  Kuyruktaki bildirimleri "push-gonder" sunucu fonksiyonu Firebase'e iletir.
-- =====================================================================
create table if not exists oyun.cihazlar(
  token      text primary key,
  user_id    uuid not null,
  platform   text,
  guncelleme timestamptz not null default now()
);
create index if not exists cihazlar_user on oyun.cihazlar(user_id);

create table if not exists oyun.push_kuyruk(
  id         bigserial primary key,
  user_id    uuid,          -- kişiye özel
  konu       text,          -- Firebase konusu
  kosul      text,          -- Firebase konu koşulu (iki konunun kesişimi)
  baslik     text not null,
  govde      text not null,
  veri       jsonb not null default '{}',
  olusturma  timestamptz not null default now(),
  alindi     timestamptz,
  gonderildi timestamptz,
  deneme     int not null default 0,
  hata       text
);
create index if not exists push_bekleyen on oyun.push_kuyruk(id) where gonderildi is null;

create or replace function oyun.push_acik() returns boolean language sql stable as $$
  select coalesce((select push_aktif from oyun.ayarlar where id = 1), false)
$$;

create or replace function oyun.push_kisiye(u uuid, tercih text, p_baslik text, p_govde text, p_veri jsonb) returns void language plpgsql as $$
begin
  if not oyun.push_acik() then return; end if;
  if not exists (select 1 from oyun.cihazlar where user_id = u) then return; end if;
  if not coalesce((select (bildirim_ayar ->> tercih)::boolean from oyun.profiller where id = u and not yasakli), false) then return; end if;
  insert into oyun.push_kuyruk(user_id, baslik, govde, veri) values (u, left(p_baslik, 80), left(p_govde, 180), p_veri);
end $$;

create or replace function oyun.push_konuya(p_konu text, p_kosul text, p_baslik text, p_govde text, p_veri jsonb) returns void language plpgsql as $$
begin
  if not oyun.push_acik() then return; end if;
  insert into oyun.push_kuyruk(konu, kosul, baslik, govde, veri) values (p_konu, p_kosul, left(p_baslik, 80), left(p_govde, 180), p_veri);
end $$;

-- Tetikleyiciler
create or replace function oyun.tg_bildirim_push() returns trigger language plpgsql as $$
begin
  perform oyun.push_kisiye(new.user_id, 'kisisel', 'Seçim Simülasyonu', new.metin, '{"ekran":"bildirim"}');
  return null;
end $$;
drop trigger if exists bildirim_push on oyun.bildirimler;
create trigger bildirim_push after insert on oyun.bildirimler for each row execute function oyun.tg_bildirim_push();

create or replace function oyun.tg_ozel_push() returns trigger language plpgsql as $$
declare k text := oyun.kad(new.gonderen);
begin
  if oyun.engelli(new.alici, new.gonderen) then return null; end if;
  perform oyun.push_kisiye(new.alici, 'ozel', k, new.metin, jsonb_build_object('ekran', 'ozel', 'kad', k));
  return null;
end $$;
drop trigger if exists ozel_push on oyun.ozel;
create trigger ozel_push after insert on oyun.ozel for each row execute function oyun.tg_ozel_push();

create or replace function oyun.tg_yayin_push() returns trigger language plpgsql as $$
declare k text := oyun.kad(new.gonderen);
begin
  if new.tur = 'sistem' then
    perform oyun.push_konuya('duyuru', null, 'Oyun Yönetimi', new.metin, '{"ekran":"bildirim"}');
  elsif new.hedef_il is null and new.hedef_parti is null then
    perform oyun.push_konuya('p_tum', null, k || ' · ' || new.unvan, new.metin, '{"ekran":"bildirim"}');
  elsif new.hedef_parti is null then
    perform oyun.push_konuya('p_il_' || new.hedef_il, null, k || ' · ' || new.unvan, new.metin, '{"ekran":"bildirim"}');
  elsif new.hedef_il is null then
    perform oyun.push_konuya('p_parti_' || new.hedef_parti, null, k || ' · ' || new.unvan, new.metin, '{"ekran":"bildirim"}');
  else
    perform oyun.push_konuya(null, format('''p_il_%s'' in topics && ''p_parti_%s'' in topics', new.hedef_il, new.hedef_parti),
                             k || ' · ' || new.unvan, new.metin, '{"ekran":"bildirim"}');
  end if;
  return null;
end $$;
drop trigger if exists yayin_push on oyun.yayinlar;
create trigger yayin_push after insert on oyun.yayinlar for each row execute function oyun.tg_yayin_push();

-- Seçim hatırlatmaları (tick içinden, her dakika). Yalnızca ilgili zaman penceresi içindeyken gönderilir.
create or replace function oyun.push_hatirlatmalar(t timestamptz) returns void language plpgsql as $$
declare s oyun.secimler; pid bigint; v jsonb;
begin
  if not oyun.push_acik() then return; end if;
  for s in select * from oyun.secimler where durum = 'bekliyor' and basvuru_bas is not null and t >= basvuru_bas and t < basvuru_bit
             and tur in ('bel_on','mv_on','kurultay') and not (hatirlatma ? 'basvuru') loop
    perform oyun.push_konuya('s_tum', null, 'Başvurular açıldı', case s.tur
      when 'bel_on' then 'Belediye başkanlığı aday adaylığı başvuruları bugün açık. Adayını çıkar!'
      when 'mv_on' then 'Milletvekili aday adaylığı başvuruları bugün açık. Listeye girmek için başvur!'
      else 'Genel başkanlık başvuruları açıldı. Kurultay ayın 18''inde.' end, jsonb_build_object('ekran', 'gundem'));
    update oyun.secimler set hatirlatma = hatirlatma || '{"basvuru":true}' where id = s.id;
  end loop;
  for s in select * from oyun.secimler where durum = 'bekliyor' and t >= oy_bas and t < oy_bit and not (hatirlatma ? 'oy') loop
    v := jsonb_build_object('ekran', 'secim', 'id', s.id);
    if s.tur = 'mv' then
      perform oyun.push_konuya('s_tum', null, 'Bugün seçim var! 🗳️', 'Genel seçim ve cumhurbaşkanlığı seçimi sandıkları 17:00''ye kadar açık.', v);
    elsif s.tur = 'cb2' then
      perform oyun.push_konuya('s_tum', null, 'Cumhurbaşkanlığı 2. turu', 'Sandıklar 17:00''de kapanıyor. Oyunu kullanmayı unutma!', v);
    elsif s.tur = 'bel' then
      perform oyun.push_konuya('s_tum', null, 'Bugün belediye seçimi var! 🗳️', 'İl belediye başkanlığı sandıkları 17:00''ye kadar açık.', v);
    elsif s.tur in ('bel_on','mv_on','kurultay','cb_on') then
      for pid in select distinct parti_id from oyun.adaylar where secim_id = s.id and parti_id is not null loop
        perform oyun.push_konuya('s_parti_' || pid, null, 'Partinde seçim var', case s.tur
          when 'bel_on' then 'Belediye başkanı ön seçimi bugün 17:00''ye kadar.'
          when 'mv_on' then 'Milletvekili ön seçimi bugün 17:00''ye kadar. Liste sırasını sen belirle!'
          when 'cb_on' then 'Cumhurbaşkanı aday ön seçimi bugün 17:00''ye kadar.'
          else 'Kurultay bugün! Genel başkanını seç.' end, v);
      end loop;
    end if;
    update oyun.secimler set hatirlatma = hatirlatma || '{"oy":true}' where id = s.id;
  end loop;
  for s in select * from oyun.secimler where durum <> 'bekliyor' and tur in ('mv','bel','cb','cb2')
             and t >= sonuc_at and t < sonuc_at + interval '3 hours' and not (hatirlatma ? 'sonuc') loop
    if not (s.tur = 'cb') then
      perform oyun.push_konuya('s_tum', null, 'Sonuçlar açıklandı', case s.tur
        when 'mv' then 'Genel seçim ve cumhurbaşkanlığı sonuçları açıklandı. Meclis''in yeni dağılımını gör!'
        when 'bel' then 'Belediye seçimi sonuçları açıklandı. İlini kim kazandı?'
        else 'Cumhurbaşkanlığı ikinci tur sonucu açıklandı.' end, jsonb_build_object('ekran', 'secim', 'id', s.id));
    end if;
    update oyun.secimler set hatirlatma = hatirlatma || '{"sonuc":true}' where id = s.id;
  end loop;
  perform oyun.kumbara_hatirlat(t);
end $$;

-- Kuyrukta bekleyen varsa sunucu fonksiyonunu uyandırır (Supabase'de pg_net eklentisiyle)
create or replace function oyun.push_tetikle() returns void language plpgsql as $$
declare a oyun.ayarlar;
begin
  select * into a from oyun.ayarlar where id = 1;
  if not a.push_aktif or a.push_url is null then return; end if;
  if not exists (select 1 from oyun.push_kuyruk where gonderildi is null and deneme < 3) then return; end if;
  begin
    execute format('select net.http_post(url := %L, body := %L::jsonb, headers := %L::jsonb)',
                   a.push_url, '{}', json_build_object('Content-Type', 'application/json', 'x-gizli', a.push_gizli)::text);
  exception when others then
    null;  -- pg_net yoksa veya istek kurulamazsa oyun motoru durmaz
  end;
end $$;

-- ---------- Uygulamanın çağırdığı fonksiyonlar ----------
create or replace function public.cihaz_kaydet(p_token text, p_platform text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  if coalesce(length(p_token), 0) < 20 or length(p_token) > 4096 then raise exception 'Geçersiz cihaz anahtarı.'; end if;
  insert into oyun.cihazlar(token, user_id, platform, guncelleme) values (p_token, p.id, left(p_platform, 20), now())
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, guncelleme = now();
  -- bir kişinin en fazla 5 cihazı tutulur
  delete from oyun.cihazlar where user_id = p.id and token not in
    (select token from oyun.cihazlar where user_id = p.id order by guncelleme desc limit 5);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.cihaz_sil(p_token text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
begin
  delete from oyun.cihazlar where token = p_token and user_id = oyun.ben();
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.bildirim_ayar_kaydet(p_ayar jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); yeni jsonb := '{}'; k text;
begin
  foreach k in array array['secim','ozel','propaganda','kisisel'] loop
    yeni := yeni || jsonb_build_object(k, coalesce((p_ayar ->> k)::boolean, (p.bildirim_ayar ->> k)::boolean, true));
  end loop;
  update oyun.profiller set bildirim_ayar = yeni where id = p.id;
  return public.durum();
end $$;

-- ---------- Sunucu fonksiyonunun çağırdığı fonksiyonlar (yalnızca service_role) ----------
create or replace function public.push_al(p_limit int default 500) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare j jsonb;
begin
  with secilen as (
    select id from oyun.push_kuyruk
    where gonderildi is null and deneme < 3 and (alindi is null or alindi < now() - interval '2 minutes')
      and olusturma > now() - interval '6 hours'
    order by id limit least(greatest(p_limit, 1), 1000) for update skip locked
  ), al as (
    update oyun.push_kuyruk k set alindi = now(), deneme = deneme + 1 from secilen where k.id = secilen.id returning k.*
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', al.id, 'konu', al.konu, 'kosul', al.kosul, 'baslik', al.baslik, 'govde', al.govde, 'veri', al.veri,
           'tokenlar', case when al.user_id is null then null else
              coalesce((select jsonb_agg(c.token) from oyun.cihazlar c where c.user_id = al.user_id), '[]'::jsonb) end) order by al.id), '[]'::jsonb)
  into j from al;
  -- 6 saatten eski gönderilmemişler artık anlamsız: kapat
  update oyun.push_kuyruk set gonderildi = now(), hata = 'süresi doldu' where gonderildi is null and olusturma <= now() - interval '6 hours';
  return j;
end $$;

-- p_sonuc: {"basarili":[id...], "hatalar":{"id":"mesaj"}, "gecersiz":[token...]}
create or replace function public.push_bitti(p_sonuc jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare n1 int; n2 int;
begin
  update oyun.push_kuyruk set gonderildi = now(), hata = null
   where id in (select (x)::bigint from jsonb_array_elements_text(coalesce(p_sonuc -> 'basarili', '[]')) x);
  get diagnostics n1 = row_count;
  update oyun.push_kuyruk k set hata = h.value, gonderildi = case when k.deneme >= 3 then now() end
   from jsonb_each_text(coalesce(p_sonuc -> 'hatalar', '{}')) h where k.id = h.key::bigint;
  delete from oyun.cihazlar where token in (select x from jsonb_array_elements_text(coalesce(p_sonuc -> 'gecersiz', '[]')) x);
  get diagnostics n2 = row_count;
  delete from oyun.push_kuyruk where olusturma < now() - interval '7 days';
  return jsonb_build_object('gonderildi', n1, 'silinen_cihaz', n2);
end $$;

revoke all on function public.push_al(int) from public, anon, authenticated;
revoke all on function public.push_bitti(jsonb) from public, anon, authenticated;
grant execute on function public.push_al(int) to service_role;
grant execute on function public.push_bitti(jsonb) to service_role;
