/* =====================================================================
   FİYAT TARİFESİ (31.10.2026) — Uzun Soluklu Ekonomi: statü hakları,
   kuruluş sermayeleri, parti kurma şartları, siyasi ücretler ve getiri
   kuralları. Sunucu: 151_uzun_soluklu_ekonomi.sql (fiyat_tarifesi).
   Bütün tutarlar sunucudaki gerçek fonksiyonlardan gelir; burada sabit yok.
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_FIYAT_TARIFESI_V1) return;
  window.SO_FIYAT_TARIFESI_V1 = true;
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var tl = function (n) { return Math.round(Number(n || 0)).toLocaleString('tr-TR') + ' ₺'; };
  var kisa = function (n) { n = Number(n || 0); return n >= 1e6 ? (n / 1e6).toLocaleString('tr-TR', { maximumFractionDigits: 2 }) + ' mn ₺' : n >= 1e4 ? Math.round(n / 1e3).toLocaleString('tr-TR') + ' bin ₺' : tl(n); };
  var aralik = function (a, b) { return b != null && Number(b) !== Number(a) ? kisa(a) + ' – ' + kisa(b) : kisa(a); };
  var oran = function (n) { return '%' + Number(n || 0).toLocaleString('tr-TR', { maximumFractionDigits: 2 }); };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var MUHUR = '<svg viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="24" r="22" fill="none" stroke="currentColor" stroke-width="1.3" opacity=".6"/><circle cx="24" cy="24" r="18.6" fill="none" stroke="currentColor" stroke-width=".8" stroke-dasharray="1.1 2.1" opacity=".7"/><path d="M16 15h11l6 6v12H16z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M27 15v6h6M20 25h9M20 29h6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>';
  var son = null;

  function bolum(ust, baslik, ic, sag) {
    return '<section class="dk-protokol"><header class="dk-bolum"><div><small>' + esc(ust) + '</small><b>' + esc(baslik) + '</b></div>' + (sag || '') + '</header>' + ic + '</section>';
  }
  function satir(ad, deger, not, statu) {
    return '<div class="ft-satir"><div class="ft-sol"><span>' + esc(ad) + '</span>' + (not ? '<small>' + esc(not) + '</small>' : '') + '</div>' +
      '<div class="ft-sag"><b>' + deger + '</b>' + (statu ? '<em>' + esc(statu) + '</em>' : '') + '</div></div>';
  }

  function govde(v) {
    var b = v.ben || {}, sh = b.sirket || {}, st = v.statuler || [], p = v.parti || {};
    var ilerleme = b.sonraki_esik ? Math.max(0, Math.min(100, 100 * Number(b.kidem || 0) / Number(b.sonraki_esik))) : 100;
    var kunye = '<section class="dk-kunye"><div class="dk-kunye-ust"><span class="dk-muhur">' + MUHUR + '</span><div class="dk-kunye-ad"><small>Ticaret Bakanlığı · Resmî tarife</small><b>Fiyat Tarifesi</b><span>Fiyat düzeyi ×' +
      Number(v.endeks || 1).toLocaleString('tr-TR', { minimumFractionDigits: 3 }) + ' · asgari ücret ' + tl(v.asgari) + '</span></div></div>' +
      (v.ben ? '<div class="dk-kpiler"><div class="dk-kpi"><small>Statün</small><b>' + esc(b.statu_ad) + '</b></div>' +
        '<div class="dk-kpi"><small>Kıdem</small><b>' + Number(b.kidem || 0).toLocaleString('tr-TR') + (b.sonraki_esik ? ' / ' + b.sonraki_esik : '') + '</b></div>' +
        '<div class="dk-kpi"><small>Şirket hakkı</small><b class="' + (Number(sh.kullanilan) < Number(sh.hak) ? 'iyi' : 'kotu') + '">' + (sh.kullanilan || 0) + ' / ' + (sh.hak || 0) + '</b></div>' +
        '<div class="dk-kpi"><small>Günlük maaş</small><b>' + kisa(b.gunluk_net) + '</b></div></div>' +
        (b.sonraki_ad ? '<div class="ft-ilerleme"><i style="--y:' + ilerleme + '%"></i></div><p class="ft-not">"<b>' + esc(b.sonraki_ad) + '</b>" statüsüne ' + Math.max(0, Number(b.sonraki_esik) - Number(b.kidem || 0)) +
          ' kıdem kaldı' + (sh.sonraki_hak != null ? ': şirket hakkın ' + sh.sonraki_hak + ' olur, maaşın artar.' : '.') + ' Kıdem; her gün maaşını topladıkça (+1), oy kullandıkça (+3) ve etkinliklere katıldıkça artar.</p>' :
          '<p class="ft-not">En yüksek statüdesin: <b>Yaşayan Efsane</b>.</p>') : '') + '</section>';

    var merdiven = st.map(function (s) {
      var ben = v.ben && Number(b.statu) === Number(s.basamak);
      return '<div class="ft-basamak' + (ben ? ' ben' : '') + (v.ben && Number(b.statu) > Number(s.basamak) ? ' gecti' : '') + '"><div class="ft-b-ust"><span class="ft-b-no">' + s.basamak + '</span><b>' + esc(s.ad) + '</b><small>' + s.esik + ' kıdem</small>' + (ben ? '<em>Sen</em>' : '') + '</div>' +
        '<div class="ft-b-alt"><span>Maaş ×' + Number(s.maas_carpan).toLocaleString('tr-TR') + '</span><span>' + s.sirket_hakki + ' şirket</span>' +
        ((s.acilan || []).length ? '<span class="ft-acilan">' + (s.acilan || []).map(esc).join(' · ') + '</span>' : '') + '</div></div>';
    }).join('');

    var gruplar = {};
    (v.sektorler || []).forEach(function (s) { (gruplar[s.min] = gruplar[s.min] || []).push(s.ad); });
    var sermaye = Object.keys(gruplar).map(Number).sort(function (a, c) { return a - c; }).map(function (m) {
      return satir(gruplar[m].length > 1 ? (m <= 200000 ? 'Küçük işletme' : m <= 500000 ? 'Orta ölçekli işletme' : 'Büyük işletme') : gruplar[m][0], kisa(m), gruplar[m].length > 1 ? gruplar[m].join(', ') : null, null);
    }).join('') + (v.kurumlar || []).map(function (k) { return satir(k.ad, aralik(k.tutar, k.en_cok), k.not, k.statu); }).join('');

    var parti = satir('Kurucular kurulu', 'en az ' + p.kurucu_kurulu + ' kişi', 'Sen dahil; aktif oyuncuların ' + oran(p.oran) + '\'si, en çok ' + p.en_cok + ' (Siyasi Partiler Kanunu)', null) +
      satir('Kuruluş harcı', kisa(p.harc), 'Genel merkez binası ve harç; başvurandan alınır', null) +
      satir('Kuruluş fonu', kisa(p.fon), 'Kurucular birlikte toplar, partinin kasasına geçer; kurulmazsa iade', null) +
      satir('Başvuran', esc(p.kurucu_statu), p.kurucu_hesap_gun + ' günlük hesap · iki kuruluş arası ' + p.bekleme_gun + ' gün', null) +
      satir('Kurucu üye', esc(p.ortak_statu), p.ortak_hesap_gun + ' günlük hesap · aynı cihazdaki hesaplar sayılmaz', null) +
      satir('İl teşkilatı', aralik(p.teskilat, p.teskilat_en_cok), 'İl büyüklüğüne göre, parti kasasından', null);

    var siyaset = (v.siyaset || []).map(function (x) { return satir(x.ad, aralik(x.tutar, x.en_cok), x.not, null); }).join('') +
      satir('Yeni oyuncu başlangıç parası', kisa(v.baslangic), null, null);

    var getiri = (v.getiri || []).map(function (x) { return satir(x.ad, oran(x.oran) + ' / ' + esc(x.birim), x.not, null); }).join('') +
      (v.reklam_odul ? satir('Reklam izleme ödülü', kisa(v.reklam_odul), 'Her reklam 2 saatlik maaşın; günde 5 kez', null) : '');

    var sss = [
      ['Neden şirket kuramıyorum?', 'Şirket kurmak en az <b>Vatandaş</b> statüsü ister. Aynı anda sahibi olabileceğin şirket sayısı da statünle artar (0, 1, 2, 3, 5, 8). Önceden kurduğun şirketler korunur; yalnız yeni kuruluş sınırlanır.'],
      ['Daha çok oynayan daha hızlı mı ilerler?', 'Evet. Kıdem her gün maaşını toplamakla, her oy ve halk oylamasıyla (+3) ve etkinliklerle artar. Düzenli giren oyuncu statüleri birkaç kat hızlı açar; seri bonusu, görev ve reklam ödülleri de cebine girer.'],
      ['Parti kurmak neden zorlaştı?', 'Oyunda yüzlerce küçük parti yerine gerçek ekiplerin kurduğu güçlü partiler olsun diye. Kurucular kurulunu topla, fona birlikte katkı yapın; parti kasası dolu başlar ve hemen il teşkilatı açabilirsiniz.'],
      ['Eski mülkümün kirası düşecek mi?', 'Hayır. Yeni kira verimi yalnız bundan sonra alınan konut ve dükkânlara uygulanır.']
    ];
    var sssHtml = '<div class="ed-sss">' + sss.map(function (x) { return '<details><summary>' + esc(x[0]) + '</summary><p>' + x[1] + '</p></details>'; }).join('') + '</div>';

    return '<div class="dk-resmi ft">' + kunye +
      bolum('İlerleme', 'Statü merdiveni', '<div class="ft-merdiven">' + merdiven + '</div>') +
      bolum('Kuruluş', 'Şirket ve kurum sermayeleri', sermaye) +
      bolum('Siyaset', 'Parti kurmak', parti, typeof window.partiKurEkrani === 'function' ? '<button type="button" class="ft-git" onclick="ekranAc(partiKurEkrani)">Parti kur ›</button>' : '') +
      bolum('Siyaset', 'Adaylık ve diğer ücretler', siyaset) +
      bolum('Kazanç', 'Getiri ve gelir kuralları', getiri) +
      bolum('Kısaca', 'Sık sorulanlar', sssHtml) + '</div>';
  }

  async function ekran() {
    try { yukleniyor('Fiyat Tarifesi'); } catch (_) {}
    try { son = await API.rpc('fiyat_tarifesi'); }
    catch (err) { iskelet('Fiyat Tarifesi', '<div class="bos">' + esc(hata(err)) + '</div>', { geri: true }); return; }
    iskelet('Fiyat Tarifesi', govde(son), { geri: true });
  }
  window.fiyatTarifesiEkrani = ekran;

  // Ekonomi menü merkezine ve genel menü aramasına ekle
  function aramaEkle() {
    var ind = window.SO_MENU_ARAMA_INDEKSI;
    if (!ind || !ind.ekonomi) return false;
    if (!ind.ekonomi.some(function (x) { return x[1] === 'Fiyat Tarifesi'; }))
      ind.ekonomi.unshift(['🏷️', 'Fiyat Tarifesi', 'Kuruluş bedelleri, statü hakları, parti kurma şartları', "soMenuGit('fiyatTarifesiEkrani')",
        'fiyat tarife ücret maliyet sermaye kuruluş statü hak şirket hakkı parti kurma kurucu banka gazete dernek aday miting taşınma kira']);
    return true;
  }
  if (!aramaEkle()) setTimeout(aramaEkle, 1500);

  // Ekonomi sekmesinin başına kısa kart (Ekonomik Denge kartının altına)
  function kartHtml(v) {
    var b = v.ben || {}, sh = b.sirket || {};
    return '<button type="button" class="ed-kart ft-kart" onclick="ekranAc(fiyatTarifesiEkrani)"><span class="dk-muhur kucuk">' + MUHUR + '</span><span class="ed-kart-g"><small>Fiyat Tarifesi · statü hakları</small><b>' +
      esc(b.statu_ad || '') + ' · şirket hakkın ' + (sh.kullanilan || 0) + '/' + (sh.hak || 0) + '</b><em>' +
      (b.sonraki_ad ? '"' + esc(b.sonraki_ad) + '" için ' + Math.max(0, Number(b.sonraki_esik) - Number(b.kidem || 0)) + ' kıdem kaldı' : 'Bütün statü hakların açık') + '</em></span><span class="ed-ok">›</span></button>';
  }
  function bagla() {
    var asil = window.ekonomiSekmeEkrani;
    if (typeof asil !== 'function' || asil._ft) return;
    var yeni = async function () {
      var r = await asil.apply(this, arguments);
      try {
        var v = await API.rpc('fiyat_tarifesi'); son = v;
        var ic = document.getElementById('icerik');
        if (ic && !ic.querySelector('.ft-kart')) {
          var d = document.createElement('div'); d.innerHTML = kartHtml(v);
          var denge = ic.querySelector('.ed-kart');
          if (denge && denge.parentNode) denge.parentNode.insertBefore(d.firstChild, denge.nextSibling); else ic.insertBefore(d.firstChild, ic.firstChild);
        }
      } catch (_) {}
      return r;
    };
    yeni._ft = true; window.ekonomiSekmeEkrani = yeni;
  }
  bagla(); setTimeout(bagla, 1600);

  // Bildirimlerde "Fiyat Tarifesi" geçiyorsa bağlantı
  function bildirimBagla() {
    var ic = document.getElementById('icerik'); if (!ic) return;
    ic.querySelectorAll('.kisisel').forEach(function (k) {
      if (k.querySelector('.ft-bag') || !/Fiyat Tarifesi|kurucular kurulu/i.test(k.textContent || '')) return;
      var btn = document.createElement('button'); btn.type = 'button'; btn.className = 'er-bag ft-bag'; btn.textContent = 'Fiyat Tarifesi ›';
      btn.onclick = function (ev) { ev.stopPropagation(); ekranAc(ekran); };
      var alt = k.querySelector('.bildirim-alt');
      (alt && alt.parentNode ? alt.parentNode : k).appendChild(btn);
    });
  }
  if (typeof iskelet === 'function') {
    var eskiIskelet = iskelet;
    iskelet = window.iskelet = function (baslik) {
      var r = eskiIskelet.apply(this, arguments);
      try { if (baslik === 'Bildirimler') setTimeout(bildirimBagla, 40); } catch (_) {}
      return r;
    };
  }

  var css = [
    '.ft .ft-satir{display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:10px 2px;border-bottom:1px solid rgba(217,178,91,.10)}',
    '.ft .ft-satir:last-child{border-bottom:0}',
    '.ft .ft-sol{min-width:0;display:flex;flex-direction:column;gap:2px}.ft .ft-sol span{font-size:13.5px;color:#e9ebf3}.ft .ft-sol small{font-size:11.5px;line-height:1.4;color:#8f9bbd}',
    '.ft .ft-sag{flex:none;display:flex;flex-direction:column;align-items:flex-end;gap:3px;text-align:right}.ft .ft-sag b{font-family:var(--disp);font-size:15px;color:#e8cf8f;font-variant-numeric:tabular-nums;white-space:nowrap}',
    '.ft .ft-sag em{font-style:normal;font-size:10.5px;font-weight:700;color:#1b1607;background:#d9b25b;padding:1px 7px;border-radius:6px;white-space:nowrap}',
    '.ft .ft-ilerleme{height:7px;border-radius:4px;background:rgba(255,255,255,.07);overflow:hidden;margin-top:12px}.ft .ft-ilerleme i{display:block;height:100%;width:var(--y);border-radius:4px;background:linear-gradient(90deg,#e8cf8f,#b8913f)}',
    '.ft .ft-not{margin:8px 2px 0;font-size:12.5px;line-height:1.5;color:#a9b2cf}.ft .ft-not b{color:#f5ecd4}',
    '.ft .ft-merdiven{display:flex;flex-direction:column;gap:6px}',
    '.ft .ft-basamak{padding:10px 12px;border-radius:12px;background:rgba(8,12,30,.45);border:1px solid rgba(217,178,91,.14)}',
    '.ft .ft-basamak.ben{border-color:rgba(217,178,91,.65);background:rgba(217,178,91,.09)}.ft .ft-basamak.gecti{opacity:.72}',
    '.ft .ft-b-ust{display:flex;align-items:center;gap:8px}.ft .ft-b-ust b{font-size:14px;color:#f3eee0;flex:1;min-width:0}.ft .ft-b-ust small{font-size:11.5px;color:#8f9bbd}',
    '.ft .ft-b-ust em{font-style:normal;font-size:10.5px;font-weight:800;color:#1b1607;background:#d9b25b;padding:1px 7px;border-radius:6px}',
    '.ft .ft-b-no{flex:none;width:22px;height:22px;border-radius:50%;display:grid;place-items:center;font-size:11.5px;font-weight:800;color:#d9b25b;border:1px solid rgba(217,178,91,.45)}',
    '.ft .ft-b-alt{display:flex;flex-wrap:wrap;gap:4px 10px;margin:6px 0 0 30px;font-size:12px;color:#c5cdf0}.ft .ft-acilan{flex-basis:100%;color:#e8cf8f}',
    '.ft .ft-git{flex:none;border:1px solid rgba(217,178,91,.45);background:rgba(217,178,91,.10);color:#e8cf8f;border-radius:999px;padding:5px 11px;font:inherit;font-size:12.5px;font-weight:700;cursor:pointer}'
  ];
  var st = document.createElement('style'); st.id = 'fiyatTarifesiStil'; st.textContent = css.join('\n'); (document.head || document.documentElement).appendChild(st);
})();
