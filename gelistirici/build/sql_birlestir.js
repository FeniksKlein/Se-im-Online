// Windows/Linux: yalnızca dosya üretir, veritabanına bağlanmaz.
const fs = require('fs'), path = require('path');
const kok = path.join(__dirname, '..');
const oku = ad => fs.readFileSync(path.join(kok, 'sql', ad), 'utf8').replace(/\r\n/g, '\n').trimEnd();
const surum = fs.readFileSync(path.join(kok, 'SURUM'), 'utf8').trim();
if (!/^\d{4}\.\d{2}\.\d{2}-\d+$/.test(surum)) throw new Error('Geçersiz sürüm');
const dosyalar = ['01_sema.sql', 'iller.sql', '02_motor.sql', '03_api.sql', '05_kabine_sosyal.sql', '07_devlet.sql', '08_asama3.sql', '09_vatandas.sql', '10_ekonomi2.sql', '11_bos_makam.sql', '12_mevzuat.sql', '13_meclis.sql', '14_guvenlik.sql', '15_ekonomi3.sql', '16_moderator.sql', '17_basin_teskilat.sql', '18_ara_secim_istifa.sql', '19_siyaset_ekonomi4.sql', '20_siyasi_sistem.sql', '21_banka_transferleri.sql', '22_saatlik_vadeli.sql', '23_bagimsiz_adaylik.sql', '24_gayrimenkul.sql', '25_milli_piyango.sql', '26_ekonomi_yasalari.sql', '06_yetkiler.sql'];
const sql = ['-- SEÇİM SİMÜLASYONU ONLINE — üretilmiş kaynak; elle düzenlemeyin.',
  '-- Oyunu sıfırlamaz. Tek işlem, otomatik yedek ve oyuncu verisi bütünlük kontrolü.',
  '-- Canlı sunucuda uygulanmış sürümler için tekrar çalıştırmayın; bu dosya kurulum/eşitleme kaynağıdır.',
  'begin;', oku('kalicilik_bas.sql'),
  `select oyun.guncelleme_basla('${surum}', 'supabase-kurulum.sql');`,
  ...dosyalar.map(oku), oku('kalicilik_son.sql'), 'select oyun.guncelleme_bitti();', 'commit;', '', oku('04_zamanlayici.sql'), ''].join('\n');
fs.mkdirSync(path.join(kok, 'dist'), { recursive: true });
fs.writeFileSync(path.join(kok, 'dist/supabase-kurulum.sql'), sql);
console.log('dist/supabase-kurulum.sql', sql.split('\n').length, 'satır');
