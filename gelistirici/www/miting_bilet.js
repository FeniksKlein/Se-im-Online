/* =====================================================================
   MİTİNG OTOBÜS BİLETİ (30.10.2026) — başka ildeki canlı mitinge
   gidiş-dönüş bilet alıp katılma. Sunucu: 149_miting_bilet_avukat.sql
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_MITING_BILET_V1) return;
  window.SO_MITING_BILET_V1 = true;
  var tl = function (n) { return Number(n || 0).toLocaleString('tr-TR', { maximumFractionDigits: 0 }) + ' ₺'; };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };

  window.mitingBiletAl = async function (id, btn) {
    try {
      if (btn) btn.disabled = true;
      var b = await API.rpc('miting_bilet_bilgi', { p_miting: id });
      if (!b.gerekli || b.biletim) {
        var r0 = await API.rpc('miting_katil', { p_id: id });
        toast('Meydandasın: ' + r0.katilim + ' kişi' + (r0.kidem ? ' · +1 kıdem' : '') + '.');
      } else {
        var ok = await onayla('Otobüsle mitinge git',
          b.kaynak + ' → ' + b.hedef + ' gidiş-dönüş otobüs bileti: <b>' + tl(b.ucret) + '</b>.<br><br>Cüzdanından ödenir. İkametgâhın değişmez; miting bitince evine dönersin. Mitinge katılır, tepki verir ve slogan atabilirsin.', 'Bileti al ve katıl');
        if (!ok) { if (btn) btn.disabled = false; return; }
        var r = await API.rpc('miting_bilet_al', { p_miting: id });
        toast('Otobüs ' + b.hedef + ' meydanına vardı. Meydandasın: ' + r.katilim + ' kişi' + (r.kidem ? ' · +1 kıdem' : '') + '.');
        try { HAPTIK.orta(); } catch (_) {}
      }
      if (typeof mtCiz === 'function') { try { mtCiz(await API.rpc('miting_meydan', { p_id: id })); } catch (_) {} }
    } catch (err) { toast(hata(err), true); if (btn) btn.disabled = false; }
  };

  function bagla() {
    if (typeof window.mtSahneHtml !== 'function' || window.mtSahneHtml._bilet) return;
    var onceki = window.mtSahneHtml;
    var yeni = function (d) {
      var s = onceki.apply(this, arguments);
      try {
        if (d && d.canli && !d.katildim && !d.benim && /yaşayanlara açık|Başka ilden katılmak/.test(s)) {
          s = s.replace(/Canlı izliyorsun\.[^<]*/, 'Canlı izliyorsun. Başka ilde yaşıyorsun: otobüs bileti alıp meydana katılabilirsin.');
          s += '<div class="kart mb-kart"><button class="btn altin mb-btn" onclick="mitingBiletAl(' + Number(d.id) + ', this)"><span aria-hidden="true">🚌</span> Otobüsle git ve katıl</button>' +
            '<p class="kucuk" style="margin-top:6px">Gidiş-dönüş bilet ücreti mesafeye göre hesaplanır; ödeme sonrası anında meydandasın.</p></div>';
        }
      } catch (_) {}
      return s;
    };
    yeni._bilet = true;
    window.mtSahneHtml = yeni;
    try { mtSahneHtml = yeni; } catch (_) {}
  }
  bagla(); setTimeout(bagla, 1200);
  var st = document.createElement('style');
  st.textContent = '.mb-kart{margin-top:8px}.mb-btn{display:flex;align-items:center;justify-content:center;gap:8px;width:100%}.mb-btn span{font-size:18px}';
  (document.head || document.documentElement).appendChild(st);
})();
