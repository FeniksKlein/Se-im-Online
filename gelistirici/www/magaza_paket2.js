/* 27.11.2026 · MAĞAZA PAKETİ 2 — istemci (sürüm 2026.11.27-4)
   Sunucu: sql/zz_20261127_magaza_paket2.sql. Ürünler aktif=false başlar; mağazada yalnız Ercan açtığı ürünler görünür.
   Bu modül:
   • Mağaza: yeni ürün satırları, hak kullanma düğmeleri (vitrin, manşet, hediye/parti kartı, plaka, mazbata, kongre sloganı)
   • Kürsü: vitrindeki paylaşıma "Öne çıkan" etiketi (sunucu zaten akışın başına koyar)
   • Gündem: yayındaki manşetler, Destekçiler Duvarı, moderatöre "Manşet onayı"
   • Sohbet: [Büyük Bağış] / [Genel Merkez] / [Zafer] / [Hediye Kart] / [Parti Kartı] / [Lansman Sahnesi] mesajları kart görünümünde; plaka ve rozetler
   • Kongre Paketi: yalnız kurultay süresince sohbette adın yanında çip, profilde/oyuncu kartında afiş (oy pusulasında ayrıcalık YOK); Aday lansmanı: Lansman Sahnesi
   • Parti sayfası: Genel Merkez kartı; Profil ve oyuncu kartı: plaka ve mazbatalar; zafer gecesi kutlama sahnesi
   Eski sunucuda (RPC yoksa) hiçbir şey eklenmez. */
(function () {
  'use strict';
  if (window.M2_YUKLENDI) return;
  window.M2_YUKLENDI = true;

  var M2 = window.M2 = { genel: null, genelT: 0, genelIstek: null, vitrin: {}, lansmanParti: {}, kongre: {}, kongreSes: {}, ben: null, yok: false };

  /* ---------- yardımcılar ---------- */
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function n(v) { var x = Number(v); return isFinite(x) ? x : 0; }
  function tl(v) { try { return Math.round(n(v)).toLocaleString('tr-TR') + ' ₺'; } catch (e) { return n(v) + ' ₺'; } }
  function rpc(ad, args) { return API.rpc(ad, args || {}); }
  function hataMetni(err) { var m = (err && err.message) || String(err || ''); return typeof hataCevir === 'function' ? hataCevir(m) : m; }
  function bildir(m, h) { if (typeof toast === 'function') toast(m, h); }
  function hata(err) { bildir(hataMetni(err), true); }
  function simdiMs() { try { return typeof simdi === 'function' ? simdi() : Date.now(); } catch (e) { return Date.now(); } }
  function trSaat(ts) {
    if (!ts) return '';
    try { return new Date(ts).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }); } catch (e) { return String(ts); }
  }
  function profil() { return (typeof D !== 'undefined' && D && D.durum && D.durum.profil) || null; }
  function benParti() { var p = profil(); return p && p.parti ? p.parti.id : null; }
  function mgDurum() { return (window.MGZ && window.MGZ.durum) || null; }
  function m2Durum() { var d = mgDurum(); return d && d.m2 ? d.m2 : null; }
  function jeton(k) { var m = m2Durum(); return m && m.jeton ? n(m.jeton[k]) : 0; }
  function paket(d, id) { return ((d && d.paketler) || []).find(function (p) { return p.urun_id === id; }); }
  function ic() { return document.getElementById('icerik'); }
  function sv(p, ek) { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"' + (ek || '') + '>' + p + '</svg>'; }
  var I = {
    pin: sv('<path d="M12 17v5M5 17h14l-2-5V5h1V2H6v3h1v7z"/>'),
    megafon: sv('<path d="M3 11v2a1 1 0 0 0 1 1h3l6 5V5L7 10H4a1 1 0 0 0-1 1zM17 8a5 5 0 0 1 0 8"/>'),
    kupa: sv('<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/>'),
    taç: sv('<path d="M3 7l4 4 5-7 5 7 4-4-2 12H5z"/>'),
    madalya: sv('<circle cx="12" cy="15" r="6"/><path d="M8 3l4 6 4-6"/>'),
    bina: sv('<path d="M3 21h18M6 21V9h12v12M9 13h2M13 13h2M9 17h2M13 17h2M12 3v6"/>'),
    kalp: sv('<path d="M12 20s-7-4.5-8.6-9.1C2.3 7.6 4.3 4.5 7.5 4.5c1.9 0 3.3 1 4.5 2.6 1.2-1.6 2.6-2.6 4.5-2.6 3.2 0 5.2 3.1 4.1 6.4C19 15.5 12 20 12 20z"/>'),
    hediye: sv('<rect x="3" y="9" width="18" height="12" rx="2"/><path d="M3 13h18M12 9v12M12 9c-2-4-6-4-6-1.5S9 9 12 9zm0 0c2-4 6-4 6-1.5S15 9 12 9z"/>'),
    belge: sv('<path d="M6 3h9l4 4v14H6z"/><path d="M14 3v5h5M9 13h7M9 17h5"/>'),
    sahne: sv('<path d="M3 20h18M5 20V10h14v10M7 6l2 4M17 6l-2 4M12 4v6"/>'),
    bayrak: sv('<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>'),
    plaka: sv('<rect x="2" y="7" width="20" height="10" rx="2"/><path d="M6 7v10"/>'),
    kart: sv('<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18"/>'),
    ok: sv('<path d="M9 6l6 6-6 6"/>'),
    paylas: sv('<path d="M4 12v7a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-7M16 6l-4-4-4 4M12 2v13"/>')
  };

  /* ---------- görünüm ---------- */
  function css() {
    if (document.getElementById('m2Stil')) return;
    var s = document.createElement('style'); s.id = 'm2Stil';
    s.textContent = [
      '.m2-plaka{display:inline-flex;align-items:stretch;border-radius:4px;overflow:hidden;border:1px solid #1B2140;font-family:ui-monospace,Menlo,Consolas,monospace;font-weight:800;font-size:11px;line-height:1.35;vertical-align:-2px;white-space:nowrap}',
      '.m2-plaka i{font-style:normal;background:#2B4FB8;color:#fff;font-size:7.5px;padding:0 2px;display:flex;align-items:flex-end;font-family:inherit}',
      '.m2-plaka b{background:#F4F6FB;color:#1B2140;padding:0 5px;letter-spacing:.6px;font-weight:800}',
      '.m2-plaka.mk{border-color:#F2C94C}.m2-plaka.mk b{background:#11162C;color:#F2C94C}',
      '.m2-plaka.buyuk{font-size:17px;border-radius:6px;border-width:2px}.m2-plaka.buyuk i{font-size:10px;padding:0 4px}.m2-plaka.buyuk b{padding:2px 12px;letter-spacing:1.5px}',
      'h3 .m2-plaka{font-size:13px}',
      '.m2-rz{display:inline-flex;align-items:center;gap:2px;vertical-align:-2px}.m2-rz svg{width:14px;height:14px}',
      '.m2-cip{display:inline-block;font-size:10.5px;font-weight:800;padding:1px 6px;border-radius:6px;line-height:1.5;white-space:nowrap}',
      '.m2-altin{color:#F2C94C}.m2-gumus{color:#D3D6E0}.m2-bronz{color:#D9A066}',
      '.m2-cip.kirmizi{background:rgba(240,69,75,.16);color:#FF7479}','.m2-cip.altin{background:rgba(242,201,76,.15);color:#F2C94C}.m2-cip.gumus{background:rgba(211,214,224,.13);color:#D3D6E0}.m2-cip.bronz{background:rgba(217,160,102,.15);color:#D9A066}.m2-cip.mor{background:var(--inkbg,rgba(123,97,255,.16));color:var(--ink2,#A895FF)}',
      '.m2-etiket{display:inline-flex;align-items:center;gap:5px;font-size:12px;font-weight:800;color:var(--ink2,#A895FF);background:var(--inkbg,rgba(123,97,255,.16));border-radius:8px;padding:3px 9px;margin:0 0 6px}',
      '.m2-etiket svg{width:13px;height:13px}',
      '.kr-g.m2-vitrin{border:1.5px solid var(--ink,#7B61FF) !important;border-radius:16px;background:rgba(123,97,255,.07);margin:6px 0}',
      '.m2-kartmsj{border:1.5px solid rgba(242,201,76,.55) !important;background:rgba(242,201,76,.07) !important}',
      '.m2-kartmsj .shm-tx,.m2-kartmsj .tx{font-weight:700}',
      '.m2-kartmsj-ust{display:flex;align-items:center;gap:6px;font-size:11.5px;font-weight:800;color:#F2C94C;margin-bottom:3px;letter-spacing:.2px}.m2-kartmsj-ust svg{width:14px;height:14px}',
      '.m2-bolum .mg-satir .orta>.m2-durum{font-size:12px;line-height:1.4;color:var(--txt2,#C9D1E6);margin-top:4px}',
      '.m2-kullan{width:auto !important;min-height:40px;margin:8px 0 0 !important;padding:8px 14px !important;font-size:14px;white-space:normal;text-align:left}',
      '.m2-not{display:block;font-size:12px;font-weight:700;color:var(--mut,#98A4C4);text-align:right;max-width:120px;white-space:normal;line-height:1.3}',
      '.m2-manset{border-radius:16px;overflow:hidden;border:1.5px solid var(--al,#F0454B);margin:0 0 12px;background:var(--panel,#151E3D)}',
      '.m2-manset-ust{display:flex;justify-content:space-between;gap:8px;background:var(--al,#F0454B);color:#fff;font-size:11.5px;font-weight:800;padding:5px 12px;letter-spacing:.3px}',
      '.m2-manset-ic{padding:10px 12px}.m2-manset-ic b{display:block;font-size:16.5px;line-height:1.32;font-weight:800;overflow-wrap:anywhere}.m2-manset-ic small{display:block;margin-top:5px;color:var(--mut,#98A4C4);font-size:12.5px}',
      '.m2-duvar{border-radius:16px;padding:12px 14px;margin:0 0 12px;background:var(--panel,#151E3D);border:1px solid rgba(242,201,76,.3)}',
      '.m2-duvar h3{font-size:15px;margin:0 0 6px;display:flex;align-items:center;gap:6px}.m2-duvar h3 svg{width:17px;height:17px;color:#F2C94C}',
      '.m2-duvar-s{display:flex;align-items:center;gap:8px;padding:5px 0;border-bottom:1px solid var(--line,rgba(164,184,255,.1));font-size:14px}.m2-duvar-s:last-child{border-bottom:0}.m2-duvar-s svg{width:17px;height:17px;flex:none}',
      '.m2-duvar-s span{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
      '.m2-modkart{display:flex;align-items:center;gap:10px;width:100%;text-align:left;border-radius:14px;padding:11px 13px;margin:0 0 12px;background:var(--albg,rgba(240,69,75,.15));border:1px solid rgba(240,69,75,.45);color:inherit;font:inherit;cursor:pointer}',
      '.m2-alan{display:block;margin:10px 0}.m2-alan label{display:block;font-size:15px;font-weight:700;margin:0 0 6px}',
      '.m2-alan input,.m2-alan textarea,.m2-alan select{width:100%;min-width:0;box-sizing:border-box;font-size:16px;color-scheme:dark;background:var(--panel2,#1D2850);color:var(--txt,#EEF1F8);border:1px solid var(--line2,rgba(164,184,255,.19));border-radius:11px;padding:11px 12px}',
      '.m2-alan option{background:#1D2850;color:#EEF1F8}',
      '.m2-sayac{font-size:12px;color:var(--mut,#98A4C4);text-align:right;margin-top:4px}',
      '.m2-secim{display:grid;gap:8px;max-height:52vh;overflow:auto;margin:10px 0}',
      '.m2-secim button{width:100%;text-align:left;border-radius:12px;padding:10px 12px;background:var(--panel2,#1D2850);border:1px solid var(--line2,rgba(164,184,255,.19));color:inherit;font:inherit;font-size:14.5px;line-height:1.4;min-height:48px;overflow-wrap:anywhere}',
      '.m2-secim button.on{border-color:var(--ink,#7B61FF);background:rgba(123,97,255,.18)}',
      '.m2-plaka-form{display:grid;grid-template-columns:72px 1fr 1fr;gap:8px}.m2-plaka-form input,.m2-plaka-form select{text-transform:uppercase}',
      '.m2-onizle{display:flex;justify-content:center;margin:12px 0}',
      '.m2-gm{border-radius:18px;overflow:hidden;border:1px solid var(--line2,rgba(164,184,255,.19));background:var(--panel,#151E3D);margin:0 0 12px}',
      '.m2-gm-gor{background:#11162C;display:flex;justify-content:center;padding:12px}',
      '.m2-gm-ic{padding:12px 14px}.m2-gm-ic h3{font-size:16px;margin:0}',
      '.m2-cubuk{height:10px;border-radius:5px;background:var(--panel3,#283563);overflow:hidden;margin:8px 0 4px}.m2-cubuk i{display:block;height:100%;background:#F2C94C;border-radius:5px}',
      '.m2-mazbata{background:#F4F6FB;color:#1B2140;border-radius:8px;padding:6px;margin:10px 0}',
      '.m2-mazbata-ic{border:2px solid #B08D3C;border-radius:5px;padding:14px 12px;text-align:center}',
      '.m2-mazbata-ic .ust{font-size:10px;letter-spacing:1.4px;color:#6E5A2B;font-weight:700}.m2-mazbata-ic h4{font-size:22px;letter-spacing:3px;margin:6px 0 2px;font-weight:800}',
      '.m2-mazbata-ic .ad{font-size:18px;font-weight:800;margin:6px 0 2px}.m2-mazbata-ic .alt2{display:flex;justify-content:space-between;align-items:flex-end;margin-top:12px;font-size:11px;color:#4A5272}',
      '.m2-muhur{width:48px;height:48px;border-radius:50%;border:2px solid #B03A2E;color:#B03A2E;display:flex;align-items:center;justify-content:center;font-size:9px;line-height:1.1;font-weight:800;transform:rotate(-12deg);text-align:center}',
      '.m2-mazbata-ic .dip{font-size:9.5px;color:#8A90A8;margin-top:8px}',
      '.m2-kongre{border-radius:12px;overflow:hidden;margin:6px 0 2px;border:1px solid rgba(240,69,75,.5)}',
      '.m2-kongre-bayrak{background:#C8102E;display:flex;align-items:center;justify-content:center;height:46px;position:relative;overflow:hidden}',
      '.m2-kongre-bayrak svg{width:92px;height:46px;animation:m2Dalga 2.4s ease-in-out infinite;transform-origin:left center}',
      '@keyframes m2Dalga{0%,100%{transform:skewY(0deg) scaleX(1)}50%{transform:skewY(-3deg) scaleX(.97)}}',
      '.m2-kongre-afis{display:flex;gap:8px;align-items:center;padding:7px 9px;background:#1D2850;font-size:12.5px;font-weight:800;color:#F2C94C;letter-spacing:.3px}',
      '.av-sahne.m2-sahne-on{border:2px solid #F2C94C;box-shadow:0 0 0 1px rgba(242,201,76,.35)}',
      '.m2-isiklar{display:flex;justify-content:space-between;margin:0 0 8px;color:#F2C94C}.m2-isiklar svg{width:20px;height:20px;animation:m2Isik 1.6s ease-in-out infinite}.m2-isiklar svg:nth-child(2n){animation-delay:.8s}',
      '@keyframes m2Isik{0%,100%{opacity:1}50%{opacity:.35}}',
      '.m2-poster{margin:10px auto 0;display:inline-block;border-radius:10px;padding:10px 16px;text-align:center;color:#fff}.m2-poster small{display:block;font-size:11px;letter-spacing:1.5px;font-weight:800}.m2-poster b{display:block;font-size:16px}',
      '.m2-konfeti{position:fixed;inset:0;pointer-events:none;z-index:9999;overflow:hidden}',
      '.m2-konfeti i{position:absolute;top:-14px;width:7px;height:12px;border-radius:2px;animation:m2Dus linear forwards}',
      '@keyframes m2Dus{to{transform:translateY(110vh) rotate(720deg)}}',
      '.m2-zafer{position:fixed;inset:0;z-index:9998;background:rgba(5,8,20,.82);display:flex;align-items:center;justify-content:center;padding:20px}',
      '.m2-zafer-k{max-width:360px;width:100%;background:#11162C;border:2px solid #F2C94C;border-radius:20px;padding:24px 18px;text-align:center;color:#EEF1F8}',
      '.m2-zafer-k svg{width:52px;height:52px;color:#F2C94C}.m2-zafer-k h2{font-size:23px;margin:8px 0 4px}.m2-zafer-k .btn{margin-top:14px}',
      '@media (prefers-reduced-motion: reduce){.m2-kongre-bayrak svg,.m2-isiklar svg,.m2-konfeti i{animation:none}}'
    ].join('\n');
    document.head.appendChild(s);
  }

  /* ---------- plaka ve rozetler ---------- */
  function plakaHtml(metin, makam, buyuk) {
    if (!metin) return '';
    return '<span class="m2-plaka' + (makam ? ' mk' : '') + (buyuk ? ' buyuk' : '') + '" title="' + (makam ? 'Makam plakası' : 'Özel plaka') + '"><i>TR</i><b>' + esc(metin) + '</b></span>';
  }
  function kademeAd(k) { return k === 3 ? 'altin' : k === 2 ? 'gumus' : 'bronz'; }
  function kademeYazi(k) { return k === 3 ? 'Altın' : k === 2 ? 'Gümüş' : 'Bronz'; }
  function gmAd(s) { return s === 3 ? 'Büyük Genel Merkez' : s === 2 ? 'Genel Merkez' : s === 1 ? 'İl Binası' : 'Arsa'; }
  // magaza.js rozetHtml çağırır: l = belirteç listesi
  window.M2_ROZET = function (l) {
    if (!l || !l.length) return '';
    var h = '', pl = l.find(function (x) { return x.indexOf('p:') === 0; });
    if (pl) h += plakaHtml(pl.slice(2), l.indexOf('pm') >= 0);
    var dw = l.find(function (x) { return x.indexOf('dw:') === 0; });
    if (dw) { var k = n(dw.slice(3)); h += '<span class="m2-rz m2-' + kademeAd(k) + '" title="Ayın destekçisi · ' + kademeYazi(k) + '">' + (k === 3 ? I.taç : I.madalya) + '</span>'; }
    var gm = l.find(function (x) { return x.indexOf('gm:') === 0; });
    if (gm) { var s = n(gm.slice(3)); h += '<span class="m2-rz m2-' + (s === 3 ? 'altin' : s === 2 ? 'gumus' : 'bronz') + '" title="Partisi: ' + gmAd(s) + '">' + I.bina + '</span>'; }
    var bb = l.find(function (x) { return x.indexOf('bb:') === 0; });
    if (bb && String(benParti()) === bb.slice(3)) h += '<span class="m2-cip altin" title="Parti içinde görünür">Büyük Bağışçı</span>';
    if (l.indexOf('yu') >= 0) h += '<span class="m2-cip mor" title="Yıllık Siyaset Kartı">Yıllık Üye</span>';
    var z = l.find(function (x) { return x.indexOf('z:') === 0; });
    if (z) h += '<span class="m2-cip altin" title="Seçim zaferi">' + esc(z.slice(2)) + '</span>';
    var kg = l.find(function (x) { return x.indexOf('kg:') === 0; });
    if (kg) h += '<span class="m2-cip kirmizi" title="Genel başkan adayı · kurultay süresince">' + I.bayrak.replace('<svg', '<svg style="width:11px;height:11px;vertical-align:-1px;margin-right:3px"') + esc(kg.slice(3)) + '</span>';
    return h;
  };
  function rozetListe(kad) {
    var r = window.MGZ && window.MGZ.rozet && kad && kad.charAt(0) !== '#' ? window.MGZ.rozet[kad] : null;
    return r ? String(r).split(',') : [];
  }

  /* ---------- herkese açık özet ---------- */
  function genelYukle(zorla) {
    if (M2.yok) return Promise.resolve(null);
    if (!zorla && M2.genel && Date.now() - M2.genelT < 60000) return Promise.resolve(M2.genel);
    if (M2.genelIstek) return M2.genelIstek;
    M2.genelIstek = rpc('m2_genel').then(function (g) {
      M2.genel = g || null; M2.genelT = Date.now(); M2.genelIstek = null;
      (g && g.vitrin || []).forEach(function (id) { M2.vitrin[id] = 1; });
      return M2.genel;
    }).catch(function (err) {
      M2.genelIstek = null;
      if (/function|does not exist|bulunamad/i.test(String(err && err.message))) M2.yok = true;
      return null;
    });
    return M2.genelIstek;
  }

  /* ---------- API kancası: Kürsü vitrini, lansman ve kurultay ---------- */
  function apiSar() {
    if (typeof API !== 'object' || !API || typeof API.rpc !== 'function' || API.rpc._m2) return;
    var eski = API.rpc;
    var yeni = function (ad, args) {
      var p = eski.apply(this, arguments);
      if (p && typeof p.then === 'function' && (ad === 'kursu_akis' || ad === 'aday_lansman_detay')) {
        p.then(function (r) {
          try {
            if (ad === 'kursu_akis' && r && Array.isArray(r.vitrin)) {
              if (!args || !args.p_imlec) { M2.vitrin = {}; r.vitrin.forEach(function (id) { M2.vitrin[id] = 1; }); }
              setTimeout(vitrinEtiketle, 30);
            } else if (ad === 'aday_lansman_detay' && r && r.parti) {
              M2.lansmanParti[r.id] = r.parti.id; setTimeout(sahneSus, 30);
            }
          } catch (e) {}
        }, function () {});
      }
      return p;
    };
    yeni._m2 = true;
    API.rpc = yeni;
  }

  /* ---------- Kürsü: vitrin etiketi ---------- */
  function vitrinEtiketle() {
    var l = document.getElementById('krListe'); if (!l) return;
    l.querySelectorAll('.kr-g[data-id]').forEach(function (a) {
      var var_ = !!M2.vitrin[a.getAttribute('data-id')];
      if (var_ && !a.classList.contains('m2-vitrin')) {
        a.classList.add('m2-vitrin');
        var g = a.querySelector('.kr-g-g') || a;
        g.insertAdjacentHTML('afterbegin', '<div class="m2-etiket">' + I.pin + 'Öne çıkan · Kürsü Vitrini</div>');
      }
    });
  }

  /* ---------- Sohbet: kart mesajları ve rozetler ---------- */
  var KART_ONEK = [
    ['[Büyük Bağış]', 'Büyük Bağış', 'kalp'], ['[Genel Merkez]', 'Genel Merkez', 'bina'], ['[Zafer]', 'Seçim zaferi', 'kupa'],
    ['[Hediye Kart]', 'Hediye Siyaset Kartı', 'hediye'], ['[Parti Kartı]', 'Parti Kartı', 'kart'], ['[Lansman Sahnesi]', 'Lansman Sahnesi', 'sahne']
  ];
  function sohbetSus(kok) {
    (kok || document).querySelectorAll('.shm[data-kad]:not([data-m2]), .balon[data-kad]:not([data-m2])').forEach(function (el) {
      el.setAttribute('data-m2', '1');
      var tx = el.querySelector('.shm-tx, .tx'); if (!tx) return;
      var t = (tx.textContent || '').trim();
      for (var i = 0; i < KART_ONEK.length; i++) {
        if (t.indexOf(KART_ONEK[i][0]) === 0) {
          var b = el.querySelector('.shm-b') || el;
          b.classList.add('m2-kartmsj');
          tx.textContent = t.slice(KART_ONEK[i][0].length).trim();
          tx.insertAdjacentHTML('beforebegin', '<div class="m2-kartmsj-ust">' + I[KART_ONEK[i][2]] + KART_ONEK[i][1] + '</div>');
          break;
        }
      }
      var kim = el.querySelector('.shm-kim b'); if (!kim || kim.parentNode.querySelector('.m2-ek')) return;
      var rz = window.M2_ROZET(rozetListe(el.getAttribute('data-kad')));
      if (rz) kim.insertAdjacentHTML('afterend', '<span class="m2-ek" style="display:inline-flex;gap:3px;margin-left:4px;vertical-align:-1px">' + rz + '</span>');
    });
  }

  /* ---------- Gündem: manşet, duvar, moderatör kartı ---------- */
  function gundemHtml(g) {
    if (!g) return '';
    var h = '';
    (g.manset || []).forEach(function (m) {
      var kalan = m.bit ? Math.max(0, Math.ceil((new Date(m.bit).getTime() - simdiMs()) / 3600000)) : 0;
      h += '<div class="m2-manset"><div class="m2-manset-ust"><span>Manşet · Sponsorlu</span><span>' + (kalan ? kalan + ' sa kaldı' : '') + '</span></div>' +
        '<div class="m2-manset-ic"><b>' + esc(m.baslik) + '</b><small>' + esc(m.parti ? m.parti.ad : m.ad) + '</small></div></div>';
    });
    if (g.manset_onay) h += '<button type="button" class="m2-modkart" data-m2="mansetOnay"><b style="flex:1">Manşet onayı · ' + n(g.manset_onay) + ' bekliyor</b><span>' + I.ok.replace('<svg', '<svg style="width:18px;height:18px"') + '</span></button>';
    var dv = (g.duvar || []).slice(0, 6);
    if (dv.length) {
      h += '<div class="m2-duvar"><h3>' + I.taç + esc(g.ay_ad || '') + ' destekçileri</h3>' + dv.map(function (x) {
        return '<div class="m2-duvar-s m2-' + kademeAd(x.kademe) + '">' + (x.kademe === 3 ? I.taç : I.madalya) + '<span>' + esc(x.ad) + '</span><span class="m2-cip ' + kademeAd(x.kademe) + '" style="flex:none">' + kademeYazi(x.kademe) + '</span></div>';
      }).join('') + ((g.duvar || []).length > 6 ? '<div class="kucuk" style="margin-top:4px">ve ' + ((g.duvar || []).length - 6) + ' destekçi daha</div>' : '') +
        '<div class="kucuk" style="margin-top:6px">Oyunu ayakta tutanlara teşekkürler.</div></div>';
    }
    return h;
  }
  function gundemde() {
    var h = document.querySelector('.ust h1');
    return !!(h && /Gündem/.test(h.textContent) && typeof D !== 'undefined' && D && D.sekme === 'gundem' && (!D.yigin || !D.yigin.length) && ic());
  }
  function gundemSus() {
    var x = ic(); if (!x) return;
    genelYukle().then(function (g) {
      if (!g) return; var k = ic(); if (!k || !document.querySelector('.ust h1') || !/Gündem/.test(document.querySelector('.ust h1').textContent)) return;
      var html = gundemHtml(g), eski = document.getElementById('m2Gundem');
      if (eski) { if (eski.innerHTML !== html) eski.innerHTML = html; } else {
        // Manşet Gündem'in en üstünde durur (haber şeridi yeni tasarımda gizli olabilir)
        k.insertAdjacentHTML('afterbegin', '<div id="m2Gundem">' + html + '</div>');
      }
      var mk = document.querySelector('[data-m2="mansetOnay"]'); if (mk) mk.onclick = function () { ekranAc(mansetOnayEkrani); };
    });
  }

  /* ---------- Mağaza bölümü (magaza.js çağırır) ---------- */
  function satir(ikon, renk, baslik, alt, durum, sag, ek) {
    return '<div class="mg-satir"><span class="mg-ikon"' + (renk ? ' style="color:' + renk + ';background:' + renk + '22"' : '') + '>' + ikon + '</span><div class="orta"><b>' + baslik + '</b>' +
      (alt ? '<div class="kucuk">' + alt + '</div>' : '') + (durum ? '<div class="m2-durum">' + durum + '</div>' : '') + (ek || '') + '</div>' + (sag || '') + '</div>';
  }
  function kullanDugme(id, yazi) { return '<button type="button" class="btn altin m2-kullan" data-m2k="' + id + '">' + yazi + '</button>'; }
  function not(yazi) { return '<span class="m2-not">' + yazi + '</span>'; }
  function kuyrukYazi(q, ad) {
    if (!q) return '';
    if (n(q.dolu) < n(q.yer) && !n(q.sira)) return 'Şu an ' + n(q.dolu) + '/' + n(q.yer) + ' dolu · alırsan hemen yayına girer.';
    return 'Şu an ' + n(q.dolu) + '/' + n(q.yer) + ' dolu' + (n(q.sira) ? ', sırada ' + n(q.sira) + ' kişi' : '') + ' · alırsan tahmini yayın: ' + esc(trSaat(q.tahmin)) + '.';
  }
  window.M2_MAGAZA = function (d, fiyat) {
    css();
    var m = d && d.m2; if (!m) return '';
    var P = d.paketler || [], h = '', b;
    var kartlar = P.filter(function (p) { return p.tur === 'kart'; }).slice(1);
    if (kartlar.length) {
      h += '<div class="bolum-bas"><h2>Uzun süreli Siyaset Kartı</h2><span class="kucuk">Süre üst üste eklenir</span></div><div class="kart">' +
        kartlar.map(function (p) { return satir(I.kart, '', esc(p.ad) + (p.etiket ? ' <span class="m2-cip mor">' + esc(p.etiket) + '</span>' : ''), esc(p.aciklama || ''), '', fiyat(p)); }).join('') + '</div>';
    }
    // Seçim dönemi
    b = '';
    var v = paket(d, 'secimonline.kursu_showcase_24h');
    if (v || jeton('m2_vitrin')) b += satir(I.pin, '#A895FF', 'Kürsü Vitrini · 24 saat', v ? esc(v.aciklama) : '', kuyrukYazi(m.vitrin), v ? fiyat(v) : '', jeton('m2_vitrin') ? kullanDugme('vitrin', jeton('m2_vitrin') + ' hakkın var · Paylaşımını seç') : '');
    var ms = paket(d, 'secimonline.headline_24h');
    if (ms || jeton('m2_manset')) b += satir(I.megafon, '#F0454B', 'Gündem Manşeti · 24 saat', ms ? esc(ms.aciklama) : '', kuyrukYazi(m.manset), ms ? fiyat(ms) : '', jeton('m2_manset') ? kullanDugme('manset', jeton('m2_manset') + ' hakkın var · Manşetini yaz') : '');
    var mz = paket(d, 'secimonline.mandate');
    var zaf = (m.zaferler || []).filter(function (z) { return !z.mazbata; });
    if (mz || jeton('m2_mazbata')) b += satir(I.belge, '#F2C94C', 'Mazbata', mz ? esc(mz.aciklama) : '',
      jeton('m2_mazbata') ? (zaf.length ? 'Kazandığın seçim için mazbatanı oluşturabilirsin.' : 'Hakkın bekliyor; kazandığın ilk seçimde kendiliğinden hazırlanır.') : (m.zaferler || []).length ? 'Son 30 günde kazandığın seçim var.' : 'Seçim kazandığında alabilirsin; önceden alırsan kazandığın gece kendiliğinden hazırlanır.',
      mz ? fiyat(mz) : '', jeton('m2_mazbata') && zaf.length ? kullanDugme('mazbata', 'Mazbatamı oluştur') : (n(m.mazbata_sayi) ? kullanDugme('mazbatalarim', 'Mazbatalarım (' + n(m.mazbata_sayi) + ')') : ''));
    var kt = paket(d, 'secimonline.victory_night');
    if (kt || jeton('m2_kutlama')) b += satir(I.kupa, '#F2C94C', 'Seçim Gecesi Kutlaması', kt ? esc(kt.aciklama) : '',
      jeton('m2_kutlama') ? 'Kutlama hakkın hazır; kazandığın gece kendiliğinden kullanılır.' : '', kt ? fiyat(kt) : '');
    if (b) h += '<div class="bolum-bas"><h2>Seçim dönemi</h2><span class="kucuk">Tekrar tekrar alınır</span></div><div class="kart m2-bolum">' + b + '</div>';
    // Parti
    b = '';
    var pa = m.parti;
    var bg = paket(d, 'secimonline.party_donation');
    if (bg || jeton('m2_bagis')) b += satir(I.kalp, '#F2C94C', 'Parti Kasasına Bağış', bg ? esc(bg.aciklama) : '',
      pa ? esc(pa.ad) + ' kasasına ' + tl(m.bagis_tutar) + ' girer.' + (pa.bagisci_bitis ? ' Büyük Bağışçı unvanın ' + esc(trSaat(pa.bagisci_bitis)) + ' tarihine kadar.' : '') : 'Bağış için önce bir partiye üye olmalısın.',
      bg ? (pa ? fiyat(bg) : not('Önce bir partiye üye ol')) : '', jeton('m2_bagis') && pa ? kullanDugme('bekleyen', 'Bekleyen bağışımı partime aktar') : '');
    var gm = paket(d, 'secimonline.hq_campaign');
    if (gm || jeton('m2_gm')) {
      var gmDur = pa ? esc(pa.kisa) + ': ' + gmAd(n(pa.gm_seviye)) + ' · ' + n(pa.gm_katki) + ' katkı' + (pa.gm_sonraki ? ' · sıradaki seviyeye ' + (n(pa.gm_sonraki) - n(pa.gm_katki)) + ' katkı' : ' · en üst seviye') : 'Katkı için önce bir partiye üye olmalısın.';
      if (pa && !m.gm_hesap_tamam) gmDur += ' Katkı için hesabın en az ' + n(m.gm_hesap_gun) + ' günlük olmalı.';
      b += satir(I.bina, '#D3D6E0', 'Genel Merkez Kampanyası', gm ? esc(gm.aciklama) : '', gmDur,
        gm ? (pa && m.gm_hesap_tamam ? fiyat(gm) : not(pa ? n(m.gm_hesap_gun) + ' günlük hesap gerekir' : 'Önce bir partiye üye ol')) : '',
        (jeton('m2_gm') && pa && m.gm_hesap_tamam ? kullanDugme('bekleyen', 'Bekleyen katkımı aktar') : '') + (pa ? '<button type="button" class="btn ikinci m2-kullan" data-m2k="gm">Kampanya ve sıralama</button>' : ''));
    }
    var sh = paket(d, 'secimonline.launch_stage');
    if (sh || jeton('m2_sahne')) b += satir(I.sahne, '#F2C94C', 'Lansman Sahnesi', sh ? esc(sh.aciklama) : '',
      pa ? (pa.sahne ? esc(pa.kisa) + ' partisinde Lansman Sahnesi var.' : esc(pa.kisa) + ' partisine kalıcı olarak bağlanır.') : 'Önce bir partiye üye olmalısın.',
      sh ? (pa && !pa.sahne ? fiyat(sh) : not(pa ? 'Partinde var' : 'Önce bir partiye üye ol')) : '', jeton('m2_sahne') && pa && !pa.sahne ? kullanDugme('bekleyen', 'Bekleyen sahneyi partime uygula') : '');
    var kg = paket(d, 'secimonline.congress_pack');
    if (kg || jeton('m2_kongre') || (m.kongre && m.kongre.slogan)) b += satir(I.bayrak, '#F0454B', 'Kongre Paketi', kg ? esc(kg.aciklama) : '',
      m.kongre ? (m.kongre.slogan ? 'Afişindeki slogan: “' + esc(m.kongre.slogan) + '”' : 'Kurultay adaylığın var.') : (jeton('m2_kongre') ? 'Hakkın bekliyor; kurultaya aday olunca kendiliğinden uygulanır.' : 'Kurultaya aday olduğunda kullanılır; önceden alırsan aday olunca uygulanır.'),
      kg ? fiyat(kg) : '', m.kongre && m.kongre.slogan ? kullanDugme('kongre', 'Sloganı değiştir') : '');
    var pk = paket(d, 'secimonline.party_card_pack');
    if (pk || jeton('m2_parti_kart')) b += satir(I.kart, '#A895FF', 'Parti Kart Paketi', pk ? esc(pk.aciklama) : '',
      pa && pa.yonetici ? (jeton('m2_parti_kart') ? jeton('m2_parti_kart') + ' kart hakkın var.' : 'Partinin genel başkanı ya da yardımcısı olarak dağıtırsın.') : 'Yalnız genel başkan ve genel başkan yardımcıları dağıtabilir.',
      pk ? (pa && pa.yonetici ? fiyat(pk) : not('Yalnız GB/GBY')) : '', jeton('m2_parti_kart') && pa && pa.yonetici ? kullanDugme('partiKart', 'Üyeye kart ver') : '');
    var hk = paket(d, 'secimonline.gift_card_30d');
    if (hk || jeton('m2_hediye_kart')) b += satir(I.hediye, '#A895FF', 'Hediye Siyaset Kartı', hk ? esc(hk.aciklama) : '', jeton('m2_hediye_kart') ? jeton('m2_hediye_kart') + ' hediye hakkın var.' : '',
      hk ? fiyat(hk) : '', jeton('m2_hediye_kart') ? kullanDugme('hediye', 'Hediye et') : '');
    if (b) h += '<div class="bolum-bas"><h2>Parti ve hediye</h2><span class="kucuk">Oy, delege ya da makam vermez</span></div><div class="kart m2-bolum">' + b + '</div>';
    // Görünüş ve tanınma
    b = '';
    if (m.plaka_hak || paket(d, 'secimonline.vanity_plate') || paket(d, 'secimonline.vanity_plate_elite')) {
      var pl = m.plaka;
      b += satir(I.plaka, '#8fbeff', 'Özel Plakan', pl ? '' : 'Özel Plaka ya da Seçkin Plaka aldığında burada görünür.',
        pl ? plakaHtml(pl.metin, pl.makam, true) + (pl.makam ? ' <span class="m2-cip altin">Makam görünümü</span>' : '') + (pl.secildi ? '' : '<div class="kucuk" style="margin-top:6px">İlk plakanı seçmek ücretsiz.</div>') : '', '',
        m.plaka_hak ? kullanDugme('plaka', pl && pl.secildi ? 'Plakanı değiştir' + (jeton('plaka_degis') ? ' (' + jeton('plaka_degis') + ' hak)' : '') : 'Plakanı seç') : '');
    }
    ['bronze', 'silver', 'gold'].forEach(function (k, i) {
      var p = paket(d, 'secimonline.supporter_wall_' + k);
      if (p) b += satir(i === 2 ? I.taç : I.madalya, i === 2 ? '#F2C94C' : i === 1 ? '#D3D6E0' : '#D9A066', esc(p.ad), esc(p.aciklama), m.destek === i + 1 ? 'Bu ay bu kademedesin. Teşekkürler!' : '', fiyat(p));
    });
    if (b) h += '<div class="bolum-bas"><h2>Görünüş ve tanınma</h2><span class="kucuk">Oyun avantajı vermez</span></div><div class="kart m2-bolum">' + b + '</div>';
    var ym = (m.yayinlarim || []).filter(function (y) { return ['onay', 'sirada', 'yayinda'].indexOf(y.durum) >= 0; });
    if (ym.length) h += '<div class="bolum-bas"><h2>Vitrin ve manşetlerim</h2></div><div class="kart m2-bolum">' + ym.map(yayinSatir).join('') + '</div>';
    return h;
  };
  function yayinSatir(y) {
    var ad = y.tur === 'kursu' ? 'Kürsü Vitrini' : 'Gündem Manşeti';
    var dur = y.durum === 'onay' ? 'İncelemede' : y.durum === 'sirada' ? y.sira + '. sırada · tahmini yayın ' + esc(trSaat(y.tahmin)) : 'Yayında · bitiş ' + esc(trSaat(y.bit));
    return satir(y.tur === 'kursu' ? I.pin : I.megafon, y.tur === 'kursu' ? '#A895FF' : '#F0454B', ad, esc(y.tur === 'kursu' ? (y.metin || '') : (y.baslik || '')), dur, '',
      ['onay', 'sirada'].indexOf(y.durum) >= 0 ? '<button type="button" class="btn ikinci m2-kullan" data-m2iptal="' + n(y.id) + '">Geri çek (hakkın iade edilir)</button>' : '');
  }
  window.M2_MAGAZA_BAGLA = function () {
    var k = ic(); if (!k) return;
    k.querySelectorAll('[data-m2k]').forEach(function (b) { b.onclick = function () { kullan(b.getAttribute('data-m2k')); }; });
    k.querySelectorAll('[data-m2iptal]').forEach(function (b) {
      b.onclick = async function () {
        if (typeof onayla === 'function' && !(await onayla('Geri çek', 'Kaydı geri çekersen hakkın iade edilir. Sıradaki yerini kaybedersin.', 'Geri çek'))) return;
        b.disabled = true;
        try { await rpc('m2_yayin_iptal', { p_id: +b.getAttribute('data-m2iptal') }); bildir('Geri çekildi, hakkın iade edildi.'); magazaTazele(); } catch (err) { b.disabled = false; hata(err); }
      };
    });
  };
  function magazaTazele() {
    if (!window.MGZ || !window.MGZ.durumYukle) return;
    window.MGZ.durumYukle().then(function () { if (document.getElementById('mgEkran') && window.MGZ.magazaCiz) window.MGZ.magazaCiz(); });
  }
  window.M2_SATIN_SONRA = function (p) {
    if (!p) return;
    var esle = { 'secimonline.kursu_showcase_24h': 'vitrin', 'secimonline.headline_24h': 'manset', 'secimonline.gift_card_30d': 'hediye',
      'secimonline.party_card_pack': 'partiKart', 'secimonline.vanity_plate': 'plaka', 'secimonline.vanity_plate_elite': 'plaka', 'secimonline.plate_change': 'plaka' };
    if (esle[p.urun_id]) setTimeout(function () { kullan(esle[p.urun_id]); }, 400);
    if (p.urun_id === 'secimonline.victory_night' || p.urun_id === 'secimonline.mandate') setTimeout(kutlamaKontrol, 600);
  };
  function kullan(ne) {
    if (ne === 'vitrin') return vitrinModal();
    if (ne === 'manset') return mansetModal();
    if (ne === 'hediye') return kartVerModal(false);
    if (ne === 'partiKart') return kartVerModal(true);
    if (ne === 'plaka') return plakaModal();
    if (ne === 'mazbata') return mazbataOlusturModal();
    if (ne === 'mazbatalarim') return mazbataListeModal(null);
    if (ne === 'kongre') return kongreModal();
    if (ne === 'gm') return ekranAc(function () { gmEkrani(null); });
    if (ne === 'bekleyen') return bekleyenUygula();
  }
  async function bekleyenUygula() {
    try { await rpc('m2_bekleyen_uygula'); bildir('Bekleyen hakların uygulandı.'); magazaTazele(); } catch (err) { hata(err); }
  }

  /* ---------- Kürsü Vitrini: paylaşım seç ---------- */
  async function vitrinModal() {
    var p = profil(); if (!p) return;
    var md = modal('<h3>Kürsü Vitrini</h3><div class="yukleniyor">Paylaşımların yükleniyor…</div>');
    var liste = [];
    try { var r = await rpc('kursu_profil', { p_kad: p.kad, p_sekme: 'gonderi', p_imlec: null }); liste = (r && (r.liste || r.gonderiler)) || []; } catch (err) { hata(err); }
    liste = liste.map(function (x) { return x && x.g ? x.g : x; }).filter(function (g) { return g && g.id && !g.yanit_id && g.benim !== false; }).slice(0, 15);
    var q = (m2Durum() || {}).vitrin;
    var kap = md.querySelector('.modal');
    kap.innerHTML = '<div class="tutamak"></div><h3>Kürsü Vitrini · 24 saat</h3><p class="alt">Seçtiğin paylaşım akışın en üstünde "Öne çıkan" etiketiyle durur. ' + esc(kuyrukYazi(q)) + ' Sıradaysan yayına girdiğin anda bildirim alırsın.</p>' +
      (liste.length ? '<div class="m2-secim">' + liste.map(function (g) { return '<button type="button" data-akis="' + n(g.id) + '">' + esc(String(g.metin || '').slice(0, 180)) + '</button>'; }).join('') + '</div>'
        : '<div class="bos">Vitrine çıkarabileceğin bir Kürsü paylaşımın yok. Önce Kürsü\'de bir paylaşım yap.</div>') +
      '<p class="kucuk">Paylaşım kaldırılır ya da silinirse vitrinden çıkar; kurala aykırı içerikte hak iade edilmez. Seçim günü oy saatlerinde vitrin durur, süresi işlemez.</p>' +
      '<button type="button" class="btn altin" id="m2VitrinBas" disabled style="min-height:48px">Vitrine çıkar</button>';
    var secili = null;
    kap.querySelectorAll('[data-akis]').forEach(function (b) { b.onclick = function () { kap.querySelectorAll('[data-akis]').forEach(function (x) { x.classList.remove('on'); }); b.classList.add('on'); secili = +b.getAttribute('data-akis'); document.getElementById('m2VitrinBas').disabled = false; }; });
    var bas = document.getElementById('m2VitrinBas');
    bas.onclick = async function () {
      if (!secili) return; bas.disabled = true;
      try {
        var r = await rpc('kursu_vitrin_baslat', { p_akis: secili });
        modalKapat();
        bildir(r.durum === 'yayinda' ? 'Paylaşımın şu an vitrinde! 24 saat sürecek.' : 'Sıraya girdin (' + r.sira + '. sıra). Tahmini yayın: ' + trSaat(r.tahmin) + '.');
        if (window.KURSU_DURUM && window.KURSU_DURUM.akis) Object.keys(window.KURSU_DURUM.akis).forEach(function (k) { window.KURSU_DURUM.akis[k].t = 0; });
        magazaTazele();
      } catch (err) { bas.disabled = false; hata(err); }
    };
  }

  /* ---------- Gündem Manşeti: yaz ---------- */
  function mansetModal() {
    var m = m2Durum() || {}, pa = m.parti;
    var md = modal('<h3>Gündem Manşeti · 24 saat</h3><p class="alt">Manşetin İçerik Masası\'nın onayından sonra haber şeridinin başına çıkar. ' + esc(kuyrukYazi(m.manset)) +
      ' En geç ' + n((m.manset || {}).oto_saat || 12) + ' saat içinde incelenir; reddedilirse hakkın geri verilir.</p>' +
      '<div class="m2-alan"><label for="m2Manset">Manşet</label><textarea id="m2Manset" maxlength="120" rows="3" placeholder="Pazar günü Konya\'da büyük mitingimize herkesi bekliyoruz"></textarea><div class="m2-sayac" id="m2MansetSay">0 / 120</div></div>' +
      (pa && pa.parti_adina ? '<label style="display:flex;gap:10px;align-items:center;font-size:15px;margin:6px 0 10px;min-height:44px"><input type="checkbox" id="m2PartiAdina" style="width:22px;height:22px"> ' + esc(pa.ad) + ' adına yayınla</label>' : '') +
      '<p class="kucuk">Bağlantı, hakaret ve yasaklı ifade içeren manşetler reddedilir. Seçim günü oy saatlerinde manşet durur.</p>' +
      '<button type="button" class="btn altin" id="m2MansetGonder" style="min-height:48px">İncelemeye gönder</button>');
    var t = md.querySelector('#m2Manset'), say = md.querySelector('#m2MansetSay');
    t.oninput = function () { say.textContent = t.value.length + ' / 120'; };
    var b = md.querySelector('#m2MansetGonder');
    b.onclick = async function () {
      var v = t.value.trim();
      if (v.length < 10) { bildir('Manşet en az 10 karakter olmalı.', true); return; }
      b.disabled = true;
      try {
        await rpc('manset_basvur', { p_baslik: v, p_parti_adina: !!(md.querySelector('#m2PartiAdina') || {}).checked });
        modalKapat(); bildir('Manşetin incelemeye gönderildi. Onaylanınca sıraya girer ve haber alırsın.'); magazaTazele();
      } catch (err) { b.disabled = false; hata(err); }
    };
  }

  /* ---------- Hediye / Parti kartı ---------- */
  function kartVerModal(parti) {
    var md = modal('<h3>' + (parti ? 'Üyeye Parti Kartı ver' : 'Siyaset Kartı hediye et') + '</h3><p class="alt">' +
      (parti ? 'Kart alan üye hemen 30.000 ₺ ve 30 gün boyunca her gün Kart ödülü alır. Aynı üyeye 30 günde bir parti kartı verilebilir. Kalan hakkın: ' + jeton('m2_parti_kart') + '.'
        : 'Hediye alan oyuncu hemen 30.000 ₺ ve 30 gün boyunca her gün Kart ödülü alır. Hediyen alana bildirilir ve Türkiye sohbetine duyurulur.') + '</p>' +
      '<div class="m2-alan"><label for="m2Kad">Oyuncunun kullanıcı adı</label><input id="m2Kad" maxlength="30" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="kullanıcı adı"></div>' +
      (parti ? '' : '<div class="m2-alan"><label for="m2Not">Notun (isteğe bağlı)</label><input id="m2Not" maxlength="120" placeholder="Hayırlı olsun!"></div>') +
      '<button type="button" class="btn altin" id="m2KartVer" style="min-height:48px">' + (parti ? 'Kartı ver' : 'Hediye et') + '</button>');
    var b = md.querySelector('#m2KartVer');
    b.onclick = async function () {
      var kad = md.querySelector('#m2Kad').value.trim(); if (!kad) { bildir('Kullanıcı adını yaz.', true); return; }
      b.disabled = true;
      try {
        var r = parti ? await rpc('parti_kart_ver', { p_kad: kad }) : await rpc('hediye_kart_ver', { p_kad: kad, p_not: (md.querySelector('#m2Not') || {}).value || null });
        modalKapat(); bildir((parti ? 'Kart verildi: ' : 'Hediyen gitti: ') + r.alan + (r.kalan ? ' · kalan hakkın ' + r.kalan : '')); magazaTazele();
      } catch (err) { b.disabled = false; hata(err); }
    };
  }

  /* ---------- Plaka ---------- */
  function plakaModal() {
    var m = m2Durum() || {}, pl = m.plaka || {};
    var il = n(pl.il) || n(m.il) || 6;
    var md = modal('<h3>Özel plakan</h3><p class="alt">Standart plakada 2–3 harf ve 100–9999 arası numara olur (örneğin 35 AY 1923).' +
      (m.seckin_hak ? ' Seçkin Plakan olduğu için tek harfli ya da 01–99 numaralı plaka da seçebilirsin (örneğin 06 K 07).' : ' Tek harfli ya da 01–99 numaralı plakalar Seçkin Plaka ister.') +
      ' Ç, Ğ, İ, Ö, Ş, Ü, Q, W ve X kullanılmaz. ' + (pl.secildi ? 'Değiştirmek bir Plaka Değiştirme hakkı harcar (' + jeton('plaka_degis') + ' hakkın var).' : 'İlk seçimin ücretsiz.') + '</p>' +
      '<div class="m2-onizle" id="m2PlOn">' + plakaHtml(pl.metin || '', pl.makam, true) + '</div>' +
      '<div class="m2-plaka-form"><div class="m2-alan"><label for="m2PlIl">İl</label><select id="m2PlIl">' + Array.from({ length: 81 }, function (_, i) { var k = i + 1; return '<option value="' + k + '"' + (k === il ? ' selected' : '') + '>' + String(k).padStart(2, '0') + '</option>'; }).join('') + '</select></div>' +
      '<div class="m2-alan"><label for="m2PlH">Harf</label><input id="m2PlH" maxlength="3" autocomplete="off" autocapitalize="characters" value="' + esc(pl.harf || '') + '"></div>' +
      '<div class="m2-alan"><label for="m2PlR">Numara</label><input id="m2PlR" maxlength="4" inputmode="numeric" autocomplete="off" value="' + esc(pl.rakam || '') + '"></div></div>' +
      '<button type="button" class="btn altin" id="m2PlKaydet" style="min-height:48px">Plakamı kaydet</button>');
    function on() {
      var h = md.querySelector('#m2PlH').value.toUpperCase().replace(/[^A-Z]/g, ''), r = md.querySelector('#m2PlR').value.replace(/\D/g, '');
      md.querySelector('#m2PlH').value = h; md.querySelector('#m2PlR').value = r;
      md.querySelector('#m2PlOn').innerHTML = plakaHtml(String(md.querySelector('#m2PlIl').value).padStart(2, '0') + ' ' + (h || '…') + ' ' + (r || '…'), pl.makam, true);
    }
    ['#m2PlIl', '#m2PlH', '#m2PlR'].forEach(function (s) { md.querySelector(s).oninput = on; md.querySelector(s).onchange = on; });
    var b = md.querySelector('#m2PlKaydet');
    b.onclick = async function () {
      b.disabled = true;
      try {
        var r = await rpc('plaka_kaydet', { p_il: +md.querySelector('#m2PlIl').value, p_harf: md.querySelector('#m2PlH').value, p_rakam: md.querySelector('#m2PlR').value });
        modalKapat(); bildir('Plakan: ' + r.plaka);
        if (window.MGZ) { window.MGZ.rozetZaman = 0; }
        magazaTazele();
      } catch (err) { b.disabled = false; hata(err); }
    };
  }

  /* ---------- Kongre sloganı ---------- */
  function kongreModal() {
    var m = m2Durum() || {}, k = m.kongre || {};
    var md = modal('<h3>Kongre afişi</h3><p class="alt">Afişin kurultay oy pusulasında ve aday listesinde adının yanında görünür.</p>' +
      '<div class="m2-alan"><label for="m2Slogan">Slogan</label><input id="m2Slogan" maxlength="40" value="' + esc(k.slogan || '') + '" placeholder="Yeniden büyük parti"></div>' +
      '<button type="button" class="btn altin" id="m2SloganK" style="min-height:48px">Kaydet</button>');
    var b = md.querySelector('#m2SloganK');
    b.onclick = async function () {
      b.disabled = true;
      try { await rpc('kongre_slogan', { p_slogan: md.querySelector('#m2Slogan').value }); modalKapat(); bildir('Sloganın güncellendi.'); magazaTazele(); } catch (err) { b.disabled = false; hata(err); }
    };
  }

  /* ---------- Mazbata ---------- */
  function mazbataHtml(z) {
    var oran = z.oy_orani != null ? '%' + String(z.oy_orani).replace('.', ',') : '—';
    var tar = z.tarih ? new Date(z.tarih).toLocaleDateString('tr-TR', { timeZone: 'Europe/Istanbul' }) : '';
    return '<div class="m2-mazbata"><div class="m2-mazbata-ic"><div class="ust">SEÇİM SİMÜLASYONU ONLINE · SEÇİM KURULU</div><h4>MAZBATA</h4>' +
      '<div style="width:60px;height:1px;background:#B08D3C;margin:6px auto 8px"></div><div style="font-size:12.5px">' + esc(z.donem || '') + ' seçiminde</div>' +
      '<div class="ad">' + esc(z.ad) + '</div><div style="font-size:13px">' + esc(z.gorev) + ' seçilmiştir.</div>' +
      '<div class="alt2"><div style="text-align:left">Oy oranı<br><b style="color:#1B2140;font-size:13px">' + esc(oran) + '</b></div><div class="m2-muhur">SSO<br>MÜHÜR</div>' +
      '<div style="text-align:right">Tarih<br><b style="color:#1B2140;font-size:13px">' + esc(tar) + '</b></div></div><div class="dip">Oyun içi belgedir</div></div></div>';
  }
  async function mazbataListeModal(kad) {
    var md = modal('<h3>Mazbatalar</h3><div class="yukleniyor">Yükleniyor…</div>');
    try {
      var l = await rpc('mazbatalar', { p_kad: kad || null });
      md.querySelector('.modal').innerHTML = '<div class="tutamak"></div><h3>Mazbatalar</h3>' + (l.length ? l.map(function (z, i) {
        return mazbataHtml(z) + (!kad ? '<button type="button" class="btn ikinci" data-paylas="' + i + '" style="min-height:44px">' + I.paylas.replace('<svg', '<svg style="width:16px;height:16px;vertical-align:-3px;margin-right:6px"') + 'Görsel olarak paylaş</button>' : '');
      }).join('') : '<div class="bos">Henüz mazbata yok.</div>');
      md.querySelectorAll('[data-paylas]').forEach(function (b) { b.onclick = function () { mazbataPaylas(l[+b.getAttribute('data-paylas')]); }; });
    } catch (err) { md.querySelector('.modal').innerHTML = '<div class="bos">' + esc(hataMetni(err)) + '</div>'; }
  }
  async function mazbataOlusturModal() {
    var m = m2Durum() || {}, z = (m.zaferler || []).filter(function (x) { return !x.mazbata; });
    if (!z.length) { bildir('Son 30 günde mazbatası alınmamış bir zaferin yok.', true); return; }
    var md = modal('<h3>Mazbatanı oluştur</h3><p class="alt">Hangi seçim için?</p><div class="m2-secim">' + z.map(function (x) {
      return '<button type="button" data-secim="' + n(x.secim_id) + '">' + esc(x.gorev) + ' · ' + esc(trSaat(x.tarih)) + '</button>';
    }).join('') + '</div>');
    md.querySelectorAll('[data-secim]').forEach(function (b) {
      b.onclick = async function () {
        b.disabled = true;
        try { await rpc('mazbata_olustur', { p_secim: +b.getAttribute('data-secim') }); modalKapat(); bildir('Mazbatan hazır.'); magazaTazele(); mazbataListeModal(null); } catch (err) { b.disabled = false; hata(err); }
      };
    });
  }
  function mazbataPaylas(z) {
    try {
      var c = document.createElement('canvas'), W = 1080, H = 1350; c.width = W; c.height = H;
      var x = c.getContext('2d');
      x.fillStyle = '#0E1530'; x.fillRect(0, 0, W, H);
      x.fillStyle = '#F4F6FB'; x.fillRect(80, 120, W - 160, H - 300);
      x.strokeStyle = '#B08D3C'; x.lineWidth = 8; x.strokeRect(110, 150, W - 220, H - 360);
      x.textAlign = 'center'; x.fillStyle = '#6E5A2B'; x.font = '700 30px sans-serif'; x.fillText('SEÇİM SİMÜLASYONU ONLINE · SEÇİM KURULU', W / 2, 240);
      x.fillStyle = '#1B2140'; x.font = '800 96px serif'; x.fillText('MAZBATA', W / 2, 360);
      x.fillStyle = '#B08D3C'; x.fillRect(W / 2 - 110, 395, 220, 4);
      x.fillStyle = '#1B2140'; x.font = '500 38px sans-serif'; x.fillText((z.donem || '') + ' seçiminde', W / 2, 500);
      x.font = '800 66px sans-serif'; x.fillText(String(z.ad || ''), W / 2, 600);
      x.font = '500 40px sans-serif'; x.fillText(String(z.gorev || '') + ' seçilmiştir.', W / 2, 670);
      x.textAlign = 'left'; x.fillStyle = '#4A5272'; x.font = '500 30px sans-serif'; x.fillText('Oy oranı', 170, 880);
      x.fillStyle = '#1B2140'; x.font = '800 44px sans-serif'; x.fillText(z.oy_orani != null ? '%' + String(z.oy_orani).replace('.', ',') : '—', 170, 935);
      x.textAlign = 'right'; x.fillStyle = '#4A5272'; x.font = '500 30px sans-serif'; x.fillText('Tarih', W - 170, 880);
      x.fillStyle = '#1B2140'; x.font = '800 44px sans-serif'; x.fillText(z.tarih ? new Date(z.tarih).toLocaleDateString('tr-TR', { timeZone: 'Europe/Istanbul' }) : '', W - 170, 935);
      x.save(); x.translate(W / 2, 900); x.rotate(-0.2); x.strokeStyle = '#B03A2E'; x.lineWidth = 6; x.beginPath(); x.arc(0, 0, 70, 0, Math.PI * 2); x.stroke();
      x.fillStyle = '#B03A2E'; x.textAlign = 'center'; x.font = '800 26px sans-serif'; x.fillText('SSO', 0, -4); x.fillText('MÜHÜR', 0, 28); x.restore();
      x.textAlign = 'center'; x.fillStyle = '#8A90A8'; x.font = '500 24px sans-serif'; x.fillText('Oyun içi belgedir', W / 2, 1110);
      x.fillStyle = '#EEF1F8'; x.font = '800 40px sans-serif'; x.fillText('Seçim Simülasyonu Online', W / 2, 1250);
      c.toBlob(async function (blob) {
        if (!blob) return;
        var dosya = null; try { dosya = new File([blob], 'mazbata.png', { type: 'image/png' }); } catch (e) {}
        if (dosya && navigator.canShare && navigator.canShare({ files: [dosya] })) {
          try { await navigator.share({ files: [dosya], title: 'Mazbatam', text: (z.ad || '') + ' · ' + (z.gorev || '') + ' — Seçim Simülasyonu Online' }); return; } catch (e) { if (e && e.name === 'AbortError') return; }
        }
        var url = URL.createObjectURL(blob);
        modal('<h3>Mazbata görseli</h3><p class="alt">Görsele basılı tutup kaydedebilir ya da indirip X ve Instagram\'da paylaşabilirsin.</p><img src="' + url + '" alt="Mazbata" style="width:100%;border-radius:10px">' +
          '<a class="btn altin" href="' + url + '" download="mazbata.png" style="display:block;text-align:center;margin-top:10px;min-height:48px;line-height:28px">Görseli indir</a>');
      }, 'image/png');
    } catch (err) { hata(err); }
  }

  /* ---------- Genel Merkez ---------- */
  function binaSvg(s, boy) {
    boy = boy || 200;
    var h = '<svg viewBox="0 0 200 96" width="' + boy + '" height="' + Math.round(boy * 0.48) + '" aria-hidden="true"><rect x="0" y="88" width="200" height="8" fill="#283563"/>';
    if (s <= 0) return h + '<rect x="60" y="70" width="80" height="18" fill="none" stroke="#4A5A8C" stroke-dasharray="4 4"/><text x="100" y="62" text-anchor="middle" fill="#6E7A9C" font-size="12">Arsa</text></svg>';
    if (s === 1) return h + '<rect x="70" y="46" width="60" height="42" fill="#2B4FB8"/><polygon points="62,46 100,24 138,46" fill="#3B5FCC"/><rect x="92" y="66" width="16" height="22" fill="#11162C"/><g fill="#F2C94C"><rect x="77" y="54" width="9" height="9"/><rect x="114" y="54" width="9" height="9"/></g></svg>';
    if (s === 2) return h + '<rect x="60" y="34" width="80" height="54" fill="#2B4FB8"/><rect x="52" y="28" width="96" height="8" fill="#3B5FCC"/><rect x="99" y="8" width="2" height="20" fill="#C9D1E6"/><rect x="101" y="8" width="12" height="7" fill="#F0454B"/>' +
      '<g fill="#F2C94C"><rect x="68" y="44" width="10" height="10"/><rect x="85" y="44" width="10" height="10"/><rect x="105" y="44" width="10" height="10"/><rect x="122" y="44" width="10" height="10"/><rect x="68" y="62" width="10" height="10"/><rect x="122" y="62" width="10" height="10"/></g><rect x="90" y="66" width="20" height="22" fill="#11162C"/></svg>';
    return h + '<rect x="20" y="50" width="34" height="38" fill="#1F3E9A"/><rect x="146" y="50" width="34" height="38" fill="#1F3E9A"/><rect x="62" y="22" width="76" height="66" fill="#2B4FB8"/><rect x="86" y="6" width="28" height="16" fill="#3B5FCC"/><rect x="99" y="0" width="2" height="8" fill="#C9D1E6"/>' +
      '<g fill="#F2C94C"><rect x="70" y="30" width="10" height="9"/><rect x="88" y="30" width="10" height="9"/><rect x="104" y="30" width="10" height="9"/><rect x="120" y="30" width="10" height="9"/><rect x="70" y="48" width="10" height="9"/><rect x="120" y="48" width="10" height="9"/><rect x="28" y="60" width="8" height="7"/><rect x="164" y="60" width="8" height="7"/></g><rect x="90" y="66" width="20" height="22" fill="#11162C"/></svg>';
  }
  function gmKartHtml(g, kendi) {
    var s = n(g.seviye), son = n(g.sonraki), k = n(g.katki), onceki = s > 0 ? n((g.esik || [])[s - 1]) : 0;
    var oran = son ? Math.max(0, Math.min(100, Math.round((k - onceki) * 100 / Math.max(1, son - onceki)))) : 100;
    return '<div class="m2-gm"><div class="m2-gm-gor">' + binaSvg(s) + '</div><div class="m2-gm-ic">' +
      '<div style="display:flex;justify-content:space-between;align-items:center;gap:8px"><h3>' + esc((g.parti || {}).kisa || '') + ' Genel Merkez Kampanyası</h3><span class="m2-cip ' + (s === 3 ? 'altin' : s === 2 ? 'gumus' : 'bronz') + '">' + gmAd(s) + '</span></div>' +
      '<div class="kucuk" style="margin-top:2px">' + (son ? 'Sıradaki: ' + esc(g.sonraki_ad) : 'En üst seviyeye ulaşıldı') + '</div>' +
      '<div class="m2-cubuk"><i style="width:' + oran + '%"></i></div><div class="kucuk" style="display:flex;justify-content:space-between"><span>' + k + (son ? ' / ' + son : '') + ' katkı</span><span>' + (son ? (son - k) + ' katkı kaldı' : '') + '</span></div>' +
      (kendi ? '<div class="kucuk" style="margin-top:6px">Her katkı parti kasasına ' + tl(g.tutar) + ' koyar. Seviyeler bütün üyelere rozet verir; oy, makam ya da seçim gücü vermez.</div>' : '') +
      '<button type="button" class="btn ikinci" data-m2gm="' + n((g.parti || {}).id) + '" style="margin-top:10px;min-height:44px">Kampanya ve sıralama</button></div></div>';
  }
  async function gmEkrani(pid) {
    if (typeof iskelet === 'function') iskelet('Genel Merkez', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    try {
      var g = await rpc('genel_merkez', { p_parti: pid || null });
      var d = mgDurum(), urun = paket(d, 'secimonline.hq_campaign');
      var h = gmKartHtml(g, true).replace(/<button type="button" class="btn ikinci" data-m2gm[^>]*>[^<]*<\/button>/, '');
      if (g.uyesiyim && urun) h += '<div class="kart"><b>Katkı ver</b><div class="kucuk" style="margin:4px 0 8px">' + (g.katki_verebilir ? 'Mağaza\'dan Genel Merkez Kampanyası satın alarak katkı verirsin.' : 'Katkı için hesabın en az ' + n(g.hesap_gun) + ' günlük olmalı.') + '</div><button type="button" class="btn altin" onclick="ekranAc(magazaEkrani)" style="min-height:44px">Mağaza\'ya git</button></div>';
      h += '<div class="kart"><h2>En çok katkı verenler</h2>' + ((g.liste || []).length ? g.liste.map(function (x, i) {
        return '<div class="kv"><span class="k">' + (i === 0 ? I.taç.replace('<svg', '<svg style="width:15px;height:15px;color:#F2C94C;vertical-align:-2px;margin-right:4px"') : '') + esc(x.ad) + '</span><span class="v">' + n(x.adet) + ' katkı</span></div>';
      }).join('') : '<div class="kucuk">Henüz katkı yok. İlk katkıyı sen ver.</div>') + '</div>';
      h += '<div class="kart"><h2>Partiler sıralaması</h2>' + (g.siralama || []).map(function (x, i) {
        return '<div class="kv"><span class="k"><b>' + (i + 1) + '.</b> <span style="color:' + esc(x.renk) + '">' + esc(x.kisa) + '</span> <span class="kucuk">· ' + n(x.katki) + ' katkı</span></span><span class="v"><span class="m2-cip ' + (x.seviye === 3 ? 'altin' : x.seviye === 2 ? 'gumus' : 'bronz') + '">' + gmAd(n(x.seviye)) + '</span></span></div>';
      }).join('') + '</div>';
      if (typeof iskelet === 'function') iskelet('Genel Merkez', h, { geri: true });
    } catch (err) { if (typeof iskelet === 'function') iskelet('Genel Merkez', '<div class="bos">' + esc(hataMetni(err)) + '</div>', { geri: true }); }
  }
  window.genelMerkezEkrani = gmEkrani;

  /* ---------- Parti sayfası: Genel Merkez kartı ---------- */
  function partiSar() {
    if (typeof partiDetay !== 'function' || partiDetay._m2) return;
    var eski = partiDetay;
    var yeni = async function (id) {
      var r = await eski.apply(this, arguments);
      try {
        var g = await rpc('genel_merkez', { p_parti: id });
        var k = ic(); if (!k || !g || !g.parti) return r;
        // Ürün mağazada açık değilse ve hiç katkı yoksa kart gösterilmez (oyuncu katkı veremeyeceği bir kampanya görmesin)
        if (!n(g.katki) && !(g.uyesiyim && paket(mgDurum(), 'secimonline.hq_campaign'))) return r;
        var ilk = k.querySelector('.kart');
        var kap = document.createElement('div'); kap.innerHTML = gmKartHtml(g, false);
        if (ilk && ilk.nextSibling) ilk.parentNode.insertBefore(kap.firstChild, ilk.nextSibling); else k.appendChild(kap.firstChild);
        var b = k.querySelector('[data-m2gm]'); if (b) b.onclick = function () { ekranAc(function () { gmEkrani(id); }); };
      } catch (e) {}
      return r;
    };
    yeni._m2 = true;
    window.partiDetay = partiDetay = yeni;
  }

  /* ---------- Profil ve oyuncu kartı ---------- */
  function iskeletSar() {
    if (typeof iskelet !== 'function' || iskelet._m2) return;
    var eski = iskelet;
    var yeni = function (baslik, govde, opt) {
      var r = eski.apply(this, arguments);
      try {
        if (baslik === 'Gündem') setTimeout(gundemSus, 0);
        if (baslik === 'Profilim') setTimeout(profilSus, 0);
      } catch (e) {}
      return r;
    };
    yeni._m2 = true;
    window.iskelet = iskelet = yeni;
  }
  async function profilSus() {
    var k = ic(), p = profil(); if (!k || !p || document.getElementById('m2Profil')) return;
    var m = m2Durum(); var l = [];
    try { l = await rpc('mazbatalar', { p_kad: null }); } catch (e) { return; }
    var pl = m && m.plaka, kg = m && m.kongre && m.kongre.slogan;
    if (!l.length && !pl && !kg) return;
    var h = '<div class="kart" id="m2Profil">' + (kg ? kongreAfis(kg) + '<div class="kucuk" style="margin:4px 0 10px">Kurultay bitene kadar sohbette adının yanında ve profilinde görünür; oy pusulasında ayrıcalık yoktur.</div>' : '') + (pl ? '<div style="display:flex;align-items:center;gap:10px;justify-content:space-between"><b>Plakam</b>' + plakaHtml(pl.metin, pl.makam, true) + '</div>' : '') +
      (l.length ? '<div style="margin-top:' + (pl ? '10px' : '0') + '"><b>Mazbatalarım</b>' + mazbataHtml(l[0]) + '<button type="button" class="btn ikinci" id="m2MazTum" style="min-height:44px">' + (l.length > 1 ? 'Bütün mazbatalarım (' + l.length + ')' : 'Paylaş') + '</button></div>' : '') + '</div>';
    var ilk = k.querySelector('.kart'); if (ilk) ilk.insertAdjacentHTML('afterend', h); else k.insertAdjacentHTML('afterbegin', h);
    var b = document.getElementById('m2MazTum'); if (b) b.onclick = function () { if (l.length > 1) mazbataListeModal(null); else mazbataPaylas(l[0]); };
  }
  function kartSar() {
    if (typeof oyuncuKart !== 'function' || oyuncuKart._m2) return;
    var eski = oyuncuKart;
    var yeni = async function (kad) {
      var r = await eski.apply(this, arguments);
      try {
        var kgT = rozetListe(kad).find(function (x) { return x.indexOf('kg:') === 0; });
        var md0 = document.querySelector('#modal .modal');
        if (kgT && md0 && !md0.querySelector('[data-m2kongre]')) {
          var tut = md0.querySelector('.tutamak');
          if (tut) tut.insertAdjacentHTML('afterend', kongreAfis(kgT.slice(3))); else md0.insertAdjacentHTML('afterbegin', kongreAfis(kgT.slice(3)));
          if (!M2.kongreSes[kad]) { M2.kongreSes[kad] = 1; alkis(1.3); }
        }
        var l = await rpc('mazbatalar', { p_kad: kad });
        var md = document.querySelector('#modal .modal');
        if (md && l && l.length && !md.querySelector('[data-m2maz]')) {
          md.insertAdjacentHTML('beforeend', '<button type="button" class="btn ikinci" data-m2maz="1" style="min-height:44px;margin-top:10px">' + I.belge.replace('<svg', '<svg style="width:16px;height:16px;vertical-align:-3px;margin-right:6px"') + 'Mazbataları (' + l.length + ')</button>');
          md.querySelector('[data-m2maz]').onclick = function () { mazbataListeModal(kad); };
        }
      } catch (e) {}
      return r;
    };
    yeni._m2 = true;
    window.oyuncuKart = oyuncuKart = yeni;
  }

  /* ---------- Kongre Paketi: yalnız kurultay süresince sohbette ve profilde (oy pusulasında ayrıcalık YOK) ---------- */
  var BAYRAK = '<svg viewBox="0 0 120 60" aria-hidden="true"><rect width="120" height="60" fill="#E30A17"/><circle cx="46" cy="30" r="14" fill="#fff"/><circle cx="50" cy="30" r="11.2" fill="#E30A17"/><polygon points="62,30 71.3,27 65.6,34.9 65.6,25.1 71.3,33" fill="#fff"/></svg>';
  function kongreAfis(slogan) {
    return '<div class="m2-kongre" data-m2kongre="1"><div class="m2-kongre-bayrak">' + BAYRAK + '</div><div class="m2-kongre-afis">' + I.bayrak.replace('<svg', '<svg style="width:15px;height:15px"') +
      '<span style="flex:1">' + esc(String(slogan || '').toLocaleUpperCase('tr')) + '</span><span style="font-size:10.5px;color:#C9D1E6;font-weight:700">Genel başkan adayı</span></div></div>';
  }
  // Kısa alkış sesi (sentezlenmiş; dosya indirmez)
  function alkis(sure) {
    try {
      var AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
      var ctx = new AC(), t0 = ctx.currentTime, adet = Math.round((sure || 1.2) * 18);
      for (var i = 0; i < adet; i++) {
        var buf = ctx.createBuffer(1, Math.floor(ctx.sampleRate * 0.03), ctx.sampleRate), d = buf.getChannelData(0);
        for (var j = 0; j < d.length; j++) d[j] = (Math.random() * 2 - 1) * Math.exp(-j / (d.length / 5));
        var s = ctx.createBufferSource(), g = ctx.createGain(), f = ctx.createBiquadFilter();
        f.type = 'bandpass'; f.frequency.value = 1200 + Math.random() * 1800; s.buffer = buf;
        g.gain.value = 0.18 * (1 - i / adet * 0.6);
        s.connect(f); f.connect(g); g.connect(ctx.destination);
        s.start(t0 + Math.random() * (sure || 1.2));
      }
      setTimeout(function () { try { ctx.close(); } catch (e) {} }, ((sure || 1.2) + 1) * 1000);
    } catch (e) {}
  }

  /* ---------- Lansman Sahnesi ---------- */
  function sahneSus() {
    var el = document.getElementById('avLansman'); if (!el || el.classList.contains('m2-sahne-on')) return;
    var pid = M2.lansmanParti[+el.getAttribute('data-id')]; if (!pid) return;
    genelYukle().then(function (g) {
      if (!g || (g.sahne || []).map(String).indexOf(String(pid)) < 0) return;
      var e2 = document.getElementById('avLansman'); if (!e2 || e2.classList.contains('m2-sahne-on')) return;
      e2.classList.add('m2-sahne-on');
      var lamba = sv('<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.8.7 1 1.5 1 2.5h6c0-1 .2-1.8 1-2.5A6 6 0 0 0 12 3z"/>');
      e2.insertAdjacentHTML('afterbegin', '<div class="m2-isiklar" aria-hidden="true">' + lamba + lamba + lamba + lamba + '</div>');
      var h2 = e2.querySelector('h2'), renk = getComputedStyle(e2).getPropertyValue('--lk') || '#7B61FF';
      if (h2) h2.insertAdjacentHTML('afterend', '<div style="text-align:center"><div class="m2-poster" style="background:' + esc(renk.trim() || '#7B61FF') + '"><small>LANSMAN SAHNESİ</small><b>' + esc(h2.textContent) + '</b></div></div>');
    });
  }
  document.addEventListener('click', function (ev) {
    var b = ev.target && ev.target.closest && ev.target.closest('.m2-sahne-on ~ * [data-alkis], #icerik [data-alkis]');
    if (b && document.querySelector('#avLansman.m2-sahne-on')) konfeti(60);
  }, true);

  /* ---------- Konfeti ve zafer sahnesi ---------- */
  function konfeti(adet) {
    try {
      if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
      var k = document.createElement('div'); k.className = 'm2-konfeti';
      var renk = ['#F0454B', '#F2C94C', '#34C98A', '#A895FF', '#FFFFFF', '#8fbeff'];
      for (var i = 0; i < (adet || 80); i++) {
        var p = document.createElement('i');
        p.style.left = Math.random() * 100 + '%'; p.style.background = renk[i % renk.length];
        p.style.animationDuration = (2.2 + Math.random() * 1.8) + 's'; p.style.animationDelay = (Math.random() * 0.6) + 's';
        p.style.transform = 'rotate(' + Math.round(Math.random() * 360) + 'deg)';
        k.appendChild(p);
      }
      document.body.appendChild(k); setTimeout(function () { k.remove(); }, 4800);
    } catch (e) {}
  }
  function kutlamaKontrol() {
    var m = m2Durum(); var z = m && m.kutlama_bekleyen; if (!z || document.querySelector('.m2-zafer')) return;
    var oran = z.oy_orani != null ? ' · %' + String(z.oy_orani).replace('.', ',') : '';
    var d = document.createElement('div'); d.className = 'm2-zafer';
    d.innerHTML = '<div class="m2-zafer-k">' + I.kupa + '<h2>Tebrikler, kazandın</h2><div class="kucuk">' + esc(z.gorev) + oran + '</div>' +
      '<div style="margin-top:10px"><span class="m2-cip altin">' + esc(z.rozet) + '</span></div><p class="kucuk" style="margin-top:10px">Türkiye sohbetine tebrik kartın düştü; zafer rozetin profilinde.</p>' +
      '<button type="button" class="btn altin" id="m2ZaferTamam" style="min-height:48px">Teşekkürler</button></div>';
    document.body.appendChild(d); konfeti(120); alkis(2);
    d.querySelector('#m2ZaferTamam').onclick = function () { d.remove(); rpc('kutlama_goruldu', { p_id: z.id }).catch(function () {}); if (m) m.kutlama_bekleyen = null; };
  }

  /* ---------- Manşet onayı (İçerik Masası) ---------- */
  async function mansetOnayEkrani() {
    if (typeof iskelet === 'function') iskelet('Manşet onayı', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    try {
      var r = await rpc('manset_onay_liste');
      var h = '<div class="kart"><p class="alt" style="margin:0">Onay bekleyen manşetler. ' + n(r.oto_saat) + ' saat içinde karar verilmezse süzgeçten geçen manşet kendiliğinden onaylanır. Ret gerekçesi oyuncuya iletilir ve hakkı iade edilir.</p></div>';
      h += (r.onay || []).length ? r.onay.map(function (y) {
        return '<div class="kart"><b style="font-size:16px;line-height:1.35;display:block;overflow-wrap:anywhere">' + esc(y.baslik) + '</b><div class="kucuk" style="margin:4px 0 8px">' + esc(y.parti ? y.parti.ad + ' adına · ' : '') + esc(y.ad) + ' (' + esc(y.kad) + ') · ' + esc(trSaat(y.olusturma)) + '</div>' +
          '<button type="button" class="btn altin" data-onay="' + n(y.id) + '" style="min-height:44px">Onayla</button><button type="button" class="btn ikinci" data-ret="' + n(y.id) + '" style="min-height:44px">Reddet</button></div>';
      }).join('') : '<div class="kart"><div class="bos">Onay bekleyen manşet yok.</div></div>';
      h += '<div class="bolum-bas"><h2>Yayındaki ve sıradaki vitrin/manşetler</h2></div>' + ((r.aktif || []).length ? r.aktif.map(function (y) {
        return '<div class="kart"><span class="m2-cip ' + (y.tur === 'kursu' ? 'mor' : 'bronz') + '">' + (y.tur === 'kursu' ? 'Kürsü Vitrini' : 'Manşet') + ' · ' + (y.durum === 'yayinda' ? 'yayında' : y.sira + '. sırada') + '</span>' +
          '<div style="margin:6px 0;font-size:15px;overflow-wrap:anywhere">' + esc(y.tur === 'kursu' ? y.metin : y.baslik) + '</div><div class="kucuk">' + esc(y.ad) + ' (' + esc(y.kad) + ')</div>' +
          '<button type="button" class="btn ikinci" data-kaldir="' + n(y.id) + '" style="min-height:44px;color:#ff8a8a">Kurala aykırı: kaldır</button></div>';
      }).join('') : '<div class="kart"><div class="kucuk">Şu an yayında ya da sırada kayıt yok.</div></div>');
      if (typeof iskelet === 'function') iskelet('Manşet onayı', h, { geri: true });
      var k = ic(); if (!k) return;
      k.querySelectorAll('[data-onay]').forEach(function (b) { b.onclick = async function () { b.disabled = true; try { await rpc('manset_karar', { p_id: +b.getAttribute('data-onay'), p_onay: true, p_gerekce: null }); bildir('Onaylandı.'); M2.genelT = 0; mansetOnayEkrani(); } catch (err) { b.disabled = false; hata(err); } }; });
      k.querySelectorAll('[data-ret]').forEach(function (b) { b.onclick = function () { gerekceModal('Manşeti reddet', 'Reddet', function (g) { return rpc('manset_karar', { p_id: +b.getAttribute('data-ret'), p_onay: false, p_gerekce: g }); }); }; });
      k.querySelectorAll('[data-kaldir]').forEach(function (b) { b.onclick = function () { gerekceModal('Yayından kaldır', 'Kaldır', function (g) { return rpc('m2_yayin_kaldir', { p_id: +b.getAttribute('data-kaldir'), p_gerekce: g }); }); }; });
    } catch (err) { if (typeof iskelet === 'function') iskelet('Manşet onayı', '<div class="bos">' + esc(hataMetni(err)) + '</div>', { geri: true }); }
  }
  function gerekceModal(baslik, buton, fn) {
    var md = modal('<h3>' + esc(baslik) + '</h3><div class="m2-alan"><label for="m2Gerekce">Gerekçe (oyuncuya iletilir)</label><textarea id="m2Gerekce" maxlength="300" rows="3" placeholder="Örneğin: hakaret içeriyor"></textarea></div>' +
      '<button type="button" class="btn tehlike" id="m2GerekceK" style="min-height:48px">' + esc(buton) + '</button>');
    var b = md.querySelector('#m2GerekceK');
    b.onclick = async function () {
      var g = md.querySelector('#m2Gerekce').value.trim(); if (g.length < 5) { bildir('Gerekçe en az 5 karakter olmalı.', true); return; }
      b.disabled = true;
      try { await fn(g); modalKapat(); bildir('Tamam.'); M2.genelT = 0; mansetOnayEkrani(); } catch (err) { b.disabled = false; hata(err); }
    };
  }
  window.mansetOnayEkrani = mansetOnayEkrani;

  /* ---------- Gözcü ve açılış ---------- */
  var bekle = 0;
  function gozle() {
    if (bekle) return;
    bekle = requestAnimationFrame(function () {
      bekle = 0;
      try { sohbetSus(); } catch (e) {}
      try { if (document.getElementById('krListe')) vitrinEtiketle(); } catch (e) {}
      try { if (document.getElementById('avLansman')) sahneSus(); } catch (e) {}
      try { if (gundemde() && !document.getElementById('m2Gundem') && !M2.gundemBekle) { M2.gundemBekle = 1; setTimeout(function () { M2.gundemBekle = 0; gundemSus(); }, 120); } } catch (e) {}
    });
  }
  function kur() {
    css(); apiSar(); iskeletSar(); partiSar(); kartSar();
    try { new MutationObserver(gozle).observe(document.body, { childList: true, subtree: true }); } catch (e) {}
    var hazir = function () { return typeof API !== 'undefined' && API && typeof D !== 'undefined' && D && D.durum; };
    setTimeout(function () { if (hazir()) { genelYukle(); setTimeout(kutlamaKontrol, 3500); } }, 3000);
    setInterval(function () { if (hazir() && !document.hidden) kutlamaKontrol(); }, 60000);
  }
  kur();
  M2.kur = function () { apiSar(); iskeletSar(); partiSar(); kartSar(); };
  M2.kutlamaKontrol = kutlamaKontrol;
  setTimeout(M2.kur, 2500);
})();
