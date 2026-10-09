/* =====================================================================
   ARAYÜZ 2 — portre, Gündem panosu, seçim gecesi, parti pusulası, tarih, mitingler
   Ana betikten sonra yüklenir; ana betikteki yardımcıları (e, $, API, D, modal…) kullanır.
   ===================================================================== */
"use strict";

/* ---------- Ek ikonlar (aynı çizgi dili: 24'lük ızgara, 2px çizgi) ---------- */
const _ik = (d) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
Object.assign(IKON, {
  banka: _ik('<path d="M3 10h18M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 21h18M12 3l9 5H3z"/>'),
  sirket: _ik('<path d="M4 21V7l8-4v18M12 21h8V11l-8-3M8 9v.01M8 13v.01M8 17v.01M16 14v.01M16 17v.01"/>'),
  ev: _ik('<path d="M4 11l8-7 8 7v9a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1z"/>'),
  grafik: _ik('<path d="M4 19V5M4 19h16M8 15l3-4 3 2 5-7"/>'),
  bilet: _ik('<path d="M4 8a2 2 0 0 0 0 4v4h16v-4a2 2 0 0 1 0-4V4H4zM10 4v12"/>'),
  fis: _ik('<path d="M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6"/>'),
  para: _ik('<rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M7 9v.01M17 15v.01"/>'),
  kalem: _ik('<path d="M4 20h4L19 9l-4-4L4 16zM14 6l4 4"/>'),
  gazete: _ik('<path d="M4 5h13v14a2 2 0 0 0 2 2H6a2 2 0 0 1-2-2zM17 9h3v10a2 2 0 0 1-2 2M8 9h5M8 13h5M8 17h3"/>'),
  anket: _ik('<path d="M5 20V10M12 20V4M19 20v-7"/>'),
  tarih: _ik('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
  insanlar: _ik('<circle cx="9" cy="8" r="3.5"/><path d="M3 20c.5-3.5 3-5.5 6-5.5s5.5 2 6 5.5M16 4.5a3.5 3.5 0 0 1 0 7M18 14.5c1.6.7 2.7 2.6 3 5.5"/>'),
  kumbara: _ik('<path d="M5 11a7 6 0 0 1 13-2h2v4l-2 1v3h-3v-2h-5v2H7v-3a6 6 0 0 1-2-3zM12 5v.01"/>'),
  uyari: _ik('<path d="M12 4l9 16H3zM12 10v4M12 17v.01"/>'),
  pusula: _ik('<circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2 5-5 2 2-5z"/>'),
  ok: _ik('<path d="M9 6l6 6-6 6"/>')
});

/* =====================================================================
   PORTRE — oyuncunun seçtiği kod "ten-saç-yüz-gözlük-kıyafet-zemin" ile çizilen SVG
   ===================================================================== */
const PORTRE = {
  ten: ["#F2D3B8", "#E5BA92", "#D09D70", "#B07A4F", "#8A5A3B", "#5E3B26"],
  sac: ["#1C1715", "#3A291D", "#6A472B", "#A26E3C", "#8E9096", "#2B2B30", "#080A0F", "#B34D32", "#E4BE6D", "#F0F0EB"],
  sacRenkAd: ["Siyah", "Koyu kahve", "Kahverengi", "Açık kahve", "Gri", "Koyu kül", "Kuzguni siyah", "Kızıl", "Sarı", "Beyaz"],
  kiyafet: ["#1F2A47", "#2E2E35", "#4A4F5A", "#5E2434", "#26442F", "#3B3F92", "#6A5A3D", "#E9ECF3"],
  zemin: ["#2B3A6B", "#3E2F6E", "#1F4D5A", "#5A3A2A", "#2F4F3A", "#4A2B45", "#5B4A1F", "#33415C"],
  sacAd: ["Saçsız", "Kısa", "Yandan ayrık", "Kıvırcık", "Uzun", "Topuz", "Küt", "Başörtüsü", "Açılmış", "At kuyruğu", "Asker tıraşı", "Sıfıra yakın", "Yanları kısa", "Undercut", "Pompadour", "Geri taranmış", "Dağınık kısa", "Dalgalı", "Keskin yan ayrım", "Klasik beyefendi", "Dikenli", "Düşük fade"],
  yuzAd: ["Yok", "Bıyık", "Kısa sakal", "Gür sakal", "Keçi sakalı", "Kalın bıyık", "Burma bıyık", "Üç günlük sakal", "Kirli sakal", "Top sakal", "Uzun sakal", "Çene çizgisi", "Nal bıyık"],
  gozAd: ["Yok", "Yuvarlak", "Köşeli"]
};
function portreKodCoz(kod) {
  if (!/^[0-9]{1,2}(-[0-9]{1,2}){5,6}$/.test(String(kod || ""))) return null;
  const p = String(kod).split("-").map(Number);
  const ten = p[0] % PORTRE.ten.length, sac = p[1] % PORTRE.sacAd.length, zemin = p[5] % PORTRE.zemin.length;
  // Eski 6 parçalı kodların orijinal saç rengini koru.
  const sacRenk = p.length === 7 ? p[6] % PORTRE.sac.length : (zemin * 7 + sac * 3 + ten) % 6;
  return { ten, sac, yuz: p[2] % PORTRE.yuzAd.length, goz: p[3] % PORTRE.gozAd.length, kiyafet: p[4] % PORTRE.kiyafet.length, zemin, sacRenk };
}
function portreSvg(kod, yedek) {
  const k = portreKodCoz(kod);
  if (!k) {   // portre yoksa: partinin renginde baş harfler
    const ad = String((yedek && yedek.ad) || "?"), renk = (yedek && yedek.renk) || "#3A4675";
    const bas = ad.replace(/[^A-Za-zÇĞİÖŞÜçğıöşü]/g, "").slice(0, 2).toLocaleUpperCase("tr") || "?";
    return `<svg class="portre" viewBox="0 0 64 64" role="img" aria-label="${e(ad)}"><rect width="64" height="64" fill="${e(renk)}"/><text x="32" y="41" text-anchor="middle" font-family="Kurul Display,Arial Narrow,sans-serif" font-weight="700" font-size="25" fill="#fff">${e(bas)}</text></svg>`;
  }
  const ten = PORTRE.ten[k.ten], sac = PORTRE.sac[k.sacRenk], kiy = PORTRE.kiyafet[k.kiyafet], zem = PORTRE.zemin[k.zemin];
  const golge = "rgba(0,0,0,.14)", cizgi = "#1B2140";
  let arka = "", on = "";
  // saç (arka katman: uzun saç, at kuyruğu, başörtüsü)
  if (k.sac === 4) arka = `<path d="M19 26c0-11 7-16 13-16s13 5 13 16v20H19z" fill="${sac}"/>`;
  if (k.sac === 9) arka = `<path d="M40 22c6 4 7 14 3 22-2-6-4-10-7-13z" fill="${sac}"/>`;
  if (k.sac === 7) arka = `<path d="M17 30c0-12 7-19 15-19s15 7 15 19c0 9-3 15-6 18H23c-3-3-6-9-6-18z" fill="${kiy === "#E9ECF3" ? "#7A5C8F" : kiy}"/>`;
  const sacOn = {
    1: `<path d="M21 25c0-9 5-13 11-13s11 4 11 13c-2-5-6-7-11-7s-9 2-11 7z" fill="${sac}"/>`,
    2: `<path d="M21 26c0-10 5-14 11-14s11 4 11 14c-3-6-8-8-13-7l-2-1c-3 1-6 4-7 8z" fill="${sac}"/><path d="M28 13l2 6" stroke="${golge}" stroke-width="1.2"/>`,
    3: `<g fill="${sac}">${[[23,20],[27,16],[32,14],[37,16],[41,20],[25,24],[39,24]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="4.6"/>`).join("")}</g>`,
    4: `<path d="M21 26c0-9 5-14 11-14s11 5 11 14c-4-4-7-8-11-8s-7 4-11 8z" fill="${sac}"/>`,
    5: `<circle cx="32" cy="10.5" r="5" fill="${sac}"/><path d="M21 25c0-8 5-12 11-12s11 4 11 12c-3-4-7-6-11-6s-8 2-11 6z" fill="${sac}"/>`,
    6: `<path d="M20 34V24c0-8 5-12 12-12s12 4 12 12v10l-3-1V24c-3-3-6-4-9-4s-6 1-9 4v9z" fill="${sac}"/>`,
    7: `<path d="M21 27c1-8 6-12 11-12s10 4 11 12c-3-3-7-5-11-5s-8 2-11 5z" fill="${kiy === "#E9ECF3" ? "#6A4E80" : kiy}" opacity=".9"/>`,
    8: `<path d="M21 24c0-3 1-5 2-6v8zM43 24c0-3-1-5-2-6v8z" fill="${sac}"/>`,
    9: `<path d="M21 25c0-9 5-13 11-13s11 4 11 13c-2-5-6-7-11-7s-9 2-11 7z" fill="${sac}"/>`,
    10: '<path d="M22 21q10-7 20 0v3q-10-4-20 0z" fill="' + sac + '"/>',
    11: '<path d="M23 22q9-4 18 0v2q-9-2-18 0z" fill="' + sac + '"/>',
    12: '<path d="M21 24q0-13 11-13t11 13l-4-3-3-5q-4 4-15 8z" fill="' + sac + '"/>',
    13: '<path d="M21 25q-1-14 11-14t11 14l-5-4-11-1-6 5z" fill="' + sac + '"/>',
    14: '<path d="M20 25q2-17 14-17 10 0 10 16-8-5-13-3-4 1-11 4z" fill="' + sac + '"/>',
    15: '<path d="M20 24q4-15 16-15 7 1 8 12-10-3-20 4z" fill="' + sac + '"/>',
    16: '<path d="M20 25l4-11 5 4 4-8 4 7 5-3 3 11-7-5-6 2-7-2z" fill="' + sac + '"/>',
    17: '<path d="M19 26q-1-10 7-14l4 2 6-3q10 3 9 15-4-3-8-7-7 5-18 7z" fill="' + sac + '"/>',
    18: '<path d="M21 25q0-13 11-13t11 13q-5-4-10-5l-5-5-1 6-6 4z" fill="' + sac + '"/>',
    19: '<path d="M21 25q0-13 11-13t11 13q-8-7-13-5-5 1-9 5z" fill="' + sac + '"/>',
    20: '<path d="M21 24l3-11 5 5 3-10 4 9 5-5 2 12-6-4-5 3-6-3z" fill="' + sac + '"/>',
    21: '<path d="M20 27v-5q3-14 12-12 11 1 12 13v4l-5-7q-5-4-11 0z" fill="' + sac + '"/>'
  }[k.sac] || "";
  const yuz = {
    1: `<path d="M27 35.5c2-1.6 3.6-1.6 5 0 1.4-1.6 3-1.6 5 0-1.6 1.2-3.4 1.6-5 .4-1.6 1.2-3.4.8-5-.4z" fill="${sac}"/>`,
    2: `<path d="M22 31c1 7 5 11 10 11s9-4 10-11c-1 3-3 5-5 5h-10c-2 0-4-2-5-5z" fill="${sac}" opacity=".85"/>`,
    3: `<path d="M21 28c0 11 5 17 11 17s11-6 11-17c-1 4-3 7-6 7H27c-3 0-5-3-6-7z" fill="${sac}"/><path d="M27 35.5c2-1.4 3.6-1.4 5 0 1.4-1.4 3-1.4 5 0" stroke="${sac}" stroke-width="2.2" fill="none"/>`,
    4: `<path d="M29 39h6l-1 5h-4z" fill="${sac}"/><path d="M27.5 35.5c2-1.2 3.4-1.2 4.5 0 1.1-1.2 2.5-1.2 4.5 0" stroke="${sac}" stroke-width="1.8" fill="none"/>`,
    5: '<path d="M26 35q3-2 6 0 3-2 6 0l1 3q-4-1-7 0-3-1-7 0z" fill="' + sac + '"/>',
    6: '<path d="M26 36q6-3 6 0 0-3 6 0 2 1 4-2-1 5-8 4h-4q-7 1-8-4 2 3 4 2z" fill="' + sac + '"/>',
    7: '<path d="M22 33q2 10 10 10t10-10" fill="none" stroke="' + sac + '" stroke-width="2.2" stroke-dasharray="1 1.7"/>',
    8: '<path d="M22 32q1 11 10 11t10-11" fill="none" stroke="' + sac + '" stroke-width="2.7" opacity=".7"/>',
    9: '<path d="M26 35q3-3 6 0 3-3 6 0" fill="none" stroke="' + sac + '" stroke-width="2"/>',
    10: '<path d="M20 30q0 13 12 17 12-4 12-17-3 10-10 10h-4q-7 0-10-10z" fill="' + sac + '"/>',
    11: '<path d="M22 34q2 10 10 10t10-10" fill="none" stroke="' + sac + '" stroke-width="3"/>',
    12: '<path d="M26 35h12m-12 0-2 6m14-6 2 6" fill="none" stroke="' + sac + '" stroke-width="3" stroke-linecap="round"/>'
  }[k.yuz] || "";
  const goz = k.goz === 1 ? `<g fill="none" stroke="${cizgi}" stroke-width="1.6"><circle cx="27.5" cy="28" r="3.6"/><circle cx="36.5" cy="28" r="3.6"/><path d="M31.1 28h1.8"/></g>`
    : k.goz === 2 ? `<g fill="none" stroke="${cizgi}" stroke-width="1.6"><rect x="23.6" y="25.2" width="7.6" height="5.4" rx="1.2"/><rect x="32.8" y="25.2" width="7.6" height="5.4" rx="1.2"/><path d="M31.2 27.6h1.6"/></g>` : "";
  const kravat = k.kiyafet < 6 ? `<path d="M31 48h2l1.6 9.5L32 60l-2.6-2.5z" fill="${k.zemin % 2 ? "#B3263A" : "#C9A23A"}"/>` : "";
  return `<svg class="portre" viewBox="0 0 64 64" role="img" aria-label="${e((yedek && yedek.ad) || "Portre")}">
    <rect width="64" height="64" fill="${zem}"/>${arka}
    <path d="M5 64c2-12 13-18 27-18s25 6 27 18z" fill="${kiy}"/>
    <path d="M26 46l6 11 6-11z" fill="${k.kiyafet === 7 ? "#C9CEDB" : "#F4F6FB"}"/>${kravat}
    <path d="M27 37h10v10c-3 2-7 2-10 0z" fill="${ten}"/><path d="M27 41c3 2 7 2 10 0v-4H27z" fill="${golge}"/>
    <ellipse cx="21.4" cy="29" rx="2.4" ry="3.4" fill="${ten}"/><ellipse cx="42.6" cy="29" rx="2.4" ry="3.4" fill="${ten}"/>
    <ellipse cx="32" cy="27.5" rx="10.6" ry="12.6" fill="${ten}"/>
    ${sacOn}
    <path d="M25.5 24.2c1.4-.8 3-.9 4.4-.3M33.9 23.9c1.4-.6 3-.5 4.4.3" stroke="${cizgi}" stroke-width="1.3" fill="none" opacity=".7"/>
    <circle cx="27.6" cy="28.2" r="1.25" fill="${cizgi}"/><circle cx="36.4" cy="28.2" r="1.25" fill="${cizgi}"/>
    <path d="M32 29.5l-1.2 4h2" stroke="${golge}" stroke-width="1.2" fill="none"/>
    <path d="M29 37.4c2 1.2 4 1.2 6 0" stroke="#7a3b32" stroke-width="1.3" fill="none" stroke-linecap="round"/>
    ${yuz}${goz}</svg>`;
}

/* Oyuncu kimlikleri (portre, biyografi, son görülme) — kısa ömürlü önbellek */
const KIMLIK = new Map();
async function kimlikYukle(kadlar) {
  const iste = [...new Set((kadlar || []).filter(k => k && !KIMLIK.has(k.toLocaleLowerCase("tr"))))].slice(0, 100);
  if (!iste.length) return;
  try {
    const r = await API.rpc("kimlikler", { p_kadlar: iste });
    iste.forEach(k => KIMLIK.set(k.toLocaleLowerCase("tr"), null));
    Object.entries(r || {}).forEach(([k, v]) => KIMLIK.set(k.toLocaleLowerCase("tr"), v));
  } catch (_) { iste.forEach(k => KIMLIK.set(k.toLocaleLowerCase("tr"), null)); }
}
const kimlik = (kad) => KIMLIK.get(String(kad || "").toLocaleLowerCase("tr")) || null;
function portre(kad, renk, boy) {
  const k = kimlik(kad);
  return portreSvg(k && k.avatar, { ad: kad, renk }).replace('class="portre"', `class="portre" data-portre="${e(kad)}"${boy ? ` style="width:${boy}px;height:${boy}px"` : ""}`);
}
// Portreleri yüklendikten sonra yerinde güncelle (ekranı yeniden çizmeden)
async function portreleriTazele(kok) {
  const els = [...(kok || document).querySelectorAll("[data-portre]")];
  await kimlikYukle(els.map(x => x.dataset.portre));
  els.forEach(el => {
    const k = kimlik(el.dataset.portre); if (!k || !k.avatar) return;
    const yeni = document.createElement("div"); yeni.innerHTML = portreSvg(k.avatar, { ad: el.dataset.portre });
    const s = yeni.firstElementChild; s.setAttribute("data-portre", el.dataset.portre); if (el.getAttribute("style")) s.setAttribute("style", el.getAttribute("style"));
    el.replaceWith(s);
  });
}
const AKTIF_YAZI = { cevrimici: "Şu an oyunda", bugun: "Bugün oyundaydı", hafta: "Bu hafta oyundaydı", uzun: "Bir haftadır görünmüyor" };

/* Portre ve biyografi düzenleyici */
async function portreModal() {
  const ben = D.durum && D.durum.profil; if (!ben) return;
  await kimlikYukle([ben.kad]);
  const k0 = kimlik(ben.kad) || {};
  let k = portreKodCoz(k0.avatar) || { ten: 1, sac: 1, yuz: 0, goz: 0, kiyafet: 0, zemin: 0, sacRenk: 1 };
  const kodYaz = () => [k.ten, k.sac, k.yuz, k.goz, k.kiyafet, k.zemin, k.sacRenk].join("-");
  const secici = (alan, sayi, ciz) => `<div class="alan"><label>${{ ten: "Ten", sac: "Saç", yuz: "Bıyık ve sakal", sacRenk: "Saç rengi", goz: "Gözlük", kiyafet: "Kıyafet", zemin: "Arka plan" }[alan]}</label>
    <div class="portre-secici" data-alan="${alan}">${Array.from({ length: sayi }, (_, i) => `<button type="button" data-i="${i}" aria-label="${e(ciz(i, true))}" class="${k[alan] === i ? "secili" : ""}">${ciz(i)}</button>`).join("")}</div></div>`;
  const renkKutu = (r) => `<span style="background:${r}"></span>`;
  const m = modal(`<h3>Portren</h3><p class="alt">Oyuncu kartında, sohbette ve aday listelerinde görünür.</p>
    <div style="display:flex;justify-content:center;margin:12px 0" id="ptOnizle"></div>
    ${secici("ten", 6, (i, a) => a ? "Ten " + (i + 1) : renkKutu(PORTRE.ten[i]))}
    ${secici("sac", PORTRE.sacAd.length, (i, a) => a ? PORTRE.sacAd[i] : "")}
    ${secici("yuz", PORTRE.yuzAd.length, (i, a) => a ? PORTRE.yuzAd[i] : "")}
    ${secici("sacRenk", PORTRE.sac.length, (i, a) => a ? PORTRE.sacRenkAd[i] : renkKutu(PORTRE.sac[i]))}
    ${secici("goz", 3, (i, a) => a ? PORTRE.gozAd[i] : "")}
    ${secici("kiyafet", 8, (i, a) => a ? "Kıyafet " + (i + 1) : renkKutu(PORTRE.kiyafet[i]))}
    ${secici("zemin", 8, (i, a) => a ? "Zemin " + (i + 1) : renkKutu(PORTRE.zemin[i]))}
    <div class="alan"><label for="ptBio">Kısa biyografi (en fazla 160 karakter)</label><textarea id="ptBio" class="alanmetin" style="min-height:76px" maxlength="160" placeholder="Örnek: İzmir. Kooperatifçi, kıyı ve emek.">${e(k0.biyografi || "")}</textarea></div>
    <div class="hata-metin" id="ptHata"></div>
    <button class="btn" id="ptKaydet">Portreyi kaydet</button>`);
  // Saç, sakal ve gözlük seçenekleri o anki portre üzerinde küçük önizleme olarak çizilir
  const ciz = () => {
    $("#ptOnizle", m).innerHTML = portreSvg(kodYaz(), { ad: ben.kad }).replace('class="portre"', 'class="portre portre-buyuk"');
    ["sac", "yuz", "goz"].forEach(alan => m.querySelectorAll(`.portre-secici[data-alan="${alan}"] button`).forEach(b => {
      const k2 = Object.assign({}, k, { [alan]: +b.dataset.i });
      b.innerHTML = portreSvg([k2.ten, k2.sac, k2.yuz, k2.goz, k2.kiyafet, k2.zemin, k2.sacRenk].join("-"), { ad: "" }).replace('class="portre"', 'class="portre" style="width:88%;height:88%"');
    }));
  };
  ciz();
  m.querySelectorAll(".portre-secici").forEach(g => g.onclick = (ev) => {
    const b = ev.target.closest("button"); if (!b) return;
    k[g.dataset.alan] = +b.dataset.i; g.querySelectorAll("button").forEach(x => x.classList.toggle("secili", x === b)); ciz();
  });
  $("#ptKaydet", m).onclick = async () => {
    const b = $("#ptKaydet", m); b.disabled = true;
    try {
      const r = await API.rpc("kimlik_guncelle", { p_avatar: kodYaz(), p_biyografi: $("#ptBio", m).value });
      KIMLIK.set(ben.kad.toLocaleLowerCase("tr"), Object.assign({}, k0, r));
      modalKapat(); toast("Portren kaydedildi."); yenidenCiz();
    } catch (err) { b.disabled = false; $("#ptHata", m).textContent = hataCevir(err.message); }
  };
}

/* =====================================================================
   GÜNDEM PANOSU — kayan şerit, sıradaki an, ay şeridi, bugün yapılacaklar
   ===================================================================== */
function seritHtml(haberler) {
  if (!haberler || !haberler.length) return "";
  const metin = haberler.slice(0, 8).map(h => e(h.metin)).join('<i>·</i>');
  const sure = Math.max(35, Math.min(120, metin.length / 6));
  return `<div class="serit" aria-label="Son gelişmeler"><span class="etiket">Gündem</span><div class="kaydir"><span style="--sure:${sure}s">${metin}</span></div></div>`;
}
const SEC_GRUP = { bel_on: "bel", bel: "bel", kurultay: "kur", mv_on: "gen", cb_on: "gen", mv: "gen", cb: "gen", cb2: "gen" };
function sahneHtml(takvim) {
  const t = simdi();
  let en = null;
  (takvim || []).forEach(s => { const a = siradakiAn(s); if (a && (!en || a.an < en.an.an)) en = { s, an: a }; });
  const p = trParca(t), ayGun = new Date(p.y, p.a, 0).getDate();
  const gunler = Array.from({ length: ayGun }, (_, i) => i + 1).map(g => {
    let cls = "";
    (takvim || []).forEach(s => {
      if (s.ara) return;
      const bas = trParca(s.basvuru_bas || s.oy_bas), bit = trParca(s.goreve_bas || s.sonuc_at), oy = trParca(s.oy_bas);
      const kapsar = (x) => (x.y * 400 + x.a * 32 + x.g);
      const bu = p.y * 400 + p.a * 32 + g;
      if (bu >= kapsar(bas) && bu <= kapsar(bit)) cls = cls || SEC_GRUP[s.tur];
      if (bu === kapsar(oy)) cls = (cls || SEC_GRUP[s.tur]) + " sec";
    });
    if (g < p.g) cls += " gecti";
    return `<i class="${cls.trim()}" title="${g} ${AYLAR[p.a - 1]}"></i>`;
  }).join("");
  const imlec = ((p.g - 1) + (+p.s + +p.d / 60) / 24) / ayGun * 100;
  return `<section class="sahne">
    ${en ? `<div class="ne">${e(en.an.ad)} · ${tarihSaat(en.an.an)}</div><div class="olay-adi">${secimTakvimAdi(en.s)}</div>
      <div class="geri-sayim" data-an="${en.an.an}">${kalan(en.an.an - t)}</div>` : `<div class="olay-adi">Takvim hazırlanıyor</div>`}
    <div class="ay-serit" style="--gun:${ayGun}" aria-label="${AYLAR[p.a - 1]} seçim takvimi"><div class="gunler">${gunler}</div><div class="imlec" style="left:calc(${imlec.toFixed(2)}% - 1px)"></div></div>
    <div class="ay-lejant"><span><i style="background:#2E7D64"></i>Belediye</span><span><i style="background:#8A6A1F"></i>Kurultay</span><span><i style="background:#5D47D6"></i>Genel seçim</span><span>${AYLAR[p.a - 1]}</span></div>
  </section>`;
}
function yapilacakSatir(o) {
  return `<button class="yapilacak ${o.cls || ""}" onclick="${o.git}"><span class="yik">${o.ikon}</span><span class="orta"><b>${o.bas}</b><span class="kucuk">${o.alt || ""}</span></span><span class="ok">›</span></button>`;
}
function ilkAdimlarHtml(ia) {
  if (!ia || !ia.yeni || ia.bitti) return "";
  const git = { maas: "sekmeAc('hayat')", kimlik: "portreModal()", parti: "partiTestiModal()", sohbet: "sekmeAc('sohbet')", anket: "ekranAc(anketEkrani)", oy: "" };
  const n = ia.adimlar.filter(a => a.tamam).length;
  return `<div class="kart"><h2>İlk adımların</h2><div class="alt">${n} / ${ia.adimlar.length} tamam. Her adım seni siyasete bir adım yaklaştırır.</div>
    <div class="adimlar">${ia.adimlar.map(a => `<i class="${a.tamam ? "tamam" : ""}"></i>`).join("")}</div>
    ${ia.adimlar.map(a => `<div class="adim ${a.tamam ? "tamam" : ""}"><span class="kutu"></span><span>${e(a.ad)}${a.kod === "oy" && !a.tamam && a.not ? `<div class="kucuk">${e(a.not)}</div>` : ""}</span>${!a.tamam && git[a.kod] ? `<button onclick="${git[a.kod]}">Başla</button>` : ""}</div>`).join("")}</div>`;
}

/* ---------- Mitingler ---------- */
function mitingHtml(liste) {
  if (!liste || !liste.length) return "";
  const t = simdi();
  return `<div class="bolum-bas"><h2>Meydanlar</h2><span class="kucuk">Mitingler</span></div><div class="kart">${liste.map(m => {
    const canli = new Date(m.bas).getTime() <= t && new Date(m.bit).getTime() > t, bitti = new Date(m.bit).getTime() <= t;
    const pr = trParca(m.bas);
    return `<div class="miting ${canli ? "canli" : ""}"><div class="zaman"><b>${canli ? "Canlı" : `${pr.s}:${pr.d}`}</b><span>${pr.g} ${AYLAR[pr.a - 1].slice(0, 3)}</span></div>
      <div class="orta" style="flex:1;min-width:0"><b>${e(m.baslik)}</b><div class="kucuk">${e(m.kad)} · ${e(m.il)}${m.parti ? ` · <span style="color:${e(m.parti.renk)}">${e(m.parti.kisa)}</span>` : ""} · ${m.katilim} kişi</div></div>
      ${canli && m.benim_ilim && !m.katildim && !m.benim ? `<button class="btn canli" style="width:auto;margin:0;padding:9px 14px" onclick="mitingKatil(${m.id})">Katıl</button>`
        : m.katildim ? `<span class="rozet yesil">Oradasın</span>` : bitti ? `<span class="rozet">Bitti</span>` : ""}</div>`;
  }).join("")}</div>`;
}
async function mitingKatil(id) {
  try { const r = await API.rpc("miting_katil", { p_id: id }); toast(`Meydandasın: ${r.katilim} kişi${r.kidem ? " · +1 kıdem" : ""}.`); yenidenCiz(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
function mitingDuzenleModal(h) {
  const t = new Date(simdi() + 2 * 3600e3); t.setMinutes(0, 0, 0);
  const p = trParca(t), iki = (n) => String(n).padStart(2, "0");
  const deger = `${p.y}-${iki(p.a)}-${iki(p.g)}T${p.s}:00`;
  const son = trParca(h.son);
  const m = modal(`<h3>Miting düzenle</h3><p class="alt">${e(h.il)} meydanında bir saatlik miting. Başladığında ildeki herkese haber gider; katılanlar günde bir kez +1 kıdem kazanır. Bedel: <b>${tlYaz(h.bedel)}</b>. Oylama ${son.g} ${AYLAR[son.a - 1]} ${son.s}:${son.d}'de bitiyor.</p>
    <div class="alan"><label for="mtBaslik">Mitingin adı</label><input id="mtBaslik" maxlength="80" placeholder="Örnek: Gündoğdu'da emek buluşması"></div>
    <div class="alan"><label for="mtZaman">Başlangıç (Türkiye saati)</label><input id="mtZaman" type="datetime-local" value="${deger}"></div>
    <div class="hata-metin" id="mtHata"></div><button class="btn" id="mtTamam">Mitingi duyur · ${tlYaz(h.bedel)}</button>`);
  $("#mtTamam", m).onclick = async () => {
    const b = $("#mtTamam", m); b.disabled = true;
    try {
      await API.rpc("miting_duzenle", { p_secim: h.secim_id, p_bas: $("#mtZaman", m).value + ":00+03:00", p_baslik: $("#mtBaslik", m).value });
      modalKapat(); toast("Miting duyuruldu."); yenidenCiz();
    } catch (err) { b.disabled = false; $("#mtHata", m).textContent = hataCevir(err.message); }
  };
}

/* =====================================================================
   SEÇİM GECESİ — sonuçların sahnelenmesi
   ===================================================================== */
function sonucSatirlari(liste, toplam, opt) {
  opt = opt || {};
  return liste.map((x, i) => {
    const y = toplam ? x.oy * 100 / toplam : (x.yuzde || 0);
    return `<div class="sonuc-satir ${i === 0 && opt.kazanan ? "kazanan" : ""}">
      <div style="display:flex;align-items:center;gap:10px;min-width:0">${opt.portre ? portre(x.kad, x.renk, 34) : ""}<div style="min-width:0"><b style="display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${e(x.ad || x.kad)}</b>
        <span class="kucuk">${x.kisa ? `<span style="color:${e(x.renk)}">${e(x.kisa)}</span> · ` : ""}${fmt(x.oy)} oy${x.sandalye != null ? ` · ${x.sandalye} sandalye` : ""}${x.not ? " · " + x.not : ""}</span></div></div>
      <span class="yuzde">%${y.toFixed(1).replace(".", ",")}</span>
      <span class="cubuk"><i style="width:${y}%;background:${e(x.renk || "#8E97B5")};animation-delay:${(.15 + i * .18).toFixed(2)}s"></i></span></div>`;
  }).join("");
}
function sonucHaritasi(r, pmap) {
  if (!r || !r.iller || !VERI.harita) return "";
  const H = VERI.harita;
  const renk = (id) => {
    const v = r.iller[String(id)]; if (!v || !v.partiler) return "#2A3460";
    const en = Object.entries(v.partiler).sort((a, b) => b[1].oy - a[1].oy)[0];
    return en && en[1].oy ? ((pmap[en[0]] || {}).renk || "#8E97B5") : "#2A3460";
  };
  return `<div class="harita" style="margin-top:12px"><svg viewBox="0 0 ${H.w} ${H.h}" style="width:100%;height:auto;display:block" aria-label="İllerde birinci parti"><g stroke="#0A1026" stroke-width="1.3">${Object.entries(H.il).map(([id, p]) =>
    `<path d="${p.d}" fill="${e(renk(+id))}"></path>`).join("")}</g></svg><div class="kucuk" style="margin-top:4px">Her il, en çok oyu alan partinin renginde.</div></div>`;
}

/* =====================================================================
   PARTİ PUSULASI ve "Hangi parti bana yakın?" testi
   ===================================================================== */
const EKSEN_YAZI = {
  eko: (v) => v <= -3 ? "devletçi" : v < 0 ? "sosyal devletçi" : v === 0 ? "merkez" : v < 3 ? "piyasa yanlısı" : "serbest piyasacı",
  toplum: (v) => v <= -3 ? "özgürlükçü" : v < 0 ? "ılımlı özgürlükçü" : v === 0 ? "merkez" : v < 3 ? "ılımlı muhafazakâr" : "muhafazakâr"
};
function pusulaSvg(partiler, ben) {
  const W = 300, P = 26, olc = (v) => P + (v + 5) / 10 * (W - 2 * P);
  const maxU = Math.max(1, ...partiler.map(p => p.uye || 0));
  return `<svg viewBox="0 0 ${W} ${W}" role="img" aria-label="Partilerin siyasi konumu">
    <rect x="${P}" y="${P}" width="${W - 2 * P}" height="${W - 2 * P}" fill="none" stroke="rgba(164,184,255,.16)"/>
    <path d="M${W / 2} ${P}V${W - P}M${P} ${W / 2}H${W - P}" stroke="rgba(164,184,255,.22)"/>
    <text x="${W / 2}" y="16" text-anchor="middle" font-size="11.5" fill="#98A4C4">Muhafazakâr</text>
    <text x="${W / 2}" y="${W - 7}" text-anchor="middle" font-size="11.5" fill="#98A4C4">Özgürlükçü</text>
    <text x="8" y="${W / 2 + 4}" font-size="11.5" fill="#98A4C4" transform="rotate(-90 8 ${W / 2})" text-anchor="middle" dx="0" dy="6">Devletçi</text>
    <text x="${W - 8}" y="${W / 2}" font-size="11.5" fill="#98A4C4" transform="rotate(90 ${W - 8} ${W / 2})" text-anchor="middle" dy="4">Serbest piyasa</text>
    ${partiler.map(p => { const r = 7 + 11 * Math.sqrt((p.uye || 0) / maxU), x = olc(p.eko), y = olc(-p.toplum);
      return `<g><circle cx="${x}" cy="${y}" r="${r.toFixed(1)}" fill="${e(p.parti.renk)}" fill-opacity=".88" stroke="#0E1530" stroke-width="2"/><text x="${x}" y="${(y - r - 4).toFixed(1)}" text-anchor="middle" font-size="12" font-weight="700" fill="#EEF1F8" font-family="Kurul Display,Arial Narrow,sans-serif">${e(p.parti.kisa)}</text></g>`; }).join("")}
    ${ben ? `<g><circle cx="${olc(ben.eko)}" cy="${olc(-ben.toplum)}" r="9" fill="none" stroke="#fff" stroke-width="2.5" stroke-dasharray="3 2.5"/><text x="${olc(ben.eko)}" y="${olc(-ben.toplum) + 23}" text-anchor="middle" font-size="12" font-weight="700" fill="#fff">Sen</text></g>` : ""}
  </svg>`;
}
const TEST_SORU = [
  ["eko", -1, "Devlet büyük şirketleri ve enerjiyi kendisi işletmeli."],
  ["eko", 1, "Vergiler düşük olmalı; ekonomiyi piyasa yönetmeli."],
  ["eko", -1, "Asgari ücret her yıl enflasyonun üstünde artırılmalı."],
  ["eko", 1, "Özelleştirme ekonomiyi güçlendirir."],
  ["toplum", 1, "Gelenekler ve aile değerleri yasalarla korunmalı."],
  ["toplum", -1, "Devlet yurttaşların yaşam tarzına karışmamalı."],
  ["toplum", 1, "Ülkenin birliği için güçlü bir merkezî yönetim şart."],
  ["toplum", -1, "İfade özgürlüğü olabildiğince geniş olmalı."]
];
function testSonucuOku() { try { return JSON.parse(localStorage.getItem("parti_testi") || "null"); } catch (_) { return null; } }
async function partiTestiModal() {
  let kim = []; try { kim = await API.rpc("parti_kimlikleri"); } catch (err) { return toast(hataCevir(err.message), true); }
  const cevap = new Array(TEST_SORU.length).fill(null);
  const OLCEK = [["-2", "Hiç"], ["-1", "Pek değil"], ["0", "Kararsız"], ["1", "Katılırım"], ["2", "Tamamen"]];
  const m = modal(`<h3>Hangi parti bana yakın?</h3><p class="alt">Sekiz cümleye ne kadar katıldığını seç. Sonuç yalnızca bu telefonda kalır.</p>
    ${TEST_SORU.map((s, i) => `<div class="test-soru"><p>${e(s[2])}</p><div class="test-olcek" data-i="${i}">${OLCEK.map(([v, a]) => `<button type="button" data-v="${v}">${a}</button>`).join("")}</div></div>`).join("")}
    <div id="testSonuc"></div><button class="btn" id="testBitir" disabled>Sonucu göster</button>`);
  m.querySelectorAll(".test-olcek").forEach(g => g.onclick = (ev) => {
    const b = ev.target.closest("button"); if (!b) return;
    cevap[+g.dataset.i] = +b.dataset.v; g.querySelectorAll("button").forEach(x => x.classList.toggle("secili", x === b));
    $("#testBitir", m).disabled = cevap.some(x => x === null);
  });
  $("#testBitir", m).onclick = () => {
    const puan = { eko: 0, toplum: 0 };
    TEST_SORU.forEach(([ek, yon], i) => { puan[ek] += yon * cevap[i]; });
    const ben = { eko: Math.round(puan.eko / 8 * 5 * 10) / 10, toplum: Math.round(puan.toplum / 8 * 5 * 10) / 10 };
    try { localStorage.setItem("parti_testi", JSON.stringify(ben)); } catch (_) {}
    const sirali = kim.filter(p => p.belirlendi).map(p => ({ p, d: Math.hypot(p.eko - ben.eko, p.toplum - ben.toplum) })).sort((a, b) => a.d - b.d);
    const uye = D.durum.profil.parti;
    $("#testSonuc", m).innerHTML = `<div class="kart" style="background:var(--bg);margin-top:14px"><h2>Sana en yakın partiler</h2>
      <p class="alt">Ekonomide ${EKSEN_YAZI.eko(Math.round(ben.eko))}, toplumsal konularda ${EKSEN_YAZI.toplum(Math.round(ben.toplum))} görünüyorsun.</p>
      <div class="pusula-alan">${pusulaSvg(kim.filter(p => p.belirlendi), ben)}</div>
      ${sirali.slice(0, 3).map(({ p, d }) => `<div class="liste-satir">${amblemKutu(p.parti)}<div class="orta"><b>${e(p.parti.ad)}</b><div class="kucuk">%${Math.max(0, Math.round(100 - d * 100 / 14.2))} uyum${p.slogan ? " · “" + e(p.slogan) + "”" : ""}</div></div>
        ${uye && uye.id === p.parti.id ? `<span class="rozet yesil">Üyesin</span>` : `<button class="btn altin" style="width:auto;margin:0;padding:8px 12px" onclick="modalKapat();ekranAc(()=>partiDetay(${p.parti.id}))">İncele</button>`}</div>`).join("")}</div>`;
    $("#testBitir", m).remove();
    $("#testSonuc", m).scrollIntoView({ behavior: "smooth", block: "start" });
  };
}
async function partiKimlikModal(pid) {
  let kim = []; try { kim = await API.rpc("parti_kimlikleri"); } catch (err) { return toast(hataCevir(err.message), true); }
  const p = kim.find(x => x.parti.id === pid) || { eko: 0, toplum: 0, slogan: "" };
  const m = modal(`<h3>Partinin kimliği</h3><p class="alt">Partinin siyasi konumu parti pusulasında ve "Hangi parti bana yakın?" testinde görünür. Konum günde bir kez değiştirilebilir; değişiklik Gündem'e haber olur.</p>
    <div class="alan"><label for="pkEko">Ekonomi: <b id="pkEkoY"></b></label><input id="pkEko" type="range" min="-5" max="5" step="1" value="${p.eko}" style="width:100%"></div>
    <div class="alan"><label for="pkTop">Toplum: <b id="pkTopY"></b></label><input id="pkTop" type="range" min="-5" max="5" step="1" value="${p.toplum}" style="width:100%"></div>
    <div class="alan"><label for="pkSlogan">Slogan (en fazla 80 karakter)</label><input id="pkSlogan" maxlength="80" value="${e(p.slogan || "")}"></div>
    <div class="hata-metin" id="pkHata"></div><button class="btn" id="pkKaydet">Kimliği kaydet</button>`);
  const yaz = () => { $("#pkEkoY", m).textContent = EKSEN_YAZI.eko(+$("#pkEko", m).value); $("#pkTopY", m).textContent = EKSEN_YAZI.toplum(+$("#pkTop", m).value); };
  $("#pkEko", m).oninput = yaz; $("#pkTop", m).oninput = yaz; yaz();
  $("#pkKaydet", m).onclick = async () => {
    const b = $("#pkKaydet", m); b.disabled = true;
    try { await API.rpc("parti_kimlik_ayarla", { p_eko: +$("#pkEko", m).value, p_toplum: +$("#pkTop", m).value, p_slogan: $("#pkSlogan", m).value }); modalKapat(); toast("Parti kimliği kaydedildi."); yenidenCiz(); }
    catch (err) { b.disabled = false; $("#pkHata", m).textContent = hataCevir(err.message); }
  };
}
async function partiKimlikKartCiz(pid) {
  const yer = $("#partiKimlikKart"); if (!yer) return;
  let kim; try { kim = await API.rpc("parti_kimlikleri"); } catch (_) { return; }
  const p = kim.find(x => x.parti.id === pid); if (!p) return;
  const gb = D.durum.profil.gb && D.durum.profil.parti && D.durum.profil.parti.id === pid;
  if (!$("#partiKimlikKart")) return;
  $("#partiKimlikKart").innerHTML = `<div class="kart cizgili" style="--parti:${e(p.parti.renk)}">
    ${p.slogan ? `<div style="font-family:var(--disp);font-size:22px;line-height:1.15">“${e(p.slogan)}”</div>` : ""}
    <div class="alt" style="margin-top:6px">${p.belirlendi ? `Ekonomide ${EKSEN_YAZI.eko(p.eko)}, toplumsal konularda ${EKSEN_YAZI.toplum(p.toplum)}.` : "Genel başkan partinin siyasi konumunu henüz açıklamadı."}</div>
    ${gb ? `<button class="btn altin" onclick="partiKimlikModal(${pid})">Konumu ve sloganı belirle</button>` : ""}</div>`;
}

/* =====================================================================
   CUMHURİYET TARİHİ — oyunun hiç silinmeyen geçmişi
   ===================================================================== */
async function tarihHtml() {
  let t; try { t = await API.rpc("tarih_arsivi"); } catch (err) { return `<div class="bos">${e(hataCevir(err.message))}</div>`; }
  await kimlikYukle(t.cumhurbaskanlari.map(c => c.kad));
  const rk = t.rekorlar || {};
  const rekor = [
    rk.en_cok_oy && ["En çok oy alan aday", `${e(rk.en_cok_oy.kad)} · ${fmt(rk.en_cok_oy.oy)} oy`],
    rk.en_uzun_cb && ["En uzun görev yapan cumhurbaşkanı", `${e(rk.en_uzun_cb.kad)} · ${fmt(rk.en_uzun_cb.gun, 0)} gün`],
    rk.en_cok_kanun && ["En çok kanun çıkaran vekil", `${e(rk.en_cok_kanun.kad)} · ${rk.en_cok_kanun.sayi} kanun`],
    rk.en_kalabalik_miting && ["En kalabalık miting", `${e(rk.en_kalabalik_miting.kad)} · ${e(rk.en_kalabalik_miting.il)} · ${rk.en_kalabalik_miting.kisi} kişi`],
    rk.en_yuksek_katilim && ["En yüksek katılımlı genel seçim", `${e(rk.en_yuksek_katilim.donem)} · ${fmt(rk.en_yuksek_katilim.oy)} oy`]
  ].filter(Boolean);
  return `<div class="kart duz"><p class="alt">Bu ülke ${t.baslangic ? tarih(t.baslangic) + "'den beri" : "kuruluşundan beri"} oyuncularla yönetiliyor. Oyun hiç sıfırlanmaz; burada yazan her şey gerçek oyuncuların kararlarıdır.</p></div>
    <div class="bolum-bas"><h2>Cumhurbaşkanları</h2><span class="kucuk">${t.cumhurbaskanlari.length} dönem</span></div>
    <div class="kart">${t.cumhurbaskanlari.length ? t.cumhurbaskanlari.slice().reverse().map(c => `<div class="liste-satir" onclick="oyuncuKart('${e(c.kad)}')" style="cursor:pointer">${portre(c.kad, c.parti && c.parti.renk, 40)}
      <div class="orta"><b>${e(c.kad)}</b><div class="kucuk">${tarih(c.bas)} – ${c.bit ? tarih(c.bit) : "görevde"} · ${fmt(c.gun, 0)} gün${c.parti ? ` · <span style="color:${e(c.parti.renk)}">${e(c.parti.kisa)}</span>` : ""}${c.neden === "ihmal" ? " · görevi ihmal etti" : c.neden === "istifa" ? " · istifa etti" : ""}</div></div></div>`).join("") : `<div class="bos">Henüz seçilmiş bir cumhurbaşkanı yok. İlk cumhurbaşkanı sen olabilirsin.</div>`}</div>
    <div class="bolum-bas"><h2>Meclis dönemleri</h2></div>
    <div class="kart">${t.meclisler.length ? t.meclisler.map(m => {
      const top = m.partiler.reduce((a, p) => a + p.sandalye, 0) || 1;
      return `<div style="padding:10px 0;border-bottom:1px solid var(--line)"><div style="display:flex;justify-content:space-between;gap:8px"><b>${e(m.donem)} dönemi</b><span class="kucuk">${fmt(m.oy)} oy · ${m.dolu} vekil</span></div>
        <div class="meclis-serit">${m.partiler.map(p => `<i style="flex:${p.sandalye};background:${e(p.parti.renk)}"></i>`).join("")}</div>
        <div class="kucuk">${m.partiler.map(p => `<span style="color:${e(p.parti.renk)}">${e(p.parti.kisa)}</span> ${p.sandalye}`).join(" · ")}</div></div>`; }).join("") : `<div class="bos">İlk genel seçim henüz yapılmadı.</div>`}</div>
    <div class="bolum-bas"><h2>Kanunlar</h2><span class="kucuk">${t.kanunlar.toplam} kanun yürürlüğe girdi</span></div>
    <div class="kart">${t.kanunlar.son.length ? t.kanunlar.son.map(k => `<div class="liste-satir"><div style="width:46px;flex:none;font-family:var(--disp);font-size:19px;color:var(--mut)">${k.no}</div><div class="orta"><b>${e(k.baslik)}</b><div class="kucuk">${k.tarih ? tarih(k.tarih) + " · " : ""}${e(k.teklif_eden || "")}${k.parti ? ` · <span style="color:${e(k.parti.renk)}">${e(k.parti.kisa)}</span>` : ""}</div></div></div>`).join("") : `<div class="bos">Meclis henüz kanun çıkarmadı.</div>`}</div>
    ${rekor.length ? `<div class="bolum-bas"><h2>Rekorlar</h2></div><div class="kart">${rekor.map(([a, b]) => `<div class="kv"><span class="k">${a}</span><span class="v">${b}</span></div>`).join("")}</div>` : ""}
    <div class="bolum-bas"><h2>Partiler</h2></div>
    <div class="kart">${t.partiler.map(p => `<div class="liste-satir" onclick="ekranAc(()=>partiDetay(${p.parti.id}))" style="cursor:pointer">${amblemKutu(p.parti)}<div class="orta"><b>${e(p.parti.ad)}</b><div class="kucuk">${p.sistem ? "Kurucu parti" : "Kuruluş " + tarih(p.kurulus)} · ${p.uye} üye${p.kapali ? " · kapandı" : ""}</div></div></div>`).join("")}</div>`;
}

/* =====================================================================
   KARŞILAMA — yarım daire Meclis
   ===================================================================== */
function hemisiklSvg() {
  const renkler = ["#c62828", "#ef8f00", "#1565c0", "#2e7d32", "#6a1b9a", "#00897b"];
  const sira = [[0, 34], [1, 27], [2, 21], [3, 11], [4, 5], [5, 2]];
  const dizi = []; sira.forEach(([r, n]) => { for (let i = 0; i < n; i++) dizi.push(renkler[r]); });
  const toplam = dizi.length, satir = 6, cx = 180, cy = 170, noktalar = [];
  let k = 0;
  for (let s = 0; s < satir; s++) {
    const R = 70 + s * 17, adet = Math.round(toplam * R / (satir * (70 + 17 * (satir - 1) / 2)));
    for (let i = 0; i < adet && k < toplam; i++, k++) {
      const a = Math.PI - (i + .5) / adet * Math.PI;
      noktalar.push([cx + R * Math.cos(a), cy - R * Math.sin(a), a]);
    }
  }
  noktalar.sort((a, b) => b[2] - a[2]);
  return `<svg class="hemisikl" viewBox="0 0 360 180" aria-hidden="true">${noktalar.map(([x, y], i) => `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="5.6" fill="${dizi[i] || "#3A4675"}" style="animation-delay:${(i * 0.005).toFixed(3)}s"/>`).join("")}</svg>`;
}
