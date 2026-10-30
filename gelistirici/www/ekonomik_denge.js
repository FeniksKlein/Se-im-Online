/* =====================================================================
   EKONOMİK DENGE (30.10.2026) — servet makası, Fırsat Eşitliği Fonu,
   otomatik Rekabet Kurumu kararları. Sunucu: 148_ekonomik_denge.sql
   (denge_paneli). Sunucu fonksiyonu yoksa hiçbir şey göstermez.
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_EKONOMIK_DENGE_V1) return;
  window.SO_EKONOMIK_DENGE_V1 = true;
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var tl = function (n) { return Number(n || 0).toLocaleString('tr-TR', { maximumFractionDigits: 0 }) + ' ₺'; };
  var kisa = function (n) { n = Number(n || 0); return n >= 1e6 ? (n / 1e6).toLocaleString('tr-TR', { maximumFractionDigits: 1 }) + ' mn ₺' : n >= 1e3 ? Math.round(n / 1e3).toLocaleString('tr-TR') + ' bin ₺' : tl(n); };
  var yuz = function (n, d) { return '%' + Number(n || 0).toLocaleString('tr-TR', { minimumFractionDigits: d || 0, maximumFractionDigits: d == null ? 1 : d }); };
  var MUHUR = '<svg viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="24" r="22" fill="none" stroke="currentColor" stroke-width="1.3" opacity=".6"/><circle cx="24" cy="24" r="18.6" fill="none" stroke="currentColor" stroke-width=".8" stroke-dasharray="1.1 2.1" opacity=".7"/><path d="M14 30h20M17 30V22M24 30V18M31 30V25" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/><path d="M12 17l6-3 6 2 6-4 6 2" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  var son = null;

  function giniYorum(g) {
    if (g == null) return '';
    return g < 0.35 ? 'dengeli' : g < 0.5 ? 'makul' : g < 0.65 ? 'yüksek eşitsizlik' : 'aşırı eşitsizlik';
  }
  function dilimim(v) {
    var s = Number(v.ben && v.ben.servet || 0), d = v.dilimler || [];
    for (var i = d.length - 1; i >= 0; i--) if (s > Number(d[i].alt)) return i;
    return 0;
  }
  function govde(v) {
    var b = v.ben || {}, di = dilimim(v), g = v.gini;
    var kunye = '<section class="dk-kunye"><div class="dk-kunye-ust"><span class="dk-muhur">' + MUHUR + '</span><div class="dk-kunye-ad"><small>Rekabet Kurumu · Fırsat Eşitliği Fonu</small><b>Ekonomik Denge</b><span>' +
      (v.aktif ? 'Kurallar yürürlükte · her gün 03:20\'de hesaplanır' : 'Kurallar hazırlanıyor; yakında yürürlüğe girecek') + '</span></div></div>' +
      '<div class="dk-kpiler"><div class="dk-kpi"><small>Gini</small><b class="' + (g != null && g < 0.5 ? 'iyi' : 'kotu') + '">' + (g != null ? Number(g).toLocaleString('tr-TR', { minimumFractionDigits: 2 }) : '—') + '</b></div>' +
      '<div class="dk-kpi"><small>En zengin</small><b>' + (v.en_zengin_pay != null ? yuz(v.en_zengin_pay) : '—') + '</b></div>' +
      '<div class="dk-kpi"><small>İlk %10</small><b>' + (v.ust10_pay != null ? yuz(v.ust10_pay) : '—') + '</b></div>' +
      '<div class="dk-kpi"><small>Medyan servet</small><b>' + kisa(v.medyan) + '</b></div></div>' +
      (g != null ? '<p class="ed-not">Servet dağılımı şu an <b>' + giniYorum(g) + '</b> düzeyinde. 0 herkesin eşit olduğu, 1 tüm servetin tek kişide toplandığı durumdur.</p>' : '') + '</section>';

    var ben = '<section class="dk-protokol"><header class="dk-bolum"><div><small>Senin durumun</small><b>' + kisa(b.servet) + ' net servet</b></div><span class="ed-kat">medyanın ' + Number(b.medyan_kat || 0).toLocaleString('tr-TR') + ' katı</span></header>' +
      '<div class="ed-bilesen">' + [['Nakit ve mevduat', b.nakit], ['Şirket payları', b.hisse], ['Mülkler', b.mulk]].map(function (x) {
        var y = Number(b.servet) > 0 ? Math.max(0, Math.min(100, 100 * Number(x[1] || 0) / Number(b.servet))) : 0;
        return '<div><span>' + x[0] + '</span><i style="--y:' + y + '%"></i><b>' + kisa(x[1]) + '</b></div>'; }).join('') + '</div>' +
      '<div class="dk-kpiler"><div class="dk-kpi"><small>Günlük vergin</small><b class="' + (b.gunluk_vergi > 0 ? 'kotu' : 'iyi') + '">' + tl(b.gunluk_vergi) + '</b></div>' +
      '<div class="dk-kpi"><small>Son 7 gün vergi</small><b>' + kisa(b.vergi_7gun) + '</b></div><div class="dk-kpi"><small>Son 7 gün fon desteği</small><b class="iyi">' + kisa(b.fon_7gun) + '</b></div></div>' +
      (Number(b.borc) > 0 ? '<p class="ed-uyari">Servet vergisi borcun: <b>' + tl(b.borc) + '</b>. Borç kapanana kadar başka oyuncuya para aktaramaz, yeni şirket kuramazsın; cüzdanına ya da banka hesabına para geldikçe kendiliğinden tahsil edilir.</p>' : '') +
      (Number(b.servet) < Number(v.medyan) ? '<p class="ed-not">Servetin medyanın altında: aktifsen ve seçmen kartın hazırsa Fırsat Eşitliği Fonu\'ndan her gün pay alırsın (kişi başı en çok ' + tl(v.kurallar && v.kurallar.kisi_tavan) + ').</p>' : '') + '</section>';

    var dilim = '<section class="dk-protokol"><header class="dk-bolum"><div><small>Kademeli, yalnız eşiği aşan kısma</small><b>Servet vergisi dilimleri</b></div></header><div class="ed-dilimler">' +
      (v.dilimler || []).map(function (d, i) {
        var ay = Number(d.oran) * 30;
        return '<div class="ed-dilim' + (i === di ? ' ben' : '') + '"><span>' + (d.ust ? kisa(d.alt) + ' – ' + kisa(d.ust) : kisa(d.alt) + ' üzeri') + '</span><b>' + (Number(d.oran) ? yuz(d.oran, 2) + ' / gün' : 'Vergi yok') + '</b><small>' + (Number(d.oran) ? 'ayda yaklaşık ' + yuz(ay, 1) : 'oyuncuların büyük çoğunluğu') + '</small>' + (i === di ? '<em>Sen buradasın</em>' : '') + '</div>';
      }).join('') + '</div><p class="ed-not">Eşikler oyuncuların medyan servetine bağlıdır: ekonomi büyüdükçe kendiliğinden yükselir, kimse için keyfî değildir. Toplanan verginin %' + esc(v.kurallar && v.kurallar.fon_pay) + '\'i aynı gün medyanın altındaki aktif oyunculara eşit dağıtılır, kalanı Hazine\'ye gider.</p></section>';

    var gec = (v.gecmis || []);
    var grafik = gec.length ? '<section class="dk-protokol"><header class="dk-bolum"><div><small>Son ' + gec.length + ' gün</small><b>Eşitsizlik eğilimi</b></div></header><div class="ed-grafik">' +
      (function () { var gs = gec.map(function (x) { return Number(x.gini || 0); }), mn = Math.min.apply(null, gs) - 0.03, mx = Math.max.apply(null, gs); return gec.map(function (x) { var h = Math.max(6, Math.min(100, 100 * (Number(x.gini || 0) - mn) / Math.max(0.01, mx - mn))); return '<div title="' + esc(x.gun) + ' · Gini ' + esc(x.gini) + '"><i style="height:' + h + '%"></i><small>' + esc(String(x.gun).slice(8, 10)) + '</small></div>'; }).join(''); })() +
      '</div><p class="ed-not">Çubuklar günlük Gini katsayısını gösterir; düştükçe servet daha adil dağılıyor demektir.</p></section>' : '';

    var rek = (v.rekabet || []);
    var rekabet = '<section class="dk-protokol"><header class="dk-bolum"><div><small>Otomatik gözetim · her saat</small><b>Rekabet Kurumu kararları</b></div></header>' +
      (rek.length ? '<div class="dk-akis">' + rek.map(function (r) {
        return '<div class="dk-akis-s' + (r.aktif ? ' canli' : '') + '"><span class="dk-akis-ik k-Nişan">' + MUHUR + '</span><div class="dk-akis-g"><b>' + esc(r.sirket) + ' <span>· ' + esc(r.il || '') + ' ' + esc(r.sektor || '') + '</span></b><small>' + esc(r.neden || '') + '</small><span class="dk-akis-alt">Ceza ' + tl(r.ceza) + ' mağdur rakiplere tazminat · ' + (r.aktif ? '<i>fiyat sınırı sürüyor</i>' : 'süresi doldu') + '</span></div></div>';
      }).join('') + '</div>' : '<p class="dk-not">Henüz yıkıcı rekabet kararı yok.</p>') + '</section>';

    var kural = '<section class="dk-protokol"><header class="dk-bolum"><div><small>Herkes için aynı</small><b>Batırmaya karşı koruma kuralları</b></div></header><ul class="ed-kurallar">' +
      '<li><b>Yıkıcı fiyat yasağı.</b> Servetinin medyanın ' + esc(v.kurallar && v.kurallar.koruma_kat) + ' katını aşan bir oyuncunun şirketi, pazarın en az %' + esc(v.kurallar && v.kurallar.rekabet_pay) + '\'ini tutarken zararına en düşük fiyattan satarsa otomatik cezalanır; fiyatı ' + esc(v.kurallar && v.kurallar.rekabet_saat) + ' saat ortaya çekilir, ceza mağdur rakiplere ödenir.</li>' +
      '<li><b>Paravan yasağı.</b> Aynı kişi ya da aynı cihazdaki hesapları aynı il ve sektöre ikinci şirket sokamaz.</li>' +
      '<li><b>Banka hücumu kalkanı.</b> Bir oyuncunun bir bankadaki vadeli ve vadesiz mevduatı o bankanın özkaynağını, bankanın toplam mevduatı özkaynağının 5 katını aşamaz.</li>' +
      '<li><b>Aktarım sınırı.</b> Oyuncu bankası içi havaleler de dahil günlük para aktarımı tek bir sınıra tabidir; aynı cihazdaki hesaplar arasında aktarım yapılamaz.</li>' +
      '<li><b>Vergiden kaçış yok.</b> Servet vergisi borcu olan oyuncu borcu kapanmadan para aktaramaz, yeni şirket kuramaz.</li></ul></section>';
    return '<div class="dk-resmi ed">' + kunye + ben + dilim + grafik + rekabet + kural + '</div>';
  }

  async function ekran() {
    try { yukleniyor('Ekonomik Denge'); } catch (_) {}
    try { son = await API.rpc('denge_paneli'); }
    catch (err) { iskelet('Ekonomik Denge', '<div class="bos">' + esc((typeof hataCevir === 'function' ? hataCevir(err.message) : err.message)) + '</div>', { geri: true }); return; }
    iskelet('Ekonomik Denge', govde(son), { geri: true });
  }
  window.ekonomikDengeEkrani = ekran;

  // Ekonomi sekmesinin başına kısa kart
  function kartHtml(v) {
    var b = v.ben || {};
    return '<button type="button" class="ed-kart" onclick="ekranAc(ekonomikDengeEkrani)"><span class="dk-muhur kucuk">' + MUHUR + '</span><span class="ed-kart-g"><small>Ekonomik Denge · Rekabet Kurumu</small><b>Gini ' +
      (v.gini != null ? Number(v.gini).toLocaleString('tr-TR', { minimumFractionDigits: 2 }) : '—') + ' · senin servetin ' + kisa(b.servet) + '</b><em>' +
      (Number(b.gunluk_vergi) > 0 ? 'Günlük servet vergin ' + tl(b.gunluk_vergi) : Number(b.servet) < Number(v.medyan) ? 'Fırsat Eşitliği Fonu\'ndan pay alabilirsin' : 'Servet vergisi dilimine girmiyorsun') + '</em></span><span class="ed-ok">›</span></button>';
  }
  function bagla() {
    var asil = window.ekonomiSekmeEkrani;
    if (typeof asil !== 'function' || asil._ed) return;
    var yeni = async function () {
      var r = await asil.apply(this, arguments);
      try {
        var v = await API.rpc('denge_paneli'); son = v;
        var ic = document.getElementById('icerik');
        if (ic && !ic.querySelector('.ed-kart')) { var d = document.createElement('div'); d.innerHTML = kartHtml(v); ic.insertBefore(d.firstChild, ic.firstChild); }
      } catch (_) {}
      return r;
    };
    yeni._ed = true; window.ekonomiSekmeEkrani = yeni;
  }
  bagla(); setTimeout(bagla, 1500);

  var css = [
    '.ed-not{margin:10px 2px 0;font-size:12.5px;line-height:1.5;color:#a9b2cf}.ed-not b{color:#f5ecd4}',
    '.ed-uyari{margin:10px 0 0;padding:10px 12px;border-radius:11px;background:rgba(240,69,75,.1);border:1px solid rgba(240,69,75,.3);font-size:13px;line-height:1.5;color:#ffc2c6}',
    '.ed-kat{flex:none;font-size:12px;font-weight:700;color:#e8cf8f;padding:4px 9px;border-radius:999px;background:rgba(217,178,91,.12)}',
    '.ed-bilesen{display:flex;flex-direction:column;gap:7px;margin-bottom:12px}.ed-bilesen div{display:grid;grid-template-columns:118px 1fr auto;align-items:center;gap:9px;font-size:12.5px;color:#c5cdf0}',
    '.ed-bilesen i{display:block;height:7px;border-radius:4px;background:rgba(255,255,255,.07);position:relative;overflow:hidden}.ed-bilesen i::after{content:"";position:absolute;inset:0;width:var(--y);border-radius:4px;background:linear-gradient(90deg,#e8cf8f,#b8913f)}',
    '.ed-bilesen b{font-variant-numeric:tabular-nums;color:#f5ecd4}',
    '.ed-dilimler{display:flex;flex-direction:column;gap:6px}',
    '.ed-dilim{position:relative;display:grid;grid-template-columns:1fr auto;gap:2px 10px;padding:10px 12px;border-radius:11px;background:rgba(8,12,30,.45);border:1px solid rgba(217,178,91,.15)}',
    '.ed-dilim span{font-size:13.5px;color:#e9ebf3}.ed-dilim b{font-family:var(--disp);font-size:15px;color:#e8cf8f;text-align:right}.ed-dilim small{grid-column:1/3;font-size:11.5px;color:#8f9bbd}',
    '.ed-dilim.ben{border-color:rgba(217,178,91,.6);background:rgba(217,178,91,.08)}.ed-dilim em{position:absolute;right:10px;bottom:8px;font-style:normal;font-size:11px;font-weight:800;color:#1b1607;background:#d9b25b;padding:1px 7px;border-radius:6px}',
    '.ed-grafik{display:flex;align-items:flex-end;gap:5px;height:110px;padding:6px 2px 0}.ed-grafik div{flex:1;height:100%;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;gap:4px}',
    '.ed-grafik i{display:block;width:100%;max-width:22px;border-radius:5px 5px 2px 2px;background:linear-gradient(180deg,#ff9aa2,#b8913f)}.ed-grafik small{font-size:10px;color:#8f9bbd}',
    '.ed-kurallar{margin:0;padding:0 0 0 18px;display:flex;flex-direction:column;gap:9px;font-size:13px;line-height:1.5;color:#c5cdf0}.ed-kurallar b{color:#f5ecd4}',
    '.ed-kart{display:flex;align-items:center;gap:11px;width:100%;margin:0 0 12px;padding:12px;border-radius:16px;border:1px solid rgba(217,178,91,.3);background:linear-gradient(135deg,rgba(217,178,91,.10),rgba(217,178,91,.02)),var(--panel,#151E3D);color:var(--txt);font:inherit;text-align:left;cursor:pointer}',
    '.ed-kart-g{flex:1;min-width:0;display:flex;flex-direction:column}.ed-kart-g small{font-size:11.5px;color:#c9b88f}.ed-kart-g b{font-size:15px;color:#f5ecd4}.ed-kart-g em{font-style:normal;font-size:12.5px;color:#a9b2cf}',
    '.ed-ok{color:#d9b25b;font-size:24px}'
  ];
  var st = document.createElement('style'); st.id = 'ekonomikDengeStil'; st.textContent = css.join('\n'); (document.head || document.documentElement).appendChild(st);
})();
