// Yerel önizleme: derlenmiş uygulamayı (dist/index.html) yerel Postgres'teki oyuna bağlar.
// Supabase yerine window.API_TEST kullanılır; her RPC psql ile "giriş yapmış oyuncu" olarak çalışır.
// Kullanım: node test/onizleme_sunucu.js [port]   → http://127.0.0.1:8788/?kad=OyuncuAdi
const http = require('http'), fs = require('fs'), path = require('path'), { execFile } = require('child_process');
const kok = path.join(__dirname, '..');
const PORT = +(process.argv[2] || 8788);

const lit = (v) => {
  if (v === null || v === undefined) return 'null';
  if (typeof v === 'number') return String(v);
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (Array.isArray(v)) return "'{" + v.map(x => '"' + String(x).replace(/["\\]/g, '\\$&') + '"').join(',') + "}'";
  if (typeof v === 'object') return "'" + JSON.stringify(v).replace(/'/g, "''") + "'::jsonb";
  return "'" + String(v).replace(/'/g, "''") + "'";
};
const psql = (sql) => new Promise((res, rej) => execFile('psql', ['-h', '/tmp', '-U', 'postgres', '-d', 'oyun_test', '-At', '-q', '-v', 'ON_ERROR_STOP=1', '-c', sql],
  { maxBuffer: 64 << 20 }, (err, out, errOut) => err ? rej(new Error((errOut || err.message).split('\n')[0].replace(/^ERROR:\s+/, '').replace(/^psql:[^:]*:\d+:\s*/, ''))) : res(out)));

async function rpc(uid, fn, args) {
  if (!/^[a-z_0-9]+$/.test(fn)) throw new Error('geçersiz fonksiyon');
  const a = Object.entries(args || {}).map(([k, v]) => `${k} => ${lit(v)}`).join(', ');
  const out = await psql(`select set_config('request.jwt.claim.sub', '${uid}', false); select coalesce(to_jsonb(public.${fn}(${a})), 'null'::jsonb);`);
  const satir = out.trim().split('\n'); return JSON.parse(satir[satir.length - 1]);
}

const KOPRU = `<script>
window.API_TEST = (function(){
  const kad = new URLSearchParams(location.search).get('kad') || '';
  let uid = null;
  async function post(u, b){ const r = await fetch(u, { method: 'POST', body: JSON.stringify(b) }); const j = await r.json(); if (j.hata) throw new Error(j.hata); return j.veri; }
  return {
    async rpc(fn, args){ if (!uid) uid = await post('/uid', { kad }); return post('/rpc', { uid, fn, args }); },
    async oturum(){ if (!kad) return null; uid = await post('/uid', { kad }); return uid ? { email: kad + '@yerel' } : null; },
    async kayit(){ return { onayGerekli: true }; }, async kodDogrula(){}, async kodTekrar(){}, async giris(){}, async sifreSifirla(){}, async sifreGuncelle(){}, async cikis(){}
  };
})();
window.PUSH_TEST = true;
</script>`;

http.createServer(async (req, res) => {
  try {
    if (req.method === 'GET') {
      let html = fs.readFileSync(path.join(kok, 'dist/index.html'), 'utf8');
      html = html.replace(/<script src="https:[^"]+"><\/script>/g, '').replace('<body>', '<body>' + KOPRU);
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }); return res.end(html);
    }
    let govde = ''; for await (const p of req) govde += p;
    const b = JSON.parse(govde || '{}');
    let veri;
    if (req.url === '/uid') veri = (await psql(`select id from oyun.profiller where lower(kad)=lower(${lit(b.kad)})`)).trim() || null;
    else veri = await rpc(b.uid, b.fn, b.args);
    res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify({ veri }));
  } catch (err) {
    res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify({ hata: err.message }));
  }
}).listen(PORT, '127.0.0.1', () => console.log('önizleme http://127.0.0.1:' + PORT));
