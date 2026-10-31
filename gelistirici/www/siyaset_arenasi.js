/* =====================================================================
   SİYASET ARENASI (31.10.2026) — oyuncuyu canlı tutan katman.
   Sunucu: 154_siyaset_arenasi.sql
   Sekmeler: Bugün (21:00 Genel Kurul, yoklama, oylamalar) · Bekleyen işler ·
   Parti hedefleri · Sıralamalar · Gölge Kabine. Gündem'e kısa kart ekler;
   oturum açıkken vekilin yoklamasını kendiliğinden alır.
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_SIYASET_ARENASI_V1) return;
  window.SO_SIYASET_ARENASI_V1 = true;
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var sayi = function (n) { return Number(n || 0).toLocaleString('tr-TR', { maximumFractionDigits: 1 }); };
  var kisaTl = function (n) { n = Number(n || 0); return n >= 1e6 ? (n / 1e6).toLocaleString('tr-TR', { maximumFractionDigits: 1 }) + ' mn ₺' : n >= 1e4 ? Math.round(n / 1e3).toLocaleString('tr-TR') + ' bin ₺' : Math.round(n).toLocaleString('tr-TR') + ' ₺'; };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var uyar = function (m, kotu) { try { toast(m, kotu); } catch (_) {} };
  var rpc = function (ad, arg) { return API.rpc(ad, arg || {}); };
  var saat = function (t) { try { return new Date(t).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Istanbul' }); } catch (_) { return ''; } };
  function kalan(t) {
    var ms = new Date(t).getTime() - Date.now(); if (!(ms > 0)) return 'şimdi';
    var dk = Math.round(ms / 60000); if (dk < 60) return dk + ' dk';
    var s = Math.floor(dk / 60); if (s < 48) return s + ' sa ' + (dk % 60 ? (dk % 60) + ' dk' : '');
    return Math.round(s / 24) + ' gün';
  }
  var A = { sekme: 'bugun', siraTur: 'siyasetci', v: {} };
  var SEKMELER = [['bugun', 'Bugün'], ['isler', 'Bekleyen'], ['hedef', 'Parti hedefi'], ['sira', 'Sıralamalar'], ['golge', 'Gölge Kabine']];

  function cerceve(ic) {
    return '<div class="sa">' +
      '<div class="segment sa-seg">' + SEKMELER.map(function (s) {
        var rozet = s[0] === 'isler' && A.v.isler && A.v.isler.length ? ' <i>' + A.v.isler.length + '</i>' : '';
        return '<button type="button" class="' + (A.sekme === s[0] ? 'aktif' : '') + '" onclick="saSekme(\'' + s[0] + '\')">' + s[1] + rozet + '</button>';
      }).join('') + '</div>' + ic + '</div>';
  }

  /* --------------------------------------------------------- 1) BUGÜN */
  function bugunHtml(o) {
    var acik = !!o.acik, bitti = !acik && new Date(o.bit) < new Date();
    var durum = acik ? '<span class="sa-canli">● CANLI</span> Genel Kurul toplantıda · ' + kalan(o.bit) + ' kaldı'
      : bitti ? 'Bugünkü oturum bitti. Sonraki: yarın 21:00' : 'Bu akşam 21:00\'de toplanıyor · ' + kalan(o.bas) + ' sonra';
    var yok = '';
    if (o.vekil) {
      yok = o.yoklamada ? '<div class="sa-tamam">✓ Yoklamadasın. Oyunu kullan, tartışmaya katıl.</div>'
        : acik ? '<button class="btn altin" onclick="saYoklama()">Yoklamaya katıl (+1 kıdem)</button>'
        : '<p class="alt">Vekil olarak 21:00–22:00 arasında oyunu açman yoklama için yeterli; katılmayanların adı herkese açık listelenir.</p>';
    } else {
      yok = '<p class="alt">Oturumu canlı izleyebilirsin. Vekiller oylamada; kim geldi, kim gelmedi burada görünür.</p>';
    }
    var oyl = (o.oylamalar || []).map(function (k) {
      var top = Number(k.kabul) + Number(k.ret) + Number(k.cekimser) || 1;
      var oy = function (d, ad) { return '<button type="button" class="sa-oy ' + d + (k.oyum === d ? ' secili' : '') + '" onclick="saOy(' + k.id + ',\'' + d + '\')">' + ad + '</button>'; };
      return '<div class="sa-kanun"><b>' + esc(k.baslik) + '</b><small>' + (k.bit ? 'Oylama ' + saat(k.bit) + '\'de bitiyor (' + kalan(k.bit) + ')' : 'Oylamada') + '</small>' +
        '<div class="sa-bar"><i class="k" style="width:' + (100 * k.kabul / top) + '%"></i><i class="r" style="width:' + (100 * k.ret / top) + '%"></i><i class="c" style="width:' + (100 * k.cekimser / top) + '%"></i></div>' +
        '<div class="sa-say"><span>Kabul ' + k.kabul + '</span><span>Ret ' + k.ret + '</span><span>Çekimser ' + k.cekimser + '</span></div>' +
        (o.vekil ? '<div class="sa-oylar">' + oy('kabul', 'Kabul') + oy('ret', 'Ret') + oy('cekimser', 'Çekimser') + '</div>' : '') + '</div>';
    }).join('') || '<div class="bos">Şu an oylamada kanun yok.</div>';
    var kat = (o.katilan || []).map(function (x) { return '<span class="sa-kisi" style="--r:' + esc(x.renk || '#8f9bbd') + '">' + esc(x.kad) + (x.parti ? ' <small>' + esc(x.parti) + '</small>' : '') + '</span>'; }).join('');
    var gel = (o.katilmayan || []);
    return '<div class="kart sa-oturum"><small class="sa-ust">TBMM Genel Kurulu · her akşam 21:00–22:00</small><div class="sa-durum">' + durum + '</div>' +
      '<div class="sa-kpi"><div><b>' + (o.katilan || []).length + '</b><small>hazır</small></div><div><b>' + (o.vekil_sayisi || 0) + '</b><small>vekil</small></div><div><b>' + (o.oylamalar || []).length + '</b><small>oylama</small></div></div>' + yok + '</div>' +
      '<div class="bolum-bas"><h2>Oylamadaki kanunlar</h2></div>' + oyl +
      '<div class="bolum-bas"><h2>Yoklamada hazır bulunanlar</h2></div><div class="kart">' + (kat || '<p class="alt">Henüz kimse yok.</p>') + '</div>' +
      (gel.length ? '<div class="bolum-bas"><h2>Katılmayan vekiller</h2></div><div class="kart sa-gelmeyen">' + gel.map(esc).join(' · ') + '</div>' : '') +
      '<p class="alt sa-dip">Seçim gecesi canlı yayını, canlı mitingler ve Ülke Kriz Merkezi de oyunun canlı anlarıdır; hepsi Gündem\'de duyurulur.</p>';
  }
  window.saYoklama = async function (sessiz) {
    try {
      var r = await rpc('meclis_yoklama');
      if (!sessiz || Number(r && r.kidem) > 0) uyar('Genel Kurul yoklamasına katıldın' + (Number(r && r.kidem) > 0 ? ' · +' + sayi(r.kidem) + ' kıdem' : '') + '.');
      if (!sessiz) await yukle('bugun');
    } catch (err) { if (!sessiz) uyar(hata(err), true); }
  };
  window.saOy = async function (id, oy) {
    try { await rpc('kanun_oy', { p_id: id, p_oy: oy }); uyar('Oyun kaydedildi.'); await yukle(A.sekme); }
    catch (err) { uyar(hata(err), true); }
  };

  /* --------------------------------------------------------- 2) BEKLEYEN İŞLER */
  var IS_AD = { juri: 'Oy ver', heyet: 'Karar ver', aym: 'Adliye', secim_itiraz: 'Adliye', oylama: 'Oy ver', odenek: 'Karar ver', kurucu: 'Yanıtla', ittifak: 'Partiye git', golge: 'Kabineyi kur', hedef: 'Hedefe bak' };
  function islerHtml(l) {
    if (!l || !l.length) return '<div class="kart"><div class="bos">Seni bekleyen bir iş yok. Kürsü\'de gündemi takip et ya da partinin hedefine katkı ver.</div></div>';
    return '<p class="alt sa-dip">Başka oyuncular senin kararını bekliyor. Cevap vermezsen süre dolar.</p>' + l.slice().sort(function (a, b) { return (a.oncelik || 9) - (b.oncelik || 9); }).map(function (x, i) {
      return '<button type="button" class="kart sa-is o' + (x.oncelik || 3) + '" onclick="saIsGit(' + i + ')"><span class="sa-is-g"><b>' + esc(x.baslik) + '</b><small>' + esc(x.alt || '') +
        (x.bit ? ' · ' + kalan(x.bit) + ' kaldı' : '') + '</small></span><em>' + (IS_AD[x.tur] || 'Aç') + ' ›</em></button>';
    }).join('');
  }
  window.saIsGit = function (i) {
    var l = (A.v.isler || []).slice().sort(function (a, b) { return (a.oncelik || 9) - (b.oncelik || 9); }), x = l[i]; if (!x) return;
    if (x.git === 'dava') { if (typeof adliyeDosya === 'function') return ekranAc(function () { return adliyeDosya(x.id); }); try { return sekmeAc('adliye'); } catch (_) { return; } }
    if (x.git === 'adliye') { try { return sekmeAc('adliye'); } catch (_) { return; } }
    if (x.git === 'meclis') return saSekme('bugun');
    if (x.git === 'golge') return saSekme('golge');
    if (x.git === 'hedef') return saSekme('hedef');
    if (x.git === 'kurucu' && typeof kurucuDavetModal === 'function') return kurucuDavetModal();
    if (x.git === 'butce' && typeof window.devletButcesiEkrani === 'function') return ekranAc(window.devletButcesiEkrani);
    try { sekmeAc(x.git === 'butce' ? 'devlet' : 'parti'); } catch (_) {}
  };

  /* --------------------------------------------------------- 3) PARTİ HEDEFLERİ */
  function hedefHtml(v) {
    if (!v || !v.parti) return '<div class="kart"><div class="bos">Bir partiye üye olunca haftalık takım hedefleri burada görünür.</div></div>';
    var h = (v.hedefler || []).map(function (x) {
      var y = Math.min(100, 100 * Number(x.ilerleme) / Math.max(1, Number(x.hedef)));
      return '<div class="kart sa-hedef' + (x.tamam ? ' tamam' : '') + '"><div class="sa-h-ust"><b>' + esc(x.ad) + '</b><span>' + (x.tamam ? '✓ Tamamlandı' : x.ilerleme + ' / ' + x.hedef) + '</span></div>' +
        '<div class="sa-ilerleme"><i style="width:' + y + '%"></i></div><small>Ödül: parti kasasına ' + kisaTl(x.odul) + ' · katkı veren her üyeye +1 kıdem</small></div>';
    }).join('') || '<div class="kart"><div class="bos">Bu haftanın hedefleri birkaç dakika içinde belirlenir. En az 2 aktif üyesi olan partilere hedef verilir.</div></div>';
    var u = (v.ayin_uyeleri || []).slice(0, 10).map(function (x, i) {
      return '<div class="sa-satir"><span class="sa-no">' + (i + 1) + '</span><span class="sa-ad">' + esc(x.kad) + (i === 0 ? ' <em>Ayın en aktif üyesi</em>' : '') + '</span><b>' + sayi(x.puan) + '</b></div>';
    }).join('') || '<p class="alt">Bu ay henüz puan yok.</p>';
    return '<div class="kart sa-parti" style="--r:' + esc(v.parti.renk || '#d9b25b') + '"><small class="sa-ust">' + esc(v.parti.ad) + ' · haftalık takım hedefi</small><div class="sa-durum">Hafta ' + kalan(v.bitis) + ' sonra bitiyor</div>' +
      '<p class="alt">Hedefler tek kişiyle değil, ekiple tamamlanır. Pazartesi yenileri gelir.</p></div>' + h +
      '<div class="bolum-bas"><h2>Partide bu ayın en aktifleri</h2></div><div class="kart">' + u + '<p class="alt sa-dip">Puan: bu ay kazanılan kıdem + seçimlerde kullanılan her oy için 2.</p></div>';
  }

  /* --------------------------------------------------------- 4) SIRALAMALAR */
  var SIRA = [['siyasetci', 'Siyasetçi', 'Ayın Siyasetçisi'], ['vekil', 'Vekil', 'Ayın Vekili'], ['is_insani', 'İş İnsanı', 'Ayın İş İnsanı'], ['kalem', 'Kalem', 'Ayın Kalemi']];
  function siraHtml(v) {
    if (!v) return '';
    var t = SIRA.filter(function (s) { return s[0] === A.siraTur; })[0] || SIRA[0];
    var l = (v[t[0]] || []).map(function (x, i) {
      var d = t[0] === 'is_insani' ? kisaTl(x.deger) : sayi(x.deger);
      return '<div class="sa-satir' + (i < 3 ? ' ilk' : '') + '"><span class="sa-no">' + (i < 3 ? ['🥇', '🥈', '🥉'][i] : i + 1) + '</span><span class="sa-ad">' + esc(x.kad) +
        (x.parti ? ' <small style="color:' + esc(x.renk || '#8f9bbd') + '">' + esc(x.parti) + '</small>' : '') + '</span><b>' + d + '</b></div>';
    }).join('') || '<p class="alt">Bu ay henüz sıralama oluşmadı.</p>';
    var notlar = { siyasetci: 'Bu ay kazanılan kıdem + seçimlerde her oy için 2 puan.', vekil: 'Kanun oyları + akşam Genel Kurul yoklamaları.', is_insani: 'Sahip olunan şirketlerin toplam değeri.', kalem: 'Kürsü gönderilerinin beğenisi − beğenmeme + başkalarından gelen yanıt ×2.' };
    var od = (v.odullu || []).map(function (x) { return '<span class="sa-kisi">' + esc(x.ad) + ' · <b>' + esc(x.kad) + '</b> <small>' + esc(x.donem) + '</small></span>'; }).join('');
    var hk = (v.haftanin_kalemi || []).map(function (x) { return '<span class="sa-kisi">' + esc(x.kad) + ' <small>' + esc(x.donem) + '</small></span>'; }).join('');
    return '<div class="kart"><small class="sa-ust">Sezon ' + esc(v.donem) + (v.canli ? ' · canlı' : '') + '</small><div class="sa-durum">Ay sonuna ' + kalan(v.bit) + '</div>' +
      '<p class="alt">Her ayın 1\'inde birinciler "' + esc(t[2]) + '" gibi unvan alır: oyuncu kartında rozet, +5 kıdem ve gazetede haber.</p>' +
      '<div class="segment sa-seg2">' + SIRA.map(function (s) { return '<button type="button" class="' + (s[0] === t[0] ? 'aktif' : '') + '" onclick="saSiraTur(\'' + s[0] + '\')">' + s[1] + '</button>'; }).join('') + '</div></div>' +
      '<div class="kart">' + l + '<p class="alt sa-dip">' + esc(notlar[t[0]]) + '</p></div>' +
      '<div class="bolum-bas"><h2>Haftanın Kalemi</h2></div><div class="kart">' + (hk || '<p class="alt">Her pazartesi Kürsü\'de geçen haftanın en çok konuşulan yazarı seçilir (+2 kıdem).</p>') + '</div>' +
      (od ? '<div class="bolum-bas"><h2>Son ödüller</h2></div><div class="kart">' + od + '</div>' : '') +
      '<p class="alt sa-dip">Kalıcı unvanlar: Kıdemli Vekil (3 dönem vekillik), Üç Dönem Başkan, Gölge Bakan, Meclis Müdavimi (20 akşam oturumu).</p>';
  }
  window.saSiraTur = function (k) { A.siraTur = k; ciz(); };

  /* --------------------------------------------------------- 5) GÖLGE KABİNE */
  function golgeHtml(v) {
    if (!v || !v.parti) return '<div class="kart"><div class="bos">Mecliste ana muhalefet partisi oluşunca gölge kabine burada kurulur.</div></div>';
    var b = (v.bakanliklar || []).map(function (x) {
      var dugme = v.gb_benim ? '<button type="button" class="sa-kucuk" onclick="saGolgeAta(\'' + esc(x.kod) + '\')">' + (x.golge ? 'Değiştir' : 'Ata') + '</button>' : '';
      var rapor = (x.golge_benim || v.gb_benim) ? '<button type="button" class="sa-kucuk altin" onclick="saRaporYaz(\'' + esc(x.kod) + '\')">Rapor yaz</button>' : '';
      return '<div class="sa-bak"><div class="sa-bak-g"><b>' + esc(x.ad) + '</b><small>Bakan: ' + esc(x.bakan || 'atanmadı') + '</small><small class="g">Gölge: ' + esc(x.golge || '—') + '</small></div><div class="sa-bak-d">' + dugme + rapor + '</div></div>';
    }).join('');
    var r = (v.raporlar || []).map(function (x) {
      return '<div class="kart sa-rapor"><small class="sa-ust">' + esc(x.bakanlik_ad) + ' · ' + esc(x.yazar) + (x.parti ? ' (' + esc(x.parti) + ')' : '') + '</small><b>' + esc(x.baslik) + '</b><p>' + esc(x.metin) + '</p></div>';
    }).join('') || '<div class="kart"><div class="bos">Henüz denetim raporu yayımlanmadı.</div></div>';
    return '<div class="kart sa-parti" style="--r:' + esc(v.parti.renk || '#d9b25b') + '"><small class="sa-ust">Ana muhalefet · ' + esc(v.parti.ad) + '</small><div class="sa-durum">Gölge Kabine</div>' +
      '<p class="alt">Ana muhalefetin genel başkanı her bakanlığa bir gölge bakan atar. Gölge bakan bakanlığı izler, altı saatte bir denetim raporu yayımlar (+1 kıdem); rapor gerçek bakana bildirim olarak gider.</p></div>' +
      '<div class="kart">' + b + '</div><div class="bolum-bas"><h2>Denetim raporları</h2></div>' + r;
  }
  window.saGolgeAta = function (kod) {
    var m = modal('<h3 style="font-size:19px;font-weight:800">Gölge bakan ata</h3><p class="alt">Partinden bir üyenin kullanıcı adını yaz.</p>' +
      '<div class="alan"><label>Kullanıcı adı</label><input id="saKad" maxlength="40" autocomplete="off"></div>' +
      '<button class="btn altin" id="saAtaOk">Ata</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    var kok = m && m.querySelector ? m : document;
    kok.querySelector('#saAtaOk').onclick = async function () {
      this.disabled = true;
      try { await rpc('golge_ata', { p_bakanlik: kod, p_kad: kok.querySelector('#saKad').value }); modalKapat(); uyar('Gölge bakan atandı.'); await yukle('golge'); }
      catch (err) { this.disabled = false; uyar(hata(err), true); }
    };
  };
  window.saRaporYaz = function (kod) {
    var m = modal('<h3 style="font-size:19px;font-weight:800">Denetim raporu</h3><p class="alt">Bakanlığın icraatını, bütçesini, ihalelerini değerlendir. Rapor Gündem\'de yayımlanır ve bakana bildirilir.</p>' +
      '<div class="alan"><label>Başlık</label><input id="saRB" maxlength="90"></div><div class="alan"><label>Rapor (en az 40 karakter)</label><textarea id="saRM" maxlength="1200" rows="6"></textarea></div>' +
      '<button class="btn altin" id="saROk">Yayımla</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    var kok = m && m.querySelector ? m : document;
    kok.querySelector('#saROk').onclick = async function () {
      this.disabled = true;
      try { var r = await rpc('golge_rapor_yaz', { p_bakanlik: kod, p_baslik: kok.querySelector('#saRB').value, p_metin: kok.querySelector('#saRM').value }); modalKapat();
        uyar('Rapor yayımlandı' + (Number(r && r.kidem) > 0 ? ' · +1 kıdem' : '') + '.'); await yukle('golge'); }
      catch (err) { this.disabled = false; uyar(hata(err), true); }
    };
  };

  /* --------------------------------------------------------- ekran */
  var RPC = { bugun: 'meclis_oturum', isler: 'bekleyen_islerim', hedef: 'parti_hedefleri', sira: 'siralamalar', golge: 'golge_kabine' };
  var CIZ = { bugun: bugunHtml, isler: islerHtml, hedef: hedefHtml, sira: siraHtml, golge: golgeHtml };
  function ciz() {
    var ic = document.querySelector('#icerik .sa');
    var html = cerceve(CIZ[A.sekme](A.v[A.sekme]));
    if (ic) ic.outerHTML = html; else iskelet('Siyaset Arenası', html, { geri: true });
  }
  async function yukle(s) {
    A.sekme = s || A.sekme;
    try {
      var istek = [rpc(RPC[A.sekme])];
      if (A.sekme !== 'isler') istek.push(rpc('bekleyen_islerim').catch(function () { return A.v.isler || []; }));
      var r = await Promise.all(istek);
      A.v[A.sekme] = r[0]; if (r[1]) A.v.isler = r[1];
      ciz();
    } catch (err) { iskelet('Siyaset Arenası', '<div class="bos">' + esc(hata(err)) + '</div>', { geri: true }); }
  }
  window.saSekme = function (s) { if (!document.querySelector('#icerik .sa')) return ekranAc(function () { return ekran(s); }); return yukle(s); };
  async function ekran(s) {
    stil();
    try { yukleniyor('Siyaset Arenası'); } catch (_) {}
    await yukle(s || 'bugun');
  }
  window.siyasetArenasiEkrani = ekran;

  /* --------------------------------------------------------- Gündem kartı + kendiliğinden yoklama */
  async function gundemEkle() {
    try {
      stil();
      var ic = document.getElementById('icerik'); if (!ic || ic.querySelector('.sa-gk')) return;
      var r = await Promise.all([rpc('meclis_oturum'), rpc('bekleyen_islerim').catch(function () { return []; })]);
      var o = r[0] || {}, l = r[1] || []; A.v.bugun = o; A.v.isler = l;
      ic = document.getElementById('icerik'); if (!ic || ic.querySelector('.sa-gk')) return;
      var ust = o.acik ? '<span class="sa-canli">● CANLI</span> Genel Kurul toplantıda' : new Date(o.bit) < new Date() ? 'Genel Kurul yarın 21:00\'de' : 'Genel Kurul bu akşam 21:00 · ' + kalan(o.bas) + ' sonra';
      var alt = (l.length ? l.length + ' iş seni bekliyor' : 'Bekleyen işin yok') + ' · ' + (o.oylamalar || []).length + ' oylama · sıralamalar ve gölge kabine';
      var yargi = l.filter(function (x) { return x.tur === 'juri' || x.tur === 'heyet'; })[0];
      var d = document.createElement('div');
      if (yargi) {
        // Yargı görevi Gündem'in en üstünde ayrı ve kırmızı kart: "atandığımı bilmiyordum" olmasın
        var y = document.createElement('div');
        y.innerHTML = '<button type="button" class="kart sa-gk sa-yargi" onclick="saYargiGit()"><span class="sa-is-g"><small>' + (yargi.tur === 'juri' ? 'Jüri görevin var' : 'Yüksek Mahkeme görevin var') + '</small><b>' + esc(yargi.baslik.replace('⚖️ ', '')) + '</b><small>' +
          esc(yargi.alt || '') + (yargi.bit ? ' · ' + kalan(yargi.bit) + ' kaldı' : '') + '</small></span><em>Oy ver ›</em></button>';
        A.yargi = yargi;
        ic.insertBefore(y.firstChild, ic.firstChild);
      }
      d.innerHTML = '<button type="button" class="kart sa-gk' + (o.acik ? ' canli' : '') + '" onclick="ekranAc(siyasetArenasiEkrani)"><span class="sa-is-g"><small>Siyaset Arenası</small><b>' + ust + '</b><small>' + esc(alt) + '</small></span>' +
        (l.length ? '<i class="sa-rozet">' + l.length + '</i>' : '') + '<em>›</em></button>';
      var yk = ic.querySelector('.sa-yargi'); if (yk && yk.nextSibling) ic.insertBefore(d.firstChild, yk.nextSibling); else ic.insertBefore(d.firstChild, ic.firstChild);
      if (o.acik && o.vekil && !o.yoklamada) saYoklama(true);
    } catch (_) { /* modül kurulmadıysa sessiz */ }
  }
  window.saGundemEkle = gundemEkle;
  window.saYargiGit = function () { var x = A.yargi; if (!x) return; if (typeof adliyeDosya === 'function') return ekranAc(function () { return adliyeDosya(x.id); }); try { sekmeAc('adliye'); } catch (_) {} };
  if (typeof gundemEkrani === 'function') {
    var eskiG = gundemEkrani;
    window.gundemEkrani = gundemEkrani = async function () { var r = await eskiG.apply(this, arguments); await gundemEkle(); return r; };
    if (typeof EKRAN === 'object' && EKRAN) EKRAN.gundem = function () { return gundemEkrani(); };
  }
  // Oturum açıkken uygulama açık duran vekilin yoklaması (5 dakikada bir kontrol)
  var sonKontrol = 0;
  setInterval(async function () {
    if (document.hidden || Date.now() - sonKontrol < 280000) return;
    var h = new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Istanbul' })).getHours(); if (h !== 21) return;
    sonKontrol = Date.now();
    try { var o = await rpc('meclis_oturum'); if (o && o.acik && o.vekil && !o.yoklamada) saYoklama(true); } catch (_) {}
  }, 60000);

  function aramaEkle() {
    var ind = window.SO_MENU_ARAMA_INDEKSI; if (!ind) return false;
    var hedef = ind.siyaset || ind.meclis || ind.gundem || ind.ekonomi; if (!hedef) return false;
    if (!hedef.some(function (x) { return x[1] === 'Siyaset Arenası'; }))
      hedef.unshift(['🏛️', 'Siyaset Arenası', 'Akşam Genel Kurulu, bekleyen işler, parti hedefleri, sıralamalar, gölge kabine', "soMenuGit('siyasetArenasiEkrani')",
        'arena meclis genel kurul yoklama oturum oylama kanun bekleyen iş hedef parti takım sıralama ödül unvan ayın siyasetçisi kalem gölge kabine muhalefet rapor']);
    return true;
  }
  if (!aramaEkle()) setTimeout(aramaEkle, 1500);

  // Bildirimlerde arena konuları için bağlantı
  function bildirimBagla() {
    var ic = document.getElementById('icerik'); if (!ic) return;
    ic.querySelectorAll('.kisisel').forEach(function (k) {
      if (k.querySelector('.sa-bag') || !/Genel Kurul|gölge|Gölge|haftalık hedef|oylaması .* bitiyor|ödülünü kazandın/.test(k.textContent || '')) return;
      var btn = document.createElement('button'); btn.type = 'button'; btn.className = 'er-bag sa-bag'; btn.textContent = 'Siyaset Arenası ›';
      var t = k.textContent || '';
      var s = /gölge|Gölge/.test(t) ? 'golge' : /haftalık hedef/.test(t) ? 'hedef' : /ödülünü/.test(t) ? 'sira' : 'bugun';
      btn.onclick = function (ev) { ev.stopPropagation(); ekranAc(function () { return ekran(s); }); };
      var alt = k.querySelector('.bildirim-alt'); (alt && alt.parentNode ? alt.parentNode : k).appendChild(btn);
    });
  }
  if (typeof iskelet === 'function') {
    var eskiIskelet = iskelet;
    iskelet = window.iskelet = function (baslik) {
      var r = eskiIskelet.apply(this, arguments);
      try { if (baslik === 'Bildirimler') setTimeout(bildirimBagla, 60); } catch (_) {}
      return r;
    };
  }

  function stil() {
    if (document.getElementById('siyasetArenasiStil')) return;
    var css = [
      '.sa .sa-seg{margin-bottom:12px}.sa .sa-seg button{flex:none;padding:8px 11px;white-space:nowrap}.sa .sa-seg button i,.sa-rozet{font-style:normal;display:inline-grid;place-items:center;min-width:18px;height:18px;padding:0 5px;border-radius:9px;background:#e5484d;color:#fff;font-size:11px;font-weight:800;margin-left:3px}',
      '.sa .sa-seg2{margin-top:10px}.sa .sa-seg2 button{padding:7px 4px;font-size:12.5px}',
      '.sa-ust{display:block;font-size:11.5px;font-weight:700;letter-spacing:.03em;color:#d9b25b;text-transform:uppercase}',
      '.sa-durum{font-family:var(--disp);font-size:18px;font-weight:800;color:var(--txt);margin:4px 0 6px;line-height:1.3}',
      '.sa-canli{color:#ff5d62;font-weight:800;animation:saNabiz 1.4s ease-in-out infinite}@keyframes saNabiz{50%{opacity:.45}}',
      '.sa-kpi{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:10px 0}.sa-kpi div{background:var(--bg);border-radius:10px;padding:8px;text-align:center}.sa-kpi b{display:block;font-size:19px;color:var(--txt)}.sa-kpi small{font-size:11.5px;color:var(--mut)}',
      '.sa-tamam{padding:11px;border-radius:10px;background:rgba(52,201,138,.13);color:var(--good);font-weight:700;font-size:14px;text-align:center}',
      '.sa-kanun{background:var(--panel);border-radius:var(--r);padding:13px 14px;margin-bottom:10px}.sa-kanun b{display:block;font-size:14.5px;line-height:1.35;color:var(--txt)}.sa-kanun small{display:block;font-size:12px;color:var(--mut);margin-top:3px}',
      '.sa-bar{display:flex;height:7px;border-radius:4px;overflow:hidden;background:var(--bg);margin-top:9px}.sa-bar i{display:block;height:100%}.sa-bar .k{background:#34c98a}.sa-bar .r{background:#e5484d}.sa-bar .c{background:#8f9bbd}',
      '.sa-say{display:flex;gap:12px;font-size:12px;color:var(--mut);margin-top:5px;flex-wrap:wrap}',
      '.sa-oylar{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-top:10px}.sa-oy{padding:9px 4px;border-radius:9px;font-weight:700;font-size:13px;background:var(--bg);color:var(--txt);border:1px solid transparent}',
      '.sa-oy.kabul.secili{border-color:#34c98a;color:#34c98a}.sa-oy.ret.secili{border-color:#e5484d;color:#e5484d}.sa-oy.cekimser.secili{border-color:#8f9bbd}',
      '.sa-kisi{display:inline-flex;align-items:baseline;gap:4px;padding:4px 9px;margin:3px 4px 3px 0;border-radius:8px;background:var(--bg);font-size:12.5px;color:var(--txt);border-left:3px solid var(--r,#8f9bbd)}.sa-kisi small{color:var(--mut);font-size:11px}',
      '.sa-gelmeyen{font-size:13px;line-height:1.6;color:var(--mut)}.sa-dip{margin:8px 2px 14px;font-size:12.5px}',
      '.sa-gk.sa-yargi{border-left-color:#e5484d;background:linear-gradient(90deg,rgba(229,72,77,.14),var(--panel) 60%)}.sa-gk.sa-yargi small:first-child{color:#ff8a8d}.sa-gk.sa-yargi em{color:#ff8a8d}',
      '.sa-is,.sa-gk{display:flex;align-items:center;gap:10px;width:100%;text-align:left;cursor:pointer;border-left:3px solid #d9b25b}.sa-is.o1{border-left-color:#e5484d}.sa-is.o2{border-left-color:#d9b25b}.sa-is.o3{border-left-color:#5b8def}',
      '.sa-is-g{flex:1;min-width:0;display:flex;flex-direction:column;gap:3px}.sa-is-g b{font-size:14.5px;line-height:1.35;color:var(--txt)}.sa-is-g small{font-size:12px;color:var(--mut);line-height:1.4}',
      '.sa-is em,.sa-gk em{flex:none;font-style:normal;font-weight:700;font-size:13px;color:#d9b25b}.sa-gk.canli{border-left-color:#ff5d62}.sa-gk small:first-child{color:#d9b25b;font-weight:700;text-transform:uppercase;font-size:11px;letter-spacing:.03em}',
      '.sa-parti{border-top:3px solid var(--r)}',
      '.sa-hedef .sa-h-ust{display:flex;justify-content:space-between;gap:10px;align-items:baseline}.sa-hedef b{font-size:14.5px;color:var(--txt)}.sa-hedef span{flex:none;font-weight:800;color:#d9b25b;font-variant-numeric:tabular-nums}.sa-hedef small{display:block;font-size:12px;color:var(--mut);margin-top:6px}',
      '.sa-hedef.tamam span{color:var(--good)}.sa-ilerleme{height:8px;border-radius:4px;background:var(--bg);overflow:hidden;margin-top:9px}.sa-ilerleme i{display:block;height:100%;background:linear-gradient(90deg,#e8cf8f,#b8913f);border-radius:4px}.sa-hedef.tamam .sa-ilerleme i{background:#34c98a}',
      '.sa-satir{display:flex;align-items:center;gap:10px;padding:9px 2px;border-bottom:1px solid var(--line)}.sa-satir:last-of-type{border-bottom:0}.sa-no{flex:none;width:26px;text-align:center;font-weight:800;color:var(--mut)}',
      '.sa-ad{flex:1;min-width:0;font-size:14px;color:var(--txt);overflow:hidden;text-overflow:ellipsis}.sa-ad em{font-style:normal;font-size:10.5px;font-weight:800;color:#1b1607;background:#d9b25b;padding:1px 6px;border-radius:6px;margin-left:4px;white-space:nowrap}.sa-ad small{font-size:11.5px;font-weight:700}',
      '.sa-satir b{flex:none;font-variant-numeric:tabular-nums;color:#e8cf8f}.sa-satir.ilk .sa-ad{font-weight:700}',
      '.sa-bak{display:flex;gap:10px;align-items:center;padding:10px 2px;border-bottom:1px solid var(--line)}.sa-bak:last-child{border-bottom:0}.sa-bak-g{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}.sa-bak-g b{font-size:14px;color:var(--txt)}.sa-bak-g small{font-size:12px;color:var(--mut)}.sa-bak-g small.g{color:#d9b25b}',
      '.sa-bak-d{flex:none;display:flex;flex-direction:column;gap:5px}.sa-kucuk{padding:6px 10px;border-radius:999px;font-size:12px;font-weight:700;background:var(--bg);color:var(--txt);border:1px solid var(--line)}.sa-kucuk.altin{border-color:rgba(217,178,91,.5);color:#e8cf8f}',
      '.sa-rapor b{display:block;font-size:15px;color:var(--txt);margin:5px 0}.sa-rapor p{margin:0;font-size:13.5px;line-height:1.5;color:var(--mut);white-space:pre-wrap;overflow-wrap:anywhere}'
    ];
    var st = document.createElement('style'); st.id = 'siyasetArenasiStil'; st.textContent = css.join('\n'); (document.head || document.documentElement).appendChild(st);
  }
})();
