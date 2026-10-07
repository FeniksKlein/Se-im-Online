-- =====================================================================
--  KALICILIK: OYUN HİÇ SIFIRLANMAZ
--
--  Her güncelleme (supabase-kurulum.sql) tek bir işlem (transaction) içinde çalışır:
--    1) guncelleme_basla : oyunun yedeği alınır, oyuncu verisinin "parmak izi" çıkarılır
--    2) şema ve fonksiyonlar güncellenir (yalnızca EKLER: yeni tablo, yeni sütun, yeni makam türü…)
--    3) guncelleme_bitti : parmak izi yeniden çıkarılır. Oyuncuların hesabı, makamı, parası, kıdemi,
--       oyları, partileri, mülkleri… tek bir bayt bile değiştiyse GÜNCELLEME DURDURULUR ve hiçbir şey
--       uygulanmaz (işlem geri alınır). Böylece bir güncelleme oyunu asla bozamaz.
--  Ayrıca: oyun tabloları TRUNCATE ile boşaltılamaz, DROP TABLE / DROP COLUMN ile silinemez
--  (yalnızca sahibinin bilerek çalıştıracağı sıfırlama/geri yükleme fonksiyonlarıyla).
--  Oyunu sıfırlamak yalnızca oyun sahibinin işidir:  select oyun.oyunu_sifirla('OYUNU SIFIRLA');
-- =====================================================================
create schema if not exists oyun;
revoke all on schema oyun from public;

create table if not exists oyun.surumler(
  id          serial primary key,
  surum       text not null,
  aciklama    text,
  baslangic   timestamptz not null default clock_timestamp(),
  bitis       timestamptz,
  yedek       text,
  parmak_once jsonb,
  parmak_sonra jsonb
);

-- Oyuncu verisinin parmak izi: sayılar, toplamlar ve içerik özetleri (var olan tablo/sütunlar üzerinden)
create or replace function oyun.parmak_izi() returns jsonb language plpgsql as $$
declare sonuc jsonb := '{}'; r record; v text;
begin
  for r in select * from (values
    ('oyuncu',        'oyun.profiller',     'select count(*)::text from oyun.profiller'),
    ('profiller',     'oyun.profiller',     'select md5(coalesce(string_agg(id::text||''|''||kad||''|''||il_id||''|''||coalesce(parti_id::text,'''')||''|''||olusturma::text, '','' order by id), '''')) from oyun.profiller'),
    ('makamlar',      'oyun.makamlar',      'select md5(coalesce(string_agg(id||''|''||tur||''|''||user_id||''|''||coalesce(il_id::text,'''')||''|''||coalesce(bakanlik,'''')||''|''||bas::text||''|''||coalesce(bit::text,''''), '','' order by id), '''')) from oyun.makamlar'),
    ('aktif_makam',   'oyun.makamlar',      'select count(*)::text from oyun.makamlar where bit is null'),
    ('cuzdanlar',     'oyun.cuzdan',        'select md5(coalesce(string_agg(user_id||''|''||para||''|''||kidem||''|''||coalesce(seri::text,''''), '','' order by user_id), '''')) from oyun.cuzdan'),
    ('toplam_para',   'oyun.cuzdan',        'select coalesce(sum(para),0)::text from oyun.cuzdan'),
    ('toplam_kidem',  'oyun.cuzdan',        'select coalesce(sum(kidem),0)::text from oyun.cuzdan'),
    ('partiler',      'oyun.partiler',      'select md5(coalesce(string_agg(id||''|''||ad||''|''||kisa||''|''||coalesce(gb::text,'''')||''|''||kasa||''|''||kapali, '','' order by id), '''')) from oyun.partiler'),
    ('gby',           'oyun.parti_gby',     'select count(*)::text from oyun.parti_gby'),
    ('oylar',         'oyun.oylar',         'select count(*)::text from oyun.oylar'),
    ('secimler',      'oyun.secimler',      'select md5(coalesce(string_agg(id||''|''||tur||''|''||donem||''|''||durum, '','' order by id), '''')) from oyun.secimler'),
    ('adaylar',       'oyun.adaylar',       'select count(*)::text from oyun.adaylar'),
    ('kazananlar',    'oyun.kazananlar',    'select count(*)::text from oyun.kazananlar'),
    ('hareketler',    'oyun.hesap_hareket', 'select count(*)::text from oyun.hesap_hareket'),
    ('kanunlar',      'oyun.kanunlar',      'select md5(coalesce(string_agg(id||''|''||durum||''|''||coalesce(no::text,''''), '','' order by id), '''')) from oyun.kanunlar'),
    ('kararnameler',  'oyun.kararnameler',  'select count(*)::text from oyun.kararnameler'),
    ('mesajlar',      'oyun.mesajlar',      'select count(*)::text from oyun.mesajlar'),
    ('ozel',          'oyun.ozel', 'select count(*)::text from oyun.ozel'),
    ('vaatler',       'oyun.vaatler',       'select count(*)::text from oyun.vaatler'),
    ('itibar',        'oyun.itibar',        'select count(*)::text from oyun.itibar'),
    ('mulkler',       'oyun.mulkler',       'select md5(coalesce(string_agg(id||''|''||user_id||''|''||bedel, '','' order by id), '''')) from oyun.mulkler'),
    ('ulke',          'oyun.ulke',          'select md5(coalesce(string_agg(hazine||''|''||vergi||''|''||asgari, '',''), '''')) from oyun.ulke'),
    ('iller',         'oyun.il_durum',      'select md5(coalesce(string_agg(il_id||''|''||gelisim||''|''||coalesce(kasa,0), '','' order by il_id), '''')) from oyun.il_durum'),
    ('satin_alma',    'oyun.satin_almalar', 'select count(*)::text from oyun.satin_almalar'),
    ('referandum',    'oyun.referandumlar', 'select count(*)::text from oyun.referandumlar'),
    ('duzenlemeler',  'oyun.duzenlemeler',  'select md5(coalesce(string_agg(kod||''|''||deger||''|''||kaynak, '','' order by kod), '''')) from oyun.duzenlemeler'),
    ('banka',         'oyun.banka_musteri', 'select md5(coalesce(string_agg(user_id||''|''||vadesiz||''|''||kredi_notu, '','' order by user_id), '''')) from oyun.banka_musteri'),
    ('vadeli',        'oyun.vadeli',        'select md5(coalesce(string_agg(id||''|''||user_id||''|''||anapara||''|''||durum, '','' order by id), '''')) from oyun.vadeli'),
    ('krediler',      'oyun.krediler',      'select md5(coalesce(string_agg(id||''|''||user_id||''|''||kalan||''|''||durum, '','' order by id), '''')) from oyun.krediler'),
    ('teskilat',      'oyun.parti_teskilat','select count(*)::text from oyun.parti_teskilat'),
    ('moderator',     'oyun.moderatorler',  'select md5(coalesce(string_agg(user_id||''|''||array_to_string(yetkiler, '';''), '','' order by user_id), '''')) from oyun.moderatorler')
  ) x(ad, tablo, sorgu) loop
    if to_regclass(r.tablo) is null then continue; end if;
    begin
      execute r.sorgu into v;
      sonuc := sonuc || jsonb_build_object(r.ad, v);
    exception when undefined_column or undefined_table then null;   -- eski sürümde olmayan sütun: karşılaştırmaya girmez
    end;
  end loop;
  return sonuc;
end $$;

-- Yedek: oyun şemasındaki bütün tabloların anlık kopyası (ayrı şemada; internete açık değildir). Son 5 yedek tutulur.
create or replace function oyun.yedek_al(p_etiket text) returns text language plpgsql as $$
declare sema text := 'yedek_' || to_char(clock_timestamp() at time zone 'Europe/Istanbul', 'YYYYMMDD_HH24MISS_US'); t record; eski record;
begin
  execute format('create schema %I', sema);
  execute format('revoke all on schema %I from public', sema);
  execute format('comment on schema %I is %L', sema, coalesce(p_etiket, 'yedek') || ' · ' || to_char(clock_timestamp() at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'));
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind in ('r','p') loop
    execute format('create table %I.%I as table oyun.%I', sema, t.relname, t.relname);
  end loop;
  for eski in select nspname from pg_namespace where nspname like 'yedek\_%' order by nspname desc offset 5 loop
    execute format('drop schema %I cascade', eski.nspname);
  end loop;
  return sema;
end $$;

create or replace function oyun.yedekler() returns table(sema text, aciklama text) language sql stable as $$
  select n.nspname::text, obj_description(n.oid, 'pg_namespace') from pg_namespace n where n.nspname like 'yedek\_%' order by n.nspname desc
$$;

create or replace function oyun.guncelleme_basla(p_surum text, p_aciklama text default null) returns void language plpgsql as $$
declare y text; var boolean := false;
begin
  if to_regclass('oyun.profiller') is not null then
    execute 'select exists (select 1 from oyun.profiller)' into var;
  end if;
  if var then y := oyun.yedek_al('Güncelleme öncesi ' || p_surum); end if;
  insert into oyun.surumler(surum, aciklama, yedek, parmak_once) values (p_surum, p_aciklama, y, oyun.parmak_izi());
end $$;
