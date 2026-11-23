// docs/kullanici-sozlesmesi.html üretir (modüldeki tek metin kaynağından). Çalıştır: node gelistirici/build/sozlesme_sayfasi.js
const fs=require('fs'), vm=require('vm'), path=require('path');
const kok=path.join(__dirname,'..','..');
const kod=fs.readFileSync(path.join(kok,'gelistirici/www/kullanici_sozlesmesi.js'),'utf8');
const ctx={window:{}, document:{}, localStorage:{getItem(){return null},setItem(){}}, AYAR:{ILETISIM:'feniksklein@gmail.com'}, METIN:{}, e:(s)=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))};
vm.createContext(ctx); vm.runInContext(kod, ctx);
const S=ctx.window.SOZLESME;
const govde=S.metin().replace('feniksklein@gmail.com','<a href="mailto:feniksklein@gmail.com">feniksklein@gmail.com</a>');
const html=`<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kullanıcı Sözleşmesi · Seçim Simülasyonu Online</title>
<meta name="description" content="Seçim Simülasyonu Online Kullanıcı Sözleşmesi">
<!-- Üretilmiş sayfa: kaynak gelistirici/www/kullanici_sozlesmesi.js (SOZLESME.metin). Elle düzenleme; metni modülde değiştirip yeniden üret. -->
<style>
:root{--bg:#0E1530;--panel:#151E3D;--txt:#EEF1FA;--mut:#A9B2D1;--ink:#8B6CFF;--al:#E5484D}
*{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--txt);font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif}
main{max-width:760px;margin:0 auto;padding:32px 16px 64px} h1{font-size:28px;line-height:1.2;margin:0 0 6px} .alt{color:var(--mut);margin:0 0 24px}
.kart{background:var(--panel);border-radius:14px;padding:18px 20px;margin:0 0 16px} h4,h2{margin:18px 0 6px;font-size:18px} p{margin:0 0 10px;overflow-wrap:anywhere}
a{color:#B9A6FF} .not{color:var(--mut);font-size:14px}
</style></head><body><main>
<h1>Kullanıcı Sözleşmesi</h1><p class="alt">Seçim Simülasyonu Online · FeniksKlein · Sürüm ${S.surum} · Yürürlük ${S.yururluk}</p>
<div class="kart">${govde}
</div>
<p class="not">Kişisel verilerin işlenmesi: <a href="gizlilik.html">Gizlilik Politikası ve KVKK Aydınlatma Metni</a> · İletişim: <a href="mailto:feniksklein@gmail.com">feniksklein@gmail.com</a></p>
</main></body></html>
`;
const hedef=path.join(kok,'docs/kullanici-sozlesmesi.html');
fs.writeFileSync(hedef, html);
console.log('yazıldı', hedef, html.length);
