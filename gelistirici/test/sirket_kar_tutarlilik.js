// Şirketlerim kartının Ekonomi 3.0 pazar tahminini finans detaylarıyla aynı
// kaynaktan göstermesini koruyan çevrimdışı regresyon testi.
// node gelistirici/test/sirket_kar_tutarlilik.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const files = ['www/index.html', 'docs/index.html', 'gelistirici/www/aday_sirket_ek.js'];
const sectors = [
  'ozel_okul', 'ozel_hastane', 'market', 'ulasim', 'enerji',
  'teknoloji', 'sanayi', 'ticaret', 'insaat', 'medya', 'tarim'
];
const estimate = {
  gelir: 200000, gider: 100000, ruhsat: 10000, ceza: 1000,
  vergi: 43000, net: 46000
};
const fmt = n => Math.round(Number(n)).toLocaleString('tr-TR');

for (const file of files) {
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  const begin = source.indexOf('function sirketMiniFinans(s,asgari){');
  const end = source.indexOf('\nasync function sirketFinansDetay', begin);
  assert.ok(begin >= 0 && end > begin, `${file}: finans kartı bulunamadı`);
  const render = new Function('fmt', `${source.slice(begin, end)}\nreturn sirketMiniFinans;`)(fmt);

  for (const sector of sectors) {
    const company = { id: 1, sektor: sector, sermaye: 2962305, pazar_tahmin: estimate };
    const html = render(company, 30000);
    assert.match(html, /46\.000 ₺/, `${file}: ${sector} için sunucu net kârı kullanılmalı`);
    assert.doesNotMatch(html, /406\.940 ₺/, `${file}: ${sector} için eski sabit oran kullanılmamalı`);
    assert.match(html, /Gelecek 7 günün/, `${file}: tahmin dönemi açıklanmalı`);

    const missing = render({ ...company, pazar_tahmin: null }, 30000);
    assert.match(missing, /Canlı pazar tahmini şu an alınamadı/, `${file}: tahmin eksikse eski formüle dönülmemeli`);
    assert.doesNotMatch(missing, /406\.940 ₺/);
  }

  const classic = render({ id: 2, sektor: 'banka', sermaye: 1000000, pazar_tahmin: null }, 30000);
  assert.match(classic, /7 günlük faaliyet tahmini/, `${file}: klasik şirketlerin hesabı korunmalı`);
}

console.log(`Şirket kâr tutarlılığı: ${files.length} arayüz × ${sectors.length} pazar sektörü + klasik sektör OK`);
