/* =====================================================================
   PARAM NEREYE GİTTİ? (30.10.2026) — vergi ve kesinti rehberi, kişisel
   7 günlük döküm, paranın şu an durduğu yerler, sık sorulanlar ve
   Ekonomik Denge için bir kerelik tanıtım ekranı.
   Sunucu: 150_ekonomi_bilgilendirme.sql (vergi_rehberi, tanitim_tamam)
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_EKONOMI_REHBER_V1) return;
  window.SO_EKONOMI_REHBER_V1 = true;
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var sayi = function (n) { return Math.round(Number(n || 0)).toLocaleString('tr-TR'); };
  var tl = function (n) { return sayi(n) + ' ₺'; };
  var kisa = function (n) { n = Number(n || 0); var a = Math.abs(n), s = n < 0 ? '−' : ''; return a >= 1e6 ? s + (a / 1e6).toLocaleString('tr-TR', { maximumFractionDigits: 1 }) + ' mn ₺' : a >= 1e4 ? s + Math.round(a / 1e3).toLocaleString('tr-TR') + ' bin ₺' : s + tl(a); };
  var kpi = function (n) { n = Number(n || 0); var a = Math.abs(n), s = n < 0 ? '−' : ''; return a >= 1e6 ? s + (a / 1e6).toLocaleString('tr-TR', { maximumFractionDigits: 1 }) + ' mn' : a >= 1e4 ? s + Math.round(a / 1e3).toLocaleString('tr-TR') + ' bin' : s + sayi(a); };
  var yuzde = function (n) { return '%' + Number(n || 0).toLocaleString('tr-TR', { maximumFractionDigits: 2 }); };
  var binde = function (yuzdeDeger) { return 'binde ' + (Number(yuzdeDeger || 0) * 10).toLocaleString('tr-TR', { maximumFractionDigits: 2 }); };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var lsOku = function (k) { try { return localStorage.getItem(k); } catch (_) { return null; } };
  var lsYaz = function (k) { try { localStorage.setItem(k, '1'); } catch (_) {} };
  var MUHUR = '<svg viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="24" r="22" fill="none" stroke="currentColor" stroke-width="1.3" opacity=".6"/><circle cx="24" cy="24" r="18.6" fill="none" stroke="currentColor" stroke-width=".8" stroke-dasharray="1.1 2.1" opacity=".7"/><path d="M15 31h18M17 31V21h14v10M14 21l10-6 10 6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M21 25.5h6M24 23v5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>';
  var TUR = {
    maas: 'Maaş', sirket: 'Şirketler', banka: 'Devlet bankası', mevduat: 'Oyuncu bankası mevduatı', piyasa: 'Yatırım (altın, döviz, hisse)',
    kredi: 'Kredi', oyb_kredi: 'Oyuncu bankası kredisi', emlak: 'Emlak ve mülk', adliye: 'Adliye', muzayede: 'Müzayede', iade: 'İade',
    bagis: 'Bağış', dernek: 'Dernek', piyango: 'Milli Piyango', ikramiye: 'İkramiye', destek: 'Sosyal destek', hemsehri: 'Hemşehri desteği',
    hosgeldin: 'Hoş geldin desteği', gorev: 'Görev ödülü', ek_is: 'Ek iş', meslek: 'Meslek ve dükkân', gazete_yazar: 'Gazete yazı ücreti',
    gazete_gelir: 'Gazete geliri', gazete_kur: 'Gazete kuruluşu', aday: 'Adaylık', reklam: 'Propaganda / reklam', parti_kur: 'Parti kuruluşu',
    parti_destek: 'Parti desteği', miting: 'Miting', ulasim: 'Ulaşım', tasinma: 'Taşınma', satin_alma: 'Mağaza', magaza: 'Mağaza',
    havale: 'Havale', fon: 'Fırsat Eşitliği Fonu', yardim: 'Sosyal yardım', kira: 'Kira geliri', ceza: 'Ceza', hibe: 'Hibe', yonetici: 'Oyun yönetimi',
    reklam_odul: 'Reklam ödülü', kampanya: 'Kampanya', teskilat: 'Teşkilat', ihale: 'İhale', tahvil: 'Tahvil'
  };
  // Cüzdandan çıkıp servette kalan kalemler: kayıp değil, başka hesaba geçiş
  var KENDI = { banka: 'kendi hesapların arasında', mevduat: 'kendi hesapların arasında' };
  var KENDI_GIDER = { piyasa: 'yatırımın olarak duruyor', sirket: 'sermaye ve hisse alımı · şirket değerinde durur' };
  var turAd = function (t) { return TUR[t] || String(t || 'Diğer').replace(/_/g, ' ').replace(/^./, function (c) { return c.toLocaleUpperCase('tr-TR'); }); };
  var ac = function (fn) { try { if (typeof ekranAc === 'function') ekranAc(fn); else fn(); } catch (_) {} };

  function servetVergisi(s, o) {
    var e = o.esikler || [], r = (o.denge_oranlar || []).map(function (x) { return Number(x) / 100; });
    if (e.length < 3 || r.length < 3) return 0;
    s = Number(s || 0);
    return Math.round(Math.max(0, Math.min(s, e[1]) - e[0]) * r[0] + Math.max(0, Math.min(s, e[2]) - e[1]) * r[1] + Math.max(0, s - e[2]) * r[2]);
  }
  function netServet(n) {
    n = n || {};
    return ['cuzdan', 'vadesiz', 'vadeli', 'oyb_vadesiz', 'oyb_vadeli', 'hisse', 'mulk'].reduce(function (t, k) { return t + Number(n[k] || 0); }, 0);
  }
  function vergiToplam(y) {
    return ['gelir_vergisi', 'kent_tahmini', 'stopaj', 'damga', 'tapu', 'emlak', 'servet_denge', 'servet_kanun'].reduce(function (t, k) { return t + Number(y[k] || 0); }, 0);
  }

  // ---------------------------------------------------------------- ekran
  function govde(v) {
    var o = v.oranlar || {}, y = v.yedi_gun || {}, b = v.bordro || {}, n = v.nerede || {};
    var vt = vergiToplam(y), net = Number(y.giris || 0) - Number(y.cikis || 0), sv = netServet(n), gv = servetVergisi(sv, o);
    var h = '<div class="dk-resmi er">';

    h += '<section class="dk-kunye"><div class="dk-kunye-ust"><span class="dk-muhur">' + MUHUR + '</span><div class="dk-kunye-ad"><small>Gelir İdaresi · Vatandaş Rehberi</small><b>Param nereye gitti?</b><span>Son 7 günde kazandığın, ödediğin ve paranın şu an durduğu yerler</span></div></div>' +
      '<div class="dk-kpiler er-kpi"><div class="dk-kpi"><small>Gelen ₺</small><b class="iyi">' + kpi(y.giris) + '</b></div><div class="dk-kpi"><small>Giden ₺</small><b class="kotu">' + kpi(y.cikis) + '</b></div>' +
      '<div class="dk-kpi"><small>Vergi ₺</small><b>' + kpi(vt) + '</b></div><div class="dk-kpi"><small>Net ₺</small><b class="' + (net >= 0 ? 'iyi' : 'kotu') + '">' + (net >= 0 ? '+' : '') + kpi(net) + '</b></div></div>' +
      '<p class="er-not">Cüzdandan çıkan paranın çoğu kaybolmaz: bankaya, vadeliye, şirketine ya da yatırıma geçer. Aşağıda önce kesintileri, sonra paranın şu an nerede durduğunu görürsün.</p></section>';

    // Maaşın yolculuğu
    var brut = Number(b.brut || 0);
    if (brut > 0) {
      var par = [['Gelir vergisi', b.vergi, 'gv'], ['Kent vergisi', b.kent, 'kv'], ['Geçim masrafı', b.gecim, 'gm'], ['Sana kalan', b.net, 'nt']];
      h += '<section class="dk-protokol"><header class="dk-bolum"><div><small>Bugünkü bordrona göre, günde</small><b>Maaşının yolculuğu</b></div><span class="dk-kasa">' + tl(brut) + '<small>brüt</small></span></header>' +
        '<div class="er-serit" role="img" aria-label="Brüt maaşın dağılımı">' + par.map(function (x) { var w = Math.max(0, 100 * Number(x[1] || 0) / brut); return w > 0 ? '<i class="' + x[2] + '" style="width:' + w.toFixed(2) + '%"></i>' : ''; }).join('') + '</div>' +
        '<div class="er-lejant">' + par.map(function (x) { return '<div><span class="er-nokta ' + x[2] + '"></span><span>' + x[0] + '</span><b>' + tl(x[1]) + '</b><small>' + yuzde(100 * Number(x[1] || 0) / brut) + '</small></div>'; }).join('') + '</div>' +
        '<p class="er-not">Maaş kumbarana <b>net</b> birikir; toplarken cüzdana yatan tutardan bu kesintiler zaten düşülmüştür. Gelir vergisi yalnız asgari ücreti aşan kısımdan alınır (%' + esc(o.gelir) + '), kent vergisi brüt maaşın %' + esc(o.kent) + '\'i (' + esc(o.il || 'ilin') + ' Belediyesi). Geçim masrafı vergi değildir; fiyatlarla artar, belediye hizmetleri indirir' + (Number(o.gecim_indirim) ? ' (şu an %' + esc(Number(o.gecim_indirim).toLocaleString('tr-TR')) + ' indirimli)' : '') + '.</p></section>';
    }

    // 7 günlük vergi ve kesintiler
    var kal = [
      ['Gelir vergisi', y.gelir_vergisi, 'Maaştan, asgari ücreti aşan kısımdan, kaynakta'],
      ['Kent vergisi', y.kent_tahmini, 'Maaştan, ' + (o.il || 'ilinin') + ' Belediyesi · bordroya göre tahmini'],
      ['Geçim masrafı', y.gecim_tahmini, 'Maaştan düşülen yaşam gideri · bordroya göre tahmini'],
      ['Kâr payı stopajı', y.stopaj, 'Genel kurul temettüsünden %' + (o.stopaj || 0)],
      ['Tapu harcı', y.tapu, 'Mülk alım-satımında %' + (o.tapu || 2)],
      ['Şirket devir vergisi', y.damga, 'Şirket ve hisse devrinde'],
      ['Emlak vergisi', y.emlak, 'İlinde yaşayan herkesten, günlük'],
      ['Servet vergisi · Ekonomik Denge', y.servet_denge, 'Eşiği aşan net servetten, her gece'],
      ['Servet vergisi · kanun', y.servet_kanun, 'Meclis\'in koyduğu muafiyet üstü vergi'],
      ['Maaş haczi', y.haciz, 'Takipteki kredi borcuna, maaşın yarısı']
    ];
    var gor = kal.filter(function (x, i) { return i < 2 || Number(x[1] || 0) > 0; });
    h += '<section class="dk-protokol"><header class="dk-bolum"><div><small>Son 7 gün</small><b>Ödediğin vergi ve kesintiler</b></div><span class="dk-kasa">' + tl(vt + Number(y.gecim_tahmini || 0) + Number(y.haciz || 0)) + '<small>toplam</small></span></header>' +
      '<div class="er-kalemler">' + gor.map(function (x) {
        return '<div class="er-kalem"><div><b>' + esc(x[0]) + '</b><small>' + esc(x[2]) + '</small></div><em class="' + (Number(x[1] || 0) > 0 ? 'kotu' : '') + '">' + (Number(x[1] || 0) > 0 ? '−' + tl(x[1]) : '0 ₺') + '</em></div>';
      }).join('') + '</div>';
    var don = [['Fırsat Eşitliği Fonu', y.fon, 'Servet vergisinden, medyanın altındakilere'], ['Devlet ve belediye destekleri', y.destek, 'Sosyal destek, hemşehri, hoş geldin, ikramiye']]
      .filter(function (x) { return Number(x[1] || 0) > 0; });
    if (don.length) h += '<h4 class="er-ara">Devletten sana gelen</h4><div class="er-kalemler">' + don.map(function (x) {
      return '<div class="er-kalem"><div><b>' + esc(x[0]) + '</b><small>' + esc(x[2]) + '</small></div><em class="iyi">+' + tl(x[1]) + '</em></div>';
    }).join('') + '</div>';
    h += '<p class="er-not">Kesin tutarlar hesap hareketlerinden gelir; kent vergisi ve geçim masrafı maaş kumbarasında düşüldüğü için bugünkü bordro oranıyla hesaplanmıştır.</p></section>';

    // Paran şu an nerede?
    var yer = [['Cüzdan', n.cuzdan], ['Devlet bankası · vadesiz', n.vadesiz], ['Devlet bankası · vadeli', n.vadeli], ['Oyuncu bankası · vadesiz', n.oyb_vadesiz],
      ['Oyuncu bankası · vadeli', n.oyb_vadeli], ['Şirket payların (güncel değer)', n.hisse], ['Mülklerin', n.mulk]];
    var mx = Math.max.apply(null, yer.map(function (x) { return Number(x[1] || 0); }).concat([1]));
    var borc = [['Kredi borcu', n.kredi], ['Oyuncu bankası kredisi', n.oyb_kredi], ['Servet vergisi borcu', n.vergi_borcu]].filter(function (x) { return Number(x[1] || 0) > 0; });
    h += '<section class="dk-protokol"><header class="dk-bolum"><div><small>Bütün hesapların bir arada</small><b>Paran şu an nerede?</b></div><span class="dk-kasa">' + kisa(sv) + '<small>net servet</small></span></header>' +
      '<div class="er-yerler">' + yer.map(function (x) {
        var d = Number(x[1] || 0);
        if (d <= 0 && x[0] !== 'Cüzdan') return '';
        return '<div class="er-yer"><span>' + esc(x[0]) + '</span><b>' + kisa(d) + '</b><i style="--y:' + (100 * Math.max(0, d) / mx).toFixed(1) + '%"></i></div>';
      }).join('') + '</div>' +
      (borc.length ? '<h4 class="er-ara">Borçların</h4><div class="er-kalemler">' + borc.map(function (x) { return '<div class="er-kalem"><div><b>' + esc(x[0]) + '</b></div><em class="kotu">−' + tl(x[1]) + '</em></div>'; }).join('') + '</div>' : '') +
      (Number(n.sirket_kasa || 0) > 0 ? '<p class="er-bilgi"><b>Şirket kasalarında senin payına düşen ' + kisa(n.sirket_kasa) + ' var.</b> Bu para şirketindir, servetine şirket değeri olarak sayılır. Kâr payı dağıtılınca ya da genel kurul temettü kararı alınca cüzdanına geçer (temettüden %' + esc(o.stopaj) + ' stopaj kesilir).</p>' : '') +
      '<p class="er-not">' + (gv > 0 ? 'Net servetin servet vergisi eşiğinin üstünde: tahmini günlük Ekonomik Denge vergin <b>' + tl(gv) + '</b>.' : 'Net servetin servet vergisi eşiğinin (' + kisa((o.esikler || [])[0]) + ') altında; servet vergisi ödemiyorsun.') + '</p></section>';

    // Para nereden geldi, nereye gitti
    var gl = (y.gelirler || []), gd = (y.giderler || []);
    if (gl.length || gd.length) {
      var satir = function (x, isaret) {
        var k = KENDI[x.tur] || (isaret < 0 ? KENDI_GIDER[x.tur] : null);
        return '<div class="er-kalem"><div><b>' + esc(turAd(x.tur)) + '</b><small>' + Number(x.adet || 0) + ' işlem' + (k ? ' · ' + esc(k) : '') + '</small></div><em class="' + (isaret > 0 ? 'iyi' : k ? '' : 'kotu') + '">' + (isaret > 0 ? '+' : '−') + tl(x.tutar) + '</em></div>';
      };
      h += '<section class="dk-protokol"><header class="dk-bolum"><div><small>Son 7 gün · cüzdan</small><b>Nereden geldi, nereye gitti?</b></div></header>' +
        (gl.length ? '<h4 class="er-ara">Gelenler</h4><div class="er-kalemler">' + gl.map(function (x) { return satir(x, 1); }).join('') + '</div>' : '') +
        (gd.length ? '<h4 class="er-ara">Gidenler</h4><div class="er-kalemler">' + gd.map(function (x) { return satir(x, -1); }).join('') + '</div>' : '') +
        '<p class="er-not">Beyaz tutarlı kalemler kayıp değildir: bankaya yatırdığın, vadeliye koyduğun, yatırım ya da şirket payı aldığın paradır; servetinde durmaya devam eder. Her hareketin tek tek listesi Cüzdan hareketlerindedir.</p>' +
        (typeof window.cuzdanEkrani === 'function' ? '<button type="button" class="dk-tum" onclick="ekranAc(cuzdanEkrani)">Bütün cüzdan hareketlerini gör</button>' : '') + '</section>';
    }

    // Oyundaki vergiler
    var e0 = (o.esikler || [])[0], dor = o.denge_oranlar || [];
    var vergiler = [
      ['Gelir vergisi', '%' + o.gelir, 'Asgari ücreti aşan maaştan, toplarken', 'Hükümet; Meclis bütçesinde %' + o.gelir_alt + '–%' + o.gelir_ust + ' bandı'],
      ['Kent vergisi', '%' + o.kent, 'Brüt maaşın tamamından (' + (o.il || 'ilin') + ')', 'Belediye başkanı, %0–5'],
      ['Geçim masrafı', tl(o.gecim_gunluk) + '/gün', 'Maaştan; fiyat düzeyiyle artar', 'Belediye hizmetleri ve hükümet tedbirleri indirir'],
      ['Emlak vergisi', Number(o.emlak_gunluk) > 0 ? tl(o.emlak_gunluk) + '/gün' : 'yok', 'İlinde yaşayan herkesten, günlük', 'İl düzenlemesi (belediye)'],
      ['Servet vergisi · Ekonomik Denge', binde(dor[0]) + ' – ' + binde(dor[2]) + '/gün', kisa(e0) + ' üstü net servetten, yalnız aşan kısma', 'Kendiliğinden: eşik medyan servetin 10 katı'],
      ['Servet vergisi · kanun', Number(o.kanuni_servet) > 0 ? 'binde ' + Number(o.kanuni_servet).toLocaleString('tr-TR') + '/gün' : 'uygulanmıyor', tl(o.kanuni_servet_muaf) + ' muafiyet üstü nakit ve mevduattan', 'Meclis'],
      ['Kurumlar vergisi', '%' + o.kurumlar, 'Şirket kârından, kâr payı dağıtılmadan önce', 'Meclis kanunu'],
      ['KDV', '%' + o.kdv, 'Şirket satışlarından', 'Meclis kanunu'],
      ['Kâr payı stopajı', '%' + o.stopaj, 'Genel kurul temettüsünden', 'Meclis kanunu'],
      ['Damga vergisi', '%' + o.damga, 'Şirket devri ve sözleşmelerden', 'Meclis kanunu'],
      ['Tapu harcı', '%' + (o.tapu || 2), 'Mülk alım-satımında alıcı ve satıcıdan', 'Sabit']
    ];
    h += '<section class="dk-protokol"><header class="dk-bolum"><div><small>Güncel oranlar · kimin belirlediği</small><b>Oyundaki vergiler</b></div></header><div class="er-vergiler">' +
      vergiler.map(function (x) { return '<div class="er-vergi"><div class="er-vergi-ust"><b>' + esc(x[0]) + '</b><em>' + esc(x[1]) + '</em></div><small>' + esc(x[2]) + '</small><span>' + esc(x[3]) + '</span></div>'; }).join('') +
      '</div><p class="er-not">Vergileri oyuncuların seçtiği hükümet, Meclis ve belediye başkanları belirler. Beğenmediğin bir vergi varsa oy ver, aday ol, kanun teklif et.</p></section>';

    // Sık sorulanlar
    var havale = Number(o.asgari || 0) * Number(o.havale_sinir || 0);
    var sss = [
      ['Bu kadar kazandım, param nereye gitti?', 'Üç yere bak. <b>Kesintiler:</b> maaşın cüzdana net yatar; gelir vergisi, kent vergisi ve geçim masrafı toplamadan önce düşülür, temettüden stopaj kesilir. <b>Kendi hesapların:</b> bankaya, vadeliye, oyuncu bankasına yatırdığın ya da yatırım aldığın para cüzdandan çıkar ama servetinde durur; yukarıdaki "Paran şu an nerede?" hepsini toplar. <b>Şirket kasası:</b> şirketin kazancı önce şirket kasasına girer, kâr payı ya da temettü olarak dağıtılınca cüzdanına geçer.'],
      ['Servet vergisi kimden alınır, ben öder miyim?', 'Yalnız net serveti medyan servetin 10 katını, bugün <b>' + tl(e0) + '</b> eşiğini aşanlardan ve sadece aşan kısım üzerinden alınır. Oyuncuların büyük çoğunluğu hiç ödemez. ' + (gv > 0 ? 'Senin net servetin ' + tl(sv) + '; tahmini günlük vergin <b>' + tl(gv) + '</b>.' : 'Senin net servetin ' + tl(sv) + '; vergi kapsamında değilsin.')],
      ['Net servetime neler dahil?', 'Cüzdan, devlet bankası vadesiz ve vadeli hesapların, oyuncu bankalarındaki mevduatın, şirket paylarının güncel değeri ve mülklerin. Kredi borcu servetten düşülmez; krediyle servet büyütmek vergiyi de büyütür.'],
      ['Vergi ne zaman ve nereden kesilir?', 'Her gece 03:20\'de. Önce cüzdandan, yetmezse devlet bankası vadesiz hesabından alınır. İkisi de yetmezse kalan tutar vergi borcu olarak yazılır ve sonraki gecelerde kendiliğinden tahsil edilir. Borç kapanana kadar başka oyuncuya para gönderemez, yeni şirket kuramazsın.'],
      ['Toplanan vergi nereye gidiyor?', 'Servet vergisinin yarısı aynı gün Fırsat Eşitliği Fonu ile medyanın altındaki aktif oyunculara eşit dağıtılır, diğer yarısı Hazine\'ye gelir yazılır. Hazine gelirleri bakanlık bütçeleri, belediye payları ve devlet destekleriyle yine oyunculara döner. Gelir vergisinin nereye harcandığını Hayat › Verginin karşılığı ekranında görebilirsin.'],
      ['Fırsat Eşitliği Fonu\'ndan nasıl pay alırım?', 'Başvuru gerekmez. Servetin medyanın altındaysa, son 3 günde oyuna girdiysen, hesabın en az 3 günlükse, hesabında yönetim uyarısı ve vergi borcun yoksa pay her gece cüzdanına yatar (kişi başı günde en çok ' + tl(o.fon_tavan) + ').'],
      ['Paramı başka hesaba aktararak vergiden kurtulabilir miyim?', 'Hayır. Aynı cihazdaki hesaplar arasında aktarım yapılamaz, oyuncular arası günlük aktarım sınırı ' + (havale > 0 ? tl(havale) : 'vardır') + ', vergi borcu olan kimse para aktaramaz. Servet bir başkasına geçerse vergisini de o öder.'],
      ['Şirketimin kârı neden cüzdanıma gelmedi?', 'Şirket kârından önce kurumlar vergisi (%' + esc(o.kurumlar) + ') düşülür. Kalan net kâr, payın oranında cüzdanına yatar; kârını şirket kasasında bırakmayı seçtiysen, şirket zarar ettiyse ya da kasası yetersizse dağıtılmaz. Genel kurul temettüsünden ayrıca %' + esc(o.stopaj) + ' stopaj kesilir.'],
      ['Rekabet Kurumu kimi cezalandırır?', 'Serveti medyanın 10 katını aşan bir oyuncunun şirketi pazarın en az %30\'unu tutarken zararına en düşük fiyattan satarsa. Ceza şirket kasasının %10\'udur ve o pazardaki mağdur rakiplere tazminat olarak ödenir; fiyat 72 saat ortaya çekilir. Normal rekabet, indirim ve kârlı satış cezalandırılmaz.'],
      ['Vergi oranlarını kim değiştirebilir?', 'Gelir vergisini hükümet, Meclis\'in bütçede belirlediği bant içinde ayarlar; kent vergisini belediye başkanı belirler; kurumlar, KDV, stopaj ve damga vergisi Meclis kanunuyla değişir. Ekonomik Denge eşikleri ise medyan servete bağlıdır ve ekonomi büyüdükçe kendiliğinden yükselir.']
    ];
    h += '<section class="dk-protokol"><header class="dk-bolum"><div><small>Oyunculardan gelen sorular</small><b>Sık sorulanlar</b></div></header><div class="er-sss">' +
      sss.map(function (x, i) { return '<details' + (i === 0 ? ' open' : '') + '><summary>' + esc(x[0]) + '</summary><p>' + x[1] + '</p></details>'; }).join('') + '</div></section>';

    // Kısayollar
    var ks = [];
    if (typeof window.cuzdanEkrani === 'function') ks.push('<button type="button" class="btn ikinci" onclick="ekranAc(cuzdanEkrani)">Cüzdan hareketleri</button>');
    if (typeof window.ekonomikDengeEkrani === 'function') ks.push('<button type="button" class="btn ikinci" onclick="ekranAc(ekonomikDengeEkrani)">Ekonomik Denge</button>');
    if (typeof window.mobilSubeEkrani === 'function') ks.push('<button type="button" class="btn ikinci" onclick="ekranAc(mobilSubeEkrani)">Mobil Şube</button>');
    if (typeof window.vergiKarneModal === 'function') ks.push('<button type="button" class="btn ikinci" onclick="vergiKarneModal()">Verginin karşılığı</button>');
    if (ks.length) h += '<div class="er-kisa">' + ks.join('') + '</div>';
    return h + '</div>';
  }

  async function ekran() {
    try { yukleniyor('Param nereye gitti?'); } catch (_) {}
    var v;
    try { v = await API.rpc('vergi_rehberi'); }
    catch (err) { iskelet('Param nereye gitti?', '<div class="bos">' + esc(hata(err)) + '</div>', { geri: true }); return; }
    iskelet('Param nereye gitti?', govde(v), { geri: true });
  }
  window.vergiRehberiEkrani = ekran;

  // ---------------------------------------------------------------- bir kerelik tanıtım
  var ANAHTAR = 'ekonomik_denge_1';
  function tanitimHtml(v) {
    var o = v.oranlar || {}, sv = netServet(v.nerede), gv = servetVergisi(sv, o), e0 = (o.esikler || [])[0];
    var kart = function (ik, bas, metin) { return '<div class="er-t-kart"><span class="er-t-ik">' + ik + '</span><div><b>' + bas + '</b><p>' + metin + '</p></div></div>'; };
    return '<div class="er-t"><div class="er-t-ust"><span class="dk-muhur">' + MUHUR + '</span><div><small>Resmî duyuru · Rekabet Kurumu ve Gelir İdaresi</small><h3>Yeni ekonomi düzeni</h3><span>Ekonomik Denge düzenlemesi yürürlükte</span></div></div>' +
      kart('%', 'Büyük servete kademeli vergi', 'Net servet ' + kisa(e0) + ' eşiğini (medyanın 10 katı) aşarsa yalnız aşan kısımdan günde binde 1 ile binde 3,5 arası vergi alınır. Oyuncuların büyük çoğunluğu bu vergiyi ödemez.') +
      '<div class="er-t-ben ' + (gv > 0 ? 'vergi' : '') + '">' + (gv > 0 ? 'Senin net servetin <b>' + kisa(sv) + '</b>: vergi kapsamındasın, tahmini günlük vergin <b>' + tl(gv) + '</b>. Her gece 03:20\'de önce cüzdandan alınır.' : 'Senin net servetin <b>' + kisa(sv) + '</b>: servet vergisi kapsamında değilsin.') + '</div>' +
      kart('⇄', 'Fırsat Eşitliği Fonu', 'Toplanan verginin yarısı her gece medyanın altındaki aktif oyunculara eşit dağıtılır (kişi başı günde en çok ' + tl(o.fon_tavan) + '). Başvuru gerekmez.') +
      kart('⚖', 'Batırmaya karşı koruma', 'Zararına satışla rakip batırmaya Rekabet Kurumu cezası, aynı pazara paravan şirket yasağı ve bankaları çökertecek mevduata sınır getirildi.') +
      kart('₺', 'Param nereye gitti?', 'Üst çubuktaki cüzdan tutarına dokun: maaşından kesilen vergiden vadeli hesabına kadar her kuruşu kalem kalem gör.') +
      '<button type="button" class="btn altin" id="erTRehber">Paramın dökümünü göster</button><button type="button" class="btn ikinci" id="erTTamam">Anladım</button></div>';
  }
  function tanitimGoster(v) {
    if (typeof modal !== 'function' || document.getElementById('modal')) return false;
    var m = modal(tanitimHtml(v));
    try { API.rpc('tanitim_tamam', { p_anahtar: ANAHTAR }).catch(function () {}); } catch (_) {}
    var r = m.querySelector('#erTRehber'), k = m.querySelector('#erTTamam');
    if (r) r.onclick = function () { try { modalKapat(); } catch (_) {} ac(ekran); };
    if (k) k.onclick = function () { try { modalKapat(); } catch (_) {} };
    return true;
  }
  var tDurum = 0, tSayac = 0;
  function tanitimDene() {
    if (tDurum) return;
    var kad;
    try { if (typeof D === 'undefined' || !D.durum || !D.durum.profil || !D.sekme) return; kad = D.durum.profil.kad; } catch (_) { return; }
    if (document.hidden || document.getElementById('modal')) return;
    var key = 'so_tanitim_' + ANAHTAR + '_' + kad;
    if (lsOku(key)) { tDurum = 2; return; }
    tDurum = 1;
    API.rpc('vergi_rehberi').then(function (v) {
      if (v && v.tanitim) { lsYaz(key); tDurum = 2; return; }
      if (document.getElementById('modal')) { tDurum = 0; return; }
      if (tanitimGoster(v)) { lsYaz(key); tDurum = 2; } else tDurum = 0;
    }).catch(function () { tDurum = 0; });
  }
  var tIv = setInterval(function () { tSayac++; tanitimDene(); if (tDurum === 2 || tSayac > 150) clearInterval(tIv); }, 2500);
  window.ekonomiTanitimGoster = function () { API.rpc('vergi_rehberi').then(tanitimGoster).catch(function (err) { try { toast(hata(err), true); } catch (_) {} }); };

  // ---------------------------------------------------------------- bildirimlerde bağlantı
  // İlk eşleşen kural kazanır: genel duyuru dökümü, kişisel vergi/fon bildirimi hesaplamayı açar.
  var BAG = [
    [/Param nereye gitti|cüzdan tutarına dokun/, 'Paramın dökümü', function () { ac(ekran); }],
    [/Servet vergisi|Fırsat Eşitliği Fonu|Ekonomik Denge|Rekabet Kurumu/, 'Hesaplamayı gör', function () { ac(window.ekonomikDengeEkrani || ekran); }]
  ];
  function bildirimBagla() {
    var ic = document.getElementById('icerik'); if (!ic) return;
    ic.querySelectorAll('.kisisel').forEach(function (k) {
      if (k.querySelector('.er-bag')) return;
      var tx = k.textContent || '', b = null;
      for (var i = 0; i < BAG.length && !b; i++) if (BAG[i][0].test(tx)) b = BAG[i];
      if (!b) return;
      var alt = k.querySelector('.bildirim-alt');
      var btn = document.createElement('button'); btn.type = 'button'; btn.className = 'er-bag'; btn.textContent = b[1] + ' ›';
      btn.onclick = function (ev) { ev.stopPropagation(); b[2](); };
      (alt && alt.parentNode ? alt.parentNode : k).appendChild(btn);
    });
  }
  if (typeof iskelet === 'function') {
    var eskiIskelet = iskelet;
    iskelet = window.iskelet = function (baslik) {
      var r = eskiIskelet.apply(this, arguments);
      try { if (baslik === 'Bildirimler') setTimeout(bildirimBagla, 30); } catch (_) {}
      return r;
    };
  }

  // ---------------------------------------------------------------- stil
  var css = [
    '.er .er-kpi .dk-kpi b{font-size:16px;white-space:nowrap}',
    '.er .er-not{margin:10px 2px 0;font-size:12.5px;line-height:1.55;color:#a9b2cf}.er .er-not b{color:#f5ecd4}',
    '.er .er-bilgi{margin:10px 0 0;padding:10px 12px;border-radius:11px;background:rgba(217,178,91,.08);border:1px solid rgba(217,178,91,.25);font-size:12.5px;line-height:1.55;color:#d9dcea}.er .er-bilgi b{color:#f5ecd4}',
    '.er .er-serit{display:flex;height:14px;border-radius:7px;overflow:hidden;background:rgba(255,255,255,.06);gap:2px}',
    '.er .er-serit i{display:block;height:100%}.er .gv{background:#ff9aa2}.er .kv{background:#ffc27a}.er .gm{background:#9fd0ff}.er .nt{background:#7fe3bf}',
    '.er .er-lejant{display:grid;grid-template-columns:1fr 1fr;gap:8px 12px;margin-top:12px}',
    '.er .er-lejant div{display:grid;grid-template-columns:10px 1fr auto;align-items:center;gap:2px 7px;min-width:0}',
    '.er .er-lejant span:nth-child(2){font-size:12.5px;color:#c5cdf0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.er .er-lejant b{font-size:13px;color:#f5ecd4;font-variant-numeric:tabular-nums;white-space:nowrap}.er .er-lejant small{grid-column:2/4;font-size:11px;color:#8f9bbd;margin-top:-2px}',
    '.er .er-nokta{width:10px;height:10px;border-radius:3px}',
    '.er .er-kalemler{display:flex;flex-direction:column}',
    '.er .er-kalem{display:flex;justify-content:space-between;align-items:center;gap:12px;padding:9px 0;border-top:1px solid rgba(217,178,91,.10)}.er .er-kalem:first-child{border-top:0}',
    '.er .er-kalem>div{min-width:0}.er .er-kalem b{display:block;font-size:14px;font-weight:700;color:#f3eee0}.er .er-kalem small{display:block;margin-top:1px;font-size:11.5px;color:#8f9bbd;line-height:1.35}',
    '.er .er-kalem em{flex:none;font-style:normal;font-weight:800;font-size:14px;font-variant-numeric:tabular-nums;color:#c5cdf0;white-space:nowrap}.er .er-kalem em.kotu{color:#ff9aa2}.er .er-kalem em.iyi{color:#7fe3bf}',
    '.er .er-ara{margin:12px 0 2px;font-size:11.5px;font-weight:700;letter-spacing:.5px;text-transform:uppercase;color:#c9b88f}',
    '.er .er-yerler{display:flex;flex-direction:column;gap:8px}',
    '.er .er-yer{display:grid;grid-template-columns:minmax(0,1fr) auto;align-items:center;gap:5px 10px;font-size:13px;color:#c5cdf0}.er .er-yer i{grid-column:1/3}',
    '.er .er-yer span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.er .er-yer i{display:block;height:7px;border-radius:4px;background:rgba(255,255,255,.07);position:relative;overflow:hidden}.er .er-yer i::after{content:"";position:absolute;inset:0;width:var(--y);border-radius:4px;background:linear-gradient(90deg,#e8cf8f,#b8913f)}',
    '.er .er-yer b{font-variant-numeric:tabular-nums;color:#f5ecd4;white-space:nowrap;text-align:right}',
    '.er .er-vergiler{display:flex;flex-direction:column;gap:6px}',
    '.er .er-vergi{padding:10px 12px;border-radius:11px;background:rgba(8,12,30,.45);border:1px solid rgba(217,178,91,.14)}',
    '.er .er-vergi-ust{display:flex;justify-content:space-between;align-items:baseline;gap:10px}.er .er-vergi-ust b{font-size:14px;color:#f3eee0;min-width:0}.er .er-vergi-ust em{flex:none;font-style:normal;font-family:var(--disp);font-size:14.5px;color:#e8cf8f;white-space:nowrap}',
    '.er .er-vergi small{display:block;margin-top:3px;font-size:12px;color:#c5cdf0;line-height:1.4}.er .er-vergi span{display:block;margin-top:2px;font-size:11.5px;color:#8f9bbd}',
    '.er .er-sss{display:flex;flex-direction:column;gap:6px}',
    '.er .er-sss details{border-radius:12px;background:rgba(8,12,30,.45);border:1px solid rgba(217,178,91,.14);overflow:hidden}',
    '.er .er-sss summary{list-style:none;cursor:pointer;padding:12px 38px 12px 13px;position:relative;font-size:14px;font-weight:700;color:#f3eee0;line-height:1.35}',
    '.er .er-sss summary::-webkit-details-marker{display:none}',
    '.er .er-sss summary::after{content:"+";position:absolute;right:14px;top:50%;transform:translateY(-50%);font-size:20px;font-weight:400;color:#d9b25b}',
    '.er .er-sss details[open] summary::after{content:"−"}.er .er-sss details[open]{border-color:rgba(217,178,91,.4)}',
    '.er .er-sss p{margin:0;padding:0 13px 13px;font-size:13px;line-height:1.6;color:#c5cdf0}.er .er-sss p b{color:#f5ecd4}',
    '.er .er-kisa{display:grid;grid-template-columns:1fr 1fr;gap:8px}.er .er-kisa .btn{margin:0}',
    '.er-t{display:flex;flex-direction:column;gap:9px}',
    '.er-t-ust{display:flex;align-items:center;gap:12px;margin-bottom:4px}.er-t-ust small{display:block;font-size:11px;letter-spacing:.3px;color:#c9b88f}',
    '.er-t-ust h3{margin:1px 0 0;font-family:var(--disp);font-size:22px;line-height:1.1;color:#f5ecd4}.er-t-ust span{display:block;font-size:12.5px;color:#a9b2cf;margin-top:2px}',
    '.er-t-kart{display:flex;gap:11px;padding:11px 12px;border-radius:13px;background:rgba(217,178,91,.05);border:1px solid rgba(217,178,91,.18)}',
    '.er-t-ik{flex:none;width:32px;height:32px;border-radius:10px;display:grid;place-items:center;font-weight:800;font-size:16px;color:#1b1607;background:linear-gradient(135deg,#e8cf8f,#b8913f)}',
    '.er-t-kart b{display:block;font-size:14.5px;color:#f3eee0}.er-t-kart p{margin:2px 0 0;font-size:12.5px;line-height:1.5;color:#c5cdf0}',
    '.er-t-ben{padding:10px 12px;border-radius:12px;font-size:13px;line-height:1.5;color:#bff3dc;background:rgba(52,201,138,.10);border:1px solid rgba(52,201,138,.28)}.er-t-ben b{color:#fff}',
    '.er-t-ben.vergi{color:#ffd6a8;background:rgba(224,138,46,.10);border-color:rgba(224,138,46,.32)}',
    '.er-t .btn{margin:2px 0 0}',
    '.er-bag{margin-top:8px;padding:6px 11px;border-radius:999px;border:1px solid rgba(217,178,91,.4);background:rgba(217,178,91,.08);color:#e8cf8f;font:inherit;font-size:12.5px;font-weight:700;cursor:pointer}',
    '@media (max-width:360px){.er .er-lejant{grid-template-columns:1fr}.er .er-kisa{grid-template-columns:1fr}}'
  ];
  var st = document.createElement('style'); st.id = 'ekonomiRehberStil'; st.textContent = css.join('\n'); (document.head || document.documentElement).appendChild(st);
})();
