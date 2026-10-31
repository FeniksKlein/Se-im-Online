// Canlı sinyal: istemci yalnız ilgili anahtarı dinler, kopunca eski hıza döner,
// SQL ise özel kutuyu ve mesaj metnini açmaz.
// Çalıştır: node gelistirici/test/canli_sinyal.js
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');

const kok = path.join(__dirname, '..');
const js = fs.readFileSync(path.join(kok, 'www/canli_sinyal.js'), 'utf8');
const sql = fs.readFileSync(path.join(kok, 'sql/159_canli_sinyal.sql'), 'utf8');

function sahne() {
  const kanallar = [];
  const zaman = { simdi: 0, iv: [], to: [] };
  const context = {
    Date: { now: () => zaman.simdi },
    setInterval: (fn, ms) => { const id = { fn, ms, tur: 'iv' }; zaman.iv.push(id); return id; },
    clearInterval: (id) => { if (id) id.silindi = true; },
    setTimeout: (fn, ms) => { const id = { fn, ms, tur: 'to' }; zaman.to.push(id); return id; },
    clearTimeout: (id) => { if (id) id.silindi = true; },
    Promise,
    document: { hidden: false },
    D: { durum: { profil: { id: '11111111-1111-1111-1111-111111111111', il_id: 34, parti: { id: 7 } } }, canli: null },
    YUK: { otomatik: () => true },
    canliDurdur() { if (this.D && this.D.canli) { this.clearInterval(this.D.canli); this.D.canli = null; } },
    API: {
      realtimeClient: {
        channel(ad) {
          const ch = {
            ad, handlers: [],
            on(tur, filtre, cb) { this.handlers.push({ tur, filtre, cb }); return this; },
            subscribe(cb) { this.statusCb = cb; kanallar.push(ch); return this; }
          };
          return ch;
        },
        removeChannel(ch) { ch.silindi = true; }
      }
    }
  };
  context.globalThis = context;
  vm.createContext(context);
  vm.runInContext(js, context);
  return { context, kanallar, zaman };
}

const s = sahne();
assert.equal(s.context.CANLI.sohbetAnahtari('il'), 'sohbet:il:34');
assert.equal(s.context.CANLI.sohbetAnahtari('parti'), 'sohbet:parti:7');
assert.equal(s.context.CANLI.sohbetAnahtari('ittifak'), null, 'ittifak kimliği sunucunun sinyal alanından gelir');

let n = 0;
s.context.CANLI.izle({ anahtarlar: ['sohbet:genel', 'mesaj metni sızmasın'], tazele: () => { n++; }, hizliMs: 6000, yedekMs: 90000, yayilim: 0, pencereMs: 1000 });
assert.equal(s.zaman.iv.at(-1).ms, 6000, 'bağlantı yokken eski hız');
assert.equal(s.kanallar.length, 1);
const filtreler = s.kanallar[0].handlers.map(h => h.filtre.filter);
assert.ok(filtreler.every(f => f === 'anahtar=eq.sohbet:genel'), 'mesaj metni filtreye girmez');
assert.equal(s.kanallar[0].handlers.length, 2, 'ekleme ve güncelleme');

s.kanallar[0].statusCb('SUBSCRIBED');
assert.equal(s.zaman.iv.at(-1).ms, 90000, 'bağlanınca yavaş yedek');
assert.equal(s.zaman.iv[0].silindi, true);
assert.ok(s.context.D.canli, 'ekran yenilemesi kurulu');

async function bosalt() { await Promise.resolve(); await Promise.resolve(); }
(async () => {
s.kanallar[0].handlers[0].cb();
await bosalt();
assert.equal(n, 1, 'sinyal tazeler');
s.zaman.simdi = 100;
s.kanallar[0].handlers[1].cb();
await bosalt();
assert.equal(n, 1, 'aynı pencerede ikinci sinyal bekler');
s.zaman.to.at(-1).fn();
await bosalt();
assert.equal(n, 2, 'pencere sonunda biriken sinyal bir kez tazeler');

s.kanallar[0].statusCb('CHANNEL_ERROR');
assert.equal(s.zaman.iv.at(-1).ms, 6000, 'kopunca eski hıza döner');

s.context.canliDurdur();
assert.equal(s.context.D.canli, null);
assert.equal(s.kanallar[0].silindi, true, 'ekrandan çıkınca abonelik kapanır');

s.context.CANLI.kutuBaslat();
const kutu = s.kanallar.at(-1);
assert.ok(kutu.handlers.every(h => h.filtre.filter === 'anahtar=eq.kutu:11111111-1111-1111-1111-111111111111'));
assert.equal(s.context.D.canli, null, 'kişisel kutu ekran yoklamasını ele geçirmez');
s.context.CANLI.kutuKopar();
assert.equal(kutu.silindi, true);

s.context.document.hidden = true;
s.context.CANLI.izle({ anahtarlar: ['miting:4'], tazele: () => { n++; }, hizliMs: 6000, yedekMs: 90000, yayilim: 0 });
s.kanallar.at(-1).handlers[0].cb();
await bosalt();
assert.equal(n, 2, 'gizli sekmede sinyal okuma başlatmaz');

// SQL sözleşmesi: sinyal tablosunun kendisinde özel yük yok. Sohbet RPC'si metin döndürmeye devam eder.
const tablo = sql.slice(sql.indexOf('create table if not exists public.canli_sinyal'), sql.indexOf('comment on table'));
assert.match(tablo, /anahtar text primary key/);
assert.match(tablo, /rev bigint/);
assert.doesNotMatch(tablo, /metin|para|kad|user_id/i);
assert.match(sql, /enable row level security/);
assert.match(sql, /grant select on public\.canli_sinyal to authenticated/);
assert.doesNotMatch(sql, /grant insert on public\.canli_sinyal|grant update on public\.canli_sinyal|grant delete on public\.canli_sinyal/i);
assert.match(sql, /revoke all on function oyun\.canli_sinyal\(text\) from public, anon, authenticated/);
assert.match(sql, /grant execute on function oyun\.canli_sinyal_gorur\(text\) to authenticated/);
assert.match(sql, /p_anahtar = 'kutu:' \|\| \(select auth\.uid\(\)\)::text/);
assert.match(sql, /oyun\.kanal_coz\(p, c\) = kod/);
assert.match(sql, /alter publication supabase_realtime add table public\.canli_sinyal/);
assert.match(sql, /'sinyal', 'sohbet:' \|\| k/);
assert.match(sql, /'sonraki_sn'/);
assert.doesNotMatch(sql, /grant execute on function public\.sohbet_oku|grant execute on function public\.secim_gecesi/);

const birlestir = fs.readFileSync(path.join(kok, 'build/sql_birlestir.js'), 'utf8');
assert.match(birlestir, /159_canli_sinyal\.sql/);
const derle = fs.readFileSync(path.join(kok, 'build/derle.js'), 'utf8');
assert.match(derle, /canli_sinyal\.js/);
console.log('canli_sinyal: istemci ve SQL sözleşmesi tamam');
})().catch(e => { console.error(e); process.exit(1); });
