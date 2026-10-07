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
async function basinEkrani() {
  yukleniyor('Basın / Gazeteler');
  let d;
  try { d = await API.rpc('basin'); }
  catch (err) { iskelet('Basın / Gazeteler', `<div class="kart"><p>${e(hataCevir(err.message))}</p><button class="btn ikinci" onclick="basinEkrani()">Tekrar dene</button></div>`); return; }
  iskelet('Basın / Gazeteler', `<div class="kart basin-manset"><div class="kucuk">OYUNCULARIN SESİ</div><h1>Basın meydanı</h1><p class="alt">Haberler, köşe yazıları ve açıkça etiketlenmiş siyasi yayınlar.</p></div>
    <div class="kart" id="basinBenim"><h2>${d.benim ? 'Gazetem' : 'Kendi gazeteni kur'}</h2><p class="alt">${d.benim ? e(d.benim.ad) + ' · Kasa: ' + tlYaz(d.benim.kasa) : 'Kuruluş bedeli: ' + tlYaz(d.kurulus_ucreti) + '. Ücretsiz veya ücretli yayın yapabilirsin.'}</p></div>
    <div id="basinTeklifler"></div><h2>Gazete büfesi</h2><div id="basinListe" class="basin-grid"></div>`, { geri: true });
  $('#basinBenim').appendChild(basinDugme(d.benim ? 'Gazetemi yönet' : 'Gazete kur', () => d.benim ? ekranAc(() => gazeteEkrani(d.benim.id)) : gazeteKurModal(d.kurulus_ucreti), 'altin'));
  for (const t of d.teklifler || []) {
    const el = document.createElement('section'); el.className = 'kart';
    el.innerHTML = `<h2>Köşe yazarlığı teklifi</h2><b>${e(t.ad)}</b><p class="alt">${e(t.sahip)} · Yazı başına ${tlYaz(t.ucret)}</p>`;
    for (const kabul of [true, false]) {
      const b = basinDugme(kabul ? 'Teklifi kabul et' : 'Reddet', () => {
        el.querySelectorAll('button').forEach(x => { if (x !== b) x.disabled = true; });
        basinIslem(b, { ad: 'gazete_yazar_yanit', args: { p_gazete: t.gazete_id, p_kabul: kabul } }, basinEkrani).finally(() => el.querySelectorAll('button').forEach(x => x.disabled = false));
      }, kabul ? 'altin' : 'ikinci'); el.appendChild(b);
    }
    $('#basinTeklifler').appendChild(el);
  }
  const liste = $('#basinListe');
  for (const g of d.gazeteler || []) {
    const el = document.createElement('article'); el.className = 'kart basin-gazete';
    el.innerHTML = `<span class="rozet ${g.abonelik_ucret > 0 ? 'altin' : 'yesil'}">${g.abonelik_ucret > 0 ? tlYaz(g.abonelik_ucret) + ' / ay' : 'Ücretsiz'}</span><h2>${e(g.ad)}</h2><p class="alt">${e(g.slogan)}</p><p class="kucuk">Sahibi: ${e(g.sahip)} · ${fmt(g.abone, 0)} abone${g.abonem ? ' · Abonesin' : ''}${g.yaziyim ? ' · Yazarsın' : ''}</p>${g.son ? `<div class="basin-son"><span class="rozet ${g.son.tur === 'propaganda' ? 'kirmizi' : ''}">${e(BASIN_TUR[g.son.tur] || g.son.tur)}</span><h3>${e(g.son.baslik)}</h3><div class="kucuk">${e(tarihSaat(g.son.zaman))}</div></div>` : '<p class="kucuk">İlk sayısını bekliyor.</p>'}`;
    el.appendChild(basinDugme('Gazeteyi oku', () => ekranAc(() => gazeteEkrani(g.id)))); liste.appendChild(el);
  }
  if (!liste.children.length) liste.innerHTML = '<div class="bos">Henüz gazete yok. İlk gazeteyi sen kurabilirsin.</div>';
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
  iskelet('Basın / Gazeteler', `<header class="kart basin-manset"><div class="kucuk">OYUNCU GAZETESİ</div><h1>${e(g.ad)}</h1><p>${e(g.slogan)}</p><p class="kucuk">Sahibi: ${e(g.sahip)} · ${fmt(g.abone, 0)} abone</p><span class="rozet ${g.abonelik_ucret > 0 ? 'altin' : 'yesil'}">${g.abonelik_ucret > 0 ? tlYaz(g.abonelik_ucret) + ' / ay' : 'Ücretsiz gazete'}</span>${g.abonelik_bitis ? `<p class="kucuk">Abonelik bitişi: ${e(tarihSaat(g.abonelik_bitis))}</p>` : ''}<div id="gazEylem"></div></header>
    <div id="gazYonetim"></div><div id="gazYayinlar">${(g.yayinlar || []).map(y => `<article class="kart basin-yazi"><span class="rozet ${y.tur === 'propaganda' ? 'kirmizi' : ''}">${e(BASIN_TUR[y.tur] || y.tur)}</span>${y.tur === 'propaganda' ? `<p class="basin-propaganda">Bu yayın siyasi propagandadır. Hedef parti: ${e(y.hedef_parti && (y.hedef_parti.ad || y.hedef_parti.kisa) || 'Belirtilmemiş')}</p>` : ''}<h2>${e(y.baslik)}</h2><div class="kucuk">${e(y.yazar)} · ${e(tarihSaat(y.zaman))}</div><div class="basin-metin">${e(y.metin)}</div>${y.kilitli ? '<div class="basin-kilit">🔒 Önizleme · Tam yazıyı okumak için gazeteye abone ol.</div>' : ''}</article>`).join('') || '<div class="bos">Henüz yazı yayımlanmamış.</div>'}</div>`, { geri: true });
  const eylem = $('#gazEylem');
  if (!g.erisim && g.abonelik_ucret > 0) eylem.appendChild(basinDugme('Abone ol · ' + tlYaz(g.abonelik_ucret), () => {
    basinForm('Gazeteye abone ol', `<p>${e(g.ad)} için cüzdanından ${tlYaz(g.abonelik_ucret)} ödenir. Abonelik bitişi işlemden sonra gösterilir.</p>`, 'Öde ve abone ol', 'gazete_abone_ol', () => ({ p_gazete: g.id }), r => gazeteEkrani(g.id, r));
  }, 'altin'));
  if (g.sahibim || (g.yazarlar || []).some(y => y.benim)) eylem.appendChild(basinDugme('Yazı yayımla', () => gazeteYayinModal(g), 'altin'));
  if (g.sahibim) {
    const yon = $('#gazYonetim');
    yon.innerHTML = `<section class="kart"><h2>Gazete kasası</h2><b>${tlYaz(g.kasa)}</b><p class="kucuk">Abonelik gelirleri kasaya eklenir; yazar ücretleri buradan ödenir.</p><div id="gazSahipEylem"></div><details><summary>Son kasa hareketleri</summary>${(g.hareketler || []).map(h => `<div class="liste-satir"><div class="orta">${e(h.aciklama)}<div class="kucuk">${e(tarihSaat(h.zaman))}</div></div><b>${tlYaz(h.tutar)}</b></div>`).join('') || '<p class="kucuk">Henüz hareket yok.</p>'}</details></section><section class="kart"><h2>Yazar kadrosu</h2><div id="gazYazarlar"></div></section>`;
    const yer = $('#gazSahipEylem');
    yer.appendChild(basinDugme('Kasadan para çek', () => basinForm('Gazete geliri çek', `<p class="alt">Kasa: ${tlYaz(g.kasa)}</p>` + basinAlan('gazMiktar', 'Çekilecek tutar (₺)', 'type="number" min="100" step="1" required'), 'Cüzdanıma aktar', 'gazete_para_cek', m => ({ p_gazete: g.id, p_miktar: +$('#gazMiktar', m).value }), r => gazeteEkrani(g.id, r))));
    yer.appendChild(basinDugme('Slogan ve abonelik ayarları', () => basinForm('Gazete ayarları', basinAlan('gazSlogan', 'Slogan', 'maxlength="100"', g.slogan) + basinAlan('gazAbone', 'Aylık abonelik (₺) — ücretsiz için 0', 'type="number" min="0" step="1" required', g.abonelik_ucret), 'Kaydet', 'gazete_ayar', m => ({ p_gazete: g.id, p_slogan: $('#gazSlogan', m).value, p_abonelik: +$('#gazAbone', m).value }), r => gazeteEkrani(g.id, r))));
    yer.appendChild(basinDugme('Köşe yazarlığı teklif et', () => basinForm('Yazarlık teklifi', basinAlan('gazKad', 'Oyuncunun kullanıcı adı', 'required maxlength="20"') + basinAlan('gazUcret', 'Yazı başına ücret (₺)', 'type="number" min="0" max="10000" step="1" required', 0), 'Teklif gönder', 'gazete_yazar_teklif', m => ({ p_gazete: g.id, p_kad: $('#gazKad', m).value.trim(), p_ucret: +$('#gazUcret', m).value }), r => gazeteEkrani(g.id, r))));
    for (const y of g.yazarlar || []) {
      const el = document.createElement('div'); el.className = 'basin-yazar';
      el.innerHTML = `<b>${e(y.kad)}</b><div class="kucuk">Yazı başına ${tlYaz(y.ucret)}</div>`;
      el.appendChild(basinDugme('Yazarlığı sonlandır', () => basinForm('Yazarlığı sonlandır', `<p>${e(y.kad)} artık bu gazetede yazı yayımlayamayacak.</p>`, 'Sonlandır', 'gazete_yazar_cikar', () => ({ p_gazete: g.id, p_kad: y.kad }), r => gazeteEkrani(g.id, r))));
      $('#gazYazarlar').appendChild(el);
    }
    if (!(g.yazarlar || []).length) $('#gazYazarlar').innerHTML = '<p class="kucuk">Henüz kabul edilmiş yazar yok. Yukarıdan teklif gönderebilirsin.</p>';
  }
}
async function gazeteYayinModal(g) {
  let partiler;
  try { partiler = await API.rpc('partiler'); }
  catch (err) { toast(hataCevir(err.message), true); return; }
  const m = basinForm('Yazı yayımla', `<div class="alan"><label for="gazTur">Yayın türü</label><select id="gazTur"><option value="haber">Haber</option><option value="kose">Köşe yazısı</option><option value="propaganda">Propaganda</option></select></div><div id="gazHedefAlan" hidden><p class="basin-propaganda">Yazı açıkça PROPAGANDA olarak etiketlenir ve oyun yayın akışında da duyurulur.</p><div class="alan"><label for="gazHedef">Hedef parti</label><select id="gazHedef"><option value="">Parti seç…</option>${partiler.filter(p => !p.kapali).map(p => `<option value="${e(p.id)}">${e(p.ad)} (${e(p.kisa)})</option>`).join('')}</select></div></div>` + basinAlan('gazBaslik', 'Başlık', 'required minlength="4" maxlength="100"') + '<div class="alan"><label for="gazMetin">Yazı (20–5000 karakter)</label><textarea id="gazMetin" rows="9" required minlength="20" maxlength="5000"></textarea></div>', 'Yayımla', 'gazete_yayinla', el => ({ p_gazete: g.id, p_tur: $('#gazTur', el).value, p_baslik: $('#gazBaslik', el).value.trim(), p_metin: $('#gazMetin', el).value.trim(), p_hedef_parti: $('#gazTur', el).value === 'propaganda' ? +$('#gazHedef', el).value : null }), r => gazeteEkrani(g.id, r));
  $('#gazTur', m).onchange = () => { const propaganda = $('#gazTur', m).value === 'propaganda'; $('#gazHedefAlan', m).hidden = !propaganda; $('#gazHedef', m).required = propaganda; };
}
