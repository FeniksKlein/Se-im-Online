// Bağımsız hızlı regresyon testi: üçüncü koltuğun Adalet Bakanına bağlanması.
// node gelistirici/test/adliye_3_uye.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const sources = [
  path.join(__dirname, '../www/adliye.js'),
  path.join(__dirname, '../../docs/index.html')
];

for (const file of sources) {
  const content = fs.readFileSync(file, 'utf8');
  const source = file.endsWith('.html')
    ? content.slice(content.indexOf('function adlMahkemeHtml('), content.indexOf('function adlJuriHtml('))
    : content;
  const context = vm.createContext({
    e: v => String(v ?? ''), tarihSaat: v => v || '—', adlTarih: v => v || '—', ADL: {},
    toast: () => { throw Error('3. üye için kullanıcı eylemi tetiklenmemeli'); }
  });
  vm.runInContext(source, context, { filename: file });
  const html = vm.runInContext('adlMahkemeHtml', context);
  const base = {
    ayar: { gorev_gun: 30 }, cb_miyim: false, vekil_miyim: true, uye_miyim: true, salt_cogunluk: 5,
    uyeler: [
      { sira: 1, kaynak: 'cb', kad: 'Başkan', gorev_bit: '2026-11-01', benim: false },
      { sira: 2, kaynak: 'meclis', kad: null, adaylar: [], benim: false },
      { sira: 3, kaynak: 'adalet', kad: 'AdaletBakani', gorev_bit: null, benim: true }
    ]
  };
  let result = html(base);
  assert.match(result, /3\. üye · Adalet Bakanı/);
  assert.match(result, /Adalet Bakanlığı görevi sürdükçe üyedir/);
  assert.match(result, /adlMeclisOyModal\(2\)/);
  assert.doesNotMatch(result, /adlMeclisOyModal\(3\)/);
  assert.doesNotMatch(result, /adlAzilModal\(3\)/);
  assert.doesNotMatch(result, /Yüksek Mahkeme üyeliğinden istifa et/);
  result = html({ ...base, uyeler: [base.uyeler[0], base.uyeler[1], { ...base.uyeler[2], kad: null, benim: false }] });
  assert.match(result, /Yeni Adalet Bakanının göreve başlaması bekleniyor/);
  assert.doesNotMatch(result, /adlMeclisOyModal\(3\)/);
  console.log(`${path.relative(process.cwd(), file)}: 3. üye testi başarılı`);
}
