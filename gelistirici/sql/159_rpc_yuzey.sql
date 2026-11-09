-- =====================================================================
--  159 · RPC YÜZEYİ: varsayılan kapalı, istemci izin listesi, sabit search_path
--
--  Neden 14_guvenlik.sql değil: 06_yetkiler ve sonraki modüller fonksiyon
--  fonksiyon grant eder. Bu dosya kurulum işleminin EN SONUNDA çalışır
--  (sql_birlestir.js, kalicilik_son.sql ve guncelleme_bitti'den sonra) ki
--  önceki grant'lar geri alınsın.
--
--  Karar:
--    • İnternete açık şema public'tir (01_sema: oyun şeması açılmaz).
--    • public ve oyun'daki bütün fonksiyonlardan PUBLIC / anon / authenticated
--      EXECUTE alınır.
--    • authenticated yalnızca istemcinin çağırdığı adlara (aşağıdaki dizi)
--      yeniden açılır. Ad canlıda yoksa atlanır.
--    • anon yalnızca giriş ekranından önce okunan surum ve uygulama_ayar.
--    • service_role (edge function, ödeme, push, kur kaydı) public ve oyun'daki
--      fonksiyonları çalıştırabilir. Bu anahtar uygulamada yoktur.
--    • Paralel PR #38: oyun.canli_sinyal_gorur(text) RLS koşuludur, authenticated
--      açık kalır. oyun.canli_sinyal(text) ve tetikleyici istemciye kapalıdır.
--      PR #40: public.reklam_hazirla() authenticated listesindedir;
--      public.reklam_ssv_isle(jsonb) yalnız service_role. Bu dalda fonksiyon
--      yoksa grant atlanır.
--    • admin_* ayrı şemaya taşınmadı: yönetici paneli aynı uygulamadan, oyuncunun
--      oturumuyla çağırır. Her admin_* gövdesi oyun.yetki_zorunlu veya
--      oyun.yonetici_zorunlu ile açılır (test bunu kaynakta doğrular).
--      İstemcinin çağırmadığı admin_* adları authenticated'a hiç verilmez.
--    • Tetikleyici, cron (postgres) ve security definer iç çağrıları sahip
--      olarak çalışır; EXECUTE listesine bağlı değildir.
--    • search_path'i boş olan fonksiyonlara sabit yol yazılır:
--      oyun, public, extensions, pg_temp. Zaten ayarlı olanlara dokunulmaz
--      (örneğin search_path = '' ile tam nitelikli yazılmış fonksiyonlar).
--    • Bundan sonra postgres/supabase_admin'in oluşturduğu fonksiyonlar
--      anon ve authenticated'a kendiliğinden açılmaz. Yeni bir RPC için
--      hem bu diziyi güncellemek hem authenticated'a grant gerekir.
--
--  Canlı veritabanına bu dosya tek başına da uygulanabilir (migrations kopyası).
--  Oyuncu verisini değiştirmez. Tekrar çalıştırmak güvenlidir.
-- =====================================================================

-- Gelecekteki fonksiyonlar: PUBLIC varsayılanı ve Supabase'in anon/authenticated
-- varsayılanı kalkar; service_role (sunucu) açık kalır.
-- Şema düzeyindeki REVOKE, Postgres'in fonksiyonlara gömülü PUBLIC hakkını silmez
-- (şema ACL'i bu varsayılanın ÜSTÜNE eklenir). Kaldırma genel (şemasız) olmalıdır.
do $varsayilan$
declare r text;
begin
  foreach r in array array['postgres', 'supabase_admin'] loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('alter default privileges for role %I revoke execute on functions from PUBLIC, anon, authenticated', r);
      execute format('alter default privileges for role %I in schema public revoke execute on functions from PUBLIC, anon, authenticated', r);
      execute format('alter default privileges for role %I in schema oyun revoke execute on functions from PUBLIC, anon, authenticated', r);
      if exists (select 1 from pg_roles where rolname = 'service_role') then
        execute format('alter default privileges for role %I in schema public grant execute on functions to service_role', r);
        execute format('alter default privileges for role %I in schema oyun grant execute on functions to service_role', r);
      end if;
    end if;
  end loop;
end
$varsayilan$;

-- Yeni fonksiyon unutulursa search_path'i yine sabitlensin. Kurulumda
-- oluşturulamazsa (yetki) mevcut fonksiyonlar aşağıdaki döngüyle düzelir.
create or replace function oyun.fn_search_path_sabitle()
returns event_trigger
language plpgsql
security definer
set search_path = pg_catalog
as $sabit$
declare
  cmd record;
  cfg text[];
begin
  for cmd in
    select *
    from pg_event_trigger_ddl_commands()
    where command_tag = 'CREATE FUNCTION'
      and schema_name in ('public', 'oyun')
      and not coalesce(in_extension, false)
  loop
    select p.proconfig into cfg
    from pg_proc p
    where p.oid = cmd.objid;
    if cfg is null or not exists (select 1 from unnest(cfg) c where c like 'search_path=%') then
      begin
        execute format('alter function %s set search_path = oyun, public, extensions, pg_temp', cmd.objid::regprocedure);
      exception when others then
        raise warning 'search_path ayarlanamadı (%): %', cmd.object_identity, sqlerrm;
      end;
    end if;
  end loop;
end
$sabit$;

revoke all on function oyun.fn_search_path_sabitle() from public, anon, authenticated;

do $tetik$
begin
  if exists (select 1 from pg_event_trigger where evtname = 'oyun_fn_search_path') then
    drop event trigger oyun_fn_search_path;
  end if;
  create event trigger oyun_fn_search_path
    on ddl_command_end
    when tag in ('CREATE FUNCTION')
    execute function oyun.fn_search_path_sabitle();
exception when insufficient_privilege or feature_not_supported then
  raise notice 'search_path olay tetikleyicisi kurulamadı; mevcut fonksiyonlar yine de ayarlanır.';
end
$tetik$;

-- Mevcut fonksiyonlar: eksik search_path sabitlenir. Uzantı fonksiyonlarına dokunulmaz.
do $yol$
declare r record;
begin
  for r in
    select p.oid::regprocedure as imza
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'oyun')
      and p.prokind in ('f', 'p')
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
      and not exists (
        select 1 from unnest(coalesce(p.proconfig, array[]::text[])) c
        where c like 'search_path=%'
      )
  loop
    begin
      execute format('alter function %s set search_path = oyun, public, extensions, pg_temp', r.imza);
    exception when others then
      raise warning 'search_path atlandı (%): %', r.imza, sqlerrm;
    end;
  end loop;
end
$yol$;

-- @@rpc_yuzey_izin_bas@@
-- authenticated izin listesi (893 ad). Kaynak: istemci çağrıları
-- (gelistirici/www, www, docs), önbellek listesi, eski mağaza uygulaması
-- ve PR #40 reklam_hazirla (bu dalda fonksiyon henüz yok; dizi onu da açar).
do $izin$
declare
  izin text[] := array[
    'sokak_talep_sec', 'sokak_talepli_baslat', 'sokak_soz_teklif', 'sokak_soz_oyla', 'sokak_uzlasma_panel', 'sokak_hukumet_panel', 'sokak_hukumet_karar', 'sokak_karar_yanit', 'sokak_eylemler', 'sokak_eylem_baslat', 'sokak_destek', 'sokak_yanit',
    'aday_ol', 'adaylik_geri_cek', 'adaylik_vazgec', 'adayliklarim', 'adliye_af_cikar', 'adliye_beyan_ver',
    'adliye_dava_ac', 'adliye_dava_ek', 'adliye_detay', 'adliye_durum', 'adliye_hakim_al', 'adliye_hakim_ata',
    'adliye_hakim_istifa', 'adliye_istinaf', 'adliye_juri_oy', 'adliye_kurum_dava_ac', 'adliye_kurum_listesi', 'adliye_mahkeme',
    'adliye_musadere_durum', 'adliye_musadere_oy', 'adliye_oy_ver', 'adliye_secim_itiraz_ac', 'adliye_secim_itiraz_karar', 'adliye_siyasi_bilgi',
    'adliye_sozcu_ata', 'adliye_tazminat_davasi_ac', 'adliye_tazminat_oy', 'adliye_temsil_yetkisi', 'adliye_yargic_oner', 'adliye_yorum_yaz',
    'admin_duyuru', 'admin_hesap_onay', 'admin_islem', 'admin_kayit_basvurulari', 'admin_kayit_karar', 'admin_kurallar',
    'admin_masak', 'admin_masak_karar', 'admin_min_uygulama', 'admin_mod_kayit', 'admin_moderator_ayarla', 'admin_moderatorler',
    'admin_oyuncu', 'admin_ozet', 'admin_sikayet_karar', 'admin_sikayetler', 'admin_supheler', 'admin_transferler_sayfa',
    'ajans_anket_cevap', 'ajans_anket_yayimla', 'ajans_ayarla', 'ajans_gundem', 'ajans_haberler', 'ajans_kur',
    'ajans_kur_ilde', 'ajans_liste', 'ajans_puanla', 'ajans_siparis', 'ajans_yonetim', 'akis_begen',
    'akis_gundem', 'akis_konu', 'akis_liste', 'akis_sikayet_et', 'akis_sil', 'akis_tepki',
    'akis_yanit_yaz', 'akis_yaz', 'aktarim_hakki', 'anket_durum', 'anket_oyla', 'arsa_teklif',
    'avukat_akademiye_katil', 'avukat_buro_ac', 'avukat_buro_davet', 'avukat_buro_davet_cevap', 'avukat_buro_davetler', 'avukat_dava_durum',
    'avukat_durum', 'avukat_iller', 'avukat_istinaf', 'avukat_karsi_teklif', 'avukat_kontenjan_ayarla', 'avukat_pazarlik_karar',
    'avukat_pazarlik_liste', 'avukat_pratik_gonder', 'avukat_prim_tahsil', 'avukat_primlerim', 'avukat_ruhsat_basvur', 'avukat_ruhsat_birak',
    'avukat_ruhsat_yenile', 'avukat_savunma_ver', 'avukat_sinav_gonder', 'avukat_teklif_karar', 'avukat_teklif_ver', 'avukat_vekalet_iptal',
    'ay_raporu', 'aym_basvur', 'aym_gorus', 'aym_oy_ver', 'bagimsiz_aday_ol', 'bagimsiz_adaylik_geri_cek',
    'bagis_yap', 'bakan_adaylari', 'bakan_ata', 'bakan_gorevden_al', 'bakan_soru_sor', 'bakan_soru_yanit',
    'bakan_sorulari', 'bakan_teklif_yanit', 'bakan_tekliflerim', 'bakanlik_aciklama_yap', 'bakanlik_etkinlik_duzenle', 'bakanlik_etkinlik_katil',
    'bakanlik_etkinlikleri', 'bakanlik_gorev_odul_al', 'bakanlik_hazineye_iade', 'bakanlik_masasi', 'bakanlik_odenek_aktar', 'bakanlik_odenek_geri_cek',
    'bakanlik_odenek_iste', 'bakanlik_odenek_karar', 'bakanlik_paneli', 'bakanlik_panellerim', 'bakanlik_saha_ziyareti', 'bakanlik_teklif_durumlari',
    'balkon_durum', 'balkon_konus', 'banka', 'banka_alici', 'banka_cek', 'banka_dibs_al',
    'banka_dibs_boz', 'banka_faiz_belirle', 'banka_fast', 'banka_genel_mudurluk', 'banka_hesaplar_arasi', 'banka_kar_dagit',
    'banka_politika_kaydet', 'banka_risk_profili', 'banka_sermaye_azalt', 'banka_sermaye_koy', 'banka_sube', 'banka_yatir',
    'banka_yonetilen_liste', 'banka_yonetim_ayar_kaydet', 'banka_yonetim_panel', 'banka_yonettiklerim', 'baro_aday_ol', 'baro_adaylik_cekil',
    'baro_adli_yardim_iste', 'baro_adli_yardim_karar', 'baro_aidat_ode', 'baro_ayril', 'baro_dava_bilgi', 'baro_durum',
    'baro_gonullu', 'baro_kaydol', 'baro_mesaj_gonder', 'baro_mesaj_sil', 'baro_oy_ver', 'baro_sikayet_et',
    'baro_sikayet_karar', 'basarimlar', 'basin', 'basin_tiraj', 'bekleyen_islerim', 'bel_aday_destek', 'bel_destek_durum',
    'bel_destek_geri_cek', 'bel_ruhsat_basvur', 'bel_ruhsat_karar', 'bel_ruhsat_merkezi', 'bel_ruhsat_tarife_ayarla', 'belediye_ayar',
    'belediye_bina_islem', 'belediye_detay_paneli', 'belediye_duzenle', 'belediye_ekonomi_programi', 'belediye_emlak_ozet', 'belediye_hizmet',
    'belediye_is_ihale_ac', 'belediye_is_iptal', 'belediye_is_pazar', 'belediye_is_tamamla', 'belediye_is_teklif_ver', 'belediye_karnesi',
    'belediye_kredi_al', 'belediye_kredi_kapat', 'belediye_kriz_karar', 'belediye_paneli', 'belediye_sehir_paneli', 'belediye_tahvil_al',
    'belediye_tahvil_ihrac', 'belediye_tahvilleri', 'belediye_yatirim', 'belediye_yatirim_ekonomi_panel', 'beyanname_kaydet', 'bildirim_ayar_kaydet',
    'bildirim_hedefleri', 'bildirim_kutusu', 'bildirim_yayin_ozet', 'bildirim_yeniler', 'borc_affi_kanun_teklif', 'borc_affi_karar',
    'borc_affi_onizle', 'borsa_al', 'borsa_iptal', 'borsa_liste', 'borsa_sat', 'borsa_sirket',
    'bos_makam_firsatlari', 'bos_makamlar', 'butce_raporu', 'canli_yayin_ac', 'canli_yayin_bitir', 'canli_yayin_davet',
    'canli_yayin_davet_yanit', 'canli_yayin_detay', 'canli_yayin_oyla', 'canli_yayin_tepki', 'canli_yayin_yaz', 'canli_yayinlar',
    'cb_aday_belirle', 'cb_destek', 'cb_destek_secenekleri', 'cb_erken_secim_karar', 'cb_kampanya_bilgi', 'cb_kampanya_etkinlik',
    'cb_kampanya_kaydet', 'cb_seslenisler', 'cb_toren_durum', 'cb_ulusa_seslen', 'cb_yardimcilari', 'cb_yardimcisi_adaylari',
    'cb_yardimcisi_ata', 'cb_yardimcisi_bakan_denetim', 'cb_yardimcisi_gorevden_al', 'cb_yardimcisi_teklif_geri', 'cb_yardimcisi_tekliflerim', 'cb_yardimcisi_yanit',
    'cb_yemin_et', 'cb_yrd_alan_ayarla', 'cb_yrd_dosya_ac', 'cb_yrd_dosya_karar', 'cb_yrd_dosya_yanitla', 'cb_yrd_panel',
    'cb_yrd_toplanti_oyla', 'cb_yrd_vekalet_ayarla', 'cek_ek_panel', 'cek_hedef_ara', 'cek_iptal_islem', 'cek_iptal_panel',
    'cek_iskonto_islem', 'cek_islem', 'cek_panel', 'cek_tazminat_ode', 'cek_ticaret_islem', 'cek_ticaret_panel',
    'cek_toptan_islem', 'cek_toptan_panel', 'cevrimici_oyuncular', 'cihaz_kaydet', 'cihaz_sil', 'cimer',
    'cimer_basvur', 'cimer_degerlendir', 'cimer_karne', 'cimer_yanitla', 'cuzdan_hareketleri', 'denge_paneli',
    'dernek_akis', 'dernek_ayril', 'dernek_bagis', 'dernek_baskan_devret', 'dernek_detay', 'dernek_etkinlik_ac',
    'dernek_eylem', 'dernek_eylem_oku', 'dernek_faaliyetler', 'dernek_gonullu_katil', 'dernek_kampanya_ac', 'dernek_kampanya_bagis',
    'dernek_kampanya_vitrin', 'dernek_katil', 'dernek_kur', 'dernek_program_baslat', 'dernek_program_katalog', 'dernek_program_katil',
    'dernek_program_ozet', 'dernek_proje_fiyatlar', 'dernek_proje_yap', 'dernek_protesto_katil', 'dernek_sube_ac', 'dernek_uye_destek_basvur',
    'dernek_uye_destek_karar', 'dernek_uye_destek_liste', 'dernek_yonetim_ata', 'dernek_ziyaret_taleplerim', 'dernek_ziyaret_tamamla', 'dernek_ziyaret_teklif',
    'dernek_ziyaret_yanit', 'dernekler', 'disiplin_baslat', 'disiplin_durum', 'disiplin_oyla', 'durum', 'istemci_hata_kaydet',
    -- 08.11.2026: Halk Hareketleri ekranlarının çağırdığı ve listede eksik kalan adlar
    'sokak_avukat_cagir', 'sokak_avukat_cevap', 'sokak_baro_ata', 'sokak_baro_iste', 'sokak_basina_aciklama', 'sokak_butce_mudahale', 'sokak_davet_gonder', 'sokak_davet_karar', 'sokak_davet_yanit', 'sokak_ek_panel', 'sokak_eylem_detay_panel', 'sokak_eylem_sonlandir', 'sokak_finans_panel', 'sokak_gozalti_hakim_incele', 'sokak_gozalti_itiraz', 'sokak_gozalti_mahkeme', 'sokak_gozalti_tazminat_tahsil', 'sokak_katil_tercih', 'sokak_koalisyon_cagri', 'sokak_koalisyon_katil', 'sokak_merkez_panel', 'sokak_olay_baslat', 'sokak_org_baslat', 'sokak_org_baslat_bildirili', 'sokak_org_baslat_kapsamli', 'sokak_org_panel', 'sokak_polis_geri_cek', 'sokak_polis_gonder',
    -- 09.11.2026 Halk Hareketleri 3.0 (supabase/migrations/20261109090000_sokak_gercek_oyuncu.sql)
    'sokak_eylemden_ayril', 'sokak_goreve_cik', 'sokak_gorevden_ayril', 'sokak_karsi_katil', 'sokak_taktik_yap', 'sokak_grev_cagri', 'sokak_nabiz_ver', 'sokak_yasak_koy', 'sokak_jest_yap', 'sokak_heyet_davet', 'sokak_heyet_yanit', 'sokak_heyet_rapor', 'sokak_seslenis_yap', 'sokak_seslenis_tepki', 'sokak_karsi_cagri', 'sokak_kalkan_birak', 'sokak_saha_panel',
    -- 09.11.2026 on iki yeni hükümet aracı (supabase/migrations/20261109150000_halk_hukumet_yeni_tedbirler.sql)
    'sokak_tedbir_ac', 'sokak_tedbir_hamle', 'sokak_tedbir_panel',
    'sokak_sohbet_oku', 'sokak_sohbet_yaz', 'sokak_meydan_islem', 'sokak_meydan_panel', 'sokak_kriz_harita', 'sokak_denetim_oku',
    'sokak_sert_islem', 'sokak_sert_panel',
    'sokak_eylem_merkezi', 'sokak_eylem_merkezi_islem',
    'sokak_katilim_ayril', 'sokak_katilim_liste', 'sokak_hamle_kisi_katil',
    'ek_is_baslat', 'ek_is_paneli', 'ek_is_ucret_al', 'eko_emlak_islem', 'eko_emlak_panel', 'eko_gunluk_kar_cek',
    'eko_islem', 'eko_magaza_hazirla', 'eko_otomasyon_ayarla', 'eko_otomasyon_panel', 'eko_panel', 'eko_ticaret_islem',
    'eko_ticaret_panel', 'eko_vergi_kanun_teklif', 'eko_vergi_panel', 'ekonomi_yasa_durum', 'ekonomi_yasa_teklif', 'emlak_pazarlik_alici_yanit',
    'emlak_pazarlik_satici_yanit', 'emlak_pazarlik_teklif', 'emlak_pazarliklarim', 'engel_kaldir', 'engelle', 'engellenenler',
    'erken_secim_oy', 'erken_secim_teklif', 'eyetkin_parti_kur', 'fiyat_tarifesi', 'gazete', 'gazete_abone_ol',
    'gazete_ayar', 'gazete_detay', 'gazete_kose_yorum_sil', 'gazete_kose_yorum_yaz', 'gazete_kose_yorumlar', 'gazete_kur',
    'gazete_para_cek', 'gazete_yayinla', 'gazete_yazar_cikar', 'gazete_yazar_teklif', 'gazete_yazar_yanit', 'gby_ata',
    'gby_gorev_ver', 'gby_gorevleri', 'gby_miting_yetkisi', 'gecmis_secimler', 'genel_baskanlik_uslen', 'genel_kurul_ac',
    'genel_kurul_oy', 'gensoru_oy', 'gensoru_ver', 'golge_ata', 'golge_kabine', 'golge_rapor_yaz',
    'gorev_odul_al', 'gorevlerim', 'grup_duyuru_yayinla', 'grup_duyurulari', 'grup_karar', 'gun_ozeti',
    'gundem_dernek_secimler', 'haberler', 'haftanin_ozeti', 'halka_arz_baslat', 'halka_arz_basvur', 'halka_arz_durum',
    'halka_arz_hesapla', 'halka_arz_iptal', 'halka_arz_liste', 'halka_arz_talep', 'halka_arz_talep_geri', 'harita',
    'hayat', 'hesabimi_sil', 'hukuk_is_davet', 'hukuk_is_iptal', 'hukuk_is_olustur', 'hukuk_is_sun',
    'hukuk_is_teklif_karar', 'hukuk_is_teklif_ver', 'hukuk_islerim', 'hukumet_destek_cek', 'hukumet_guven_oy', 'hukumet_teklif',
    'hukumet_teklif_yanit', 'ib_eft', 'ib_havale', 'ib_hesap_ozet', 'ib_pos_nakit_ode', 'ib_vadesiz_islem',
    'icra_baslatilabilir', 'icra_dosya_panel', 'icra_haczet', 'icra_ihale_sonuclandir', 'icra_ihale_teklif', 'icra_ihale_tem_iade',
    'icra_itiraz_et', 'icra_itiraz_karar', 'icra_takip_ac', 'icra_varliklar', 'icraat_yap', 'ideoloji_durum',
    'ideoloji_oyla', 'ideoloji_teklif_ver', 'ihale_ac', 'ihale_ekrani', 'ihale_iptal', 'ihale_teklif',
    'ihale_teklif_geri', 'ihale_yontem', 'ihaleler', 'il_bagis', 'il_bagis_durum', 'il_degistir',
    'il_detay', 'il_ruhsat_ayarla', 'il_tasinma_bilgisi', 'ilan_detay', 'ilan_duzenle', 'ilan_favori',
    'ilan_hemen_al', 'ilan_hesabim', 'ilan_kaldir', 'ilan_karsi_yanit', 'ilan_meydani', 'ilan_one_cikar',
    'ilan_sirket_raporu', 'ilan_teklif_geri_cek', 'ilan_teklif_ver', 'ilan_teklif_yanit', 'ilan_varliklarim', 'ilan_ver',
    'ilk_adimlar', 'internet_banka_hesaplarim', 'istifa', 'ittifak_ayril', 'ittifak_bilgi', 'ittifak_davet',
    'ittifak_davet_yanit', 'ittifak_kur', 'ittifak_masasi', 'ittifak_ortak_aday_iptal', 'ittifak_ortak_aday_teklif', 'ittifak_ortak_aday_yanit',
    'ittifak_teklif', 'kabine', 'kamu_butce_dagit', 'kamu_butce_panel', 'kamu_kurum_islem', 'kamu_kurum_panel',
    'kamu_toptan_islem', 'kamu_toptan_panel', 'kanun_cb_karar', 'kanun_detay', 'kanun_geri_cek', 'kanun_imza',
    'kanun_oy', 'kanun_teklif', 'kanunlar', 'kapi_kapi', 'kapi_kapi_haklarim', 'kararname_cikar',
    'kararnameler', 'kart_basvur', 'kart_basvuru_karar', 'kart_belge_iste', 'kart_belge_yanit', 'kart_dondur',
    'kart_nakit_avans', 'kart_ode', 'kart_odul_al', 'kart_panel', 'kart_pos_bekleyen', 'kart_pos_iade',
    'kart_pos_yanit', 'kasa_gizlilik_ayarla', 'kasa_gizlilik_listem', 'kayit_basvur', 'kazikazan_durum', 'kazikazan_oyna',
    'kimlik_guncelle', 'kimlikler', 'koalisyon_durum', 'koalisyon_sonlandir', 'koalisyon_teklif', 'koalisyon_yanit',
    'konkordato_ekrani', 'kredi_cek', 'kredi_ode', 'kredi_uygunluk', 'kriz_ayar_degistir', 'kriz_karar_ver',
    'kriz_merkezi', 'kursu_akis', 'kursu_alinti', 'kursu_ara', 'kursu_ben', 'kursu_bildirimler',
    'kursu_etiket', 'kursu_gonderi', 'kursu_gundem', 'kursu_profil', 'kursu_profil_guncelle', 'kursu_sabitle',
    'kursu_takip_et', 'kursu_takip_listesi', 'kursu_yp', 'kurucu_davet_ekle', 'kurucu_davet_yanit', 'kurucu_davetlerim',
    'kurucu_katki', 'maas_durum', 'maas_oyla', 'maas_teklif_ver', 'magaza_durum', 'magaza_rozetler',
    'mahkeme_azil_oy', 'mahkeme_azil_teklif', 'mahkeme_meclis_oy', 'matestappen_parti_kur', 'meclis', 'meclis_aday_ol',
    'meclis_baskanlik', 'meclis_ihtar', 'meclis_oturum', 'meclis_oy', 'meclis_projeksiyon', 'meclis_rehber',
    'meclis_sandalye', 'meclis_vekiller', 'meclis_yoklama', 'mentor_birak', 'mentor_durum', 'mentor_gonullu_ol',
    'mentor_sec', 'merkez_bankasi', 'mesaj_tepki_ver', 'mesaj_tepkileri', 'meslek_dukkan_ac', 'meslek_kasa',
    'meslek_komisyon_ayarla', 'meslek_makas_ayarla', 'meslek_panel', 'meslek_stok_tedarik', 'meslek_ticaret', 'mevzuat',
    'mevzuat_onizle', 'milletvekili_ozgecmis', 'miting_bilet_al', 'miting_bilet_bilgi', 'miting_duzenle', 'miting_haklarim',
    'miting_katil', 'miting_konus', 'miting_meydan', 'miting_otobus_bilgi', 'miting_otobus_kaldir', 'miting_otobus_yer_ayirt',
    'miting_slogan_at', 'miting_tepki', 'mitingler', 'mulk_il_satin_al', 'mulk_il_stok', 'mulk_ilan_iptal',
    'mulk_ilan_satin_al', 'mulk_ilan_ver', 'mulk_liste', 'mulk_pazar', 'mulk_satin_al', 'musahit_ata',
    'musahit_kaldir', 'musahit_paneli', 'musahit_sandik', 'musahit_tutanak', 'muzayede_bagis', 'muzayede_eve_sat',
    'muzayede_koleksiyonum', 'muzayede_lot', 'muzayede_lot_ac', 'muzayede_lot_iptal', 'muzayede_pey', 'muzayede_salon',
    'muzayede_sergi', 'muzayede_siralama', 'mv_ortak_liste_gorunum', 'mv_ortak_liste_iptal', 'mv_ortak_liste_teklif', 'mv_ortak_liste_yanit',
    'npc_isletme_islem', 'npc_isletme_panel', 'ortak_sirket_devir_iptal', 'ortak_sirket_devir_karar', 'ortak_sirket_devir_teklif', 'ortak_sirket_kur_iptal',
    'ortak_sirket_kur_karar', 'ortak_sirket_kur_tamamla', 'ortak_sirket_kur_teklif', 'ortak_sirket_panel', 'oturum_kaydet', 'oy_ver',
    'oyb_bilgi_bekleyen', 'oyb_bilgi_dokumu', 'oyb_bilgi_talep', 'oyb_bilgi_yanit', 'oyb_hesap_ac', 'oyb_hesap_bilgi_dokum',
    'oyb_hesap_bilgi_iste', 'oyb_hesap_bilgi_yanit', 'oyb_hesap_kapat', 'oyb_icra_baslat', 'oyb_icra_dosyalar', 'oyb_icra_haciz_al',
    'oyb_icra_haciz_liste', 'oyb_icra_haciz_sec', 'oyb_icra_itiraz', 'oyb_icra_karar', 'oyb_icra_savun', 'oyb_kredi_basvur',
    'oyb_kredi_basvuru_iptal', 'oyb_kredi_cek', 'oyb_kredi_ekler', 'oyb_kredi_erken_kapat', 'oyb_kredi_faiz_ayarla', 'oyb_kredi_karar',
    'oyb_kredi_masasi', 'oyb_kredi_ode', 'oyb_kredi_plan', 'oyb_kredi_teklif_iptal', 'oyb_kredi_teklif_ver', 'oyb_kredi_teklif_yanit',
    'oyb_liste', 'oyb_mevduat_cek', 'oyb_oran_ayarla', 'oyb_paket_kaydet', 'oyb_paket_sil', 'oyb_portfoy',
    'oyb_teklif', 'oyb_urun_ayarla', 'oyb_urunler', 'oyb_yatir', 'oyb_yonetim', 'oyuncu_arama',
    'oyuncu_kart', 'oyuncu_nisanlari', 'oyuncu_parti_gecmisi', 'ozel_liste', 'ozel_oku', 'ozel_yasa_durum',
    'ozel_yasa_teklif', 'ozel_yaz', 'para_gonder', 'parti_aciklama_sil', 'parti_aciklama_yap', 'parti_aciklamalari',
    'parti_ad_degistir', 'parti_ad_ozel_hakki', 'parti_aday_kart', 'parti_aday_tanit', 'parti_amblem_degistir', 'parti_birlesme_iptal',
    'parti_birlesme_teklif', 'parti_birlesme_yanit', 'parti_destek', 'parti_detay', 'parti_finans_bagis', 'parti_finans_durum',
    'parti_finans_emir', 'parti_finans_kampanya', 'parti_gecisleri', 'parti_hedefleri', 'parti_il_uyeleri', 'parti_isbirligi_durum',
    'parti_kasa', 'parti_kasa_defteri', 'parti_kimlik_ayarla', 'parti_kimlikleri', 'parti_kur_baslat', 'parti_kur_iptal',
    'parti_kur_tamamla', 'parti_miting_bilgi', 'parti_miting_duzenle', 'parti_sozcu_bilgi', 'parti_tuzuk', 'parti_tuzuk_oyla',
    'parti_tuzuk_teklif', 'parti_ucret_ayarla', 'parti_ucret_tarife', 'parti_yetkilerim', 'partiden_ayril', 'partiler',
    'partiye_katil', 'pazar_ayarla', 'pazar_danisman', 'pazar_detay', 'pazar_harita', 'pazar_katalog',
    'pazar_otopilot', 'pazar_sirket_kur', 'pazar_tasi', 'piyasa_durum', 'piyasa_emir', 'piyasa_panosu',
    'piyasa_raporu', 'politika_ayarla', 'politika_onizle', 'pos_banka_otomatik', 'pos_banka_panel', 'pos_basvur',
    'pos_basvuru_karar', 'pos_satis_talep', 'ppk_faiz_karari', 'profil_olustur', 'referandum_detay', 'referandum_oy',
    'referandumlar', 'rekabet_ac', 'rekabet_ekrani', 'rekabet_paneli', 'reklam_al', 'reklam_hazirla', 'reklam_odul',
    'resmi_gun_mesaj_yaz', 'resmi_gunler', 'resmi_program_katil', 'resmi_program_panel', 'resmi_program_yap', 'resmi_programlar',
    'rozet_tak', 'rozetler', 'secim_ayrintili_sonuclar', 'secim_detay', 'secim_gecesi', 'secim_gecesi_aktif',
    'sektor_politika_ayarla', 'serbest_bagis', 'sigorta_afet_panel', 'sigorta_isletme_panel', 'sigorta_isletme_police_al', 'sigorta_mulk_onar',
    'sigorta_mulk_police_al', 'sikayet_et', 'siralamalar', 'sirket_as_donustur', 'sirket_finans_ozeti', 'sirket_hisse_ilan_al',
    'sirket_hisse_pazar', 'sirket_insaat_portfoyu', 'sirket_insaat_ruhsat_teklif', 'sirket_insaat_ruhsatli_baslat', 'sirket_insaat_teklif', 'sirket_kar_birikim_ayarla',
    'sirket_kar_payi', 'sirket_kar_tercihleri', 'sirket_karnesi', 'sirket_kasa_bilgi', 'sirket_kasa_yatir', 'sirket_konkordato_ilan',
    'sirket_kur', 'sirket_kur_aktif', 'sirket_kur_aktif_ilde', 'sirket_kur_ilde', 'sirket_liste', 'sirket_parti_bagis',
    'sirket_pay_kabul', 'sirket_pay_teklif', 'sirket_reklam_ayarla', 'sirket_satiliga_cikar', 'sirket_satilik_al', 'sirket_satis_raporu',
    'sirket_sermaye_artir', 'sirket_sube_ac_ilde', 'sirket_sube_finans', 'sirket_sube_teklif', 'sirket_vitrini', 'sirket_yerleri',
    'siyaset_merkezi_ozet', 'siyasi_bagislar', 'siyasi_hafta', 'siyasi_sistem', 'sohbet_oku', 'sohbet_ozet',
    'sohbet_yaz', 'sos_dernek_durum', 'sos_dilekce_gonder', 'sos_dilekce_yanit', 'sos_dilekceler', 'sos_duello_davet',
    'sos_duello_konus', 'sos_duello_oyla', 'sos_duellolar', 'sos_haber_cevapla', 'sos_haber_hedefle', 'sos_haberler',
    'sos_imza_baslat', 'sos_imza_kampanyalari', 'sos_parti_imza_durum', 'sos_parti_imzala', 'sos_roportaj_davet', 'sos_roportaj_yanit',
    'sos_roportajlar', 'spk_ekrani', 'spk_inceleme_ac', 'spk_karar', 'stant_ac', 'stant_cevapla',
    'stant_gonullu_ol', 'stant_ziyaret', 'stantlar', 'surum', 'tanitim_tamam', 'tarih_arsivi',
    'tcmb_baskan_ata', 'tcmb_baskan_gorevden_al', 'tcmb_teklif_yanit', 'tebrik_et', 'teskilat_ac2', 'teskilat_gorev_al',
    'teskilat_gorev_ver', 'teskilatlar', 'ticaret_gecmisim', 'topla', 'uc_etkinlik_iptal', 'uc_etkinlik_islem',
    'uc_etkinlik_panel', 'uc_kitap_islem', 'uc_kitap_panel', 'kitap_rekabet', 'kitap_imza_islem', 'uc_medya_bagis', 'uc_medya_panel', 'uc_tarim_islem',
    'uc_tarim_panel', 'ulke_karnesi', 'uygulama_ayar', 'uzaktan_kontrol_ayarla', 'uzaktan_kontrol_ayarlari', 'uzaktan_kontrol_durum',
    'uzaktan_kontrol_yayin', 'vaat_hesapla', 'vaat_secenekleri', 'vaat_yaz', 'vaatlerim', 'vadeli_ac',
    'vadeli_boz', 'varlik_fonu_aktar', 'vatandaslik', 'vekalet_paneli', 'vergi_kanun_teklif', 'vergi_karnem',
    'vergi_rehberi', 'yatirim_kasam', 'yatirim_pazar_islem', 'yatirim_pazar_panel', 'yayin_gonder', 'yayin_haklari',
    'yk_ad_degistir', 'yk_adaylik_yasagi', 'yk_bildirim', 'yk_degisiklikler', 'yk_engel_kaldir', 'yk_engelle',
    'yk_geri_al', 'yk_il_degistir', 'yk_kasa', 'yk_kidem', 'yk_makam_al', 'yk_makam_ver',
    'yk_makamlar', 'yk_motor_calistir', 'yk_oyuncu', 'yk_oyuncular', 'yk_ozet', 'yk_para',
    'yk_parti_degistir', 'yk_parti_gorev_al', 'yk_satir_kaydet', 'yk_satir_sil', 'yk_satislar', 'yk_secimler',
    'yk_sistem_hatalari', 'yk_sustur', 'yk_tablo', 'yk_tablolar', 'yk_uygulama_ayar_kaydet', 'yk_uygulama_ayarlari',
    'yonetim_hediyeleri', 'yurutme_butce_masasi',
    -- 161 (02.11.2026) il ekonomisi
    'il_ekonomi_bilgi', 'il_ekonomi_liste',
    -- 164 · Süper Yönetici Portalı (docs/yonetim/): gövdeler oyun.yp_sahip() ile açılır (yönetici + aal2).
    'yp_ben', 'yp_islemler', 'yp_onizle', 'yp_oy_teshis', 'yp_oyuncu_ara', 'yp_pano',
    'yp_secim', 'yp_secimler', 'yp_sozluk', 'yp_uygula',
    -- 168 · Portal aşama 2: oyuncu listesi ve oyuncu dosyası
    'yp_oyuncu', 'yp_oyuncular',
    -- 171 · Portal aşama 3: canlı ayarlar
    'yp_ayar_gecmis', 'yp_ayarlar',
    -- 172 · Portal aşama 4: siyaset ve ekonomi
    'yp_dernekler', 'yp_ekonomi', 'yp_parti', 'yp_siyaset', 'yp_sirketler',
    -- 173 · Portal aşama 5: duyuru, olay, destek (+ oyuncunun destek talebi)
    'yp_destek', 'yp_duyurular', 'yp_olaylar', 'destek_gonder', 'destek_taleplerim',
    -- 174 · Portal aşama 6: sistem, tutarlılık, asistan kaydı
    'yp_asistan_gecmis', 'yp_asistan_kaydet', 'yp_sistem', 'yp_tutarlilik',
    -- 175 (07.11.2026) afiş stüdyosu ve reklam panoları
    'pano_vitrin', 'pano_merkez', 'afis_kaydet', 'afis_sil', 'pano_teklif', 'pano_kirala', 'pano_begen', 'pano_sikayet', 'pano_il_tarife', 'pano_kaldir', 'pano_sikayet_kapat',
    -- 176 (07.11.2026) pano işletme hakkı ihalesi
    'pano_teklif_v2', 'pano_kirala_v2', 'pano_ihale_teklif_ver', 'pano_isletme_fiyat', 'pano_ihale_merkez',
    -- 165 (06.11.2026) seçim gecesi canlı yayını
    'secim_yayini', 'secim_yayini_tekrar'
  ];
-- @@rpc_yuzey_izin_son@@
  anon_izin text[] := array['surum', 'uygulama_ayar'];
  r record;
begin
  for r in
    select p.oid::regprocedure as imza, p.proname as ad, n.nspname as sema
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'oyun')
      and p.prokind in ('f', 'p', 'a')
  loop
    begin
      if r.sema = 'public' and r.ad = any (izin) then
        execute format('revoke all on function %s from public, anon', r.imza);
        execute format('grant execute on function %s to authenticated', r.imza);
        if r.ad = any (anon_izin) then
          execute format('grant execute on function %s to anon', r.imza);
        end if;
      else
        execute format('revoke all on function %s from public, anon, authenticated', r.imza);
      end if;
      if exists (select 1 from pg_roles where rolname = 'service_role') then
        execute format('grant execute on function %s to service_role', r.imza);
      end if;
    exception when others then
      raise warning 'izin atlandı (%): %', r.imza, sqlerrm;
    end;
  end loop;
end
$izin$;

-- Paralel PR'ler bu dalda yok. Kilit en sonda çalışınca onların grant'ını ezmesin.
-- Fonksiyon henüz yoksa atlanır; varsa doğru rol açık kalır.
do $paralel$
begin
  -- PR #38: Realtime satırını kim görür. RLS koşulu, oyun RPC'si değil.
  -- Yazan oyun.canli_sinyal(text) ve tetikleyici istemciye kapalı kalır.
  if to_regprocedure('oyun.canli_sinyal_gorur(text)') is not null then
    revoke all on function oyun.canli_sinyal_gorur(text) from public, anon;
    grant execute on function oyun.canli_sinyal_gorur(text) to authenticated;
  end if;
  if to_regprocedure('oyun.canli_sinyal(text)') is not null then
    revoke all on function oyun.canli_sinyal(text) from public, anon, authenticated;
  end if;
  if to_regprocedure('oyun.canli_sinyal_tetik()') is not null then
    revoke all on function oyun.canli_sinyal_tetik() from public, anon, authenticated;
  end if;
  -- PR #40: ödül hazırlığı oyuncuya, SSV tahsilatı yalnız service_role.
  if to_regprocedure('public.reklam_ssv_isle(jsonb)') is not null then
    revoke all on function public.reklam_ssv_isle(jsonb) from public, anon, authenticated;
    if exists (select 1 from pg_roles where rolname = 'service_role') then
      grant execute on function public.reklam_ssv_isle(jsonb) to service_role;
    end if;
  end if;
end
$paralel$;
