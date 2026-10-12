/* Seçim sonuçları: gerçek sandık oylarından il, parti, CB ve ittifak dökümü. */
(function () {
  'use strict';
  var stil = document.createElement('style');
  stil.textContent = '.detay-secim-kart{border:1px solid var(--line2)}' +
    '.detay-secim-kart .detay-baslik{display:flex;align-items:center;justify-content:space-between;gap:9px;flex-wrap:wrap}' +
    '.detay-secim-kart .detay-baslik h2{margin:0}' +
    '.detay-secim-kart details{border-top:1px solid var(--line);padding:12px 0}' +
    '.detay-secim-kart details:first-of-type{margin-top:10px}' +
    '.detay-secim-kart summary{cursor:pointer;font-weight:800;list-style:revert;padding:2px 0;color:var(--txt)}' +
    '.detay-secim-kart .sonuc-kalem{padding:9px 0;border-bottom:1px solid var(--line)}' +
    '.detay-secim-kart .sonuc-kalem:last-child{border-bottom:0}' +
    '.detay-secim-kart .sonuc-kalem-ust{display:flex;justify-content:space-between;gap:12px;align-items:baseline}' +
    '.detay-secim-kart .sonuc-kalem-ust b{overflow-wrap:anywhere;font-size:14px}' +
    '.detay-secim-kart .sonuc-kalem-ust span{font-size:13px;white-space:nowrap;font-weight:700;font-variant-numeric:tabular-nums}' +
    '.detay-secim-kart .sonuc-alt{font-size:12px;color:var(--mut);margin-top:2px}' +
    '.detay-secim-kart .sonuc-cubuk{height:5px;background:var(--panel3);border-radius:4px;overflow:hidden;margin-top:6px}' +
    '.detay-secim-kart .sonuc-cubuk i{display:block;height:100%;border-radius:4px}' +
    '.detay-secim-kart .sonuc-il-sec{width:100%;min-height:42px;background:var(--bg);color:var(--txt);border:1px solid var(--line2);border-radius:9px;padding:8px 11px;margin:12px 0}' +
    '.detay-secim-kart .sonuc-il-sec option{background:var(--bg);color:var(--txt)}' +
    '.detay-secim-kart .sonuc-il-bolum{font-size:14px;font-weight:800;margin:15px 0 3px}';
  document.head.appendChild(stil);
  function sayi(n) { return Number(n || 0).toLocaleString('tr-TR'); }
  function yuzde(n) { return Number(n || 0).toLocaleString('tr-TR', {maximumFractionDigits:2,minimumFractionDigits:1}); }
  function barRenk(n) { return /^#[0-9a-fA-F]{3,8}$/.test(String(n || '')) ? n : '#8e7dff'; }
  function satir(x, tip) {
    var ad = x.kad || x.ad || x.kisa || 'Diğer';
    var renk = barRenk(x.renk);
    var oran = Math.max(0, Math.min(100, Number(x.yuzde) || 0));
    var alt = tip === 'aday' ? (x.kisa || 'Bağımsız') : tip === 'ittifak' ?
      (Array.isArray(x.partiler) ? x.partiler.join(' + ') : 'Üye partilerin milletvekili oyları') :
      (x.kisa && x.ad !== x.kisa ? x.kisa : '');
    return '<div class="sonuc-kalem"><div class="sonuc-kalem-ust"><b>' +
      e(ad) + '</b><span>' + sayi(x.oy) + ' oy · %' + yuzde(x.yuzde) +
      '</span></div>' + (alt ? '<div class="sonuc-alt">' + e(alt) + '</div>' : '') +
      '<div class="sonuc-cubuk"><i style="width:' + oran + '%;background:' +
      renk + '"></i></div></div>';
  }
  function liste(xs, tip) {
    return xs && xs.length ? xs.map(function(x){ return satir(x,tip); }).join('') :
      '<p class="alt" style="margin-top:9px">Bu kategoride kayıtlı oy yok.</p>';
  }
  function ilDetay(i) {
    if(!i) return '<div class="alt">İl sonucu bulunamadı.</div>';
    var pc = (i.partiler || []).length;
    return '<p class="alt">' + e(i.il) + ': ' + sayi(i.toplam) +
      ' milletvekili oyu, ' + sayi(i.cb_toplam) + ' cumhurbaşkanlığı oyu</p>' +
      '<h4 class="sonuc-il-bolum">Partiler · Milletvekili (' + pc + ')</h4>' +
      liste(i.partiler, 'parti') +
      (Number(i.bagimsiz) > 0 ? '<p class="sonuc-alt">Bağımsızlara verilen oy: <b>' +
       sayi(i.bagimsiz) + '</b></p>' : '') +
      '<h4 class="sonuc-il-bolum">Cumhurbaşkanı adayları</h4>' + liste(i.adaylar,'aday') +
      '<h4 class="sonuc-il-bolum">İttifaklar · Milletvekili</h4>' + liste(i.ittifaklar,'ittifak');
  }
  function kart(r,s) {
    var secenek = (r.iller || []).map(function(i) {
      return '<option value="' + Number(i.il_id) + '">' + e(i.il) + '</option>';
    }).join('');
    var ikinciTur = s.tur === 'cb' && s.sonuc && s.sonuc.ikinci_tur;
    return '<section class="kart detay-secim-kart" id="detaySecimSonuclari">' +
      '<div class="detay-baslik"><h2>Kesin seçim sonuçları</h2>' +
      '<span class="rozet yesil">Sayım tamamlandı</span></div>' +
      '<p class="alt" style="margin-top:6px">Oyundaki gerçek oylar · ' +
      sayi(r.mv_toplam) + ' milletvekili oyu · ' + sayi(r.cb_toplam) +
      ' cumhurbaşkanlığı oyu' +
      (ikinciTur ? ' · Cumhurbaşkanlığı ikinci tura kaldı' : '') + '</p>' +
      '<details open><summary>Cumhurbaşkanı adaylarının aldığı oylar</summary>' +
      liste(r.adaylar, 'aday') + '</details>' +
      '<details open><summary>Partilerin aldığı oylar · Milletvekili</summary>' +
      liste(r.partiler, 'parti') +
      (Number(r.bagimsiz_oy) > 0 ? '<p class="sonuc-alt">Bağımsız adaylar: ' +
      sayi(r.bagimsiz_oy) + ' oy</p>' : '') + '</details>' +
      '<details open><summary>İttifakların aldığı oylar · Milletvekili</summary>' +
      '<p class="sonuc-alt">İttifak toplamları, üye partilerin aldığı milletvekili oylarının toplamıdır.</p>' +
      liste(r.ittifaklar, 'ittifak') + '</details>' +
      '<details><summary>İl il seçim sonuçları (' +
      (r.iller || []).length + ' il)</summary>' +
      '<select class="sonuc-il-sec" id="detaySecimIl" aria-label="Sonuçları gösterilecek il">' +
      secenek + '</select><div id="detaySecimIlSonucu"></div></details>' +
      '</section>';
  }
  async function goster(s) {
    if (!s || ['mv','cb','cb2'].indexOf(s.tur) < 0 || s.asama !== 'bitti') return;
    var alan = document.getElementById('icerik');
    if (!alan) return;
    try {
      var r = await API.rpc('secim_ayrintili_sonuclar', {p_secim:s.id});
      if (document.getElementById('icerik') !== alan || !r || !r.hazir) return;
      var onceki = alan.querySelector('#detaySecimSonuclari');
      if (onceki) onceki.remove();
      var kapsayici = document.createElement('div');
      kapsayici.innerHTML = kart(r,s);
      var kutu = kapsayici.firstElementChild;
      var gece = alan.querySelector('#geceKart');
      if (gece) gece.insertAdjacentElement('afterend',kutu);
      else alan.insertAdjacentElement('afterbegin',kutu);
      var sec = kutu.querySelector('#detaySecimIl');
      var hedef = kutu.querySelector('#detaySecimIlSonucu');
      if(sec && hedef) {
        var iller = r.iller || [];
        if(iller.some(function(i){return String(i.il_id)===String(s.benim_il);}))
          sec.value = String(s.benim_il);
        var yenile = function(){
          hedef.innerHTML = ilDetay(iller.find(function(i){return String(i.il_id)===sec.value;}));
        };
        sec.addEventListener('change',yenile);
        yenile();
      }
    } catch(err) {
      // Bağlantı geçici olarak yoksa eski seçim sayfası çalışmaya devam eder.
      console.warn('Ayrıntılı seçim sonuçları henüz alınamadı.',err);
    }
  }
  window.ayrintiliSecimSonucGoster = goster;
})();