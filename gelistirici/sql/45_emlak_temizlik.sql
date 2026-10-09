-- =====================================================================
--  45 · 9 EKİM DENEME GEÇİŞLERİNİN TEMİZLİĞİ
--  9 Ekim'de aynı emlak/meclis isteği için birbirinin yerine geçen ~20 deneme migration'ı üretildi.
--  Canlıda hangileri çalıştırılmış olursa olsun bu modül onların bıraktığı tetikleyicileri,
--  eski satın alma kapılarını ve ölü kuralları kaldırır; geçerli tanım 43 ve 44 modülleridir.
--  Temiz bir kurulumda hiçbir şey yapmaz.
-- =====================================================================
do $$
declare r record;
begin
  -- 1) Kanunlar ve mülk tablosundaki deneme tetikleyicileri (geçerli olan yalnız mulk_devir_vergi)
  for r in select tgname, tgrelid::regclass rel from pg_trigger
           where not tgisinternal and tgrelid in ('oyun.kanunlar'::regclass, 'oyun.yatirim_mulkleri'::regclass)
             and tgname like 'emlak%' loop
    execute format('drop trigger if exists %I on %s', r.tgname, r.rel);
  end loop;

  -- 2) Deneme sürümlerinde kalan, yeni stok/fiyat kuralını atlayabilecek fonksiyonlar
  --    (geçerli emlak_* fonksiyonları yalnız emlak_pazarlik_* ve _emlak_pazarlik_tamamla)
  for r in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('oyun','public')
             and ((p.proname ~ '^(emlak_|belediye_emlak_vergi)' and p.proname !~ '^emlak_pazarlik')
                  or p.proname in ('kanun_karar_yeter','mulk_il_fiyat','mulk_katalog','mulk_satin_al_il','mulk_sehir_satin_al')) loop
    execute format('drop function if exists %s cascade', r.f);
  end loop;

  -- 2b) Eski uygulamanın çağırdığı tek parametreli mulk_satin_al dışındaki deneme kopyaları
  for r in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'mulk_satin_al' and p.pronargs <> 1 loop
    execute format('drop function if exists %s', r.f);
  end loop;

  -- 3) Deneme sütunlarındaki NOT NULL kısıtları yeni mülk eklemeyi engellemesin
  for r in select attname from pg_attribute
           where attrelid = 'oyun.yatirim_mulkleri'::regclass and attnum > 0 and not attisdropped and attnotnull
             and attname in ('emlak_vergi_son','emlak_vergi_sonraki','sonraki_emlak_vergi','sonraki_vergi','vergi_borcu','toplam_vergi') loop
    execute format('alter table oyun.yatirim_mulkleri alter column %I drop not null', r.attname);
  end loop;
end $$;

-- 4) Deneme sürümlerinin bekleyen "emlak vergisi" serbest kanun teklifleri düşer (artık "Kural düzenlemesi" kanunuyla değişir)
update oyun.kanunlar set durum = 'dustu', sonuc_at = oyun.simdi(),
  sonuc_metin = 'Teklif, mülk vergisi sisteminin yenilenmesiyle düştü. Haftalık mülk vergisi artık "Kural düzenlemesi" kanunuyla değiştirilir.'
where tur = 'serbest' and durum in ('gorusmede','oylamada','cb_onayinda','israr')
  and (veri ->> 'ozel_tur' = 'emlak_vergisi' or baslik ilike '%emlak vergi%');

-- 5) Deneme kurallarının kalıntıları (geçerli kodlar: mulk_vergi_ulusal, mulk_vergi_yerel)
--    ('emlak' = ildeki herkesin günlük emlak vergisi, asıl kuraldır; ona dokunulmaz)
delete from oyun.il_duzenleme where kod ~ '^(emlak_|yatirim_emlak)';
delete from oyun.duzenlemeler where kod ~ '^(emlak_|yatirim_emlak)';
delete from oyun.duzenleme_tanim where kod ~ '^(emlak_|yatirim_emlak)';
delete from oyun.yasa_ekonomi_ayar where kod = 'emlak_haftalik_baz';

-- 6) Bir deneme sürümü Meclis ölçeğini sabit 600'e bağlamıştı; asıl tanım (39) geri yüklenir.
create or replace function oyun.meclis_olcek_hesap(t timestamptz) returns jsonb
language plpgsql stable set search_path = '' as $$
declare a numeric := (select meclis_olcek from oyun.ayarlar where id = 1);
        anayasal int := coalesce((select round(deger)::int from oyun.anayasa where kod = 'milletvekili_sayisi'), 600);
        aktif int := (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '14 days');
        n int;
begin
  n := case when coalesce(a, 0) <= 0 then anayasal else least(anayasal, greatest(81, ceil(aktif * a)::int)) end;
  return jsonb_build_object('aktif', aktif, 'sandalye', n, 'anayasal', anayasal, 'olcek', a);
end $$;
