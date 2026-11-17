// Windows/Linux: yalnızca dosya üretir, veritabanına bağlanmaz.
const fs = require('fs'), path = require('path');
const kok = path.join(__dirname, '..');
const oku = ad => fs.readFileSync(path.join(kok, 'sql', ad), 'utf8').replace(/\r\n/g, '\n').trimEnd();
// Canlıda Supabase migration'larıyla kurulmuş tablolara (halk hareketleri, gözaltı, kabine süresi, görev denetimi) dayanan
// modüller: tam kurulumda bu tablolar yoksa dosya atlanır, varsa tek parça çalışır. Böylece tam kurulum bozulmaz.
const KOSULLU = {
  'zz_20261116_baro_mudafi_guvence.sql': ['oyun.gozalti_baro_talep', 'oyun.sokak_baro_talep', 'oyun.yonetim_tutuklama', 'oyun.icisleri_tedbir_v2', 'oyun.baro_adli_yardim', 'oyun.zamanlayici_adim'],
  'zz_20261116_kabine_48_saat_kaldir.sql': ['oyun.cb_kabine_sure'],
  'zz_20261116_makam_guvenligi.sql': ['oyun_yonetim.gorev_denetim', 'oyun.gorev_tercihi', 'oyun.cb_yardimcisi_teklifleri', 'oyun.mahkeme_uye'],
  'zz_20261116_gby_yetki_sistemi.sql': ['oyun.parti_gby', 'oyun.parti_teskilat_gorev', 'oyun.partiler'],
  'zz_20261116_yk_kurum_gorevleri.sql': ['oyun.mahkeme_uye', 'oyun.icisleri_atama', 'oyun.vali_havuz', 'oyun.oda', 'oyun.baro'],
  'zz_20261116_il_kongre_sistemi.sql': ['oyun.parti_gby', 'oyun.parti_teskilat_gorev', 'oyun.parti_teskilat', 'oyun.iller'],
  'zz_20261116_kredi_denge.sql': ['oyun.krediler', 'oyun.oyb_kredi', 'oyun.kredi_kartlari', 'oyun.masak', 'oyun.yatirim_kredisi'],
  'zz_20261116_davet_aktiflik.sql': ['oyun.davet', 'oyun.davet_ayar', 'oyun.oturumlar', 'oyun.masak', 'oyun.zamanlayici_adim'],
  'zz_20261116_mod_gorev_finans.sql': ['oyun.moderatorler', 'oyun.masak', 'oyun.yatirim_kredisi', 'oyun.davet_aktiflik_odul'],
  'zz_20261116_kurucu_partiler.sql': ['oyun.secim_takvim_istisna', 'oyun.zamanlayici_adim', 'oyun.parti_teskilat'],
  'zz_20261117_ad_soyad_profil.sql': ['oyun_yonetim.yasak_isim', 'oyun.moderatorler'],
  'zz_20261116_kayit_onay_ad_soyad.sql': ['oyun_yonetim.kayit_basvurulari', 'oyun.moderatorler', 'oyun.yonetici_kimlik'],
};
const okuKosullu = ad => {
  const govde = oku(ad), tablolar = KOSULLU[ad];
  if (!tablolar) return govde;
  if (govde.includes('$kosullu_govde$')) throw new Error(ad + ': koşullu gövde etiketi çakışıyor');
  const kosul = tablolar.map(t => `to_regclass('${t}') is null`).join(' or ');
  return `-- ${ad} (koşullu)\ndo $kosullu_dis$\nbegin\n  if ${kosul} then raise notice '${ad} atlandı: önkoşul tablo yok'; return; end if;\n  execute $kosullu_govde$\n${govde}\n$kosullu_govde$;\nend $kosullu_dis$;`;
};
const surum = fs.readFileSync(path.join(kok, 'SURUM'), 'utf8').trim();
if (!/^\d{4}\.\d{2}\.\d{2}-\d+$/.test(surum)) throw new Error('Geçersiz sürüm');
const dosyalar = ['01_sema.sql', 'iller.sql', '02_motor.sql', '03_api.sql', '05_kabine_sosyal.sql', '07_devlet.sql', '08_asama3.sql', '09_vatandas.sql', '10_ekonomi2.sql', '11_bos_makam.sql', '12_mevzuat.sql', '13_meclis.sql', '14_guvenlik.sql', '15_ekonomi3.sql', '16_moderator.sql', '17_basin_teskilat.sql', '18_ara_secim_istifa.sql', '19_siyaset_ekonomi4.sql', '20_siyasi_sistem.sql', '21_banka_transferleri.sql', '22_saatlik_vadeli.sql', '23_bagimsiz_adaylik.sql', '24_gayrimenkul.sql', '25_milli_piyango.sql', '26_ekonomi_yasalari.sql', '27_ekonomi_etkileri.sql', '28_sirket_banka_asgari.sql', '29_oyuncu_banka_liste.sql', '30_sirket_kira_satis_sermaye.sql', '31_piyasa_kazikazan.sql', '32_mulk_pazar.sql', '33_genel_baskan_vekil.sql', '34_maas_meclis.sql', '35_soru_anket.sql', '36_parti_toplanti_disiplin.sql', '37_gb_vekil_goreve_baslat.sql', '38_canli_20261008.sql', '39_oyuncu_deneyimi.sql', '40_portre_erkek_secenekleri.sql', '41_kurucu_ideoloji.sql', '42_ekonomi_vitrin_emlak.sql', '43_meclis_salt_cogunluk.sql', '44_il_emlak_stok_vergi.sql', '45_emlak_temizlik.sql', '46_miting_canli.sql', '47_test_baslangic.sql', '48_eyetkin_parti.sql', '49_celal_parti.sql', '50_parti_miting_bagimsiz.sql', '51_matestappen_parti.sql', '52_gby_gorev_miting_tepki.sql', '53_gby_gorev_yetki.sql', '54_ittifak_teklif_ortak_aday.sql', '55_dernekler.sql', '56_mv_test_ittifak_vitrin.sql', '57_dernek_sohbet.sql', '58_sivil_demokrasi_kurultay.sql', '59_roportaj_duello_cevap_hakki.sql', '60_imza_dilekce_katilim.sql', '61_katilim_son_duzeltmeler.sql', '62_halka_arz.sql', '62_hayat_gorevleri.sql', '63_gb_mv_cb_adaylik.sql', '63_halka_arz_kar_birikim.sql', '65_mv_bakan_uyum.sql', '06_yetkiler.sql', '68_bildirim_goster.sql', '69_adliye.sql', '70_parti_sozcu_bilgi.sql', '71_yargic_oner_secim_itiraz.sql', '72_parti_birlesme_ortak_mv_listesi.sql', '73_ortak_mv_pusula_ittifak_koruma.sql', '74_meclis_rehber.sql', '75_secim_gecesi.sql', '77_bos_makam_firsat.sql', '78_akis.sql', '79_basarim_rapor_gun_ozeti.sql', '80_erken_secim_takvim_koruma.sql', '81_cimer.sql', '82_akis_sosyal.sql', '83_yargi_reformu.sql', '84_ekonomi_pazar_ihale.sql', '85_ekonomi_borsa_rekabet.sql', '86_reklam_anket_ajansi.sql', '87_haftalik_kredi.sql', '88_ekonomi_guvenligi.sql', '89_belediye_sehir.sql', '91_belediye_detay.sql', '93_ekonomi_kurumlar.sql', '94_cevrimici_oyuncular.sql',
  '76_sonuc_mv_takma_ad_duzeltme.sql', '95_gby_makam_uyumu.sql', '97_borsa_manipulasyon_koruma.sql', '98_borsa_spk_gozetim.sql', '99_ekonomi3_a_duzeltme.sql', '99_ekonomi3_b_faaliyet.sql', '99_ekonomi3_c_piyasa.sql', '100_oyuncu_arama.sql', '101_cb_yrd_guclu.sql', '101_bakanlik_gorevleri.sql', '102_siyaset_merkezi.sql', '103_oyuncu_tasinma.sql', '104_tek_uye_genel_baskan.sql', '105_tgp_tek_ad_hakki.sql', '106_cb_erken_secim.sql', '107_erken_secim_21_ekim.sql', '108_kurucu_davet_ekleme.sql', '109_ek_is_yeni_sektorler.sql', '110_yolsuzluk_musadere.sql', '111_yolsuzluk_portfoy_hazine.sql', '112_tazminat_otomatik_icra.sql', '113_yonetici_kontrol.sql', '114_hesap_silme.sql', '115_magaza.sql', '116_kamu_icra_20261022.sql', '117_kamu_yetki_koruma.sql', '117_belediye_npc_devir_20261022.sql', '118_uzaktan_yonetim_canli_20261022.sql', '119_oyuncu_incelemesi_duzeltmeler.sql', '120_sirket_merkez_ve_sehir_serbest_subeler.sql', '121_secilen_sirket_ilinin_isletme_ruhsatina_aktarimi.sql', '122_oz_sigorta.sql', '123_ortak_sermayeli_sirketler.sql', '124_ortak_sermaye_sektor_kapsami.sql', '123_avukatlik_b_modeli.sql', '124_avukatlik_pazarlik_prim.sql', '125_avukat_istatistik_duzelt.sql', '126_adliye_kurum_davalari.sql', '127_onsecim_uyelik_kesimi.sql', '128_halka_arz_gercekci.sql', '129_bildirim_merkezi.sql', '130_baro_avukat_kontenjan.sql', '131_avukat_zorunlu_sozcu.sql', '132_parti_finans_kasasi.sql', '133_piyango_kazikazan_kaldir.sql', '134_banka_ve_kar_tercihleri.sql', '135_bankacilik_v2.sql', '136_kuyumcu_doviz.sql', '137_meslek_komisyon.sql', '138_yatirim_kasasi.sql', '139_ilan_meydani.sql', '140_muzayede.sql', '141_kursu.sql', '142_bakanlik_masasi.sql', '143_oyuncu_bildirimleri_20261027.sql', '144_sohbet_tasarim.sql', '145_banka_kapasite_cbyrd.sql', '146_makam_protokol.sql', '147_yargic_maas.sql', '148_ekonomik_denge.sql', '149_miting_bilet_avukat.sql', '150_ekonomi_bilgilendirme.sql', '151_uzun_soluklu_ekonomi.sql', '152_kidem_kaynaklari_ihmal_bildirim.sql', '154_siyaset_arenasi.sql', '155_yargi_duzeni.sql', '156_meclis_sandalye.sql', '157_canli_sinyal_sadece_degisince.sql', '158_kamu_maliyesi.sql', '159_canli_sinyal.sql', 'zz_20261029_npc_rekabet.sql', '160_banka_not_onemlilik.sql', '161_il_ekonomisi.sql', '162_iptal_secim_takvimden_cikar.sql', '163_yargi_sure_sonu.sql', '164_yonetim_portali.sql', '165_secim_gecesi_yayini.sql', '166_halk_hareketleri.sql', '167_yonetim_portali_tek_adim.sql', '168_yonetim_oyuncu.sql', '169_halk_hukumet.sql', '170_halk_uzlasma.sql', '171_yonetim_ayarlar.sql', '172_yonetim_siyaset_ekonomi.sql', '173_yonetim_duyuru_olay_destek.sql', '174_yonetim_sistem_asistan.sql', '175_reklam_panosu.sql', '176_pano_ihale.sql', '177_pano_ihale_bloke.sql', '178_pano_acik_ihale.sql', '179_istemci_hata.sql', '180_bakan_fezleke.sql', '181_kurus_borc_odemeleri.sql', '182_kurus_erken_kapama.sql', '183_ym_fezleke_meclis.sql', '185_borsa_endeks_etki.sql', '186_cek_dongu_engel.sql', '187_sirket_cek_kisiye_yasak.sql', '188_ortak_cari_hesap.sql', '189_sirket_kisi_ticari_odeme.sql', '190_yatirim_kredisi.sql', '191_kredi_odeme_gucu.sql', '192_kredi_kalibrasyon.sql', '193_karikatur_dergisi.sql', '194_dergi_kapat_fiyat_guvenlik.sql', '195_dergi_raf_arsiv_duzelt.sql', '196_ticaret_odasi.sql', '197_valilik.sql', '198_tv_kanallari.sql', '199_sirket_kredi_kapasite_duzeltme.sql', '200_sohbet_gruplari.sql', '201_sohbet_grup_katilim.sql', '200_one_cikan_ozet.sql', '201_finans_guvenlik.sql', '202_finans_denge.sql', '184_metin_sinirlari.sql', '203_cb_yrd_tum_bakanliklar.sql', '204_cb_adayi_mv_adayi_olamaz.sql', '205_gorev_devri_korumasi.sql', '206_magaza_fiyat_2.sql', '207_magaza_gorunum_urunleri.sql', '208_calistay_maliyeti.sql', '209_tv_canli_yayin.sql', '211_tv_yarisma_guvenligi.sql', '212_tv_soru_bankasi_tarih_cografya.sql', '213_tv_soru_bankasi_bilim_matematik_teknoloji.sql', '214_tv_soru_bankasi_kultur_sanat_spor.sql', '215_tv_soru_onizleme_guvenligi.sql', '216_tv_kutunu_sec.sql', '217_tv_kutu_numara_guvenlik.sql',
  'zz_20261115_gercekci_siyaset_asama1.sql',
  'zz_20261115_cb_bagimsiz_imza.sql',
  'zz_20261115_gercekci_siyaset_oylama_ek.sql',
  'zz_20261115_gercekci_siyaset_onerge.sql',
  'zz_20261115_anayasa_iade_400.sql',
  'zz_20261115_kanun_gercekci_rehber.sql',
  'zz_20261115_kanun_rejim_goster.sql',
  'zz_20261115_butce_teklif_cumhurbaskani.sql',
  'zz_20261115_anayasa_iki_gorusme.sql',
  'zz_20261115_mv_afk_gorev_korumasi.sql',
  'zz_20261115_anayasa_imza_2tur_koruma.sql',
  'zz_20261115_siyaset_oy_sayim_indeksleri.sql',
  'zz_20261115_cb_parti_aday_yuzde5.sql',
  '210_rutbe_lansman_dengesi.sql', 'zz_20261116_tbmm_nisap_oy_koruma.sql', 'zz_20261116_yargi_gozalti_serbest.sql', 'zz_20261115_beta_gercekci_siyaset_kalici.sql', 'zz_20261116_aday_belirleme_dhondt.sql', 'zz_20261116_aday_riza_sifir_oy_koruma.sql', 'zz_20261116_mahkeme_cb_baro_tbmm.sql', 'zz_20261116_belediye_ertesi_gun_ara_secim.sql', 'zz_20261116_ysk_bagimsiz_itiraz_sayim.sql', 'zz_20261116_genel_baskan_secimi_uyeler.sql', 'zz_20261116_mahkeme_bagimsiz_azil_koruma.sql', 'zz_20261116_belediye_oy_disinda_atama_yasagi.sql', 'zz_20261116_belediye_bosluk_otomatik_ara_secim.sql',
  'zz_20261116_baro_mudafi_guvence.sql', 'zz_20261116_kabine_48_saat_kaldir.sql', 'zz_20261116_makam_guvenligi.sql',
  'zz_20261116_gby_yetki_sistemi.sql', 'zz_20261116_il_kongre_sistemi.sql', 'zz_20261116_yk_kurum_gorevleri.sql', 'zz_20261116_kurulus_canli_fiyat_sartlar.sql',
  'zz_20261116_kredi_denge.sql', 'zz_20261116_davet_aktiflik.sql', 'zz_20261116_mod_gorev_finans.sql', 'zz_20261116_kurucu_partiler.sql', 'zz_20261116_kayit_onay_ad_soyad.sql', 'zz_20261117_ad_soyad_profil.sql', 'zz_20261117_hukuk_reformu.sql', 'zz_20261117_kursu_kurumsal.sql', 'zz_20261117_kursu_kurumsal_yanit.sql'];
const sql = ['-- SEÇİM SİMÜLASYONU ONLINE — üretilmiş kaynak; elle düzenlemeyin.',
  '-- Oyunu sıfırlamaz. Tek işlem, otomatik yedek ve oyuncu verisi bütünlük kontrolü.',
  '-- Canlı sunucuda uygulanmış sürümler için tekrar çalıştırmayın; bu dosya kurulum/eşitleme kaynağıdır.',
  'begin;', oku('kalicilik_bas.sql'),
  `select oyun.guncelleme_basla('${surum}', 'supabase-kurulum.sql');`,
  ...dosyalar.map(okuKosullu), oku('kalicilik_son.sql'), 'select oyun.guncelleme_bitti();',
  '-- 159: bütün fonksiyonlar yazıldıktan sonra RPC yüzeyi kapanır. Bu dosya listenin ve işlemin sonunda kalmalı.',
  oku('159_rpc_yuzey.sql'),
  'commit;', '', oku('04_zamanlayici.sql'), ''].join('\n');
fs.mkdirSync(path.join(kok, 'dist'), { recursive: true });
fs.writeFileSync(path.join(kok, 'dist/supabase-kurulum.sql'), sql);
console.log('dist/supabase-kurulum.sql', sql.split('\n').length, 'satır');
