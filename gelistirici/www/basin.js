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
    <div class="kart tg-kart-kisa"><h2>📰 TÜRKİYE GÜNDEM · OTOMATİK GAZETE</h2>
  <p class="alt">Cumhurbaşkanı adayları, parti değişimleri, seçim beyannameleri ve ittifaklar; bütün gerçek gelişmeler tek gazetede. Ücretsiz ve 5 dakikada bir güncellenir.</p>
  <button class="btn altin" onclick="otomatikGazeteEkrani()">📰 Son dakika ve manşetleri oku</button></div>
  <div class="kart" id="basinBenim"><h2>${d.benim ? 'Gazetem' : 'Kendi gazeteni kur'}</h2><p class="alt">${d.benim ? e(d.benim.ad) + ' · Kasa: ' + tlYaz(d.benim.kasa) : 'Kuruluş bedeli: ' + tlYaz(d.kurulus_ucreti) + '. Ücretsiz veya ücretli yayın yapabilirsin.'}</p></div>
    <div id="basinTeklifler"></div><div id="basinYazarlik"></div><h2>Gazete büfesi</h2><div id="basinListe" class="basin-grid"></div>`, { geri: true });
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
  const yazarlik=(d.gazeteler||[]).filter(g=>g.yaziyim);
  if(yazarlik.length)$('#basinYazarlik').innerHTML='<section class="kart"><h2>✍️ Köşe yazarı olduğum gazeteler</h2>'+yazarlik.map(g=>'<div class="kv"><span>'+e(g.ad)+'</span><button class="btn ikinci" onclick="ekranAc(()=>gazeteEkrani('+Number(g.id)+'))">Yazı yaz</button></div>').join('')+'</section>';
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
    <div id="gazYonetim"></div><div id="gazYayinlar">${(g.yayinlar || []).map(y => `<article class="kart basin-yazi"><span class="rozet ${y.tur === 'propaganda' ? 'kirmizi' : ''}">${e(BASIN_TUR[y.tur] || y.tur)}</span>${y.tur === 'propaganda' ? `<p class="basin-propaganda">Bu yayın siyasi propagandadır. Hedef parti: ${e(y.hedef_parti && (y.hedef_parti.ad || y.hedef_parti.kisa) || 'Belirtilmemiş')}</p>` : ''}<h2>${e(y.baslik)}</h2><div class="kucuk">${e(y.yazar)} · ${e(tarihSaat(y.zaman))}</div><div class="basin-metin">${e(y.metin)}</div>${y.kilitli ? '<div class="basin-kilit">🔒 Önizleme · Tam yazıyı okumak için gazeteye abone ol.</div>' : ''}${y.tur==='kose' && !y.kilitli && g.erisim ? `<div style="margin-top:10px"><button class="btn ikinci" onclick="gazeteKoseYorumGoster(${Number(y.id)},${Number(g.id)})">💬 Yorumları gör / yorum yaz</button><div id="gaz_kose_yorum_${Number(y.id)}"></div></div>` : ''}</article>`).join('') || '<div class="bos">Henüz yazı yayımlanmamış.</div>'}</div>`, { geri: true });
  const eylem = $('#gazEylem');
  if (!g.erisim && g.abonelik_ucret > 0) eylem.appendChild(basinDugme('Abone ol · ' + tlYaz(g.abonelik_ucret), () => {
    basinForm('Gazeteye abone ol', `<p>${e(g.ad)} için cüzdanından ${tlYaz(g.abonelik_ucret)} ödenir. Abonelik bitişi işlemden sonra gösterilir.</p>`, 'Öde ve abone ol', 'gazete_abone_ol', () => ({ p_gazete: g.id }), r => gazeteEkrani(g.id, r));
  }, 'altin'));
  eylem.appendChild(basinDugme('🤝 Bu gazeteye bağış yap', () => aliciBagisModal('gazete',g.id,g.ad), 'ikinci'));
  if (g.sahibim || (g.yazarlar || []).some(y => y.benim)) eylem.appendChild(basinDugme('Yazı yayımla', () => gazeteYayinModal(g), 'altin'));
  if (g.sahibim) {
    const yon = $('#gazYonetim');
    yon.innerHTML = `<section class="kart"><h2>Gazete kasası</h2><b>${tlYaz(g.kasa)}</b><p class="kucuk">Abonelik gelirleri kasaya eklenir; yazar ücretleri buradan ödenir.</p><div id="gazSahipEylem"></div><details><summary>Son kasa hareketleri</summary>${(g.hareketler || []).map(h => `<div class="liste-satir"><div class="orta">${e(h.aciklama)}<div class="kucuk">${e(tarihSaat(h.zaman))}</div></div><b>${tlYaz(h.tutar)}</b></div>`).join('') || '<p class="kucuk">Henüz hareket yok.</p>'}</details></section><section class="kart"><h2>✍️ Köşe yazarları</h2><p class="alt">Oyuncu kullanıcı adıyla teklif gönder. Kabul eden yazar burada görünür ve yazı başına ücret alır.</p><div id="gazYazarlar"></div></section>`;
    const yer = $('#gazSahipEylem');
    yer.appendChild(basinDugme('Kasadan para çek', () => basinForm('Gazete geliri çek', `<p class="alt">Kasa: ${tlYaz(g.kasa)}</p>` + basinAlan('gazMiktar', 'Çekilecek tutar (₺)', 'type="number" min="100" step="1" required'), 'Cüzdanıma aktar', 'gazete_para_cek', m => ({ p_gazete: g.id, p_miktar: +$('#gazMiktar', m).value }), r => gazeteEkrani(g.id, r))));
    yer.appendChild(basinDugme('Slogan ve abonelik ayarları', () => basinForm('Gazete ayarları', basinAlan('gazSlogan', 'Slogan', 'maxlength="100"', g.slogan) + basinAlan('gazAbone', 'Aylık abonelik (₺) — ücretsiz için 0', 'type="number" min="0" step="1" required', g.abonelik_ucret), 'Kaydet', 'gazete_ayar', m => ({ p_gazete: g.id, p_slogan: $('#gazSlogan', m).value, p_abonelik: +$('#gazAbone', m).value }), r => gazeteEkrani(g.id, r))));
    yer.appendChild(basinDugme('✍️ Köşe yazarı işe al', () => basinForm('Yazarlık teklifi', basinAlan('gazKad', 'Oyuncunun kullanıcı adı', 'required maxlength="20"') + basinAlan('gazUcret', 'Yazı başına ücret (₺)', 'type="number" min="0" max="10000" step="1" required', 0), 'Teklif gönder', 'gazete_yazar_teklif', m => ({ p_gazete: g.id, p_kad: $('#gazKad', m).value.trim(), p_ucret: +$('#gazUcret', m).value }), r => gazeteEkrani(g.id, r))));
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
  host.innerHTML='<section class="kart" style="margin-top:10px"><h3>💬 Yorumlar ('+fmt(d.yorum_sayisi,0)+')</h3>'+
   (d.yorumlar||[]).map(x=>'<div class="liste-satir"><div class="orta"><b>'+e(x.kad)+'</b> <span class="kucuk">'+e(tarihSaat(x.zaman))+'</span><div class="basin-metin">'+e(x.metin)+'</div></div>'+
    (x.silebilir?'<button type="button" class="btn ikinci" onclick="gazeteKoseYorumSil('+Number(x.id)+','+yayinId+','+gazeteId+')">Kaldır</button>':'')+'</div>').join('')+
   (d.yorumlar.length?'':'<p class="alt">Henüz yorum yapılmamış. İlk yorumu sen yazabilirsin.</p>')+
   '<div class="alan"><label for="gaz_yorum_metin_'+yayinId+'">Senin yorumun (2–500 karakter)</label><textarea id="gaz_yorum_metin_'+yayinId+'" rows="3" minlength="2" maxlength="500" placeholder="Bu köşe yazısı hakkında ne düşünüyorsun?"></textarea></div>'+
   '<button class="btn altin" type="button" onclick="gazeteKoseYorumYaz('+yayinId+','+gazeteId+')">Yorum gönder</button>'+
   '<p class="kucuk">30 saniyede bir, 24 saatte en fazla 25 yorum. Yorumunu sen veya gazetenin sahibi kaldırabilir.</p></section>';
 }catch(err){host.textContent=hataCevir(err.message);}
}
async function gazeteKoseYorumYaz(yayinId,gazeteId){
 const el=document.getElementById("gaz_yorum_metin_"+yayinId);if(!el)return;
 const metin=el.value.trim();
 if(metin.length<2||metin.length>500){toast("Yorum 2–500 karakter olmalı.",true);return;}
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
  const m = basinForm('Yazı yayımla', `<div class="alan"><label for="gazTur">Yayın türü</label><select id="gazTur"><option value="haber">Haber</option><option value="kose">Köşe yazısı</option><option value="propaganda">Propaganda</option></select></div><div id="gazHedefAlan" hidden><p class="basin-propaganda">Yazı açıkça PROPAGANDA olarak etiketlenir ve oyun yayın akışında da duyurulur.</p><div class="alan"><label for="gazHedef">Hedef parti</label><select id="gazHedef"><option value="">Parti seç…</option>${partiler.filter(p => !p.kapali).map(p => `<option value="${e(p.id)}">${e(p.ad)} (${e(p.kisa)})</option>`).join('')}</select></div></div>` + basinAlan('gazBaslik', 'Başlık', 'required minlength="4" maxlength="100"') + '<div class="alan"><label for="gazMetin">Yazı (20–5000 karakter)</label><textarea id="gazMetin" class="basin-redaktor" rows="12" required minlength="20" maxlength="5000" spellcheck="true" autocapitalize="sentences" placeholder="Haberini veya köşe yazını buraya yaz..."></textarea><span id="gazSayac" aria-live="polite">0 / 5000 karakter</span><p class="kucuk">En az 20, en fazla 5.000 karakter. Yazı alanı boyunca tamamını yazabilir veya yapıştırabilirsin.</p></div>', 'Yayımla', 'gazete_yayinla', el => ({ p_gazete: g.id, p_tur: $('#gazTur', el).value, p_baslik: $('#gazBaslik', el).value.trim(), p_metin: $('#gazMetin', el).value.trim(), p_hedef_parti: $('#gazTur', el).value === 'propaganda' ? +$('#gazHedef', el).value : null }), r => gazeteEkrani(g.id, r));
  $('#gazTur', m).onchange = () => { const propaganda = $('#gazTur', m).value === 'propaganda'; $('#gazHedefAlan', m).hidden = !propaganda; $('#gazHedef', m).required = propaganda; };
  const gazYazi = $('#gazMetin', m), gazSayac = $('#gazSayac', m);
  const gazSay = () => { const n=Array.from(gazYazi.value).length; gazSayac.textContent=n+" / 5000 karakter"; gazSayac.style.color=n>=5000?"var(--gold)":"var(--txt2)"; };
  gazYazi.addEventListener('input',gazSay);gazSay();
}
