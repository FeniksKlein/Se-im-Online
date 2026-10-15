/* Canli veritabanina dokunmadan ilan panosu ve teklif RPC'lerini sinar. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dosya = path.join(__dirname, '..', 'www', 'ihale_ilan_panosu.js');
const kaynak = fs.readFileSync(dosya, 'utf8');
const calls = [];
const fields = {
  ipS_h11: { value: '44' }, ipT_h11: { value: '850000' },
  ipS_k21: { value: '45' }, ipT_k21: { value: '900000' }
};
const kamu = {
  acik: [{ id: 21, ad: 'Sahil yolu', kurum_ad: 'Muğla Belediyesi', il: 'Muğla', durum: 'acik',
    bit: '2099-01-01T12:00:00Z', tavan: 1000000, teklif_say: 2, tekliflerim: [], deneyim: 0 }],
  yapim: [], biten: [], insaat_sirketlerim: [{ id: 45, ad: 'Yapı AŞ', deneyim: 3 }],
  yetki: { belediye_il: 48, bakanliklar: [] }
};
const hizmet = {
  ihaleler: [{ id: 11, il: 'Muğla', baslik: 'Park <script>alert(1)</script>', aciklama: 'İlçe parkı',
    sektor: 'hizmet', butce: 1000000, teklif_bit: '2099-01-01T12:00:00Z', teklif_sayisi: 1,
    durum: 'acik', benim_tekliflerim: [], baskanim: false }],
  sirketlerim: [{ id: 44, ad: 'Temizlik Ltd', sektor: 'hizmet', pay: 60 }]
};
const escape = x => String(x).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const ctx = vm.createContext({
  document: { head: { appendChild() {} }, createElement: () => ({ style: {} }), getElementById: id => id === 'ipStil' ? null : fields[id] },
  window: {}, D: { durum: { profil: { makamlar: [{ tur: 'bel' }] } } }, PZ: {},
  API: { rpc: async (name, params) => { calls.push({ name, params });
    if (name === 'ihale_ekrani') return kamu;
    if (name === 'belediye_is_pazar') return hizmet;
    return { tamam: true }; } },
  yukleniyor() {}, iskelet: (baslik, html) => { ctx.last = { baslik, html }; },
  toast() {}, hataCevir: x => x, e: escape, onayla: async () => true,
  Date, Number, Math, Object, Promise, String, Array
});
vm.runInContext(kaynak, ctx, { filename: dosya });

(async () => {
  await ctx.ihaleIlanPanosu();
  assert.match(ctx.last.html, /Sahil yolu/);
  assert.match(ctx.last.html, /Park &lt;script&gt;/);
  assert.doesNotMatch(ctx.last.html, /<script>alert/);
  assert.match(ctx.last.html, /Belediye hizmet ihalesi/);
  assert.match(ctx.last.html, /Kamu yapım ihalesi/);
  assert.match(ctx.last.html, /ipS_h11/);
  assert.match(ctx.last.html, /ipS_k21/);

  await ctx.ipTeklifVer('hizmet', 11);
  assert(calls.some(x => x.name === 'belediye_is_teklif_ver' && x.params.p_sirket === 44 && x.params.p_tutar === 850000));
  await ctx.ipTeklifVer('kamu', 21);
  assert(calls.some(x => x.name === 'ihale_teklif' && x.params.p_sirket === 45 && x.params.p_tutar === 900000));

  fields.ipT_h11.value = '5';
  const once = calls.filter(x => x.name === 'belediye_is_teklif_ver').length;
  await ctx.ipTeklifVer('hizmet', 11);
  assert.equal(calls.filter(x => x.name === 'belediye_is_teklif_ver').length, once);

  await ctx.ipSecim('hizmet', 'acik');
  assert.match(ctx.last.html, /Park &lt;script&gt;/);
  assert.doesNotMatch(ctx.last.html, /Sahil yolu/);
  console.log('İhale İlan Panosu: ilan görünürlüğü, XSS, filtre ve teklif testleri başarılı.');
})().catch(e => { console.error(e); process.exitCode = 1; });
