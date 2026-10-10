// Windows/Linux: yalnızca dosya üretir, veritabanına bağlanmaz.
const fs = require('fs'), path = require('path');
const kok = path.join(__dirname, '..');
const oku = ad => fs.readFileSync(path.join(kok, 'sql', ad), 'utf8').replace(/\r\n/g, '\n').trimEnd();
const surum = fs.readFileSync(path.join(kok, 'SURUM'), 'utf8').trim();
if (!/^\d{4}\.\d{2}\.\d{2}-\d+$/.test(surum)) throw new Error('Geçersiz sürüm');
const dosyalar = ['01_sema.sql', 'iller.sql', '02_motor.sql', '03_api.sql', '05_kabine_sosyal.sql', '07_devlet.sql', '08_asama3.sql', '09_vatandas.sql', '10_ekonomi2.sql', '11_bos_makam.sql', '12_mevzuat.sql', '13_meclis.sql', '14_guvenlik.sql', '15_ekonomi3.sql', '16_moderator.sql', '17_basin_teskilat.sql', '18_ara_secim_istifa.sql', '19_siyaset_ekonomi4.sql', '20_siyasi_sistem.sql', '21_banka_transferleri.sql', '22_saatlik_vadeli.sql', '23_bagimsiz_adaylik.sql', '24_gayrimenkul.sql', '25_milli_piyango.sql', '26_ekonomi_yasalari.sql', '27_ekonomi_etkileri.sql', '28_sirket_banka_asgari.sql', '29_oyuncu_banka_liste.sql', '30_sirket_kira_satis_sermaye.sql', '31_piyasa_kazikazan.sql', '32_mulk_pazar.sql', '33_genel_baskan_vekil.sql', '34_maas_meclis.sql', '35_soru_anket.sql', '36_parti_toplanti_disiplin.sql', '37_gb_vekil_goreve_baslat.sql', '38_canli_20261008.sql', '39_oyuncu_deneyimi.sql', '40_portre_erkek_secenekleri.sql', '41_kurucu_ideoloji.sql', '42_ekonomi_vitrin_emlak.sql', '43_meclis_salt_cogunluk.sql', '44_il_emlak_stok_vergi.sql', '45_emlak_temizlik.sql', '46_miting_canli.sql', '47_test_baslangic.sql', '48_eyetkin_parti.sql', '49_celal_parti.sql', '50_parti_miting_bagimsiz.sql', '51_matestappen_parti.sql', '52_gby_gorev_miting_tepki.sql', '53_gby_gorev_yetki.sql', '54_ittifak_teklif_ortak_aday.sql', '55_dernekler.sql', '56_mv_test_ittifak_vitrin.sql', '57_dernek_sohbet.sql', '58_sivil_demokrasi_kurultay.sql', '59_roportaj_duello_cevap_hakki.sql', '60_imza_dilekce_katilim.sql', '61_katilim_son_duzeltmeler.sql', '62_halka_arz.sql', '62_hayat_gorevleri.sql', '63_gb_mv_cb_adaylik.sql', '65_mv_bakan_uyum.sql', '06_yetkiler.sql', '68_bildirim_goster.sql'];
const sql = ['-- SEÇİM SİMÜLASYONU ONLINE — üretilmiş kaynak; elle düzenlemeyin.',
  '-- Oyunu sıfırlamaz. Tek işlem, otomatik yedek ve oyuncu verisi bütünlük kontrolü.',
  '-- Canlı sunucuda uygulanmış sürümler için tekrar çalıştırmayın; bu dosya kurulum/eşitleme kaynağıdır.',
  'begin;', oku('kalicilik_bas.sql'),
  `select oyun.guncelleme_basla('${surum}', 'supabase-kurulum.sql');`,
  ...dosyalar.map(oku), oku('kalicilik_son.sql'), 'select oyun.guncelleme_bitti();', 'commit;', '', oku('04_zamanlayici.sql'), ''].join('\n');
fs.mkdirSync(path.join(kok, 'dist'), { recursive: true });
fs.writeFileSync(path.join(kok, 'dist/supabase-kurulum.sql'), sql);
console.log('dist/supabase-kurulum.sql', sql.split('\n').length, 'satır');
