// Sohbet rozetleri için tarayıcı gerektirmeyen regresyon kontrolü.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const path = require('path');

function parca(html, baslangic, bitis) {
  const i = html.indexOf(baslangic);
  assert(i !== -1, `Fonksiyon bulunamadı: ${baslangic}`);
  const j = html.indexOf(bitis, i + baslangic.length);
  assert(j !== -1, `Fonksiyon sonu bulunamadı: ${bitis}`);
  return html.slice(i, j);
}

async function kontrol(dosya) {
  const html = fs.readFileSync(dosya, 'utf8');
  const satir = { classList: { yeni: false, toggle(ad, durum) { if (ad === 'mesaj-yeni') this.yeni = durum; } },
    dataset: { sohbetAlt: 'Tüm oyuncular' },
    ozet: { textContent: '' }, sag: { innerHTML: '' },
    querySelector(ad) { return ad === '[data-sohbet-ozet]' ? this.ozet : this.sag; } };
  let kanallar = [];
  const ortam = {
    D: { sekme: 'sohbet', yigin: [] },
    document: { hidden: false, querySelector(ad) { return ad === '[data-sohbet-kanal]' || ad === '[data-sohbet-kanal="genel"]' ? satir : null; } },
    API: { rpc: async (ad) => { assert.strictEqual(ad, 'sohbet_ozet'); return { kanallar }; } },
    $: ad => ad === '[data-sohbet-kanal]' ? satir : null,
    zamanKisa: () => '21:50', Number, Math,
  };
  const kod = [
    parca(html, 'function sohbetOkunmamisSayi(ok){', 'function iskelet('),
    parca(html, 'function sohbetKanalSagHtml(k){', 'async function sohbetListe('),
  ].join('\n');
  vm.runInNewContext(kod, ortam, { filename: dosya });

  assert.strictEqual(ortam.sohbetOkunmamisSayi({ ozel: 1, sohbet: 5 }), 5);
  assert.strictEqual(ortam.sohbetOkunmamisSayi({ ozel: 1 }), 1); // Eski sunucu uyumu.
  assert.strictEqual(ortam.sohbetOkunmamisSayi({ ozel: 0, sohbet: 0 }), 0);
  assert(ortam.sohbetKanalSagHtml({ okunmamis: 3, son: { zaman: 'x' } }).includes('Yeni mesaj · 3'));

  kanallar = [{ kanal: 'genel', okunmamis: 3, kilit: null, son: { kad: 'Test', metin: 'Yeni sohbet', zaman: 'x' } }];
  await ortam.sohbetKanallariTazele();
  assert.strictEqual(satir.classList.yeni, true);
  assert.strictEqual(satir.ozet.textContent, 'Test: Yeni sohbet');
  assert(satir.sag.innerHTML.includes('Yeni mesaj · 3'));

  kanallar = [{ kanal: 'genel', okunmamis: 0, kilit: null, son: { kad: 'Test', metin: 'Yeni sohbet', zaman: 'x' } }];
  await ortam.sohbetKanallariTazele();
  assert.strictEqual(satir.classList.yeni, false);
  assert(!satir.sag.innerHTML.includes('Yeni mesaj'));

  kanallar = [{ kanal: 'genel', okunmamis: 5, kilit: 'Erişim yok', son: null }];
  await ortam.sohbetKanallariTazele();
  assert.strictEqual(satir.classList.yeni, false);
  assert.strictEqual(satir.ozet.textContent, 'Erişim yok');
}

(async () => {
  const kok = path.join(__dirname, '..', '..');
  await kontrol(path.join(kok, 'www/index.html'));
  await kontrol(path.join(kok, 'gelistirici/www/index.html'));
  await kontrol(path.join(kok, 'docs/index.html'));
  console.log('Sohbet rozetleri: kaynak, uygulama ve web sürümünde başarılı.');
})().catch(err => { console.error(err); process.exitCode = 1; });
