-- 160 · Dış anahtar indeksleri (yeni kurulum).
-- Canlıdaki CONCURRENTLY sürümü: migrations/20261031_fk_indeksleri.sql
-- Bu dosya supabase-kurulum.sql transaction'ının içinde çalışır; bu yüzden
-- CONCURRENTLY yoktur ve tablo henüz yoksa indeksi atlar (bazı tablolar yalnız
-- canlı migration'larında kuruludur). Canlıda bu dosyayı ayrıca çalıştırmayın;
-- kilitli CREATE INDEX yerine concurrent migration'ı kullanın.
-- Mükerrer indeks adları kaynakta da bırakılmaz (78 ve 85); DROP yine de güvenlidir.

drop index if exists oyun.akis_kullanici;
drop index if exists oyun.borc_aflari_zaman;
drop index if exists oyun.borsa_islem_sirket;
drop index if exists oyun.parti_tuzuk_aktif;

do $$
begin
  if to_regclass('oyun.adliye_beyan') is not null then
    execute 'create index if not exists adliye_beyan_yazar_fk_idx on oyun.adliye_beyan (yazar)';
  end if;
  if to_regclass('oyun.adliye_davalar') is not null then
    execute 'create index if not exists adliye_davalar_af_veren_fk_idx on oyun.adliye_davalar (af_veren) where af_veren IS NOT NULL';
  end if;
  if to_regclass('oyun.adliye_davalar') is not null then
    execute 'create index if not exists adliye_davalar_davaci_fk_idx on oyun.adliye_davalar (davaci)';
  end if;
  if to_regclass('oyun.adliye_davalar') is not null then
    execute 'create index if not exists adliye_davalar_davaci_parti_fk_idx on oyun.adliye_davalar (davaci_parti) where davaci_parti IS NOT NULL';
  end if;
  if to_regclass('oyun.adliye_davalar') is not null then
    execute 'create index if not exists adliye_davalar_davali_parti_fk_idx on oyun.adliye_davalar (davali_parti) where davali_parti IS NOT NULL';
  end if;
  if to_regclass('oyun.adliye_davalar') is not null then
    execute 'create index if not exists adliye_davalar_hakim_fk_idx on oyun.adliye_davalar (hakim) where hakim IS NOT NULL';
  end if;
  if to_regclass('oyun.ajans_haberleri') is not null then
    execute 'create index if not exists ajans_haberleri_il_id_fk_idx on oyun.ajans_haberleri (il_id) where il_id IS NOT NULL';
  end if;
  if to_regclass('oyun.ajans_haberleri') is not null then
    execute 'create index if not exists ajans_haberleri_parti_id_fk_idx on oyun.ajans_haberleri (parti_id) where parti_id IS NOT NULL';
  end if;
  if to_regclass('oyun.avukat_vekaletleri') is not null then
    execute 'create index if not exists avukat_vekaletleri_avukat_id_fk_idx on oyun.avukat_vekaletleri (avukat_id)';
  end if;
  if to_regclass('oyun.avukat_vekaletleri') is not null then
    execute 'create index if not exists avukat_vekaletleri_muvekkil_fk_idx on oyun.avukat_vekaletleri (muvekkil)';
  end if;
  if to_regclass('oyun.banka_mevduat') is not null then
    execute 'create index if not exists banka_mevduat_user_id_fk_idx on oyun.banka_mevduat (user_id)';
  end if;
  if to_regclass('oyun.bel_yatirim_ruhsat') is not null then
    execute 'create index if not exists bel_yatirim_ruhsat_baskan_fk_idx on oyun.bel_yatirim_ruhsat (baskan) where baskan IS NOT NULL';
  end if;
  if to_regclass('oyun.bel_yatirim_ruhsat') is not null then
    execute 'create index if not exists bel_yatirim_ruhsat_sirket_id_fk_idx on oyun.bel_yatirim_ruhsat (sirket_id) where sirket_id IS NOT NULL';
  end if;
  if to_regclass('oyun.belediye_bina') is not null then
    execute 'create index if not exists belediye_bina_baskan_fk_idx on oyun.belediye_bina (baskan)';
  end if;
  if to_regclass('oyun.belediye_bina') is not null then
    execute 'create index if not exists belediye_bina_kod_fk_idx on oyun.belediye_bina (kod)';
  end if;
  if to_regclass('oyun.belediye_kriz') is not null then
    execute 'create index if not exists belediye_kriz_baskan_fk_idx on oyun.belediye_kriz (baskan) where baskan IS NOT NULL';
  end if;
  if to_regclass('oyun.belediye_kriz') is not null then
    execute 'create index if not exists belediye_kriz_kod_fk_idx on oyun.belediye_kriz (kod)';
  end if;
  if to_regclass('oyun.belediye_sehir_hareket') is not null then
    execute 'create index if not exists belediye_sehir_hareket_bina_id_fk_idx on oyun.belediye_sehir_hareket (bina_id) where bina_id IS NOT NULL';
  end if;
  if to_regclass('oyun.cek_tahsilat') is not null then
    execute 'create index if not exists cek_tahsilat_cek_id_fk_idx on oyun.cek_tahsilat (cek_id)';
  end if;
  if to_regclass('oyun.cekler') is not null then
    execute 'create index if not exists cekler_borclu_sirket_fk_idx on oyun.cekler (borclu_sirket) where borclu_sirket IS NOT NULL';
  end if;
  if to_regclass('oyun.cekler') is not null then
    execute 'create index if not exists cekler_hesap_id_fk_idx on oyun.cekler (hesap_id)';
  end if;
  if to_regclass('oyun.cekler') is not null then
    execute 'create index if not exists cekler_ilk_lehtar_fk_idx on oyun.cekler (ilk_lehtar) where ilk_lehtar IS NOT NULL';
  end if;
  if to_regclass('oyun.cekler') is not null then
    execute 'create index if not exists cekler_ilk_lehtar_sirket_fk_idx on oyun.cekler (ilk_lehtar_sirket) where ilk_lehtar_sirket IS NOT NULL';
  end if;
  if to_regclass('oyun.dernek_sube') is not null then
    execute 'create index if not exists dernek_sube_il_id_fk_idx on oyun.dernek_sube (il_id)';
  end if;
  if to_regclass('oyun.eko_islem_kayit') is not null then
    execute 'create index if not exists eko_islem_kayit_diger_sirket_fk_idx on oyun.eko_islem_kayit (diger_sirket) where diger_sirket IS NOT NULL';
  end if;
  if to_regclass('oyun.eko_islem_kayit') is not null then
    execute 'create index if not exists eko_islem_kayit_oyuncu_fk_idx on oyun.eko_islem_kayit (oyuncu) where oyuncu IS NOT NULL';
  end if;
  if to_regclass('oyun.eko_isletmeler') is not null then
    execute 'create index if not exists eko_isletmeler_il_id_fk_idx on oyun.eko_isletmeler (il_id)';
  end if;
  if to_regclass('oyun.eko_npc_satis') is not null then
    execute 'create index if not exists eko_npc_satis_urun_fk_idx on oyun.eko_npc_satis (urun)';
  end if;
  if to_regclass('oyun.eko_uretim_emir') is not null then
    execute 'create index if not exists eko_uretim_emir_urun_fk_idx on oyun.eko_uretim_emir (urun)';
  end if;
  if to_regclass('oyun.eko_urun_stok') is not null then
    execute 'create index if not exists eko_urun_stok_urun_fk_idx on oyun.eko_urun_stok (urun)';
  end if;
  if to_regclass('oyun.eko_vergi_hareket') is not null then
    execute 'create index if not exists eko_vergi_hareket_oyuncu_fk_idx on oyun.eko_vergi_hareket (oyuncu) where oyuncu IS NOT NULL';
  end if;
  if to_regclass('oyun.etkiler') is not null then
    execute 'create index if not exists etkiler_il_id_fk_idx on oyun.etkiler (il_id) where il_id IS NOT NULL';
  end if;
  if to_regclass('oyun.gazete_yayinlari') is not null then
    execute 'create index if not exists gazete_yayinlari_hedef_parti_fk_idx on oyun.gazete_yayinlari (hedef_parti) where hedef_parti IS NOT NULL';
  end if;
  if to_regclass('oyun.gazete_yayinlari') is not null then
    execute 'create index if not exists gazete_yayinlari_yazar_fk_idx on oyun.gazete_yayinlari (yazar)';
  end if;
  if to_regclass('oyun.genel_kurul') is not null then
    execute 'create index if not exists genel_kurul_acan_fk_idx on oyun.genel_kurul (acan)';
  end if;
  if to_regclass('oyun.haftalik_anket_oy') is not null then
    execute 'create index if not exists haftalik_anket_oy_parti_id_fk_idx on oyun.haftalik_anket_oy (parti_id)';
  end if;
  if to_regclass('oyun.haftalik_anket_oy') is not null then
    execute 'create index if not exists haftalik_anket_oy_user_id_fk_idx on oyun.haftalik_anket_oy (user_id)';
  end if;
  if to_regclass('oyun.il_hizmet') is not null then
    execute 'create index if not exists il_hizmet_kod_fk_idx on oyun.il_hizmet (kod)';
  end if;
  if to_regclass('oyun.makamlar') is not null then
    execute 'create index if not exists makamlar_secim_id_fk_idx on oyun.makamlar (secim_id) where secim_id IS NOT NULL';
  end if;
  if to_regclass('oyun.meclis_aday') is not null then
    execute 'create index if not exists meclis_aday_user_id_fk_idx on oyun.meclis_aday (user_id)';
  end if;
  if to_regclass('oyun.miting_konusma') is not null then
    execute 'create index if not exists miting_konusma_user_id_fk_idx on oyun.miting_konusma (user_id)';
  end if;
  if to_regclass('oyun.miting_tepki') is not null then
    execute 'create index if not exists miting_tepki_user_id_fk_idx on oyun.miting_tepki (user_id)';
  end if;
  if to_regclass('oyun.muzayede_eserler') is not null then
    execute 'create index if not exists muzayede_eserler_bagisci_fk_idx on oyun.muzayede_eserler (bagisci) where bagisci IS NOT NULL';
  end if;
  if to_regclass('oyun.muzayede_lotlar') is not null then
    execute 'create index if not exists muzayede_lotlar_lider_fk_idx on oyun.muzayede_lotlar (lider) where lider IS NOT NULL';
  end if;
  if to_regclass('oyun.npc_satis_kayit') is not null then
    execute 'create index if not exists npc_satis_kayit_urun_fk_idx on oyun.npc_satis_kayit (urun)';
  end if;
  if to_regclass('oyun.npc_stok') is not null then
    execute 'create index if not exists npc_stok_urun_fk_idx on oyun.npc_stok (urun)';
  end if;
  if to_regclass('oyun.partiler') is not null then
    execute 'create index if not exists partiler_gb_vekil_fk_idx on oyun.partiler (gb_vekil) where gb_vekil IS NOT NULL';
  end if;
  if to_regclass('oyun.piyango_iadeleri') is not null then
    execute 'create index if not exists piyango_iadeleri_user_id_fk_idx on oyun.piyango_iadeleri (user_id)';
  end if;
  if to_regclass('oyun.piyasa_pozisyon') is not null then
    execute 'create index if not exists piyasa_pozisyon_kod_fk_idx on oyun.piyasa_pozisyon (kod)';
  end if;
  if to_regclass('oyun.sirket_hareket') is not null then
    execute 'create index if not exists sirket_hareket_sirket_id_fk_idx on oyun.sirket_hareket (sirket_id)';
  end if;
  if to_regclass('oyun.sirket_ortaklari') is not null then
    execute 'create index if not exists sirket_ortaklari_user_id_fk_idx on oyun.sirket_ortaklari (user_id)';
  end if;
  if to_regclass('oyun.sirketler') is not null then
    execute 'create index if not exists sirketler_kurucu_fk_idx on oyun.sirketler (kurucu)';
  end if;
  if to_regclass('oyun.sirketler') is not null then
    execute 'create index if not exists sirketler_yonetici_fk_idx on oyun.sirketler (yonetici) where yonetici IS NOT NULL';
  end if;
  if to_regclass('oyun.uc_etkinlik') is not null then
    execute 'create index if not exists uc_etkinlik_il_id_fk_idx on oyun.uc_etkinlik (il_id)';
  end if;
  if to_regclass('oyun.uc_etkinlik') is not null then
    execute 'create index if not exists uc_etkinlik_sirket_id_fk_idx on oyun.uc_etkinlik (sirket_id)';
  end if;
  if to_regclass('oyun.uc_kitap') is not null then
    execute 'create index if not exists uc_kitap_yayinevi_fk_idx on oyun.uc_kitap (yayinevi)';
  end if;
  if to_regclass('oyun.uc_kitap') is not null then
    execute 'create index if not exists uc_kitap_yazar_fk_idx on oyun.uc_kitap (yazar)';
  end if;
  if to_regclass('oyun.uc_kitap_satis') is not null then
    execute 'create index if not exists uc_kitap_satis_alici_fk_idx on oyun.uc_kitap_satis (alici) where alici IS NOT NULL';
  end if;
end $$;
