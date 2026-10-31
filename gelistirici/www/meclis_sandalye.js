/* =====================================================================
   MECLİS SANDALYE DAĞILIMI ve MİLLETVEKİLİ ÖZ GEÇMİŞİ (31.10.2026)
   Gerçek TBMM sitesindeki düzen: sandalye dağılımı tablosu (anlık),
   partiye dokununca vekillerin portresi, adı ve ili; vekile dokununca
   öz geçmiş, yasama dönemleri, meclis çalışmaları ve Kürsü hesabı.
   Sunucu: 156_meclis_sandalye.sql (meclis_sandalye, meclis_vekiller,
   milletvekili_ozgecmis). Meclis › Sandalyeler sekmesindeki parti
   kartının yerine TBMM düzenindeki tablo gelir.
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_MECLIS_SANDALYE_V1) return;
  window.SO_MECLIS_SANDALYE_V1 = true;
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var buyuk = function (s) { return String(s || '').toLocaleUpperCase('tr'); };
  var sayi = function (n) { return Number(n || 0).toLocaleString('tr-TR', { maximumFractionDigits: 0 }); };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var rpc = function (ad, arg) { return API.rpc(ad, arg || {}); };
  var gun = function (t) { try { return new Date(t).toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Europe/Istanbul' }); } catch (_) { return ''; } };
  var saat = function (t) { try { return new Date(t).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Istanbul' }); } catch (_) { return ''; } };
  var donemAd = function (no) { return Number(no) === 0 ? 'Kuruluş Meclisi' : no + '. Dönem'; };
  var foto = function (kad, renk, boy) { return '<span class="ms-foto" style="width:' + boy + 'px;height:' + boy + 'px">' + (typeof portre === 'function' ? portre(kad, renk, boy) : '') + '</span>'; };
  var tazele = function () { try { var ic = document.getElementById('icerik'); if (ic && typeof portreleriTazele === 'function') portreleriTazele(ic); } catch (_) {} };
  var S = { donem: null, v: null };

  /* ---------------------------------------------------------- tablo */
  function tabloHtml(v, tiklanir) {
    var satirlar = (v.partiler || []).map(function (p) {
      return '<button type="button" class="ms-satir" ' + (tiklanir ? 'onclick="msParti(' + p.id + ')"' : '') + '><span class="ms-ad"><i style="background:' + esc(p.renk || '#8E97B5') + '"></i>' + esc(buyuk(p.ad)) + '</span><b>' + sayi(p.n) + '</b></button>';
    }).join('');
    if (v.bagimsiz) satirlar += '<button type="button" class="ms-satir" ' + (tiklanir ? 'onclick="msParti(\'bagimsiz\')"' : '') + '><span class="ms-ad"><i style="background:#8E97B5"></i>BAĞIMSIZ MİLLETVEKİLİ</span><b>' + sayi(v.bagimsiz) + '</b></button>';
    if (v.bos != null && v.bos > 0) satirlar += '<div class="ms-satir bos"><span class="ms-ad"><i></i>BOŞ SANDALYE</span><b>' + sayi(v.bos) + '</b></div>';
    return '<div class="ms-tablo"><div class="ms-baslik"><span>Parti Adı</span><span>Üye Sayısı</span></div>' +
      (satirlar || '<div class="ms-bos">Bu dönemde milletvekili yok.</div>') +
      '<div class="ms-toplam"><span>Toplam</span><b>' + sayi(v.bos != null ? v.toplam : v.dolu) + '</b></div></div>';
  }
  function bant(ust, alt) { return '<div class="ms-bant"><small>' + esc(ust) + '</small><b>' + esc(alt) + '</b></div>'; }

  // Meclis › Sandalyeler sekmesine gömülü kart (meclis_rehber verisinden, eşzamanlı)
  function rehberKart(r) {
    var v = { partiler: (r.partiler || []).map(function (p) { return { id: p.id, ad: p.ad, renk: p.renk, n: p.n }; }), bagimsiz: r.bagimsiz || 0, dolu: r.dolu || 0, toplam: r.toplam || 600 };
    v.bos = Math.max(0, v.toplam - v.dolu);
    S.gomulu = v;
    return '<div class="kart ms ms-gomulu">' + bant('Türkiye Büyük Millet Meclisi', 'Milletvekilleri sandalye dağılımı') + tabloHtml(v, true) +
      '<p class="kucuk ms-not">Anlık: bir vekil partisinden istifa ettiğinde ya da başka partiye geçtiğinde tablo hemen değişir. Partiye dokun, vekillerini gör.</p>' +
      '<div class="satir" style="margin-top:10px"><button class="btn yarim altin" onclick="ekranAc(()=>meclisSandalyeEkrani())">Dönemler ve tüm vekiller</button><button class="btn yarim ikinci" onclick="ekranAc(()=>sohbetEkrani(\'meclis\'))">TBMM Genel Kurulu</button></div>' +
      '<button class="btn ikinci" style="margin-top:8px" onclick="meclisSekmeAc(\'vekiller\',\'\')">İl il vekiller</button></div>';
  }

  /* ---------------------------------------------------------- sandalye ekranı */
  function sandalyeHtml(v) {
    var ds = (v.donemler || []).slice();
    var secenek = ds.map(function (d) { return '<option value="' + d.no + '"' + (Number(d.no) === Number(v.donem) ? ' selected' : '') + '>' + esc(donemAd(d.no)) + (d.bit ? '' : ' (güncel)') + '</option>'; }).join('');
    if (!ds.some(function (d) { return Number(d.no) === 0; })) secenek += '<option value="0"' + (Number(v.donem) === 0 ? ' selected' : '') + '>Kuruluş Meclisi</option>';
    return '<div class="ms ms-ekran">' + bant('TBMM', donemAd(v.donem) + ' milletvekilleri sandalye dağılımı') +
      '<div class="kart ms-ust"><label class="kucuk" for="msDonem">Yasama dönemi</label><select id="msDonem" class="ms-sec" onchange="msDonem(this.value)">' + secenek + '</select>' +
      '<div class="kucuk ms-guncel">' + (v.guncel ? '<span class="ms-canli">●</span> Canlı · son güncelleme ' + saat(v.guncelleme) : 'Bu dönemde görev yapan milletvekilleri, seçildikleri partiye göre') + '</div></div>' +
      '<div class="kart">' + tabloHtml(v, true) + '</div>' +
      '<button type="button" class="kart ms-git" onclick="msListe(' + (v.guncel ? 'null' : v.donem) + ')"><span><b>' + esc(donemAd(v.donem)) + ' milletvekili listesi</b><small>Portre, ad ve il; dokununca öz geçmiş</small></span><em>›</em></button>' +
      '<button type="button" class="kart ms-git" onclick="msListe(0)"><span><b>Tüm dönem milletvekili listesi</b><small>Bugüne kadar Meclis\'e girmiş herkes</small></span><em>›</em></button></div>';
  }
  async function sandalyeEkrani(donem) {
    stil();
    try { yukleniyor('Sandalye Dağılımı'); } catch (_) {}
    S.donem = donem == null ? null : Number(donem);
    try { S.v = await rpc('meclis_sandalye', { p_donem: S.donem }); }
    catch (err) { iskelet('Sandalye Dağılımı', '<div class="bos">' + esc(hata(err)) + '</div>', { geri: true }); return; }
    iskelet('Sandalye Dağılımı', sandalyeHtml(S.v), { geri: true });
  }
  window.meclisSandalyeEkrani = sandalyeEkrani;
  window.msDonem = function (no) { sandalyeEkrani(no); };
  window.msParti = function (id) {
    var gomulu = !document.querySelector('#icerik .ms-ekran'), v = (gomulu ? S.gomulu : S.v) || {};
    var donem = gomulu || v.guncel ? null : v.donem;
    var p = id === 'bagimsiz' ? null : ((v.partiler || []).filter(function (x) { return x.id === id; })[0] || { id: id });
    ekranAc(function () { return listeEkrani({ donem: donem, parti: id === 'bagimsiz' ? null : id, bagimsiz: id === 'bagimsiz', partiAd: id === 'bagimsiz' ? 'Bağımsız milletvekilleri' : p.ad, renk: p.renk }); });
  };
  window.msListe = function (donem) { ekranAc(function () { return listeEkrani({ donem: donem }); }); };

  // Sandalye ekranı açıkken her dakika tazele (yalnız güncel dönem)
  setInterval(async function () {
    if (document.hidden || !S.v || !S.v.guncel || !document.querySelector('#icerik .ms-ekran')) return;
    if (typeof window.SO_MESGUL === 'function' && window.SO_MESGUL()) return;
    try { var v = await rpc('meclis_sandalye', { p_donem: null }); S.v = v; var el = document.querySelector('#icerik .ms-ekran'); if (el) el.outerHTML = sandalyeHtml(v); } catch (_) {}
  }, 60000);

  /* ---------------------------------------------------------- vekil listesi */
  var L = { o: null, l: [] };
  function vekilKart(x, tum) {
    var p = x.parti, alt = tum ? (x.il ? buyuk(x.il) + ' · ' : '') + (x.donemler || []).map(donemAd).join(', ') : buyuk(x.il || '') + ' MİLLETVEKİLİ';
    return '<button type="button" class="ms-vekil" data-ad="' + esc(String(x.kad).toLocaleLowerCase('tr') + ' ' + String(x.il || '').toLocaleLowerCase('tr')) + '" onclick="msOzgecmis(\'' + esc(x.kad).replace(/'/g, "\\'") + '\')">' +
      foto(x.kad, p && p.renk, 78) + '<span class="ms-v-g"><b>' + esc(buyuk(x.kad)) + '</b><span class="ms-cizgi"></span><span class="ms-il">' + esc(alt) + '</span>' +
      '<span class="ms-v-alt">' + (typeof partiRozet === 'function' ? partiRozet(p) : esc(p ? p.kisa : 'Bağımsız')) + (x.aktif === false ? ' <span class="kucuk">· eski vekil</span>' : '') + '</span>' +
      ((x.gorevler || []).length ? '<span class="ms-gorev">' + x.gorevler.map(function (g) { return '<em>' + esc(g) + '</em>'; }).join('') + '</span>' : '') +
      '<span class="ms-oz">ÖZ GEÇMİŞ ›</span></span></button>';
  }
  async function listeEkrani(o) {
    stil();
    L.o = o || {};
    var tum = L.o.donem != null && Number(L.o.donem) === 0;
    var baslik = L.o.partiAd || (tum ? 'Tüm dönem milletvekilleri' : L.o.donem != null ? donemAd(L.o.donem) + ' milletvekilleri' : 'Milletvekilleri');
    try { yukleniyor(baslik); } catch (_) {}
    try { L.l = await rpc('meclis_vekiller', { p_donem: L.o.donem == null ? null : Number(L.o.donem), p_parti: L.o.parti || null, p_bagimsiz: !!L.o.bagimsiz }); }
    catch (err) { iskelet(baslik, '<div class="bos">' + esc(hata(err)) + '</div>', { geri: true }); return; }
    var ust = tum ? 'Tüm dönem milletvekili listesi' : (L.o.partiAd ? buyuk(L.o.partiAd) : 'Milletvekili listesi');
    iskelet(baslik, '<div class="ms ms-liste"' + (L.o.renk ? ' style="--r:' + esc(L.o.renk) + '"' : '') + '>' + bant(L.o.donem != null && !tum ? donemAd(L.o.donem) : tum ? 'TBMM' : 'Güncel dönem', ust + ' · ' + L.l.length + ' kişi') +
      '<div class="kart ms-ara-k"><input type="search" class="ms-ara" placeholder="Ad ya da il ara" oninput="msAra(this.value)" autocapitalize="off"></div>' +
      '<div class="ms-vekiller">' + (L.l.map(function (x) { return vekilKart(x, tum); }).join('') || '<div class="kart"><div class="bos">Bu listede milletvekili yok.</div></div>') + '</div>' +
      '<div class="bos" id="msYok" style="display:none">Aramaya uyan milletvekili yok.</div></div>', { geri: true });
    tazele();
  }
  window.meclisVekilListesiEkrani = listeEkrani;
  window.msAra = function (q) {
    q = String(q || '').trim().toLocaleLowerCase('tr'); var n = 0;
    document.querySelectorAll('#icerik .ms-vekil').forEach(function (b) { var ok = !q || b.dataset.ad.indexOf(q) >= 0; b.style.display = ok ? '' : 'none'; if (ok) n++; });
    var y = document.getElementById('msYok'); if (y) y.style.display = n ? 'none' : '';
  };

  /* ---------------------------------------------------------- öz geçmiş */
  var AKTIF = { cevrimici: 'Şu an oyunda', bugun: 'Bugün oyundaydı', hafta: 'Bu hafta oyundaydı', uzun: 'Bir haftadır görünmüyor' };
  var DURUM = { oylamada: 'Oylamada', gorusmede: 'Görüşmede', ret: 'Reddedildi', dustu: 'Düştü', kaduk: 'Kadük', geri_cekildi: 'Geri çekildi', yururlukte: 'Yürürlükte' };
  function donemGrupla(l) {
    var g = {}, sira = [];
    (l || []).forEach(function (d) { var k = d.no + '|' + (d.il || '') + '|' + (d.parti ? d.parti.id : ''); if (!g[k]) { g[k] = { no: d.no, il: d.il, parti: d.parti, bas: d.bas, bit: d.bit, acik: !d.bit }; sira.push(k); }
      var x = g[k]; if (new Date(d.bas) < new Date(x.bas)) x.bas = d.bas; if (!d.bit) x.acik = true; else if (!x.acik && new Date(d.bit) > new Date(x.bit)) x.bit = d.bit; });
    return sira.map(function (k) { return g[k]; });
  }
  function ozgecmisHtml(v) {
    var p = v.parti, mv = v.mv, mc = v.meclis || {}, k = v.kursu || {};
    var unvan = mv ? buyuk(mv.il) + ' MİLLETVEKİLİ' : (v.donemler || []).length ? 'ESKİ MİLLETVEKİLİ' : 'MİLLETVEKİLİ DEĞİL';
    var oran = mc.oylanabilir ? Math.round(100 * Math.min(mc.oy, mc.oylanabilir) / mc.oylanabilir) : null;
    var kpi = function (b, s, t) { return '<div class="ms-kpi"><b>' + b + '</b><small>' + esc(s) + '</small>' + (t ? '<em>' + esc(t) + '</em>' : '') + '</div>'; };
    var donem = donemGrupla(v.donemler).map(function (d) {
      return '<div class="ms-donem"><span class="ms-d-no">' + esc(donemAd(d.no)) + '</span><span class="ms-d-g"><b>' + esc(d.il || '—') + ' Milletvekili</b><small>' + (typeof partiRozet === 'function' ? partiRozet(d.parti) : '') +
        ' · ' + gun(d.bas) + ' – ' + (d.acik ? 'görevde' : gun(d.bit)) + '</small></span></div>';
    }).join('') || '<p class="alt">Henüz Meclis\'e girmedi.</p>';
    var teklif = (mc.teklifler || []).map(function (t) { return '<div class="ms-teklif"><b>' + esc(t.baslik) + '</b><small>' + esc(DURUM[t.durum] || t.durum) + (t.no ? ' · Kanun no. ' + esc(t.no) : '') + '</small></div>'; }).join('');
    var gonderi = (k.son || []).map(function (g) { return '<div class="ms-gonderi"><p>' + esc(g.metin) + '</p><small>' + gun(g.zaman) + ' · ' + sayi(g.begeni) + ' beğeni · ' + sayi(g.yanit) + ' yanıt</small></div>'; }).join('');
    var gecmis = (v.gecmis || []).map(function (g) { return '<div class="kv"><span class="k">' + esc(g.makam) + '</span><span class="v kucuk">' + gun(g.bas) + (g.bit ? ' – ' + gun(g.bit) : ' – görevde') + '</span></div>'; }).join('');
    var kad = esc(v.kad).replace(/'/g, "\\'");
    return '<div class="ms ms-oz-ekran"' + (p ? ' style="--r:' + esc(p.renk) + '"' : '') + '>' +
      '<div class="kart ms-kimlik">' + foto(v.kad, p && p.renk, 112) + '<div class="ms-k-g"><b>' + esc(buyuk(v.kad)) + '</b><span class="ms-cizgi"></span><span class="ms-il">' + esc(unvan) + '</span>' +
        '<span>' + (typeof partiRozet === 'function' ? partiRozet(p) : '') + '</span><span class="kucuk">' + esc(AKTIF[v.aktif] || '') + '</span></div></div>' +
      ((v.gorevler || []).length ? '<div class="ms-gorev ms-gorev-b">' + v.gorevler.map(function (g) { return '<em>' + esc(g) + '</em>'; }).join('') + '</div>' : '') +
      '<div class="bolum-bas"><h2>Öz geçmiş</h2></div><div class="kart">' +
        (v.biyografi ? '<p class="ms-bio">' + esc(v.biyografi) + '</p>' : '<p class="alt">' + (v.ben ? 'Henüz öz geçmiş yazmadın.' : 'Henüz öz geçmiş yazmamış.') + '</p>') +
        '<div class="kv"><span class="k">Memleket</span><span class="v">' + esc(v.il || '—') + '</span></div>' +
        (mv ? '<div class="kv"><span class="k">Seçim bölgesi</span><span class="v">' + esc(mv.il) + ' · ' + esc(mv.nasil) + '</span></div>' : '') +
        '<div class="kv"><span class="k">Oyuna katılım</span><span class="v">' + gun(v.katilim) + '</span></div>' +
        '<div class="kv"><span class="k">Kıdem</span><span class="v">' + sayi(v.kidem) + '</span></div>' +
        (v.ben && typeof portreModal === 'function' ? '<button class="btn ikinci" style="margin-top:10px" onclick="portreModal()">Portre ve öz geçmişimi düzenle</button>' : '') + '</div>' +
      '<div class="bolum-bas"><h2>Yasama dönemleri</h2></div><div class="kart">' + donem + '</div>' +
      '<div class="bolum-bas"><h2>Meclis çalışmaları</h2></div><div class="kart"><div class="ms-kpiler">' +
        kpi(sayi(mc.teklif), 'kanun teklifi', mc.yasalasan ? sayi(mc.yasalasan) + ' yasalaştı' : '') +
        kpi(sayi(mc.oy), 'kanun oyu', oran != null ? '%' + oran + ' katılım' : '') +
        kpi(sayi(mc.yoklama), 'akşam oturumu', '') + kpi(sayi(mc.soru), 'soru önergesi', '') + kpi(sayi(mc.gensoru), 'gensoru', '') + '</div>' +
        (teklif ? '<div class="ms-alt-b">Son kanun teklifleri</div>' + teklif : '') + '</div>' +
      '<div class="bolum-bas"><h2>Kürsü hesabı</h2></div><div class="kart ms-kursu">' +
        '<div class="ms-kursu-ust"><span><b>@' + esc(v.kad) + '</b>' + (k.bio ? '<small>' + esc(k.bio) + '</small>' : '') + '</span><button class="btn yarim altin" onclick="msKursu(\'' + kad + '\')">Kürsü profili</button></div>' +
        '<div class="ms-kursu-say"><span><b>' + sayi(k.gonderi) + '</b> gönderi</span><span><b>' + sayi(k.takipci) + '</b> takipçi</span><span><b>' + sayi(k.takip) + '</b> takip</span></div>' +
        (gonderi || '<p class="alt">Henüz Kürsü\'de yazmadı.</p>') + '</div>' +
      (gecmis ? '<div class="bolum-bas"><h2>Diğer görevleri</h2></div><div class="kart">' + gecmis + '</div>' : '') +
      ((v.rozetler || []).length ? '<div class="bolum-bas"><h2>Rozet ve unvanlar</h2></div><div class="kart"><div class="rozetler">' + v.rozetler.map(function (r) { return '<span class="rozet altin" title="' + esc(r.aciklama || '') + '">' + esc(r.ad) + '</span>'; }).join('') + '</div></div>' : '') +
      '<div class="satir" style="margin-top:4px"><button class="btn yarim ikinci" onclick="oyuncuKart(\'' + kad + '\')">Oyuncu kartı</button>' +
        (v.ben ? '' : '<button class="btn yarim" onclick="ekranAc(()=>ozelEkrani(\'' + kad + '\'))">Özel mesaj</button>') + '</div></div>';
  }
  async function ozgecmisEkrani(kad) {
    stil();
    try { yukleniyor('Öz Geçmiş'); } catch (_) {}
    var v; try { v = await rpc('milletvekili_ozgecmis', { p_kad: kad }); }
    catch (err) { iskelet('Öz Geçmiş', '<div class="bos">' + esc(hata(err)) + '</div>', { geri: true }); return; }
    iskelet('Öz Geçmiş', ozgecmisHtml(v), { geri: true });
    tazele();
  }
  window.milletvekiliOzgecmisEkrani = ozgecmisEkrani;
  window.msOzgecmis = function (kad) { ekranAc(function () { return ozgecmisEkrani(kad); }); };
  window.msKursu = function (kad) { if (typeof window.kursuProfilEkrani === 'function') ekranAc(function () { return window.kursuProfilEkrani(kad); }); else { try { sekmeAc('sohbet'); } catch (_) {} } };

  /* ---------------------------------------------------------- Meclis sekmesine bağla */
  function bagla() {
    if (typeof meclisGenelHtml !== 'function' || meclisGenelHtml._ms) return false;
    var eski = meclisGenelHtml;
    var yeni = function (r) {
      stil();
      var h = eski.apply(this, arguments);
      var i = h.indexOf('<div class="kart"><h2>Partilerin sandalyeleri</h2>');
      return (i >= 0 ? h.slice(0, i) : h) + rehberKart(r);
    };
    yeni._ms = true;
    try { meclisGenelHtml = yeni; } catch (_) {}
    window.meclisGenelHtml = yeni;
    return true;
  }
  if (!bagla()) setTimeout(bagla, 1200);

  // Il il vekiller ve diğer listelerden açılan oyuncu kartına "Öz geçmiş" düğmesi (vekiller için)
  if (typeof oyuncuKart === 'function' && !oyuncuKart._ms) {
    var eskiKart = oyuncuKart;
    var yeniKart = async function (kad) {
      var r = await eskiKart.apply(this, arguments);
      try {
        var ms = document.querySelectorAll('.modal'), m = ms[ms.length - 1];
        if (m && !m.querySelector('.ms-kart-oz') && /Milletvekili|milletvekil/i.test(m.textContent || '')) {
          var b = document.createElement('button'); b.className = 'btn altin ms-kart-oz'; b.type = 'button'; b.textContent = 'Milletvekili öz geçmişi';
          b.onclick = function () { try { modalKapat(); } catch (_) {} window.msOzgecmis(kad); };
          var ilk = m.querySelector('.btn'); if (ilk) ilk.parentNode.insertBefore(b, ilk); else m.appendChild(b);
        }
      } catch (_) {}
      return r;
    };
    yeniKart._ms = true;
    try { oyuncuKart = yeniKart; } catch (_) {}
    window.oyuncuKart = yeniKart;
  }

  function aramaEkle() {
    var ind = window.SO_MENU_ARAMA_INDEKSI; if (!ind) return false;
    var hedef = ind.siyaset || ind.meclis || ind.gundem || ind.ekonomi; if (!hedef) return false;
    if (!hedef.some(function (x) { return x[1] === 'Sandalye Dağılımı'; }))
      hedef.unshift(['🪑', 'Sandalye Dağılımı', 'Meclisteki partilerin vekil sayıları, vekil listeleri ve öz geçmişler', "soMenuGit('meclisSandalyeEkrani')",
        'sandalye dağılımı meclis tbmm milletvekili vekil listesi parti üye sayısı öz geçmiş özgeçmiş dönem tüm dönem']);
    return true;
  }
  if (!aramaEkle()) setTimeout(aramaEkle, 1500);

  function stil() {
    if (document.getElementById('meclisSandalyeStil')) return;
    var css = [
      '.ms-bant{background:linear-gradient(90deg,#4b505c,#3b3f4a);border-radius:var(--r) var(--r) 0 0;padding:14px 16px;margin:-15px -15px 12px}.ms-ekran .ms-bant,.ms-liste .ms-bant{margin:0 0 12px;border-radius:var(--r)}',
      '.ms-bant small{display:block;font-size:11px;letter-spacing:.12em;color:#d9c79a;opacity:.85;text-transform:uppercase}.ms-bant b{display:block;font-size:15.5px;font-weight:500;letter-spacing:.08em;color:#e6d7ae;text-transform:uppercase;line-height:1.35;margin-top:3px}',
      '.ms-tablo{border-radius:10px;overflow:hidden;border:1px solid var(--line)}',
      '.ms-baslik{display:flex;justify-content:space-between;padding:11px 14px;background:rgba(255,255,255,.08);font-size:14px;color:var(--txt)}',
      '.ms-satir{display:flex;align-items:center;justify-content:space-between;gap:10px;width:100%;padding:12px 14px;border-top:1px solid var(--line);background:transparent;text-align:left;cursor:pointer;color:inherit;font:inherit}',
      '.ms-satir:nth-of-type(odd){background:rgba(255,255,255,.025)}.ms-satir:active{background:rgba(217,178,91,.10)}.ms-satir.bos{cursor:default;opacity:.7}',
      '.ms-ad{flex:1;min-width:0;display:flex;align-items:center;gap:8px;font-size:13px;font-weight:800;letter-spacing:.02em;color:#c9a65a;line-height:1.3}.ms-ad i{flex:none;width:9px;height:9px;border-radius:2px}.ms-satir.bos .ms-ad{color:var(--mut)}',
      '.ms-satir b{flex:none;font-size:15px;font-weight:600;color:var(--txt);font-variant-numeric:tabular-nums}',
      '.ms-toplam{display:flex;justify-content:space-between;padding:12px 14px;border-top:2px solid var(--line);font-weight:800;color:var(--txt)}.ms-toplam b{font-variant-numeric:tabular-nums}',
      '.ms-not{margin:8px 2px 0}.ms-bos{padding:16px;text-align:center;color:var(--mut)}',
      '.ms-sec{width:100%;margin-top:6px;padding:11px 12px;border-radius:10px;background:var(--bg);color:var(--txt);border:1px solid var(--line);font:inherit;font-size:15px}',
      '.ms-guncel{margin-top:8px}.ms-canli{color:#34c98a;animation:msNabiz 1.6s ease-in-out infinite}@keyframes msNabiz{50%{opacity:.35}}',
      '.ms-git{display:flex;align-items:center;gap:10px;width:100%;text-align:left;cursor:pointer}.ms-git span{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}.ms-git b{font-size:15px;color:var(--txt)}.ms-git small{font-size:12.5px;color:var(--mut)}.ms-git em{font-style:normal;color:#c9a65a;font-size:20px}',
      '.ms-ara{width:100%;padding:11px 12px;border-radius:10px;background:var(--bg);color:var(--txt);border:1px solid var(--line);font:inherit;font-size:15px}',
      '.ms-vekil{display:flex;gap:14px;width:100%;padding:16px 4px;border-bottom:1px solid var(--line);background:transparent;text-align:left;cursor:pointer;color:inherit;font:inherit}.ms-vekil:last-child{border-bottom:0}',
      '.ms-vekiller{background:var(--panel);border-radius:var(--r);padding:0 12px;margin-bottom:12px}',
      '.ms-foto{flex:none;display:block;border-radius:8px;overflow:hidden;box-shadow:0 6px 14px rgba(0,0,0,.35)}.ms-foto .portre,.ms-foto svg{width:100%!important;height:100%!important;margin:0!important;border:0!important;border-radius:0!important;display:block}',
      '.ms-v-g,.ms-k-g{flex:1;min-width:0;display:flex;flex-direction:column;gap:5px}.ms-v-g b,.ms-k-g b{font-size:14.5px;font-weight:800;letter-spacing:.09em;color:var(--txt);overflow-wrap:anywhere;line-height:1.3}',
      '.ms-cizgi{display:block;height:1px;background:var(--line);margin:2px 0}.ms-il{font-size:13px;letter-spacing:.03em;color:var(--txt);opacity:.85}',
      '.ms-v-alt{font-size:12.5px}.ms-gorev{display:flex;flex-wrap:wrap;gap:4px}.ms-gorev em{font-style:normal;font-size:11px;font-weight:700;color:#e8cf8f;background:rgba(217,178,91,.12);border:1px solid rgba(217,178,91,.3);padding:2px 7px;border-radius:6px}',
      '.ms-gorev-b{margin:-4px 0 12px}.ms-oz{align-self:flex-end;font-size:12px;font-weight:700;letter-spacing:.12em;color:#c9a65a;margin-top:2px}',
      '.ms-kimlik{display:flex;gap:16px;align-items:center;border-top:3px solid var(--r,#c9a65a)}.ms-k-g b{font-size:17px}',
      '.ms-bio{font-size:15px;line-height:1.55;margin:0 0 10px;color:var(--txt)}',
      '.ms-donem{display:flex;gap:12px;align-items:flex-start;padding:10px 0;border-bottom:1px solid var(--line)}.ms-donem:last-child{border-bottom:0}',
      '.ms-d-no{flex:none;min-width:86px;font-size:12px;font-weight:800;letter-spacing:.04em;color:#c9a65a;padding-top:2px}.ms-d-g{flex:1;min-width:0;display:flex;flex-direction:column;gap:3px}.ms-d-g b{font-size:14px;color:var(--txt)}.ms-d-g small{font-size:12px;color:var(--mut)}',
      '.ms-kpiler{display:grid;grid-template-columns:repeat(auto-fit,minmax(92px,1fr));gap:8px}.ms-kpi{background:var(--bg);border-radius:10px;padding:10px 8px;text-align:center}.ms-kpi b{display:block;font-size:20px;color:var(--txt)}.ms-kpi small{font-size:11.5px;color:var(--mut)}.ms-kpi em{display:block;font-style:normal;font-size:11px;color:#34c98a;margin-top:2px}',
      '.ms-alt-b{font-size:12px;font-weight:700;color:var(--mut);margin:14px 0 4px;text-transform:uppercase;letter-spacing:.05em}.ms-teklif{padding:8px 0;border-bottom:1px solid var(--line)}.ms-teklif:last-child{border-bottom:0}.ms-teklif b{display:block;font-size:13.5px;line-height:1.35;color:var(--txt)}.ms-teklif small{font-size:12px;color:var(--mut)}',
      '.ms-kursu-ust{display:flex;gap:10px;align-items:center}.ms-kursu-ust span{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}.ms-kursu-ust b{font-size:15px;color:var(--txt);overflow-wrap:anywhere}.ms-kursu-ust small{font-size:12.5px;color:var(--mut)}.ms-kursu-ust .btn{flex:none;width:auto;padding:9px 14px;margin:0}',
      '.ms-kursu-say{display:flex;gap:14px;flex-wrap:wrap;margin:10px 0 4px;font-size:13px;color:var(--mut)}.ms-kursu-say b{color:var(--txt)}',
      '.ms-gonderi{padding:10px 0;border-top:1px solid var(--line)}.ms-gonderi p{margin:0;font-size:14px;line-height:1.45;color:var(--txt);white-space:pre-wrap;overflow-wrap:anywhere}.ms-gonderi small{font-size:11.5px;color:var(--mut)}'
    ];
    var st = document.createElement('style'); st.id = 'meclisSandalyeStil'; st.textContent = css.join('\n'); (document.head || document.documentElement).appendChild(st);
  }
})();
