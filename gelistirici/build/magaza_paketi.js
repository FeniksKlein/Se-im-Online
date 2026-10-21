// Mağaza uygulamasının web içeriği: docs/ (canlı web oyunu) → mobil/www
// Canlı web ile telefon uygulaması birebir aynı dosyaları kullanır; yalnızca Supabase istemcisi
// internetten (CDN) değil uygulamanın içinden yüklenir ve uygulama sürümü SURUM dosyasından yazılır.
// Kullanım: node gelistirici/build/magaza_paketi.js   (mobil/ içinde "npm install" yapılmış olmalı)
const fs = require('fs'), path = require('path');
const kok = path.join(__dirname, '../..');
const kaynak = path.join(kok, 'docs'), hedef = path.join(kok, 'mobil/www');
fs.rmSync(hedef, { recursive: true, force: true });
fs.mkdirSync(hedef, { recursive: true });
const dosyalar = fs.readdirSync(kaynak).filter(f => /\.js$/.test(f));
for (const f of dosyalar) fs.copyFileSync(path.join(kaynak, f), path.join(hedef, f));
let html = fs.readFileSync(path.join(kaynak, 'index.html'), 'utf8');
const surum = fs.readFileSync(path.join(kok, 'gelistirici/SURUM'), 'utf8').trim();
const cdn = /<script src="https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@2\/dist\/umd\/supabase\.min\.js"><\/script>/;
if (!cdn.test(html)) throw new Error('Supabase CDN etiketi bulunamadı');
html = html.replace(cdn, '<script src="supabase.min.js"></script>');
html = html.replace(/window\.UYGULAMA_SURUM = "[^"]*";/, `window.UYGULAMA_SURUM = ${JSON.stringify(surum)};`);
fs.writeFileSync(path.join(hedef, 'index.html'), html);
// Supabase istemcisi (npm paketinden)
const aday = ['dist/umd/supabase.js', 'dist/umd/supabase.min.js'].map(x => path.join(kok, 'mobil/node_modules/@supabase/supabase-js', x)).find(x => fs.existsSync(x));
if (!aday) throw new Error('@supabase/supabase-js bulunamadı: önce mobil/ içinde npm install çalıştır');
fs.copyFileSync(aday, path.join(hedef, 'supabase.min.js'));
// Sayfanın yüklediği her yerel dosya pakette mi? (statik ve sonradan yüklenen modüller)
const tum = html + dosyalar.map(f => fs.readFileSync(path.join(hedef, f), 'utf8')).join('\n');
const istenen = new Set([...tum.matchAll(/(?:src="|src=')([\w.-]+\.js)(?:\?[^"']*)?["']/g)].map(m => m[1]));
for (const m of tum.matchAll(/\.src\s*=\s*["']([\w.-]+\.js)(?:\?[^"']*)?["']/g)) istenen.add(m[1]);
const eksik = [...istenen].filter(f => !fs.existsSync(path.join(hedef, f)));
if (eksik.length) throw new Error('Pakette eksik dosya: ' + eksik.join(', '));
console.log(`mobil/www hazır: ${dosyalar.length + 2} dosya, sürüm ${surum}, yerel modüller: ${[...istenen].length}`);
