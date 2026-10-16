// Bakanlıklara yeni görev kataloğu: eski icraatları ve makamları koruyarak ekleme.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const kok = path.join(__dirname, '..');
const kaynak = fs.readFileSync(path.join(kok, 'sql/101_bakanlik_gorevleri.sql'), 'utf8').trim();
const migration = fs.readFileSync(path.join(kok, '../migrations/20261016_bakanlik_36_yeni_gorev.sql'), 'utf8').trim();
const kodlar = [...kaynak.matchAll(/^\s*\('([^']+)','([^']+)','Görev: /gm)];
const bakanliklar = ['adalet', 'disisleri', 'icisleri', 'maliye', 'savunma', 'egitim',
  'saglik', 'sanayi', 'ticaret', 'tarim', 'ulastirma', 'calisma'];

assert.equal(kodlar.length, 36, '12 bakanlık × 3 görev olmalı');
assert.equal(new Set(kodlar.map(x => x[1])).size, 36, 'Görev kodları tekil olmalı');
for (const b of bakanliklar) {
  assert.equal(kodlar.filter(x => x[2] === b).length, 3, `${b} için üç görev olmalı`);
}
assert.ok(kodlar.every(x => x[1].startsWith('bg_')), 'Görev kodları ayrı bir önek taşımalı');
assert.ok(kaynak.includes('on conflict (kod) do nothing'), 'Tekrar kurulum mevcut görevleri değiştirmemeli');
assert.ok(!/\b(?:delete|truncate|drop|update)\b\s+(?:from\s+)?oyun\./i.test(kaynak), 'Oyuncu verisi silinmemeli/değiştirilmemeli');
assert.equal(migration, `begin;\n${kaynak}\ncommit;`, 'Canlı migration kaynakla aynı olmalı');

const anaKaynak = fs.readFileSync(path.join(kok, 'sql/07_devlet.sql'), 'utf8');
assert.ok(!/delete from oyun\.icraatlar/i.test(anaKaynak), 'Kurulum, yeni görevleri silmemeli');
console.log('Başarılı: 12 bakanlık, 36 benzersiz görev, tekrar kurulum ve migration uyumu.');
