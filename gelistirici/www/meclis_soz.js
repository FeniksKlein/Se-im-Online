/* 24.11.2026 · GENEL KURUL: SÖZ HAKKI VE KONUŞMA SINIRI (sql/zz_20261124_meclis_soz.sql)
   Genel Kurul sohbetinde yazma alanının üstüne söz şeridini kurar: vekil söz ister, Meclis Başkanı / başkanvekili
   sıradan söz verir; söz türüne göre karakter sınırı uygulanır. Yetki ve sınır sunucuda doğrulanır (sohbet_yaz).
   sohbet_tasarim.js › kanalEkrani('meclis') sonunda window.meclisSozKur(S) çağrılır. */
(function () {
  'use strict';
  var Z = null, zam = null, S0 = null;
  function q(s, k) { return (k || document).querySelector(s); }
  function e(x) { return typeof esc === 'function' ? esc(x) : String(x == null ? '' : x).replace(/[&<>"']/g, function (c) { return '&#' + c.charCodeAt(0) + ';'; }); }
  function saat(x) { try { return new Date(x).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' }); } catch (err) { return ''; } }
  function bildir(m, kotu) { try { toast(m, kotu); } catch (err) {} }
  function hataGoster(err) { var m = (err && err.message) || String(err || ''); try { if (typeof hataCevir === 'function') m = hataCevir(m); } catch (x) {} bildir(m, true); }
  function css() {
    if (q('#mszCss')) return;
    var s = document.createElement('style'); s.id = 'mszCss';
    s.textContent = '.msz{margin:0 10px 8px;padding:12px;border-radius:14px;background:#161c2c;border:1px solid rgba(217,178,91,.45);color:#f2f5ff;font-size:15px;line-height:1.4;color-scheme:dark}' +
      '.msz b{font-weight:800}.msz small{display:block;color:#b9c2da;font-size:14px;margin-top:3px}' +
      '.msz-d{display:block;width:100%;box-sizing:border-box;min-height:46px;margin-top:8px;padding:8px 12px;border-radius:12px;border:1px solid rgba(217,178,91,.6);background:#232b40;color:#f2f5ff;font:inherit;font-size:15.5px;font-weight:700;text-align:center;cursor:pointer;white-space:normal}' +
      '.msz-d.ana{background:#d9b25b;border-color:#d9b25b;color:#1a1405}.msz-d.cizgi{background:transparent;border-color:rgba(255,255,255,.22);font-weight:600}.msz-d:disabled{opacity:.5}' +
      '.msz-s{padding:10px 0;border-top:1px solid rgba(255,255,255,.1);margin-top:10px}.msz-s:first-of-type{border-top:0}' +
      '.msz-iki{display:flex;gap:8px}.msz-iki .msz-d{flex:1 1 0;min-width:0}' +
      '.msz-say{float:right;font-variant-numeric:tabular-nums;color:#b9c2da;font-size:14px}.msz-say.asti{color:#ff8a80;font-weight:800}' +
      '.msz-liste{max-height:240px;overflow:auto}';
    document.head.appendChild(s);
  }
  function dur() { if (zam) { clearInterval(zam); zam = null; } }
  function yonetimAdina() { var cb = q('#shyResmi'); return !!(cb && cb.checked); }
  async function yenile() {
    if (!q('.shr-meclis') || !q('#yazbar')) { dur(); return; }
    try { Z = await API.rpc('meclis_soz_durum'); } catch (err) { return; }
    ciz();
  }
  function sayac() {
    var ta = q('#yaz'), el = q('#mszSay'); if (!ta || !el) return;
    var sinir = +el.getAttribute('data-sinir') || 0, n = ta.value.trim().length;
    el.textContent = n + ' / ' + sinir; el.classList.toggle('asti', n > sinir);
  }
  function ciz() {
    var bar = q('#yazbar'), ta = q('#yaz'); if (!bar || !ta || !Z || !q('.shr-meclis')) return;
    css();
    var kutu = q('#mszKutu');
    if (!kutu) { bar.insertAdjacentHTML('beforebegin', '<div class="msz" id="mszKutu" role="region" aria-label="Söz hakkı"></div>'); kutu = q('#mszKutu'); }
    var h = '', yazar = false, sinir = 1500;
    if (Z.serbest) { kutu.remove(); ta.disabled = false; ta.maxLength = 1500; return; }
    if (Z.baskanlik) {
      yazar = true; sinir = Z.baskanlik_sinir || 600;
      var l = Z.sira || [];
      h = '<b>Oturumu sen yönetiyorsun</b><span class="msz-say" id="mszSay" data-sinir="' + sinir + '"></span><small>Söz istemeden yazarsın (en çok ' + sinir + ' karakter). Söz isteyenlere sırayla söz ver; 5 dakika işlem yapmazsan söz kendiliğinden verilir.</small>' +
        '<div class="msz-liste">' + (l.map(function (x) {
          return '<div class="msz-s"><b>' + e(x.kad) + '</b>' + (x.parti ? ' · ' + e(x.parti) : '') + '<small>' + e(x.ad) + ' · ' + saat(x.istek) + '\'de istedi · ' + saat(x.otomatik) + '\'de kendiliğinden verilir</small>' +
            '<div class="msz-iki"><button type="button" class="msz-d ana" data-ver="' + x.id + '">Söz ver</button><button type="button" class="msz-d cizgi" data-ret="' + x.id + '">Reddet</button></div></div>';
        }).join('') || '<small>Şu an söz isteyen yok.</small>') + '</div>';
    } else if (Z.soz) {
      yazar = true; sinir = Z.soz.sinir;
      h = '<b>Söz sende · ' + e(Z.soz.ad) + '</b><span class="msz-say" id="mszSay" data-sinir="' + sinir + '"></span><small>Tek konuşma, en çok ' + sinir + ' karakter. ' + saat(Z.soz.bitis) + '\'e kadar yazmazsan söz hakkın düşer.</small>' +
        '<button type="button" class="msz-d cizgi" id="mszVaz">Sözümden vazgeçiyorum</button>';
    } else if (Z.bekleyen) {
      h = '<b>Söz sırasındasın · ' + e(Z.bekleyen.ad) + '</b><small>' + Z.bekleyen.sira + '. sıradasın. Meclis Başkanlığı söz verince bildirim alırsın; vermezse ' + saat(Z.bekleyen.otomatik) + '\'de söz kendiliğinden verilir.</small>' +
        '<button type="button" class="msz-d cizgi" id="mszVaz">Söz istemimi geri al</button>';
    } else {
      var bekle = Z.bekleme_bitis && new Date(Z.bekleme_bitis) > new Date();
      h = '<b>Konuşmak için söz iste</b><small>' + (Z.baskanlik_cevrimici ? 'Sözü Meclis Başkanlığı verir.' : 'Başkanlık şu an kürsüde değil; söz hemen verilir.') +
        (Z.sira_sayi ? ' Sırada ' + Z.sira_sayi + ' kişi var.' : '') + (bekle ? ' Az önce konuştun; ' + saat(Z.bekleme_bitis) + '\'den sonra yeniden isteyebilirsin.' : '') + '</small>' +
        (Z.turler || []).map(function (t) { return '<button type="button" class="msz-d' + (t.kod === 'kisisel' ? ' ana' : '') + '" data-iste="' + e(t.kod) + '"' + (bekle ? ' disabled' : '') + '>' + e(t.ad) + ' · ' + t.sinir + ' karakter</button>'; }).join('');
    }
    var imza = h.replace(/id="mszSay"[^>]*>/, '');
    if (kutu.getAttribute('data-imza') !== imza) { kutu.innerHTML = h; kutu.setAttribute('data-imza', imza); bagla(kutu); }
    var ya = yonetimAdina();
    ta.disabled = !(yazar || ya);
    ta.maxLength = ya ? 1500 : sinir + 200; /* sınırı sunucu denetler; sayaç aşımı kırmızı gösterir */
    if (!yazar && !ya) ta.placeholder = 'Önce söz iste'; else if (ta.placeholder === 'Önce söz iste') ta.placeholder = 'Sayın Başkan, değerli milletvekilleri…';
    var gb = q('#gonder'); if (gb) gb.disabled = !(yazar || ya);
    sayac();
  }
  function bagla(kutu) {
    kutu.querySelectorAll('[data-iste]').forEach(function (b) { b.onclick = async function () {
      b.disabled = true;
      try { Z = await API.rpc('meclis_soz_iste', { p_tur: b.getAttribute('data-iste') }); bildir(Z.soz ? 'Söz sende; konuşmanı yaz.' : 'Söz istemin Başkanlığa iletildi.'); ciz(); var ta = q('#yaz'); if (Z.soz && ta) ta.focus(); }
      catch (err) { b.disabled = false; hataGoster(err); }
    }; });
    var vz = q('#mszVaz', kutu); if (vz) vz.onclick = async function () { try { Z = await API.rpc('meclis_soz_vazgec'); ciz(); } catch (err) { hataGoster(err); } };
    kutu.querySelectorAll('[data-ver]').forEach(function (b) { b.onclick = async function () {
      b.disabled = true;
      try { Z = await API.rpc('meclis_soz_karar', { p_id: +b.getAttribute('data-ver'), p_ver: true, p_gerekce: null }); bildir('Söz verildi.'); ciz(); } catch (err) { hataGoster(err); yenile(); }
    }; });
    kutu.querySelectorAll('[data-ret]').forEach(function (b) { b.onclick = function () {
      if (typeof modal !== 'function') return;
      var md = modal('<h3 style="font-size:19px;font-weight:800;margin:0 0 6px">Söz istemini reddet</h3><p style="font-size:14.5px;opacity:.8;margin:0 0 8px">Gerekçeyi vekil görür. Vekil yeniden söz isteyebilir.</p>' +
        '<label for="mszG" style="display:block;font-size:15px;font-weight:700;margin-bottom:4px">Gerekçe</label><textarea id="mszG" maxlength="200" style="display:block;width:100%;min-width:0;box-sizing:border-box;min-height:88px;font-size:16px;padding:12px;border-radius:12px;background:#1b2030;color:#f2f5ff;border:1px solid rgba(255,255,255,.2);color-scheme:dark" placeholder="Örn. Gündem dışı; görüşülen konu hakkında söz veriliyor."></textarea>' +
        '<button type="button" class="msz-d ana" id="mszROk">Reddet</button><button type="button" class="msz-d cizgi" id="mszRVaz">Vazgeç</button>');
      css();
      q('#mszRVaz', md).onclick = function () { modalKapat(); };
      q('#mszROk', md).onclick = async function () {
        var g = q('#mszG', md).value.trim(); if (g.length < 5) { bildir('Gerekçe en az 5 karakter olmalı.', true); return; }
        try { Z = await API.rpc('meclis_soz_karar', { p_id: +b.getAttribute('data-ret'), p_ver: false, p_gerekce: g }); modalKapat(); ciz(); } catch (err) { hataGoster(err); }
      };
    }; });
  }
  window.meclisSozKur = function (S) {
    S0 = S; dur();
    var ta = q('#yaz'); if (ta && !ta._msz) { ta._msz = true; ta.addEventListener('input', sayac); }
    if (S && typeof S.yaz === 'function' && !S.yaz._msz) {
      var eski = S.yaz;
      S.yaz = function () { return Promise.resolve(eski.apply(this, arguments)).then(function (r) { setTimeout(yenile, 150); return r; }, function (err) { setTimeout(yenile, 150); throw err; }); };
      S.yaz._msz = true;
    }
    document.addEventListener('change', function (ev) { if (ev.target && ev.target.id === 'shyResmi') ciz(); });
    yenile();
    zam = setInterval(yenile, 8000);
  };
})();
