// Basın: tüm erişim, bakiye ve ücret kararları RPC tarafından verilir.
const BASIN_TUR = { haber: 'Haber', kose: 'Köşe yazısı', propaganda: 'PROPAGANDA' };
function basinDugme(metin, fn, sinif = 'ikinci') {
  const b = document.createElement('button'); b.className = 'btn ' + sinif;
  b.textContent = metin; b.onclick = fn; return b;
}
function basinAlan(id, etiket, ozellik = '', deger = '') {
  return `<div class="alan"><label for="${id}">${etiket}</label><input id="${id}" ${ozellik} value="${e(deger)}"></div>`;
}
// Çift tıklamayla ikinci ödeme/yayın oluşmasını engeller; hatada form korunur.
async function basinIslem(buton, fn, sonra) {
  if (buton.disabled) return;
  buton.disabled = true;
  try {
    const r = await API.rpc(fn.ad, fn.args);
    D._hayat = null; D._banka = null;
    modalKapat(); toast('İşlem tamamlandı.');
    await sonra(r);
  } catch (err) { toast(hataCevir(err.message), true); }
  finally { buton.disabled = false; }
}
function basinForm(baslik, alanlar, dugme, ad, args, sonra) {
  const m = modal(`<h3>${e(baslik)}</h3><form id="basinForm">${alanlar}<button class="btn altin" type="submit">${e(dugme)}</button></form><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
  $('#basinForm', m).onsubmit = ev => {
    ev.preventDefault();
    basinIslem($('button[type="submit"]', m), { ad, args: args(m) }, sonra);
  };
  return m;
}
// 05.11.2026 — Basın Meydanı 2.0: künye, canlı tiraj yarışı, gazete büfesi (kâğıt ön sayfalar).
const BS_AY = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
let bsTabloTam = false;
function bsZaman(ts) {
  const d = new Date(ts); if (isNaN(d)) return { g: '', a: '', y: '', hg: '' };
  const p = {}; new Intl.DateTimeFormat('tr-TR', { timeZone: 'Europe/Istanbul', day: 'numeric', month: 'numeric', year: 'numeric', weekday: 'long' }).formatToParts(d).forEach(x => { p[x.type] = x.value; });
  return { g: p.day, a: BS_AY[(+p.month || 1) - 1], y: p.year, hg: p.weekday };
}
function bsKalan(ms) {
  if (ms <= 0) return 'şimdi';
  const dk = Math.floor(ms / 60000), g = Math.floor(dk / 1440), sa = Math.floor(dk % 1440 / 60), d = dk % 60;
  return g > 0 ? `${g} gün ${sa} sa` : sa > 0 ? `${sa} sa ${d} dk` : `${Math.max(1, d)} dk`;
}
function bsHareket(simdiki, eski) {
  if (!simdiki) return '';
  if (!eski) return '<span class="bs-hareket yeni">yeni</span>';
  if (eski > simdiki) return `<span class="bs-hareket ust" aria-label="${eski - simdiki} sıra yükseldi">▲${eski - simdiki}</span>`;
  if (eski < simdiki) return `<span class="bs-hareket alt" aria-label="${simdiki - eski} sıra düştü">▼${simdiki - eski}</span>`;
  return '<span class="bs-hareket ayni">aynı</span>';
}
function bsStil() {
  if (document.getElementById('so-basin-stil-v2')) return;
  const css = document.createElement('style'); css.id = 'so-basin-stil-v2';
  css.textContent = [
    '.bs-kunye{text-align:center;margin:2px 0 18px;padding:0 4px}',
    '.bs-kunye-ust{display:flex;justify-content:space-between;gap:10px;font-size:11.5px;color:var(--mut);padding-bottom:8px;border-bottom:1px solid var(--line2)}',
    '.bs-kunye h1{font-family:Georgia,"Times New Roman",serif;font-weight:700;font-size:clamp(34px,10.5vw,50px);line-height:1.02;letter-spacing:-.02em;margin:12px 0 10px;color:var(--txt)}',
    '.bs-kunye p{margin:0;padding-top:9px;border-top:3px double var(--line2);font-size:13px;color:var(--txt2)}',
    /* tiraj yarışı */
    '.bs-tiraj{background:var(--panel);border:1px solid var(--line2);border-radius:20px;padding:16px 15px 12px;margin:0 0 14px}',
    '.bs-tiraj-bas{display:flex;justify-content:space-between;align-items:flex-start;gap:10px;margin-bottom:6px}',
    '.bs-tiraj-bas h2{font-family:var(--disp);font-size:24px;font-weight:700;line-height:1.05;margin:0 0 5px}',
    '.bs-canli{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:800;color:var(--al2)}',
    '.bs-canli i{width:8px;height:8px;border-radius:50%;background:var(--al);animation:bsNabiz 1.6s infinite}',
    '@keyframes bsNabiz{0%{box-shadow:0 0 0 0 rgba(240,69,75,.55)}70%{box-shadow:0 0 0 8px rgba(240,69,75,0)}100%{box-shadow:0 0 0 0 rgba(240,69,75,0)}}',
    '@media (prefers-reduced-motion:reduce){.bs-canli i{animation:none}}',
    '.bs-kalan{text-align:right;flex:none}.bs-kalan small{display:block;font-size:11px;color:var(--mut)}.bs-kalan b{font:700 17px/1.2 var(--disp);font-variant-numeric:tabular-nums}',
    '.bs-tablo{list-style:none;margin:6px 0 0;padding:0}',
    '.bs-satir{display:flex;align-items:center;gap:11px;padding:11px 0;cursor:pointer;min-width:0}',
    '.bs-satir+.bs-satir{border-top:1px solid var(--line)}',
    '.bs-no{flex:none;width:28px;text-align:center;font:700 26px/1 var(--disp);color:var(--txt2);font-variant-numeric:tabular-nums}',
    '.bs-satir.lider .bs-no{color:#F2B33D}',
    '.bs-ad{flex:1;min-width:0}.bs-ad b{display:block;font-family:Georgia,"Times New Roman",serif;font-size:15.5px;line-height:1.2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '.bs-ad small{display:block;font-size:11.5px;color:var(--mut);margin-top:5px}',
    '.bs-cubuk{height:7px;margin-top:6px;border-radius:7px;background:rgba(255,255,255,.07);overflow:hidden}.bs-cubuk i{display:block;height:100%;border-radius:7px;background:linear-gradient(90deg,var(--ink),var(--ink2))}',
    '.bs-satir.lider .bs-cubuk i{background:linear-gradient(90deg,#c98b14,#F2B33D)}',
    '.bs-satir.benim .bs-ad b::after{content:"Senin";margin-left:7px;padding:1px 6px;border-radius:5px;font:800 10.5px/1.5 -apple-system,system-ui,sans-serif;background:var(--inkbg);color:var(--ink2);vertical-align:2px}',
    '.bs-sayi{flex:none;text-align:right;min-width:64px}.bs-sayi b{display:block;font:700 21px/1.05 var(--disp);font-variant-numeric:tabular-nums}.bs-sayi small{font-size:11px;color:var(--mut)}',
    '.bs-hareket{display:block;font-size:11px;font-weight:800;margin-top:2px}.bs-hareket.ust{color:var(--good)}.bs-hareket.alt{color:var(--al2)}.bs-hareket.yeni{color:var(--ink2)}.bs-hareket.ayni{color:var(--faint)}',
    '.bs-tam{display:block;width:100%;margin:4px 0 0;padding:10px;border:0;border-radius:11px;background:var(--panel2);color:var(--txt);font-weight:800;font-size:13.5px;cursor:pointer}',
    '.bs-tiraj-alt{display:flex;flex-wrap:wrap;gap:6px 14px;margin-top:12px;padding-top:11px;border-top:1px solid var(--line);font-size:12px;color:var(--mut)}.bs-tiraj-alt b{color:var(--txt)}',
    '.bs-nasil{margin-top:10px;font-size:12.5px;color:var(--mut)}.bs-nasil summary{cursor:pointer;font-weight:800;color:var(--txt2);list-style:none}.bs-nasil summary::-webkit-details-marker{display:none}',
    '.bs-nasil summary::after{content:" ›";}.bs-nasil[open] summary::after{content:" ‹"}.bs-nasil p{margin:8px 0 0;line-height:1.55}',
    '.bs-bos{padding:16px 4px 8px;text-align:center;color:var(--mut);font-size:13.5px;line-height:1.5}',
    /* Türkiye Gündem şeridi */
    '.bs-tg{display:flex;align-items:center;gap:12px;width:100%;text-align:left;margin:0 0 14px;padding:13px 14px;border:0;border-radius:16px;cursor:pointer;color:var(--txt);background:var(--panel);box-shadow:inset 4px 0 0 var(--al),inset 0 0 0 1px var(--line2)}',
    '.bs-tg>span:first-child{flex:1;min-width:0}.bs-tg b{display:block;font-family:Georgia,"Times New Roman",serif;font-size:17px}.bs-tg small{display:block;font-size:12.5px;color:var(--mut);margin-top:2px;line-height:1.4}',
    '.bs-tg em{font-style:normal;font-size:11px;font-weight:800;color:var(--al2)}.bs-tg .ok{font-size:24px;color:var(--txt2)}',
    /* gazetem */
    '.bs-gazetem{background:linear-gradient(160deg,#1d2650,#151c3b);border:1px solid var(--line2);border-radius:20px;padding:16px 15px;margin:0 0 14px}',
    '.bs-gazetem .bs-etiket{font-size:12px;font-weight:800;color:var(--ink2)}',
    '.bs-gazetem h3{font-family:Georgia,"Times New Roman",serif!important;font-size:23px!important;line-height:1.15!important;margin:3px 0 0!important;overflow-wrap:anywhere}',
    '.bs-gazetem>p{margin:6px 0 0;font-size:13px;color:var(--txt2);line-height:1.5}',
    '.bs-gz-sayi{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));margin:13px 0 2px;border-top:1px solid var(--line2);border-bottom:1px solid var(--line2)}',
    '.bs-gz-sayi div{padding:9px 3px;text-align:center}.bs-gz-sayi div+div{border-left:1px solid var(--line)}',
    '.bs-gz-sayi b{display:block;font:700 18px/1.15 var(--disp);font-variant-numeric:tabular-nums;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bs-gz-sayi small{font-size:11px;color:var(--mut)}',
    '.bs-teklif{background:var(--panel);border:1px solid rgba(168,149,255,.35);border-radius:16px;padding:14px;margin:0 0 12px}',
    '.bs-teklif h3{font-size:15px!important;margin:0 0 4px!important}.bs-teklif p{margin:0;font-size:13px;color:var(--txt2)}',
    '.bs-teklif .bs-iki{display:grid;grid-template-columns:1fr 1fr;gap:8px}.bs-teklif .bs-iki .btn{margin-top:10px}',
    '.bs-yazarlik{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:6px 14px;margin:0 0 12px}',
    '.bs-yazarlik .kv{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:8px 0}',
    '.bs-yazarlik .kv+.kv{border-top:1px solid var(--line)}.bs-yazarlik .kv .btn{width:auto;margin:0;padding:9px 13px;font-size:13px}',
    /* büfe */
    '.bs-bufe-bas{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin:24px 0 12px}',
    '.bs-bufe-bas h2{font-family:var(--disp);font-size:24px;font-weight:700;margin:0}.bs-bufe-bas span{font-size:12px;color:var(--mut)}',
    '.bs-bufe{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}',
    '@media(max-width:340px){.bs-bufe{grid-template-columns:1fr}}',
    '@media(min-width:700px){.bs-bufe{grid-template-columns:repeat(3,minmax(0,1fr))}}',
    '.bs-kagit{position:relative;display:flex;flex-direction:column;min-width:0;min-height:214px;padding:11px 11px 10px;border:0;border-radius:4px;text-align:left;cursor:pointer;background:var(--paper);color:var(--paperInk);font-family:Georgia,"Times New Roman",serif;box-shadow:0 1px 0 rgba(255,255,255,.6) inset,0 16px 26px -16px rgba(0,0,0,.85),0 2px 0 #d5dae8,0 4px 0 #c3c9da}',
    '.bs-kagit:active{transform:translateY(1px)}',
    '.bs-kagit-ust{display:flex;justify-content:space-between;align-items:center;gap:6px;font:700 10px/1.3 -apple-system,system-ui,sans-serif;color:#525a78}',
    '.bs-kagit-ust .bs-fiyat{padding:2px 6px;border-radius:4px;background:rgba(27,33,64,.08)}.bs-kagit-ust .bs-fiyat.bedava{background:rgba(19,120,82,.12);color:#126a49}',
    '.bs-kagit-ust .bs-rutbe{font-family:var(--disp);font-size:13px;color:var(--paperInk)}',
    '.bs-kagit.lider .bs-kagit-ust .bs-rutbe{padding:1px 6px;border-radius:4px;background:#F2B33D;color:#2a1d00}',
    '.bs-kagit-ad{display:block;margin:9px 0 0;padding-bottom:6px;border-bottom:3px double rgba(27,33,64,.55);font-size:18px;font-weight:700;line-height:1.08;text-align:center;letter-spacing:-.01em;overflow-wrap:anywhere}',
    '.bs-kagit-slogan{display:block;margin:5px 0 0;font-size:10.5px;font-style:italic;line-height:1.3;text-align:center;color:#4a5272;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}',
    '.bs-kagit-tur{display:block;margin:10px 0 3px;font:800 10px/1.3 -apple-system,system-ui,sans-serif;color:#5a6282}',
    '.bs-kagit-tur.propaganda{color:#b4232a}',
    '.bs-kagit-manset{display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:3;overflow:hidden;font-size:15px;font-weight:700;line-height:1.22;overflow-wrap:anywhere}',
    '.bs-kagit-bos{display:block;margin-top:10px;font-size:12.5px;font-style:italic;color:#6a7290}',
    '.bs-kagit-alt{display:flex;gap:10px;margin-top:auto;padding-top:9px;border-top:1px solid rgba(27,33,64,.18);font:600 11px/1.3 -apple-system,system-ui,sans-serif;color:#4a5272}',
    '.bs-kagit-alt b{font:700 14px/1 var(--disp);color:var(--paperInk);margin-right:2px}',
    '.bs-kagit-sahip{display:block;margin-top:4px;font:500 10.5px/1.3 -apple-system,system-ui,sans-serif;color:#6a7290;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}',
    '.bs-kagit-sahip .im{color:#5a3fe0;font-weight:800}',
    /* ön sayfa (gazete içi) */
    '.bs-onsayfa{margin:0 0 10px;padding:14px 15px 13px;border-radius:6px;background:var(--paper);color:var(--paperInk);text-align:center;box-shadow:0 18px 30px -20px rgba(0,0,0,.9)}',
    '.bs-os-ust,.bs-os-alt{display:flex;justify-content:space-between;gap:8px;font:600 11px/1.3 -apple-system,system-ui,sans-serif;color:#4a5272}',
    '.bs-onsayfa h1{font-family:Georgia,"Times New Roman",serif;font-weight:700;font-size:clamp(28px,9vw,44px);line-height:1.04;letter-spacing:-.02em;margin:10px 0 6px;color:var(--paperInk);overflow-wrap:anywhere}',
    '.bs-onsayfa .slogan{margin:0 0 9px;font-family:Georgia,serif;font-style:italic;font-size:13px;color:#4a5272;overflow-wrap:anywhere}',
    '.bs-os-alt{padding-top:7px;border-top:3px double rgba(27,33,64,.5)}',
    '.bs-tiraj-serit{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));margin:0 0 12px;background:var(--panel);border:1px solid var(--line2);border-radius:14px;overflow:hidden}',
    '.bs-tiraj-serit div{padding:10px 4px;text-align:center}.bs-tiraj-serit div+div{border-left:1px solid var(--line)}',
    '.bs-tiraj-serit b{display:block;font:700 19px/1.15 var(--disp);font-variant-numeric:tabular-nums}.bs-tiraj-serit small{font-size:11px;color:var(--mut)}',
    '#gazEylem{display:grid;gap:0;margin:0 0 12px}#gazEylem .btn{margin-top:8px}',
    '#icerik .bs-bufe~.sos-menu-karti,#icerik .sos-menu-karti{margin-top:20px}'
  ].join('');
  document.head.appendChild(css);
}
function bsSayacBaslat() {
  canliDurdur();
  if (!document.querySelector('[data-bs-sayac]')) return;
  D.canli = setInterval(() => {
    const el = document.querySelectorAll('[data-bs-sayac]');
    if (!el.length) { clearInterval(D.canli); D.canli = null; return; }
    el.forEach(x => { x.textContent = bsKalan(new Date(x.getAttribute('data-bs-sayac')) - simdi()); });
  }, 15000);
}
function bsTirajHtml(tj) {
  if (!tj || !tj.hafta) return '';
  const liste = (tj.canli || []).filter(x => Number(x.tiraj) > 0);
  const en = Math.max(1, Number(liste[0] && liste[0].tiraj) || 0);
  const gorunen = bsTabloTam ? liste : liste.slice(0, 5);
  const satir = (x, i) => {
    const sira = i + 1;
    return `<li class="bs-satir${sira === 1 ? ' lider' : ''}${x.benim ? ' benim' : ''}" role="button" tabindex="0" onclick="ekranAc(()=>gazeteEkrani(${Number(x.gazete_id)}))" onkeydown="if(event.key==='Enter')ekranAc(()=>gazeteEkrani(${Number(x.gazete_id)}))">
      <span class="bs-no">${sira}</span>
      <div class="bs-ad"><b>${e(x.ad)}</b><div class="bs-cubuk"><i style="width:${Math.max(3, Math.round(Number(x.tiraj) / en * 100))}%"></i></div>
      <small>${fmt(x.yayin, 0)} yazı · ${fmt(x.okur, 0)} okur · ${fmt(x.abone, 0)} abone</small></div>
      <div class="bs-sayi"><b>${fmt(x.tiraj, 0)}</b><small>nüsha</small>${bsHareket(sira, x.gecen_sira)}</div></li>`;
  };
  const gecen = tj.gecen && (tj.gecen.liste || [])[0];
  const alt = [];
  if (gecen) alt.push(`Geçen hafta birinci: <b>${e(gecen.ad)}</b>, ${fmt(gecen.tiraj, 0)} nüsha`);
  if (tj.rekor && Number(tj.rekor.tiraj) > 0) alt.push(`Rekor: <b>${e(tj.rekor.ad)}</b>, ${fmt(tj.rekor.tiraj, 0)}`);
  return `<section class="bs-tiraj" aria-labelledby="bsTirajBaslik">
    <div class="bs-tiraj-bas"><div><h2 id="bsTirajBaslik">Tiraj yarışı</h2><span class="bs-canli"><i></i>Canlı sayım · ${e(tj.hafta.no)}. hafta</span></div>
    <div class="bs-kalan"><small>Resmî tiraja</small><b data-bs-sayac="${e(tj.hafta.bit)}">${e(bsKalan(new Date(tj.hafta.bit) - simdi()))}</b></div></div>
    ${liste.length ? `<ol class="bs-tablo">${gorunen.map(satir).join('')}</ol>` : '<div class="bs-bos">Bu hafta henüz sayı çıkmadı. Bu hafta ilk yazıyı yayımlayan gazete tabloya girer.</div>'}
    ${liste.length > 5 ? `<button type="button" class="bs-tam" onclick="bsTabloTam=!bsTabloTam;basinEkrani()">${bsTabloTam ? 'Daralt' : 'Tüm tablo · ' + liste.length + ' gazete'}</button>` : ''}
    ${alt.length ? `<div class="bs-tiraj-alt">${alt.map(x => `<span>${x}</span>`).join('')}</div>` : ''}
    <details class="bs-nasil"><summary>Tiraj nasıl hesaplanır?</summary>
    <p>Hafta Pazartesi 00:00'da başlar. Haftanın en iyi 14 yazısı sayılır: köşe yazısı en çok, haber orta, propaganda en az puan alır; uzun yazı (800 karakter ve üstü) tam puan alır. Bu taban; gazeteyi okuyan gerçek oyuncu, aktif abone ve köşe yazılarına yorum yapan okur sayısıyla büyür. Ücretsiz gazeteler %10 daha geniş dağıtılır. Sahip ve köşe yazarlarının okuması sayılmaz.</p>
    <p>Pazartesi gece yarısı geçen haftanın resmî tirajı Türkiye Gündem'de açıklanır ve gazete sahiplerine bildirilir.</p></details>
  </section>`;
}
function bsKagitHtml(g, t) {
  const ucretli = Number(g.abonelik_ucret) > 0;
  const son = g.son;
  const tur = son ? (BASIN_TUR[son.tur] || son.tur) : '';
  const z = son ? bsZaman(son.zaman) : null;
  const durum = [g.abonem ? '<span class="im">Abonesin</span>' : '', g.yaziyim ? '<span class="im">Yazarsın</span>' : ''].filter(Boolean).join(' · ');
  return `<button type="button" class="bs-kagit${t && t.sira === 1 ? ' lider' : ''}" aria-label="${e(g.ad)} gazetesini oku" onclick="ekranAc(()=>gazeteEkrani(${Number(g.id)}))">
    <span class="bs-kagit-ust"><span class="bs-fiyat${ucretli ? '' : ' bedava'}">${ucretli ? e(tlYaz(g.abonelik_ucret)) + ' / ay' : 'Ücretsiz'}</span>${t && t.sira ? `<span class="bs-rutbe">${t.sira === 1 ? 'Haftanın lideri' : t.sira + '.'}</span>` : ''}</span>
    <b class="bs-kagit-ad">${e(g.ad)}</b>
    ${g.slogan ? `<i class="bs-kagit-slogan">${e(g.slogan)}</i>` : ''}
    ${son ? `<span class="bs-kagit-tur${son.tur === 'propaganda' ? ' propaganda' : ''}">${e(tur)} · ${e(z.g + ' ' + z.a)}</span><strong class="bs-kagit-manset">${e(son.baslik)}</strong>` : '<span class="bs-kagit-bos">İlk sayısını bekliyor.</span>'}
    <span class="bs-kagit-alt"><span><b>${fmt(t ? t.tiraj : 0, 0)}</b>nüsha</span><span><b>${fmt(g.abone, 0)}</b>abone</span></span>
    <span class="bs-kagit-sahip">${e(g.sahip)}${durum ? ' · ' + durum : ''}</span>
  </button>`;
}
async function basinEkrani() {
  bsStil();
  yukleniyor('Basın / Gazeteler');
  let d, tj = null;
  try {
    const s = await Promise.allSettled([API.rpc('basin'), API.rpc('basin_tiraj')]);
    if (s[0].status !== 'fulfilled') throw s[0].reason;
    d = s[0].value || {};
    tj = s[1].status === 'fulfilled' && s[1].value && typeof s[1].value === 'object' ? s[1].value : null;
  } catch (err) { iskelet('Basın / Gazeteler', `<div class="kart"><p>${e(hataCevir(err && err.message || String(err)))}</p><button class="btn ikinci" onclick="basinEkrani()">Tekrar dene</button></div>`, { geri: true }); return; }
  const tmap = {};
  (tj && tj.canli || []).filter(x => Number(x.tiraj) > 0).forEach((x, i) => { tmap[Number(x.gazete_id)] = Object.assign({}, x, { sira: i + 1 }); });
  const bugun = bsZaman(tj && tj.simdi || simdi());
  const benimT = d.benim ? tmap[Number(d.benim.id)] : null;
  const benimHam = d.benim && tj ? (tj.canli || []).find(x => Number(x.gazete_id) === Number(d.benim.id)) : null;
  const gazeteler = (d.gazeteler || []).slice().sort((a, b) => ((tmap[b.id] || {}).tiraj || 0) - ((tmap[a.id] || {}).tiraj || 0));
  iskelet('Basın / Gazeteler', `<header class="bs-kunye">
      <div class="bs-kunye-ust"><span>${e(bugun.hg)}, ${e(bugun.g + ' ' + bugun.a + ' ' + bugun.y)}</span><span>${tj && tj.hafta ? e(tj.hafta.no) + '. hafta' : 'Oyuncu basını'}</span></div>
      <h1>Basın Meydanı</h1>
      <p>Oyuncuların gazeteleri, köşe yazıları ve açıkça etiketlenmiş siyasi yayınlar.</p></header>
    ${bsTirajHtml(tj)}
    <button type="button" class="bs-tg" onclick="otomatikGazeteEkrani()"><span><em>Son dakika</em><b>Türkiye Gündem</b><small>Adaylar, parti değişimleri, beyannameler ve ittifaklar. Ücretsiz, 5 dakikada bir güncellenir.</small></span><span class="ok" aria-hidden="true">›</span></button>
    <section class="bs-gazetem" id="basinBenim">${d.benim
      ? `<span class="bs-etiket">Gazeten</span><h3>${e(d.benim.ad)}</h3>
        <div class="bs-gz-sayi"><div><b>${fmt(benimHam ? benimHam.tiraj : 0, 0)}</b><small>Bu hafta</small></div><div><b>${benimT ? benimT.sira + '.' : '—'}</b><small>Sıra</small></div><div><b>${fmt(d.benim.abone || 0, 0)}</b><small>Abone</small></div><div><b>${e(tlYaz(d.benim.kasa || 0))}</b><small>Kasa</small></div></div>`
      : `<span class="bs-etiket">Kendi gazeten</span><h3>Gazeteni kur, tiraj yarışına katıl</h3><p>Kuruluş bedeli ${e(tlYaz(d.kurulus_ucreti))}. Ücretsiz ya da abonelikli yayın yapabilir, köşe yazarı tutabilirsin.</p>`}</section>
    <div id="basinTeklifler"></div><div id="basinYazarlik"></div>
    <div class="bs-bufe-bas"><h2>Gazete büfesi</h2><span>${fmt(gazeteler.length, 0)} gazete · tiraja göre</span></div>
    <div id="basinListe" class="bs-bufe">${gazeteler.map(g => bsKagitHtml(g, tmap[Number(g.id)])).join('')}</div>`, { geri: true });
  $('#basinBenim').appendChild(basinDugme(d.benim ? 'Gazetemi yönet' : 'Gazete kur', () => d.benim ? ekranAc(() => gazeteEkrani(d.benim.id)) : gazeteKurModal(d.kurulus_ucreti), d.benim ? 'ikinci' : ''));
  for (const t of d.teklifler || []) {
    const el = document.createElement('section'); el.className = 'bs-teklif';
    el.innerHTML = `<h3>Köşe yazarlığı teklifi</h3><p><b>${e(t.ad)}</b> gazetesinden ${e(t.sahip)}, yazı başına ${tlYaz(t.ucret)} öneriyor.</p><div class="bs-iki"></div>`;
    const iki = el.querySelector('.bs-iki');
    for (const kabul of [true, false]) {
      const b = basinDugme(kabul ? 'Teklifi kabul et' : 'Reddet', () => {
        el.querySelectorAll('button').forEach(x => { if (x !== b) x.disabled = true; });
        basinIslem(b, { ad: 'gazete_yazar_yanit', args: { p_gazete: t.gazete_id, p_kabul: kabul } }, basinEkrani).finally(() => el.querySelectorAll('button').forEach(x => x.disabled = false));
      }, kabul ? '' : 'ikinci'); iki.appendChild(b);
    }
    $('#basinTeklifler').appendChild(el);
  }
  const yazarlik = (d.gazeteler || []).filter(g => g.yaziyim);
  if (yazarlik.length) $('#basinYazarlik').innerHTML = '<section class="bs-yazarlik"><div class="kv" style="padding-top:8px"><b style="font-size:14px">Köşe yazarı olduğun gazeteler</b></div>' + yazarlik.map(g => '<div class="kv"><span>' + e(g.ad) + '</span><button class="btn ikinci" onclick="ekranAc(()=>gazeteEkrani(' + Number(g.id) + '))">Yazı yaz</button></div>').join('') + '</section>';
  const liste = $('#basinListe');
  if (!liste.children.length) liste.outerHTML = '<div class="bs-tiraj"><div class="bs-bos">Henüz gazete yok. İlk gazeteyi sen kurabilirsin.</div></div>';
  bsSayacBaslat();
}
function gazeteKurModal(ucret) {
  basinForm('Gazete kur', `<p class="alt">Kuruluş için cüzdanından ${tlYaz(ucret)} ödenir.</p>` +
    basinAlan('gazAd', 'Gazete adı', 'required minlength="4" maxlength="40"') +
    basinAlan('gazSlogan', 'Slogan', 'maxlength="100"') +
    basinAlan('gazAbone', 'Aylık abonelik (₺) — ücretsiz için 0', 'type="number" min="0" step="1" required', 0),
    'Kuruluş bedelini öde ve kur', 'gazete_kur', m => ({ p_ad: $('#gazAd', m).value.trim(), p_slogan: $('#gazSlogan', m).value.trim(), p_abonelik: +$('#gazAbone', m).value }), r => ekranAc(() => gazeteEkrani(r.id)));
}
async function gazeteEkrani(id, veri) {
  let g = veri;
  if (!g) {
    yukleniyor('Gazete');
    try { g = await API.rpc('gazete_detay', { p_gazete: id }); }
    catch (err) { iskelet('Gazete', `<div class="kart">${e(hataCevir(err.message))}<button class="btn ikinci" onclick="yenidenCiz()">Tekrar dene</button></div>`); return; }
  }
  bsStil();
  const tjd = g.tiraj && typeof g.tiraj === 'object' ? g.tiraj : null, bz = bsZaman(simdi());
  const tjSerit = tjd ? `<div class="bs-tiraj-serit"><div><b>${fmt(tjd.hafta && tjd.hafta.tiraj || 0, 0)}</b><small>Bu hafta tiraj</small></div><div><b>${tjd.gecen && tjd.gecen.tiraj > 0 ? tjd.gecen.sira + '.' : '—'}</b><small>Geçen hafta sıra</small></div><div><b>${fmt(tjd.birincilik || 0, 0)}</b><small>Birincilik</small></div></div>` : '';
  iskelet('Basın / Gazeteler', `<header class="bs-onsayfa"><div class="bs-os-ust"><span>Sahibi: ${e(g.sahip)}</span><span>${g.abonelik_ucret > 0 ? e(tlYaz(g.abonelik_ucret)) + ' / ay' : 'Ücretsiz gazete'}</span></div><h1>${e(g.ad)}</h1>${g.slogan ? `<p class="slogan">${e(g.slogan)}</p>` : ''}<div class="bs-os-alt"><span>${e(bz.g + ' ' + bz.a + ' ' + bz.y)}</span><span>${fmt(g.abone, 0)} abone${g.abonelik_bitis ? ' · abonelik bitişi ' + e(tarihSaat(g.abonelik_bitis)) : ''}</span></div></header>${tjSerit}<div id="gazEylem"></div>
    <div id="gazYonetim"></div><div id="gazYayinlar">${(g.yayinlar || []).map(y => `<article class="kart basin-yazi"><span class="rozet ${y.tur === 'propaganda' ? 'kirmizi' : ''}">${e(BASIN_TUR[y.tur] || y.tur)}</span>${y.tur === 'propaganda' ? `<p class="basin-propaganda">Bu yayın siyasi propagandadır. Hedef parti: ${e(y.hedef_parti && (y.hedef_parti.ad || y.hedef_parti.kisa) || 'Belirtilmemiş')}</p>` : ''}<h2>${e(y.baslik)}</h2><div class="kucuk">${e(y.yazar)} · ${e(tarihSaat(y.zaman))}</div><div class="basin-metin">${e(y.metin)}</div>${y.kilitli ? '<div class="basin-kilit">Önizleme · Tam yazıyı okumak için gazeteye abone ol.</div>' : ''}${y.tur==='kose' && !y.kilitli && g.erisim ? `<div style="margin-top:10px"><button class="btn ikinci" onclick="gazeteKoseYorumGoster(${Number(y.id)},${Number(g.id)})">Yorumları gör / yorum yaz</button><div id="gaz_kose_yorum_${Number(y.id)}"></div></div>` : ''}</article>`).join('') || '<div class="bos">Henüz yazı yayımlanmamış.</div>'}</div>`, { geri: true });
  const eylem = $('#gazEylem');
  if (!g.erisim && g.abonelik_ucret > 0) eylem.appendChild(basinDugme('Abone ol · ' + tlYaz(g.abonelik_ucret), () => {
    basinForm('Gazeteye abone ol', `<p>${e(g.ad)} için cüzdanından ${tlYaz(g.abonelik_ucret)} ödenir. Abonelik bitişi işlemden sonra gösterilir.</p>`, 'Öde ve abone ol', 'gazete_abone_ol', () => ({ p_gazete: g.id }), r => gazeteEkrani(g.id, r));
  }, 'altin'));
  eylem.appendChild(basinDugme('Bu gazeteye bağış yap', () => aliciBagisModal('gazete',g.id,g.ad), 'ikinci'));
  if (g.sahibim || (g.yazarlar || []).some(y => y.benim)) eylem.appendChild(basinDugme('Yazı yayımla', () => gazeteYayinModal(g), 'altin'));
  if (g.sahibim) {
    const yon = $('#gazYonetim');
    yon.innerHTML = `<section class="kart"><h2>Gazete kasası</h2><b>${tlYaz(g.kasa)}</b><p class="kucuk">Abonelik gelirleri kasaya eklenir; yazar ücretleri buradan ödenir.</p><div id="gazSahipEylem"></div><details><summary>Son kasa hareketleri</summary>${(g.hareketler || []).map(h => `<div class="liste-satir"><div class="orta">${e(h.aciklama)}<div class="kucuk">${e(tarihSaat(h.zaman))}</div></div><b>${tlYaz(h.tutar)}</b></div>`).join('') || '<p class="kucuk">Henüz hareket yok.</p>'}</details></section><section class="kart"><h2>Köşe yazarları</h2><p class="alt">Oyuncu kullanıcı adıyla teklif gönder. Kabul eden yazar burada görünür ve yazı başına ücret alır.</p><div id="gazYazarlar"></div></section>`;
    const yer = $('#gazSahipEylem');
    yer.appendChild(basinDugme('Kasadan para çek', () => basinForm('Gazete geliri çek', `<p class="alt">Kasa: ${tlYaz(g.kasa)}</p>` + basinAlan('gazMiktar', 'Çekilecek tutar (₺)', 'type="number" min="100" step="1" required'), 'Cüzdanıma aktar', 'gazete_para_cek', m => ({ p_gazete: g.id, p_miktar: +$('#gazMiktar', m).value }), r => gazeteEkrani(g.id, r))));
    yer.appendChild(basinDugme('Slogan ve abonelik ayarları', () => basinForm('Gazete ayarları', basinAlan('gazSlogan', 'Slogan', 'maxlength="100"', g.slogan) + basinAlan('gazAbone', 'Aylık abonelik (₺) — ücretsiz için 0', 'type="number" min="0" step="1" required', g.abonelik_ucret), 'Kaydet', 'gazete_ayar', m => ({ p_gazete: g.id, p_slogan: $('#gazSlogan', m).value, p_abonelik: +$('#gazAbone', m).value }), r => gazeteEkrani(g.id, r))));
    yer.appendChild(basinDugme('Köşe yazarı işe al', () => basinForm('Yazarlık teklifi', basinAlan('gazKad', 'Oyuncunun kullanıcı adı', 'required maxlength="20"') + basinAlan('gazUcret', 'Yazı başına ücret (₺)', 'type="number" min="0" max="10000" step="1" required', 0), 'Teklif gönder', 'gazete_yazar_teklif', m => ({ p_gazete: g.id, p_kad: $('#gazKad', m).value.trim(), p_ucret: +$('#gazUcret', m).value }), r => gazeteEkrani(g.id, r))));
    for (const y of g.yazarlar || []) {
      const el = document.createElement('div'); el.className = 'basin-yazar';
      el.innerHTML = `<b>${e(y.kad)}</b><div class="kucuk">Yazı başına ${tlYaz(y.ucret)}</div>`;
      el.appendChild(basinDugme('Yazarlığı sonlandır', () => basinForm('Yazarlığı sonlandır', `<p>${e(y.kad)} artık bu gazetede yazı yayımlayamayacak.</p>`, 'Sonlandır', 'gazete_yazar_cikar', () => ({ p_gazete: g.id, p_kad: y.kad }), r => gazeteEkrani(g.id, r))));
      $('#gazYazarlar').appendChild(el);
    }
    if (!(g.yazarlar || []).length) $('#gazYazarlar').innerHTML = '<p class="kucuk">Henüz kabul edilmiş yazar yok. Yukarıdan teklif gönderebilirsin.</p>';
  }
}
async function gazeteKoseYorumGoster(yayinId,gazeteId){
 const host=document.getElementById("gaz_kose_yorum_"+yayinId);if(!host)return;
 host.textContent="Köşe yazısı yorumları yükleniyor...";
 try{
  const d=await API.rpc("gazete_kose_yorumlar",{p_yayin:yayinId,p_limit:50});
  host.innerHTML='<section class="kart" style="margin-top:10px"><h3>Yorumlar ('+fmt(d.yorum_sayisi,0)+')</h3>'+
   (d.yorumlar||[]).map(x=>'<div class="liste-satir"><div class="orta"><b>'+e(x.kad)+'</b> <span class="kucuk">'+e(tarihSaat(x.zaman))+'</span><div class="basin-metin">'+e(x.metin)+'</div></div>'+
    (x.silebilir?'<button type="button" class="btn ikinci" onclick="gazeteKoseYorumSil('+Number(x.id)+','+yayinId+','+gazeteId+')">Kaldır</button>':'')+'</div>').join('')+
   (d.yorumlar.length?'':'<p class="alt">Henüz yorum yapılmamış. İlk yorumu sen yazabilirsin.</p>')+
   '<div class="alan"><label for="gaz_yorum_metin_'+yayinId+'">Senin yorumun (2–1500 karakter)</label><textarea id="gaz_yorum_metin_'+yayinId+'" rows="3" minlength="2" maxlength="1500" placeholder="Bu köşe yazısı hakkında ne düşünüyorsun?"></textarea></div>'+
   '<button class="btn altin" type="button" onclick="gazeteKoseYorumYaz('+yayinId+','+gazeteId+')">Yorum gönder</button>'+
   '<p class="kucuk">30 saniyede bir, 24 saatte en fazla 25 yorum. Yorumunu sen veya gazetenin sahibi kaldırabilir.</p></section>';
 }catch(err){host.textContent=hataCevir(err.message);}
}
async function gazeteKoseYorumYaz(yayinId,gazeteId){
 const el=document.getElementById("gaz_yorum_metin_"+yayinId);if(!el)return;
 const metin=el.value.trim();
 if(metin.length<2||metin.length>1500){toast("Yorum 2–1500 karakter olmalı.",true);return;}
 try{await API.rpc("gazete_kose_yorum_yaz",{p_yayin:yayinId,p_metin:metin});toast("Yorumun yayımlandı.");await gazeteKoseYorumGoster(yayinId,gazeteId)}
 catch(err){toast(hataCevir(err.message),true);}
}
async function gazeteKoseYorumSil(yorumId,yayinId,gazeteId){
 if(!await onayla("Yorumu kaldır","Seçilen yorumu kaldırmak istiyor musun?","Kaldır"))return;
 try{await API.rpc("gazete_kose_yorum_sil",{p_yorum:yorumId});toast("Yorum kaldırıldı.");await gazeteKoseYorumGoster(yayinId,gazeteId)}
 catch(err){toast(hataCevir(err.message),true);}
}
async function gazeteYayinModal(g) {
  let partiler;
  try { partiler = await API.rpc('partiler'); }
  catch (err) { toast(hataCevir(err.message), true); return; }
  const m = basinForm('Yazı yayımla', `<div class="alan"><label for="gazTur">Yayın türü</label><select id="gazTur"><option value="haber">Haber</option><option value="kose">Köşe yazısı</option><option value="propaganda">Propaganda</option></select></div><div id="gazHedefAlan" hidden><p class="basin-propaganda">Yazı açıkça PROPAGANDA olarak etiketlenir ve oyun yayın akışında da duyurulur.</p><div class="alan"><label for="gazHedef">Hedef parti</label><select id="gazHedef"><option value="">Parti seç…</option>${partiler.filter(p => !p.kapali).map(p => `<option value="${e(p.id)}">${e(p.ad)} (${e(p.kisa)})</option>`).join('')}</select></div></div>` + basinAlan('gazBaslik', 'Başlık', 'required minlength="4" maxlength="100"') + '<div class="alan"><label for="gazMetin">Yazı (20–15000 karakter)</label><textarea id="gazMetin" class="basin-redaktor" rows="12" required minlength="20" maxlength="15000" spellcheck="true" autocapitalize="sentences" placeholder="Haberini veya köşe yazını buraya yaz..."></textarea><span id="gazSayac" aria-live="polite">0 / 5000 karakter</span><p class="kucuk">En az 20, en fazla 15.000 karakter. Yazı alanı boyunca tamamını yazabilir veya yapıştırabilirsin.</p></div>', 'Yayımla', 'gazete_yayinla', el => ({ p_gazete: g.id, p_tur: $('#gazTur', el).value, p_baslik: $('#gazBaslik', el).value.trim(), p_metin: $('#gazMetin', el).value.trim(), p_hedef_parti: $('#gazTur', el).value === 'propaganda' ? +$('#gazHedef', el).value : null }), r => gazeteEkrani(g.id, r));
  $('#gazTur', m).onchange = () => { const propaganda = $('#gazTur', m).value === 'propaganda'; $('#gazHedefAlan', m).hidden = !propaganda; $('#gazHedef', m).required = propaganda; };
  const gazYazi = $('#gazMetin', m), gazSayac = $('#gazSayac', m);
  const gazSay = () => { const n=Array.from(gazYazi.value).length; gazSayac.textContent=n+" / 5000 karakter"; gazSayac.style.color=n>=5000?"var(--gold)":"var(--txt2)"; };
  gazYazi.addEventListener('input',gazSay);gazSay();
}
