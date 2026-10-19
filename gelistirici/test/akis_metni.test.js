// Akışta HTML karakter kodları etiket sanılmasın; tarayıcı bağımlılığı olmayan regresyon testi.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dosyalar = [
  '../www/canli_ek.js',
  '../../www/index.html',
  '../../docs/index.html',
];

for (const dosya of dosyalar) {
  test(`Akış metni güvenli ve okunaklı: ${dosya}`, () => {
    const kaynak = fs.readFileSync(path.join(__dirname, dosya), 'utf8');
    const fonksiyon = kaynak.match(/function akisMetinHtml\(m\)\{[\s\S]*?\n\}/);
    assert.ok(fonksiyon, 'akış metni işleyicisi bulunmalı');
    const e = s => String(s).replace(/[&<>"']/g, c => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
    const akisMetinHtml = vm.runInNewContext(`${fonksiyon[0]}\nakisMetinHtml`, { e });
    const sonuc = akisMetinHtml("Türkiye'nin #Seçim gündemi & <haber> \"alıntı\"");
    assert.match(sonuc, /Türkiye&#39;nin/);
    assert.doesNotMatch(sonuc, /data-etk="39"/);
    assert.equal((sonuc.match(/class="etk"/g) || []).length, 1);
    assert.match(sonuc, /data-etk="seçim">#Seçim<\/span>/);
    assert.match(sonuc, /&amp; &lt;haber&gt; &quot;alıntı&quot;/);
    assert.equal(akisMetinHtml("Özel #39 ifadesi"), 'Özel <span class="etk" data-etk="39">#39</span> ifadesi');
  });
}
