-- =====================================================================
--  KALICILIK (son): bütünlük kontrolü, silme koruması, sürüm bilgisi, sahibin sıfırlama/geri yükleme araçları
-- =====================================================================
alter table oyun.ayarlar add column if not exists son_uygulama text not null default '0';
alter table oyun.ayarlar add column if not exists min_uygulama text not null default '0';

-- TRUNCATE koruması (tablo bazında): oyun tabloları yalnızca sahibinin sıfırlama/geri yükleme işlemiyle boşaltılabilir
create or replace function oyun.bosaltma_korumasi() returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('oyun.sifirlama', true), '') <> 'evet' then
    raise exception 'Oyun verileri korunuyor: % tablosu boşaltılamaz. Oyunu sıfırlamak için: select oyun.oyunu_sifirla(''OYUNU SIFIRLA'');', tg_table_name;
  end if;
  return null;
end $$;

-- DROP TABLE / DROP COLUMN koruması (olay tetikleyicisi; Supabase izin vermezse atlanır, TRUNCATE koruması yine çalışır)
create or replace function oyun.silme_korumasi() returns event_trigger language plpgsql as $$
declare o record;
begin
  if coalesce(current_setting('oyun.sifirlama', true), '') = 'evet' or coalesce(current_setting('oyun.tablo_kaldir', true), '') = 'evet' then return; end if;
  for o in select * from pg_event_trigger_dropped_objects() loop
    if o.schema_name = 'oyun' and o.object_type in ('table','table column') and not o.is_temporary then
      raise exception 'Oyun verileri korunuyor: % (%) silinemez. Güncellemeler yalnızca ekleme yapar.', o.object_identity, o.object_type;
    end if;
  end loop;
end $$;

create or replace function oyun.koruma_kur() returns void language plpgsql as $$
declare t record;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind = 'r' loop
    execute format('drop trigger if exists bosaltma_korumasi on oyun.%I', t.relname);
    execute format('create trigger bosaltma_korumasi before truncate on oyun.%I for each statement execute function oyun.bosaltma_korumasi()', t.relname);
  end loop;
  begin
    if not exists (select 1 from pg_event_trigger where evtname = 'oyun_silme_korumasi') then
      create event trigger oyun_silme_korumasi on sql_drop execute function oyun.silme_korumasi();
    end if;
  exception when insufficient_privilege or feature_not_supported then
    raise notice 'Bilgi: DROP koruması (olay tetikleyicisi) bu sunucuda kurulamadı; TRUNCATE koruması ve güncelleme bütünlük kontrolü etkin.';
  end;
end $$;

-- Güncellemenin sonu: oyuncu verisi değiştiyse her şey geri alınır
create or replace function oyun.guncelleme_bitti() returns jsonb language plpgsql as $$
declare s oyun.surumler; once jsonb; sonra jsonb := oyun.parmak_izi(); k text; farklar text := '';
begin
  select * into s from oyun.surumler where bitis is null order by id desc limit 1;
  if s.id is null then raise exception 'guncelleme_basla çağrılmadan guncelleme_bitti çağrıldı.'; end if;
  once := coalesce(s.parmak_once, '{}');
  -- hiç oyuncu yokken (ilk kurulum ya da sahibin sıfırlaması) başlangıç verileri yüklenir; korunacak oyuncu verisi yoktur
  if coalesce(once ->> 'oyuncu', '0') = '0' then once := '{}'; end if;
  for k in select jsonb_object_keys(once) loop
    if sonra ->> k is distinct from once ->> k then farklar := farklar || ' ' || k; end if;
  end loop;
  if farklar <> '' then
    raise exception 'GÜNCELLEME DURDURULDU: bu güncelleme oyuncu verisini değiştirecekti (%). Hiçbir değişiklik uygulanmadı; oyun olduğu gibi duruyor.', btrim(farklar);
  end if;
  update oyun.surumler set bitis = clock_timestamp(), parmak_sonra = sonra where id = s.id;
  update oyun.ayarlar set son_uygulama = s.surum where id = 1;
  perform oyun.koruma_kur();
  return jsonb_build_object('surum', s.surum, 'yedek', s.yedek, 'kontrol', 'oyuncu verisi değişmedi', 'oyuncu', sonra ->> 'oyuncu', 'aktif_makam', sonra ->> 'aktif_makam');
end $$;

-- Uygulamanın sürüm kontrolü: eski uygulama sunucuyla uyumsuz hâle gelirse "güncelle" ekranı gösterir
create or replace function public.surum() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select jsonb_build_object('sunucu', (select surum from oyun.surumler where bitis is not null order by id desc limit 1),
                            'son_uygulama', a.son_uygulama, 'min_uygulama', a.min_uygulama)
  from oyun.ayarlar a where a.id = 1
$$;
revoke all on function public.surum() from public;
grant execute on function public.surum() to anon, authenticated;

-- Yönetici: eski uygulamaları zorunlu güncellemeye yönlendir
create or replace function public.admin_min_uygulama(p_surum text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare y oyun.profiller := oyun.yonetici_zorunlu();
begin
  if p_surum !~ '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9]+$' and p_surum <> '0' then raise exception 'Sürüm biçimi YYYY.AA.GG-N olmalı.'; end if;
  update oyun.ayarlar set min_uygulama = p_surum where id = 1;
  return public.surum();
end $$;
revoke all on function public.admin_min_uygulama(text) from public, anon;
grant execute on function public.admin_min_uygulama(text) to authenticated;

-- ---------------------------------------------------------------------
-- SAHİBİN ARAÇLARI (yalnızca Supabase SQL Editor'den; uygulamadan çağrılamaz)
-- ---------------------------------------------------------------------
-- Katalog tabloları sıfırlamada korunur (iller, bakanlıklar, icraat/vaat/kural katalogları, ayarlar, sürümler)
create or replace function oyun.katalog_tablo(t text) returns boolean language sql immutable as $$
  select t in ('ayarlar','iller','bakanliklar','icraatlar','vaat_turleri','duzenleme_tanim','belediye_hizmetleri','belediye_yatirimlari',
               'paketler','gecici_eposta','surumler','yonetici_kimlik')
$$;

-- Oyunu sıfırlar: önce yedek alır, sonra oyun dünyasını boşaltır. Oyuncu hesapları (giriş bilgileri) kalır;
-- herkes yeniden profil oluşturur. Ardından supabase-kurulum.sql bir kez daha çalıştırılmalıdır (başlangıç verileri).
create or replace function oyun.oyunu_sifirla(p_onay text) returns text language plpgsql as $$
declare y text; liste text;
begin
  if p_onay is distinct from 'OYUNU SIFIRLA' then
    raise exception 'Oyunu sıfırlamak için tam olarak şunu yaz: select oyun.oyunu_sifirla(''OYUNU SIFIRLA'');';
  end if;
  y := oyun.yedek_al('Sıfırlama öncesi');
  perform set_config('oyun.sifirlama', 'evet', true);
  select string_agg(format('oyun.%I', c.relname), ', ') into liste
    from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind = 'r' and not oyun.katalog_tablo(c.relname);
  execute 'truncate ' || liste || ' restart identity cascade';
  return format('Oyun sıfırlandı. Yedek: %s. Şimdi supabase-kurulum.sql dosyasını bir kez daha çalıştır.', y);
end $$;

-- Bir yedeğe geri döner (o anki durumun da yedeği alınır). Sütunu yedekte olmayan yeni tablolar boş kalır.
create or replace function oyun.yedekten_don(p_sema text, p_onay text) returns text language plpgsql as $$
declare y text; t record; liste text; kalan text[]; tur int := 0; sutunlar text; ok boolean; n int;
begin
  if p_onay is distinct from 'GERİ YÜKLE' then
    raise exception 'Geri yüklemek için: select oyun.yedekten_don(''%'', ''GERİ YÜKLE'');', p_sema;
  end if;
  if p_sema !~ '^yedek_' or not exists (select 1 from pg_namespace where nspname = p_sema) then raise exception 'Yedek bulunamadı: %', p_sema; end if;
  y := oyun.yedek_al('Geri yükleme öncesi');
  perform set_config('oyun.sifirlama', 'evet', true);
  select array_agg(c.relname::text) into kalan from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'oyun' and c.relkind = 'r' and c.relname <> 'surumler'
     and exists (select 1 from pg_class c2 join pg_namespace n2 on n2.oid = c2.relnamespace where n2.nspname = p_sema and c2.relname = c.relname);
  select string_agg(format('oyun.%I', x), ', ') into liste from unnest(kalan) x;
  execute 'truncate ' || liste || ' cascade';
  foreach liste in array kalan loop execute format('alter table oyun.%I disable trigger user', liste); end loop;
  -- yabancı anahtar sırası bilinmediği için birkaç turda yükle
  while array_length(kalan, 1) > 0 and tur < 10 loop
    tur := tur + 1;
    foreach liste in array kalan loop
      select string_agg(format('%I', a.attname), ', ') into sutunlar
        from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'oyun' and c.relname = liste and a.attnum > 0 and not a.attisdropped and a.attgenerated = ''
         and exists (select 1 from pg_attribute b join pg_class c2 on c2.oid = b.attrelid join pg_namespace n2 on n2.oid = c2.relnamespace
                     where n2.nspname = p_sema and c2.relname = liste and b.attname = a.attname and not b.attisdropped);
      ok := true;
      begin
        -- overriding system value: "generated always as identity" sütunlu tablolar da yedekten dönebilsin
        execute format('insert into oyun.%I (%s) overriding system value select %s from %I.%I', liste, sutunlar, sutunlar, p_sema, liste);
      exception when foreign_key_violation then ok := false;
      end;
      if ok then kalan := array_remove(kalan, liste); end if;
    end loop;
  end loop;
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind = 'r' loop
    execute format('alter table oyun.%I enable trigger user', t.relname);
  end loop;
  if array_length(kalan, 1) > 0 then raise exception 'Geri yükleme tamamlanamadı (%); hiçbir şey değişmedi.', array_to_string(kalan, ', '); end if;
  -- kimlik sayaçlarını yedekteki en büyük değere getir
  for t in select s.relname seq, tc.relname tablo, a.attname sutun from pg_class s
             join pg_depend d on d.objid = s.oid and d.deptype in ('a','i') join pg_class tc on tc.oid = d.refobjid
             join pg_attribute a on a.attrelid = tc.oid and a.attnum = d.refobjsubid join pg_namespace n on n.oid = tc.relnamespace
            where s.relkind = 'S' and n.nspname = 'oyun' loop
    execute format('select coalesce(max(%I), 0) from oyun.%I', t.sutun, t.tablo) into n;
    if n > 0 then execute format('select setval(%L, %s)', 'oyun.' || t.seq, n); end if;
  end loop;
  return format('%s yedeğine dönüldü. Dönüş öncesi durumun yedeği: %s', p_sema, y);
end $$;

revoke all on function oyun.oyunu_sifirla(text), oyun.yedekten_don(text, text), oyun.yedek_al(text) from public;
