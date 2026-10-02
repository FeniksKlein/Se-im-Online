// Supabase panelinden tek dosya olarak yapıştırılabilen sunucu fonksiyonlarını üretir (push-gonder, odeme-webhook)
const fs = require('fs'), path = require('path');
for (const ad of ['push-gonder', 'odeme-webhook']) {
  const kok = path.join(__dirname, '..', 'supabase', 'functions', ad);
  const cekirdek = fs.readFileSync(path.join(kok, 'cekirdek.mjs'), 'utf8').replace(/^export /gm, '');
  const sunucu = fs.readFileSync(path.join(kok, 'index.ts'), 'utf8').replace(/^import .*cekirdek.*\n/m, '');
  const cikti = `// TEK DOSYA SÜRÜMÜ — Supabase → Edge Functions → ${ad} → index.ts içine olduğu gibi yapıştır\n` + cekirdek + '\n' + sunucu;
  fs.writeFileSync(path.join(__dirname, '..', 'dist', ad + '.ts'), cikti);
  console.log(`dist/${ad}.ts`, cikti.length, 'bayt');
}
