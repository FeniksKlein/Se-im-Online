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
  for r in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where (n.nspname, p.proname) in (
             ('oyun','emlak_bedel'),('oyun','emlak_bolge_fiyat'),('oyun','emlak_bolge_kira'),('oyun','emlak_devri_vergi_sifirla'),
             ('oyun','emlak_efektif_oran'),('oyun','emlak_fiyat'),('oyun','emlak_haftalik_oran'),('oyun','emlak_haftalik_tick'),
             ('oyun','emlak_il_bilgi'),('oyun','emlak_il_fiyat'),('oyun','emlak_il_stok'),('oyun','emlak_kanun_etki'),
             ('oyun','emlak_kanun_yururluk'),('oyun','emlak_kapasite'),('oyun','emlak_kira'),('oyun','emlak_oran'),
             ('oyun','emlak_sehir_fiyat'),('oyun','emlak_sehir_kapasite'),('oyun','emlak_stok'),('oyun','emlak_vergi_borclandir'),
             ('oyun','emlak_vergi_kanun_uygula'),('oyun','emlak_vergi_kanun_yururluk'),('oyun','emlak_vergi_kanun_yururluk_trigger'),
             ('oyun','emlak_vergi_oran'),('oyun','emlak_vergi_oran_il'),('oyun','emlak_vergi_orani'),('oyun','emlak_vergi_tahsil'),
             ('oyun','emlak_vergi_tick'),('oyun','emlak_vergisi_oran'),('oyun','kanun_karar_yeter'),('oyun','mulk_il_fiyat'),
             ('public','belediye_emlak_vergi_ayarla'),('public','belediye_emlak_vergisi'),('public','belediye_emlak_vergisi_ayarla'),
             ('public','emlak_belediye_durum'),('public','emlak_belediye_oran'),('public','emlak_belediye_oran_ayarla'),
             ('public','emlak_il_katalog'),('public','emlak_il_listesi'),('public','emlak_il_piyasa'),('public','emlak_il_rehberi'),
             ('public','emlak_il_stok'),('public','emlak_iller'),('public','emlak_kanun_teklif'),('public','emlak_piyasa'),
             ('public','emlak_sehirler'),('public','emlak_vergi_belediye'),('public','emlak_vergi_belediye_ayar'),
             ('public','emlak_vergi_belediye_ayarla'),('public','emlak_vergi_bilgi'),('public','emlak_vergi_durum'),
             ('public','emlak_vergi_kanun_teklif'),('public','emlak_vergi_oranlari'),('public','emlak_vergi_yasa_teklif'),
             ('public','emlak_vergisi_kanun_teklif'),('public','mulk_katalog'),('public','mulk_satin_al_il'),('public','mulk_sehir_satin_al')) loop
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
delete from oyun.il_duzenleme where kod in ('emlak_haftalik_oran','emlak_mulk','emlak_mulk_carpan','emlak_ulusal_oran','emlak_vergi_carpan','emlak_vergi_ulke','yatirim_emlak_vergisi');
delete from oyun.duzenlemeler where kod in ('emlak_haftalik_oran','emlak_mulk','emlak_mulk_carpan','emlak_ulusal_oran','emlak_vergi_carpan','emlak_vergi_ulke','yatirim_emlak_vergisi');
delete from oyun.duzenleme_tanim where kod in ('emlak_haftalik_oran','emlak_mulk','emlak_mulk_carpan','emlak_ulusal_oran','emlak_vergi_carpan','emlak_vergi_ulke','yatirim_emlak_vergisi');
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
