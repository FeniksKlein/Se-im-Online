-- 2026-10-31 · Dış anahtar indeksleri ve mükerrer indeksler.
-- Kaynak: canlı performans danışmanı (31 Ekim 2026). Bu dosya CANLIYA bu oturumda UYGULANMADI.
--
-- UYGULAMA (transaction DIŞI, autocommit):
--   CREATE/DROP INDEX CONCURRENTLY bir transaction bloğunda çalışmaz
--   ("cannot run inside a transaction block"). Supabase SQL Editor betiğin
--   tamamını tek transaction sayabilir; bu dosyayı oraya olduğu gibi yapıştırmayın.
--   psql ile, --single-transaction OLMADAN:
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--       -c "set statement_timeout = 0" \
--       -c "set lock_timeout = '30s'" \
--       -f migrations/20261031_fk_indeksleri.sql
--   Her komut kendi transaction'ında biter. Yarıda kesilirse geçersiz (INVALID)
--   indeks kalabilir. Yeniden çalıştırmadan önce:
--     select n.nspname, c.relname
--     from pg_index i
--     join pg_class c on c.oid = i.indexrelid
--     join pg_namespace n on n.oid = c.relnamespace
--     where not i.indisvalid;
--   Geçersiz olanı DROP INDEX CONCURRENTLY ile silip dosyayı baştan çalıştırın
--   (IF NOT EXISTS / IF EXISTS yüzünden tamamlananlar atlanır).
--
-- Neden bu 58 indeks, 404 uyarının hepsi değil:
--   Çocuk tablo canlıda en az 100 satır ya da 64 KB, VEYA en az 10 satır ve
--   10.000 ardışık tarama. Boş ve çok küçük tablolarda eksik FK indeksi
--   silme/join maliyetini değiştirmez; yazma başına indeks bakımı ekler.
--   kurucu_portal iki FK'si de bu eşiğin altında (şema toplam ~64 KB).
--   Boş bırakılanlar için danışman uyarısı durur; istenirse aynı ölçütle genişletilir.
--   Nullable kolonlarda kısmi indeks (WHERE kolon IS NOT NULL) FK denetimini
--   karşılar: Postgres yalnız dolu anahtarı arar.
--
-- Mükerrer indeksler (tanım birebir aynı; kullanılan/kaynakta kalan tutulur):
--   oyun.akis: akis_kullanici silinir, akis_user_zaman_idx kalır
--   oyun.borc_aflari: borc_aflari_zaman silinir, borc_aflari_zaman_idx kalır
--   oyun.borsa_islem: borsa_islem_sirket silinir, borsa_islem_fiyat_koruma_idx kalır
--   oyun.parti_tuzuk_teklifleri: parti_tuzuk_aktif silinir, parti_tuzuk_aktif_idx kalır
--
-- GERİ ALMA: aşağıdaki DROP INDEX CONCURRENTLY satırlarını CREATE ile,
-- CREATE satırlarını DROP INDEX CONCURRENTLY IF EXISTS ile ters çevirin.
-- Yeni kurulum (boş veritabanı, tek transaction) için eşlenik:
--   gelistirici/sql/160_fk_indeksleri.sql  (CONCURRENTLY yok; kurulum dosyasına girer).
-- Bu dosyayı supabase-kurulum.sql transaction'ının içine koymayın.

drop index concurrently if exists oyun.akis_kullanici;
drop index concurrently if exists oyun.borc_aflari_zaman;
drop index concurrently if exists oyun.borsa_islem_sirket;
drop index concurrently if exists oyun.parti_tuzuk_aktif;

create index concurrently if not exists adliye_beyan_yazar_fk_idx on oyun.adliye_beyan (yazar);
create index concurrently if not exists adliye_davalar_af_veren_fk_idx on oyun.adliye_davalar (af_veren) where af_veren IS NOT NULL;
create index concurrently if not exists adliye_davalar_davaci_fk_idx on oyun.adliye_davalar (davaci);
create index concurrently if not exists adliye_davalar_davaci_parti_fk_idx on oyun.adliye_davalar (davaci_parti) where davaci_parti IS NOT NULL;
create index concurrently if not exists adliye_davalar_davali_parti_fk_idx on oyun.adliye_davalar (davali_parti) where davali_parti IS NOT NULL;
create index concurrently if not exists adliye_davalar_hakim_fk_idx on oyun.adliye_davalar (hakim) where hakim IS NOT NULL;
create index concurrently if not exists ajans_haberleri_il_id_fk_idx on oyun.ajans_haberleri (il_id) where il_id IS NOT NULL;
create index concurrently if not exists ajans_haberleri_parti_id_fk_idx on oyun.ajans_haberleri (parti_id) where parti_id IS NOT NULL;
create index concurrently if not exists avukat_vekaletleri_avukat_id_fk_idx on oyun.avukat_vekaletleri (avukat_id);
create index concurrently if not exists avukat_vekaletleri_muvekkil_fk_idx on oyun.avukat_vekaletleri (muvekkil);
create index concurrently if not exists banka_mevduat_user_id_fk_idx on oyun.banka_mevduat (user_id);
create index concurrently if not exists bel_yatirim_ruhsat_baskan_fk_idx on oyun.bel_yatirim_ruhsat (baskan) where baskan IS NOT NULL;
create index concurrently if not exists bel_yatirim_ruhsat_sirket_id_fk_idx on oyun.bel_yatirim_ruhsat (sirket_id) where sirket_id IS NOT NULL;
create index concurrently if not exists belediye_bina_baskan_fk_idx on oyun.belediye_bina (baskan);
create index concurrently if not exists belediye_bina_kod_fk_idx on oyun.belediye_bina (kod);
create index concurrently if not exists belediye_kriz_baskan_fk_idx on oyun.belediye_kriz (baskan) where baskan IS NOT NULL;
create index concurrently if not exists belediye_kriz_kod_fk_idx on oyun.belediye_kriz (kod);
create index concurrently if not exists belediye_sehir_hareket_bina_id_fk_idx on oyun.belediye_sehir_hareket (bina_id) where bina_id IS NOT NULL;
create index concurrently if not exists cek_tahsilat_cek_id_fk_idx on oyun.cek_tahsilat (cek_id);
create index concurrently if not exists cekler_borclu_sirket_fk_idx on oyun.cekler (borclu_sirket) where borclu_sirket IS NOT NULL;
create index concurrently if not exists cekler_hesap_id_fk_idx on oyun.cekler (hesap_id);
create index concurrently if not exists cekler_ilk_lehtar_fk_idx on oyun.cekler (ilk_lehtar) where ilk_lehtar IS NOT NULL;
create index concurrently if not exists cekler_ilk_lehtar_sirket_fk_idx on oyun.cekler (ilk_lehtar_sirket) where ilk_lehtar_sirket IS NOT NULL;
create index concurrently if not exists dernek_sube_il_id_fk_idx on oyun.dernek_sube (il_id);
create index concurrently if not exists eko_islem_kayit_diger_sirket_fk_idx on oyun.eko_islem_kayit (diger_sirket) where diger_sirket IS NOT NULL;
create index concurrently if not exists eko_islem_kayit_oyuncu_fk_idx on oyun.eko_islem_kayit (oyuncu) where oyuncu IS NOT NULL;
create index concurrently if not exists eko_isletmeler_il_id_fk_idx on oyun.eko_isletmeler (il_id);
create index concurrently if not exists eko_npc_satis_urun_fk_idx on oyun.eko_npc_satis (urun);
create index concurrently if not exists eko_uretim_emir_urun_fk_idx on oyun.eko_uretim_emir (urun);
create index concurrently if not exists eko_urun_stok_urun_fk_idx on oyun.eko_urun_stok (urun);
create index concurrently if not exists eko_vergi_hareket_oyuncu_fk_idx on oyun.eko_vergi_hareket (oyuncu) where oyuncu IS NOT NULL;
create index concurrently if not exists etkiler_il_id_fk_idx on oyun.etkiler (il_id) where il_id IS NOT NULL;
create index concurrently if not exists gazete_yayinlari_hedef_parti_fk_idx on oyun.gazete_yayinlari (hedef_parti) where hedef_parti IS NOT NULL;
create index concurrently if not exists gazete_yayinlari_yazar_fk_idx on oyun.gazete_yayinlari (yazar);
create index concurrently if not exists genel_kurul_acan_fk_idx on oyun.genel_kurul (acan);
create index concurrently if not exists haftalik_anket_oy_parti_id_fk_idx on oyun.haftalik_anket_oy (parti_id);
create index concurrently if not exists haftalik_anket_oy_user_id_fk_idx on oyun.haftalik_anket_oy (user_id);
create index concurrently if not exists il_hizmet_kod_fk_idx on oyun.il_hizmet (kod);
create index concurrently if not exists makamlar_secim_id_fk_idx on oyun.makamlar (secim_id) where secim_id IS NOT NULL;
create index concurrently if not exists meclis_aday_user_id_fk_idx on oyun.meclis_aday (user_id);
create index concurrently if not exists miting_konusma_user_id_fk_idx on oyun.miting_konusma (user_id);
create index concurrently if not exists miting_tepki_user_id_fk_idx on oyun.miting_tepki (user_id);
create index concurrently if not exists muzayede_eserler_bagisci_fk_idx on oyun.muzayede_eserler (bagisci) where bagisci IS NOT NULL;
create index concurrently if not exists muzayede_lotlar_lider_fk_idx on oyun.muzayede_lotlar (lider) where lider IS NOT NULL;
create index concurrently if not exists npc_satis_kayit_urun_fk_idx on oyun.npc_satis_kayit (urun);
create index concurrently if not exists npc_stok_urun_fk_idx on oyun.npc_stok (urun);
create index concurrently if not exists partiler_gb_vekil_fk_idx on oyun.partiler (gb_vekil) where gb_vekil IS NOT NULL;
create index concurrently if not exists piyango_iadeleri_user_id_fk_idx on oyun.piyango_iadeleri (user_id);
create index concurrently if not exists piyasa_pozisyon_kod_fk_idx on oyun.piyasa_pozisyon (kod);
create index concurrently if not exists sirket_hareket_sirket_id_fk_idx on oyun.sirket_hareket (sirket_id);
create index concurrently if not exists sirket_ortaklari_user_id_fk_idx on oyun.sirket_ortaklari (user_id);
create index concurrently if not exists sirketler_kurucu_fk_idx on oyun.sirketler (kurucu);
create index concurrently if not exists sirketler_yonetici_fk_idx on oyun.sirketler (yonetici) where yonetici IS NOT NULL;
create index concurrently if not exists uc_etkinlik_il_id_fk_idx on oyun.uc_etkinlik (il_id);
create index concurrently if not exists uc_etkinlik_sirket_id_fk_idx on oyun.uc_etkinlik (sirket_id);
create index concurrently if not exists uc_kitap_yayinevi_fk_idx on oyun.uc_kitap (yayinevi);
create index concurrently if not exists uc_kitap_yazar_fk_idx on oyun.uc_kitap (yazar);
create index concurrently if not exists uc_kitap_satis_alici_fk_idx on oyun.uc_kitap_satis (alici) where alici IS NOT NULL;
