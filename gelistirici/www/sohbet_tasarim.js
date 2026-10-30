/* =====================================================================
   MESAJLAR — Sohbet bölümünün yeniden tasarımı (30.10.2026)
   Kürsü'nün görsel dilinde, tanıdık mesajlaşma uygulamaları gibi:
   - Gelen kutusu: arama, Özel / Kanallar sekmeleri, çevrimiçi kişiler şeridi,
     okunmamış konuşmalar, son mesajda okundu tikleri, yeni mesaj düğmesi.
   - Konuşma ekranı: günlere bölünmüş akış, gruplanmış balonlar, emoji-only büyük
     gösterim, anında görünen gönderim, okundu çift tiki, çevrimiçi durumu,
     "aşağı in" düğmesi, eylem sayfası (kopyala / şikâyet / profil).
   - Kanal ekranı: aynı kabuk, gönderen portresi ve makam nişanıyla.
   - Her ekranın üst çubuğuna mesaj kısayolu (okunmamış sayısıyla).
   Sunucu: ozel_liste / ozel_oku / ozel_yaz / sohbet_ozet / sohbet_oku / sohbet_yaz (144 ile
   ozel_liste'ye aktif+okundu, ozel_oku'ya aktif+okundu_son eklendi; yoksa da çalışır).
   ===================================================================== */
(function () {
  'use strict';
  if (window.SOHBET_TASARIM_V1) return;
  window.SOHBET_TASARIM_V1 = true;

  var ST = { seg: 'ozel', dm: null, oz: null, ara: '', yalnizYeni: false, sonCiz: '' };
  window.SOHBET_DURUM = ST;

  /* ---------- küçük yardımcılar ---------- */
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function n(v) { var x = Number(v); return isFinite(x) ? x : 0; }
  function $1(s, k) { return (k || document).querySelector(s); }
  function profil() { return (typeof D !== 'undefined' && D.durum && D.durum.profil) || null; }
  function hafif() { try { HAPTIK.hafif(); } catch (e) {} }
  function hataYaz(err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (e) { return m; } }
  function tst(m, kotu) { try { toast(m, kotu); } catch (e) {} }
  function otomatik() { try { return !window.YUK || !YUK.otomatik || YUK.otomatik(); } catch (e) { return true; } }
  function suan() { try { return typeof simdi === 'function' ? simdi() : Date.now(); } catch (e) { return Date.now(); } }
  function av(kad, renk, boy) {
    try { return portre(kad, renk, boy); }
    catch (e) { return '<span class="sh-av-bos" style="width:' + boy + 'px;height:' + boy + 'px">' + esc(String(kad || '?').slice(0, 2).toLocaleUpperCase('tr-TR')) + '</span>'; }
  }
  function avTazele(k) { try { if (typeof portreleriTazele === 'function') portreleriTazele(k); } catch (e) {} }
  function kimlikAktif(kad) { try { var k = typeof kimlik === 'function' ? kimlik(kad) : null; return k && k.aktif; } catch (e) { return null; } }
  var AKTIF = { cevrimici: 'Çevrimiçi', bugun: 'Bugün oyundaydı', hafta: 'Bu hafta oyundaydı', uzun: 'Bir süredir görünmüyor' };

  /* Saat ve gün: İstanbul saatiyle */
  var TZ = 'Europe/Istanbul';
  var GUNF = new Intl.DateTimeFormat('tr-TR', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' });
  var SAATF = new Intl.DateTimeFormat('tr-TR', { timeZone: TZ, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
  var HAFTAF = new Intl.DateTimeFormat('tr-TR', { timeZone: TZ, weekday: 'long' });
  var KISAF = new Intl.DateTimeFormat('tr-TR', { timeZone: TZ, day: 'numeric', month: 'short' });
  var UZUNF = new Intl.DateTimeFormat('tr-TR', { timeZone: TZ, day: 'numeric', month: 'long', year: 'numeric' });
  function gunAnahtar(ts) { return GUNF.format(new Date(ts)); }
  function gunFark(ts) {
    var a = GUNF.formatToParts(new Date(ts)), b = GUNF.formatToParts(new Date(suan()));
    var c = function (p) { var o = {}; p.forEach(function (x) { o[x.type] = +x.value; }); return Date.UTC(o.year, o.month - 1, o.day); };
    return Math.round((c(b) - c(a)) / 864e5);
  }
  function saat(ts) { try { return SAATF.format(new Date(ts)); } catch (e) { return ''; } }
  function listeZaman(ts) {
    if (!ts) return '';
    var f = gunFark(ts);
    if (f <= 0) return saat(ts);
    if (f === 1) return 'Dün';
    if (f < 7) { var h = HAFTAF.format(new Date(ts)); return h.charAt(0).toLocaleUpperCase('tr-TR') + h.slice(1); }
    return KISAF.format(new Date(ts)).replace('.', '');
  }
  function gunBaslik(ts) {
    var f = gunFark(ts);
    if (f <= 0) return 'Bugün';
    if (f === 1) return 'Dün';
    if (f < 7) { var h = HAFTAF.format(new Date(ts)); return h.charAt(0).toLocaleUpperCase('tr-TR') + h.slice(1); }
    return UZUNF.format(new Date(ts));
  }

  /* Yalnız emojiden oluşan mesajlar (bayrak dahil) balonsuz ve büyük gösterilir */
  var EMOJI_TEK = null;
  try { EMOJI_TEK = new RegExp('^(?:(?:\\p{Regional_Indicator}{2})|(?:\\p{Extended_Pictographic}(?:\\uFE0F|[\\u{1F3FB}-\\u{1F3FF}])?(?:\\u200D\\p{Extended_Pictographic}(?:\\uFE0F|[\\u{1F3FB}-\\u{1F3FF}])?)*)|\\s){1,8}$', 'u'); } catch (e) {}
  function emojiSayisi(m) {
    var t = String(m || '').trim();
    if (!t || !EMOJI_TEK || !EMOJI_TEK.test(t)) return 0;
    try { return Array.from(new Intl.Segmenter('tr', { granularity: 'grapheme' }).segment(t.replace(/\s+/g, ''))).length; }
    catch (e) { return Array.from(t.replace(/\s+/g, '')).length > 6 ? 4 : 1; }
  }
  function metinHtml(m) {
    // Bağlantı ve etiketleri vurgula (yalnızca görsel; metin aynen kalır)
    return esc(m).replace(/(^|\s)(#[0-9A-Za-zÇĞİÖŞÜçğıöşü_]{2,40})/g, '$1<span class="shm-et">$2</span>')
      .replace(/(^|\s)(@[0-9A-Za-zÇĞİÖŞÜçğıöşü_.]{2,30})/g, '$1<span class="shm-an">$2</span>');
  }

  /* Makam nişanı (Kürsü ile aynı renk mantığı) */
  function nisanRenk(u) {
    u = String(u || '');
    if (!u) return '';
    return /Cumhurbaşkanı Yardımcısı/.test(u) ? '#f59e0b' : /Cumhurbaşkanı/.test(u) ? '#d4a62c' : /Başbakan/.test(u) ? '#e85568'
      : /Bakanı|Bakan(?:$|\s|\()/.test(u) ? '#a78bfa' : /Milletvekili/.test(u) ? '#419dff' : /Belediye Başkanı/.test(u) ? '#20bd83'
      : /TBMM Başkan|Meclis Başkan/.test(u) ? '#ff7a59' : /Genel Başkan/.test(u) ? '#ff4f8b' : '#8b6cff';
  }
  function nisan(u) {
    var r = nisanRenk(u); if (!r) return '';
    return '<span class="sh-nisan" style="color:' + r + '" title="' + esc(u) + '"><svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 1.8l2.4 1.7 2.9-.2 1 2.7 2.5 1.5-.6 2.9 1.2 2.6-2.1 2 .1 2.9-2.8.8-1.6 2.4-2.8-.9L12 22.2l-2.4-1.7-2.9.2-1-2.7-2.5-1.5.6-2.9L2.6 11l2.1-2-.1-2.9 2.8-.8 1.6-2.4 2.8.9z"/><path d="M8.2 12.2l2.5 2.5 5-5.2" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg></span>';
  }

  /* ---------- simgeler ---------- */
  function sv(p, ek) { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"' + (ek || '') + '>' + p + '</svg>'; }
  var I = {
    mesaj: sv('<path d="M20.5 11.6a8.1 8.1 0 0 1-11.8 7.2L3.5 20l1.4-4.5a8.1 8.1 0 1 1 15.6-3.9z"/>'),
    ucak: sv('<path d="M21.2 2.8L10.4 13.6"/><path d="M21.2 2.8l-6.9 18.4-3.9-7.6-7.6-3.9z"/>'),
    yeni: sv('<path d="M12.5 4H6.8A2.8 2.8 0 0 0 4 6.8v10.4A2.8 2.8 0 0 0 6.8 20h10.4a2.8 2.8 0 0 0 2.8-2.8v-5.7"/><path d="M17.9 3.1a2 2 0 0 1 2.9 2.9L12.6 14.2 9 15l.8-3.6z"/>'),
    ara: sv('<circle cx="10.8" cy="10.8" r="6.6"/><path d="M20.3 20.3l-4.8-4.8"/>'),
    kapat: sv('<path d="M6 6l12 12M18 6L6 18"/>', ' stroke-width="2.2"'),
    geri: sv('<path d="M15 5l-7 7 7 7"/>', ' stroke-width="2.4"'),
    menu: '<svg viewBox="0 0 24 24" aria-hidden="true" fill="currentColor"><circle cx="5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="19" cy="12" r="1.8"/></svg>',
    gonder: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M3.4 20.6c-.5.2-1-.3-.8-.8l2.6-6.9c.1-.3.4-.5.7-.5l7.6-.4-7.6-.4a.8.8 0 0 1-.7-.5L2.6 4.2c-.2-.5.3-1 .8-.8l17.7 7.8c.6.3.6 1.2 0 1.5z"/></svg>',
    tik: '<svg viewBox="0 0 18 12" aria-hidden="true"><path d="M1.5 6.6l3.4 3.4L11.6 2.4" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ciftTik: '<svg viewBox="0 0 22 12" aria-hidden="true"><path d="M1.2 6.6l3.4 3.4L11.3 2.4M8.6 9.4l.6.6 6.7-7.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    saat: sv('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>'),
    unlem: sv('<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5M12 16.5v.1"/>', ' stroke-width="2.2"'),
    asagi: sv('<path d="M6 9.5l6 6 6-6"/>', ' stroke-width="2.4"'),
    kilit: sv('<rect x="5" y="10.5" width="14" height="10" rx="2.6"/><path d="M8.3 10.5V8a3.7 3.7 0 0 1 7.4 0v2.5"/>'),
    goz: sv('<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>'),
    kisiler: sv('<circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.5"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M15 14.5c3 0 6 2 6 5.5"/>'),
    kart: sv('<rect x="3" y="5" width="18" height="14" rx="3"/><circle cx="9" cy="11" r="2.3"/><path d="M5.8 16.4c.7-1.6 1.8-2.4 3.2-2.4s2.5.8 3.2 2.4M14.5 10h4M14.5 13.5h3"/>'),
    kopya: sv('<rect x="8.5" y="8.5" width="12" height="12" rx="2.6"/><path d="M15.5 8.5V6a2.5 2.5 0 0 0-2.5-2.5H6A2.5 2.5 0 0 0 3.5 6v7A2.5 2.5 0 0 0 6 15.5h2.5"/>'),
    bayrak: sv('<path d="M5 21V4M5 4h11.5l-2.2 4.2 2.2 4.3H5"/>'),
    engel: sv('<circle cx="12" cy="12" r="8.5"/><path d="M6 6l12 12"/>'),
    kursu: sv('<path d="M7.5 21h9l-1.2-7h-6.6z"/><path d="M5.5 14h13"/><path d="M12 14v-3"/><circle cx="12" cy="8" r="2.4"/>'),
    zil: sv('<path d="M6 8.6a6 6 0 1 1 12 0c0 6.6 2.8 8.4 2.8 8.4H3.2S6 15.2 6 8.6"/><path d="M10.2 20.6a2 2 0 0 0 3.6 0"/>'),
    ok: sv('<path d="M9 5l7 7-7 7"/>', ' stroke-width="2.2"'),
    canli: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4" fill="currentColor"/><circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="1.6" opacity=".45"/></svg>'
  };
  var KANAL_IK = {
    genel: ['#ff5a6e', sv('<path d="M3.5 10.5l13-6v15l-13-6z"/><path d="M16.5 8.5a3.5 3.5 0 0 1 0 7"/><path d="M6.5 14l1.2 5.5h3L9.8 15"/>')],
    il: ['#e7a93b', sv('<path d="M4.5 9.5h12v4.5a6 6 0 0 1-12 0z"/><path d="M16.5 10.5h1.2a2.3 2.3 0 0 1 0 4.6h-1.6"/><path d="M8 3.5c-.8 1 .8 2 0 3M12 3.5c-.8 1 .8 2 0 3"/><path d="M3.5 21h15"/>')],
    belediye: ['#26c281', sv('<path d="M3 21h18M5 21V8l7-5 7 5v13M9 21v-6h6v6"/>')],
    parti: ['#8b6cff', null],
    yonetim: ['#ff9f0a', sv('<path d="M12 3l8 4v5c0 5-3.5 8-8 9-4.5-1-8-4-8-9V7z"/><path d="M9 12l2 2 4-4"/>')],
    ittifak: ['#c26bf5', sv('<path d="M8 12h8M5 8l-3 4 3 4M19 8l3 4-3 4"/>')],
    meclis: ['#2f8cff', sv('<path d="M3 21h18M5 21V11M19 21V11M9.5 21V11M14.5 21V11M2 11l10-7 10 7z"/>')],
    grup: ['#5e5ce6', sv('<circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.5"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M15 14.5c3 0 6 2 6 5.5"/>')],
    divan: ['#ffcf3a', sv('<path d="M4 20h16M6 20v-8h12v8M9 12V8h6v4M12 8V4"/>')],
    kabine: ['#4cc3ff', sv('<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M3 13h18"/>')]
  };
  var KANAL_ALT = { genel: 'Tüm oyuncular', il: 'Senin ilindeki oyuncular', belediye: 'Herkes izler; belediye başkanı ve ilin vekilleri konuşur',
    parti: 'Yalnızca parti üyeleri görür', yonetim: 'Genel başkan ve yardımcıları', ittifak: 'İttifak partilerinin üyeleri',
    meclis: 'Açık oturum · Kürsü milletvekilleri, bakanlar ve Cumhurbaşkanına açık', kabine: 'Kapalı oturum · Cumhurbaşkanı ve bakanlar',
    grup: 'Grup toplantısı · Partinin milletvekilleri ve genel başkanı', divan: 'Kapalı oturum · TBMM Başkanı, başkanvekilleri ve grup başkanvekilleri' };
  var KANAL_GRUP = [['Herkese açık', ['il', 'belediye']], ['Siyasi örgüt', ['parti', 'yonetim', 'ittifak']], ['Devlet', ['meclis', 'grup', 'divan', 'kabine']]];
  /* Devlet kanalları: sohbet değil, resmî oturum. Tutanak düzeni, hitap kalıpları, oturum şeridi. */
  var RESMI = {
    meclis: { kurum: 'Türkiye Büyük Millet Meclisi', oturum: 'Genel Kurul', gun: 'Birleşim', gizlilik: 'Açık oturum', renk: '#d9b25b',
      yer: 'Kürsüden söz alın', bos: 'Bu birleşimde henüz söz alan olmadı. Kürsü, milletvekilleri, bakanlar ve Cumhurbaşkanı için açıktır.',
      izle: 'Genel Kurul görüşmeleri kamuya açıktır. Söz hakkı milletvekillerine, bakanlara ve Cumhurbaşkanına aittir; görüşmeleri izleyici sırasından takip ediyorsunuz.',
      hitap: ['Sayın Başkan, değerli milletvekilleri; ', 'Sayın Başkan, söz istiyorum.', 'Grubumuz adına söz almış bulunuyorum. ', 'Yüce Meclisi saygıyla selamlıyorum.'] },
    kabine: { kurum: 'Cumhurbaşkanlığı', oturum: 'Bakanlar Kurulu', gun: 'Toplantı', gizlilik: 'Kapalı oturum · Gizli', renk: '#d9b25b',
      yer: 'Kurula arz edin', bos: 'Kurul henüz toplanmadı. Gündem maddelerini Cumhurbaşkanı ve bakanlar burada görüşür; görüşmeler gizlidir.',
      izle: 'Bakanlar Kurulu görüşmeleri gizlidir; yalnızca Cumhurbaşkanı ve bakanlar söz alabilir.',
      hitap: ['Sayın Cumhurbaşkanım, değerli bakanlar; ', 'Bakanlığımın çalışmalarını bilgilerinize sunarım. ', 'Takdirlerinize arz ederim.', 'Uygun görülmüştür.'] },
    grup: { kurum: 'TBMM', oturum: 'Grup Toplantısı', gun: 'Grup toplantısı', gizlilik: 'Kapalı · Yalnız grup üyeleri', renk: '#b9a8ff',
      yer: 'Gruba hitap edin', bos: 'Grup henüz toplanmadı. Milletvekilleri ve genel başkan, Meclis\'teki tutumu burada belirler.',
      izle: 'Grup toplantısında yalnızca partinin milletvekilleri ve genel başkanı söz alabilir.',
      hitap: ['Sayın Genel Başkanım, değerli grup üyeleri; ', 'Grup önerimizi takdirlerinize sunarım. ', 'Grubumuzun tutumu şudur: ', 'Saygılarımı sunarım.'] },
    divan: { kurum: 'TBMM', oturum: 'Başkanlık Divanı ve Danışma Kurulu', gun: 'Toplantı', gizlilik: 'Kapalı oturum', renk: '#e8c35a',
      yer: 'Kurula görüş bildirin', bos: 'Kurul henüz toplanmadı. Meclis\'in gündemi ve çalışma takvimi burada belirlenir.',
      izle: 'Bu kurulda yalnızca TBMM Başkanı, başkanvekilleri ve grup başkanvekilleri söz alabilir.',
      hitap: ['Sayın Başkan, değerli grup başkanvekilleri; ', 'Danışma Kurulu önerimizi arz ederim: ', 'Grubumuz öneriye katılmaktadır.', 'Grubumuz öneriye katılmamaktadır.'] }
  };
  var RESMI_GUNF = new Intl.DateTimeFormat('tr-TR', { timeZone: TZ, day: 'numeric', month: 'long', year: 'numeric', weekday: 'long' });
  var ARMA = '<svg viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="24" r="22" fill="none" stroke="currentColor" stroke-width="1.4" opacity=".55"/><circle cx="24" cy="24" r="18.5" fill="none" stroke="currentColor" stroke-width=".8" stroke-dasharray="1.2 2.2" opacity=".6"/>' +
    '<path d="M13 33.5h22M15 33.5V22.5M33 33.5V22.5M20 33.5V22.5M28 33.5V22.5M12 22.5L24 14l12 8.5z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" stroke-linecap="round"/><path d="M24 9.6l.9 1.9 2.1.3-1.5 1.5.4 2.1-1.9-1-1.9 1 .4-2.1-1.5-1.5 2.1-.3z" fill="currentColor"/></svg>';
  /* Kanal kimlikleri: meydan, il kahvesi, parti salonu, belediye meclisi, genel merkez, ittifak masası */
  var TEMA = {
    genel: { renk: '#ff5a6e', ust: 'Türkiye Meydanı', alt: 'Ülkenin dört bir yanından herkes burada', yer: 'Meydana seslen' },
    il: { renk: '#e7a93b', ust: 'İl Kahvesi', alt: 'Çaylar demlendi, hemşehriler masada', yer: 'Masaya bir laf at' },
    belediye: { renk: '#26c281', ust: 'Belediye Meclisi', alt: 'Şehrin gündemi burada konuşulur', yer: 'Meclise söz al' },
    parti: { renk: '#8b6cff', ust: 'Parti Salonu', alt: 'Yalnızca partililer içeride', yer: 'Arkadaşlarına yaz' },
    yonetim: { renk: '#ff9f0a', ust: 'Genel Merkez', alt: 'Yönetim kurulu · kapalı toplantı', yer: 'Yönetime yaz' },
    ittifak: { renk: '#c26bf5', ust: 'İttifak Masası', alt: 'Ortak partilerin buluşma noktası', yer: 'Ortaklara yaz' }
  };
  function temaKur(kanal, oz) {
    var T = TEMA[kanal]; if (!T) return;
    var kok = $1('.shk-kanal'); if (!kok) return;
    var renk = T.renk, alt = T.alt, ust = T.ust, desen = '';
    var p = profil();
    if (kanal === 'parti' && p && p.parti) {
      if (/^#[0-9a-f]{6}$/i.test(p.parti.renk || '')) renk = p.parti.renk;
      ust = p.parti.ad || p.parti.kisa || ust;
      try { var sv0 = amblemSvg(p.parti.amblem, renk); if (sv0 && sv0.indexOf('<svg') === 0) desen = 'url("data:image/svg+xml;utf8,' + encodeURIComponent(sv0.indexOf('xmlns') < 0 ? sv0.replace('<svg', '<svg xmlns="http://www.w3.org/2000/svg"') : sv0).replace(/"/g, '%22') + '")'; } catch (e) {}
    }
    if (kanal === 'il' && p && (p.il_ad || (p.il && p.il.ad))) ust = (p.il_ad || p.il.ad) + ' Kahvesi';
    kok.classList.add('shk-tema', 'shk-tema-' + kanal);
    kok.style.setProperty('--tema', renk);
    if (desen) kok.style.setProperty('--desen', desen);
    var ustEl = $1('.shk-ust');
    if (ustEl) ustEl.insertAdjacentHTML('afterend', '<div class="sht-serit"><b>' + esc(ust) + '</b><span>' + esc(alt) + '</span></div>');
    var ta = $1('#yaz'); if (ta) ta.placeholder = T.yer;
  }
  function konusmaciRol(m) {
    var u = String(m.unvan || '');
    if (/Milletvekili$/.test(u)) return u.replace(/\s*Milletvekili$/, '') + ' Milletvekili';
    return u;
  }
  function resmiKayit(m, S, ilk, son) {
    var renk = (m.parti && m.parti.renk) || '#9aa6cc';
    var cls = 'shm shr' + (m.benim ? ' benim' : '') + (ilk ? ' ilk' : '') + (son ? ' son' : '') + (m._bekle ? ' bekle' : '') + (m._hata ? ' hata' : '');
    var h = '<div class="' + cls + '" data-id="' + esc(m.id) + '" data-kad="' + esc(m.kad || '') + '" style="--pr:' + esc(/^#[0-9a-f]{6}$/i.test(renk) ? renk : '#9aa6cc') + '">';
    if (ilk) {
      var rol = konusmaciRol(m), parti = m.parti && m.parti.kisa ? m.parti.kisa : '';
      h += '<div class="shr-kim"><span class="shm-av">' + av(m.kad, renk, 34) + '</span><span class="shr-ad"><b>' + esc(m.kad) + '</b>' + nisan(m.unvan) +
        (m.benim ? '<em>Siz</em>' : '') + '<small>' + esc([rol, parti].filter(Boolean).join(' · ') || 'Üye') + '</small></span><time>' + esc(saat(m.zaman)) + '</time></div>';
    }
    h += '<div class="shr-metin"><span class="shm-tx">' + metinHtml(m.metin) + '</span>' + (m._bekle || m._hata ? '<span class="shr-dur">' + tikHtml(m, S) + (m._hata ? ' Kayda geçmedi, dokunarak tekrar deneyin' : ' Kayda geçiyor') + '</span>' : '') + '</div></div>';
    return h;
  }
  function kanalIkon(kod, boy) {
    var k = KANAL_IK[kod] || ['#8f9bbd', I.mesaj], renk = k[0], ic = k[1];
    var p = profil();
    if (kod === 'parti' && p && p.parti) {
      renk = /^#[0-9a-f]{6}$/i.test(p.parti.renk || '') ? p.parti.renk : renk;
      try { ic = amblemSvg(p.parti.amblem, p.parti.renk); } catch (e) { ic = I.kisiler; }
    }
    if (!ic) ic = I.kisiler;
    return '<span class="sh-kik" style="--k:' + renk + ';width:' + (boy || 50) + 'px;height:' + (boy || 50) + 'px">' + ic + '</span>';
  }

  /* ---------- ortak: okunmamış ---------- */
  function dmOkunmamis(liste) { return (liste || []).reduce(function (t, x) { return t + n(x.okunmamis); }, 0); }
  function kanalOkunmamis(oz) { return ((oz && oz.kanallar) || []).reduce(function (t, k) { return t + (k.kilit ? 0 : n(k.okunmamis)); }, 0); }
  function rozet(s) { return s > 0 ? '<i class="sh-say">' + (s > 99 ? '99+' : s) + '</i>' : ''; }

  /* =====================================================================
     GELEN KUTUSU (Sohbet sekmesi)
     ===================================================================== */
  function aktifMi(x) { return (x.aktif || kimlikAktif(x.kad)) === 'cevrimici'; }
  function dmSirala(liste) {
    return (liste || []).slice().sort(function (a, b) {
      return (n(b.okunmamis) > 0) - (n(a.okunmamis) > 0) || new Date(b.zaman).getTime() - new Date(a.zaman).getTime();
    });
  }
  function onizleme(x) {
    var t = String(x.son || '').replace(/\s+/g, ' ').trim();
    var em = emojiSayisi(t);
    var tik = '';
    if (x.benden) tik = x.okundu === true ? '<span class="sh-tik on" aria-label="Okundu">' + I.ciftTik + '</span>' : x.okundu === false ? '<span class="sh-tik" aria-label="Gönderildi">' + I.tik + '</span>' : '';
    return tik + (x.benden ? '<span class="sh-sen">Sen:</span> ' : '') + '<span class="sh-onm' + (em ? ' em' : '') + '">' + esc(t) + '</span>';
  }
  function dmSatir(x) {
    var yeni = n(x.okunmamis), renk = x.parti && x.parti.renk;
    return '<button type="button" class="sh-k' + (yeni ? ' yeni' : '') + '" data-sh="dm" data-kad="' + esc(x.kad) + '">' +
      '<span class="sh-k-av' + (aktifMi(x) ? ' cev' : '') + '">' + av(x.kad, renk, 54) + '</span>' +
      '<span class="sh-k-orta"><span class="sh-k-ust"><b>' + esc(x.kad) + '</b>' + nisan(x.unvan) + '<time>' + esc(listeZaman(x.zaman)) + '</time></span>' +
      '<span class="sh-k-alt"><span class="sh-k-m">' + onizleme(x) + '</span>' + (yeni ? '<i class="sh-k-say">' + (yeni > 99 ? '99+' : yeni) + '</i>' : '') + '</span>' +
      (x.unvan ? '<span class="sh-k-unv">' + esc(x.unvan) + (x.parti && x.parti.kisa ? ' · ' + esc(x.parti.kisa) : '') + '</span>' : '') + '</span></button>';
  }
  function hikayeler(liste) {
    var h = '<button type="button" class="sh-h sh-h-yeni" data-sh="yeni"><span class="sh-h-hal"><span class="sh-h-ic">' + I.yeni + '</span></span><small>Yeni</small></button>' +
      '<button type="button" class="sh-h sh-h-cev" data-sh="cevrimici"><span class="sh-h-hal"><span class="sh-h-ic">' + I.kisiler + '</span><em>' + esc(ST.oz && ST.oz.cevrimici != null ? ST.oz.cevrimici : '') + '</em></span><small>Çevrimiçi</small></button>';
    var sira = (liste || []).slice().sort(function (a, b) {
      return (aktifMi(b) - aktifMi(a)) || (n(b.okunmamis) > 0) - (n(a.okunmamis) > 0) || new Date(b.zaman) - new Date(a.zaman);
    }).slice(0, 14);
    return h + sira.map(function (x) {
      return '<button type="button" class="sh-h' + (n(x.okunmamis) ? ' halka' : '') + (aktifMi(x) ? ' cev' : '') + '" data-sh="dm" data-kad="' + esc(x.kad) + '"><span class="sh-h-hal">' + av(x.kad, x.parti && x.parti.renk, 56) + '</span><small>' + esc(x.kad) + '</small></button>';
    }).join('');
  }
  function bosDm() {
    return '<div class="sh-bos"><div class="sh-bos-res" aria-hidden="true">' +
      '<svg viewBox="0 0 160 120"><defs><linearGradient id="shBg1" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8b6cff"/><stop offset="1" stop-color="#ff4f8b"/></linearGradient></defs>' +
      '<rect x="18" y="18" width="92" height="58" rx="22" fill="#1c2652"/><path d="M40 76l-6 16 18-16z" fill="#1c2652"/>' +
      '<rect x="34" y="36" width="52" height="7" rx="3.5" fill="#33407a"/><rect x="34" y="50" width="34" height="7" rx="3.5" fill="#33407a"/>' +
      '<rect x="62" y="44" width="82" height="52" rx="20" fill="url(#shBg1)"/><path d="M124 96l8 14-20-14z" fill="#ff4f8b"/>' +
      '<circle cx="86" cy="70" r="4.5" fill="#fff"/><circle cx="103" cy="70" r="4.5" fill="#fff" opacity=".8"/><circle cx="120" cy="70" r="4.5" fill="#fff" opacity=".6"/></svg></div>' +
      '<b>Henüz özel mesajın yok</b><p>Seçim pazarlığı, ittifak, kabine… Siyaset kulislerde yapılır. Bir oyuncuya yazarak başla.</p>' +
      '<div class="sh-bos-d"><button type="button" class="sh-btn ana" data-sh="yeni">' + I.yeni + 'Yeni mesaj</button><button type="button" class="sh-btn" data-sh="cevrimici">' + I.kisiler + 'Çevrimiçi oyuncular</button></div></div>';
  }
  function ozelGovde() {
    var dm = ST.dm || [], q = ST.ara.toLocaleLowerCase('tr-TR');
    if (!dm.length) return bosDm();
    var liste = dmSirala(dm).filter(function (x) {
      if (ST.yalnizYeni && !n(x.okunmamis)) return false;
      return !q || String(x.kad).toLocaleLowerCase('tr-TR').indexOf(q) >= 0 || String(x.son || '').toLocaleLowerCase('tr-TR').indexOf(q) >= 0 || String(x.unvan || '').toLocaleLowerCase('tr-TR').indexOf(q) >= 0;
    });
    var yeni = dm.filter(function (x) { return n(x.okunmamis) > 0; }).length;
    var cevSay = dm.filter(aktifMi).length;
    return (q ? '' : '<div class="sh-hikaye" role="list" aria-label="Kişiler">' + hikayeler(dm) + '</div>') +
      '<div class="sh-bas"><h3>Sohbetler</h3>' +
      '<span class="sh-cipler"><button type="button" class="sh-cip' + (!ST.yalnizYeni ? ' on' : '') + '" data-sh="suz" data-v="0">Tümü <small>' + dm.length + '</small></button>' +
      '<button type="button" class="sh-cip' + (ST.yalnizYeni ? ' on' : '') + '" data-sh="suz" data-v="1">Okunmamış <small>' + yeni + '</small></button></span></div>' +
      (cevSay && !q ? '<div class="sh-ipucu"><span class="sh-nokta"></span>' + cevSay + ' kişi şu an oyunda — yazarsan hemen görür.</div>' : '') +
      '<div class="sh-liste" id="shDmListe">' + (liste.length ? liste.map(dmSatir).join('') :
        '<div class="sh-bos kucuk"><p>' + (q ? '“' + esc(ST.ara) + '” ile eşleşen konuşma yok.' : 'Okunmamış mesajın yok. Hepsini okudun.') + '</p>' +
        (q ? '<button type="button" class="sh-btn" data-sh="araOyuncu">' + I.ara + 'Oyuncularda ara</button>' : '') + '</div>') + '</div>';
  }
  function kanalSatir(k, buyuk) {
    if (!k) return '';
    var kilit = !!k.kilit, yeni = kilit ? 0 : n(k.okunmamis), q = ST.ara.toLocaleLowerCase('tr-TR');
    if (q && String(k.baslik || '').toLocaleLowerCase('tr-TR').indexOf(q) < 0 && String(KANAL_ALT[k.kanal] || '').toLocaleLowerCase('tr-TR').indexOf(q) < 0) return '';
    var alt = kilit ? esc(k.kilit) : k.son ? '<b>' + esc(k.son.kad) + ':</b> ' + esc(k.son.metin) : esc(KANAL_ALT[k.kanal] || '');
    var cip = !kilit && k.cevrimici != null ? '<span class="sh-c-cev"><span class="sh-nokta"></span>' + k.cevrimici + ' çevrimiçi</span>' : '';
    var izle = !kilit && !k.yazabilir ? '<span class="sh-c-izle">' + I.goz + 'İzleyici</span>' : '';
    return '<button type="button" class="sh-c' + (kilit ? ' kilit' : '') + (yeni ? ' yeni' : '') + '" data-sh="' + (kilit ? 'kilit' : 'kanal') + '" data-kanal="' + esc(k.kanal) + '" data-kilit="' + esc(k.kilit || '') + '">' +
      kanalIkon(k.kanal, 50) + (kilit ? '<span class="sh-c-kilit">' + I.kilit + '</span>' : '') +
      '<span class="sh-k-orta"><span class="sh-k-ust"><b>' + esc(k.baslik) + '</b><time>' + (k.son && !kilit ? esc(listeZaman(k.son.zaman)) : '') + '</time></span>' +
      '<span class="sh-k-alt"><span class="sh-k-m">' + alt + '</span>' + (yeni ? '<i class="sh-k-say">' + (yeni > 99 ? '99+' : yeni) + '</i>' : '') + '</span>' +
      (cip || izle ? '<span class="sh-c-alt">' + cip + izle + '</span>' : '') + '</span></button>';
  }
  function kanalGovde() {
    var oz = ST.oz; if (!oz) return iskeletSatir(5);
    var bul = function (kod) { return (oz.kanallar || []).find(function (k) { return k.kanal === kod; }); };
    var g = bul('genel'), q = ST.ara;
    var meydan = '';
    if (g && !g.kilit && !q) {
      var yeni = n(g.okunmamis);
      meydan = '<button type="button" class="sh-meydan" data-sh="kanal" data-kanal="genel">' +
        '<span class="sh-meydan-desen" aria-hidden="true"></span>' +
        '<span class="sh-meydan-ust"><span class="sh-canli">' + I.canli + 'CANLI</span>' + (yeni ? '<i class="sh-k-say">' + (yeni > 99 ? '99+' : yeni) + ' yeni</i>' : '') + '</span>' +
        '<b>' + esc(g.baslik || 'Türkiye Meydanı') + '</b>' +
        '<span class="sh-meydan-alt">' + (g.son ? '<em>' + esc(g.son.kad) + ':</em> ' + esc(g.son.metin) : 'Bütün Türkiye burada konuşuyor. İlk sözü sen al.') + '</span>' +
        '<span class="sh-meydan-alt2"><span><span class="sh-nokta"></span>' + n(g.cevrimici != null ? g.cevrimici : oz.cevrimici) + ' oyuncu çevrimiçi</span><span class="sh-meydan-git">Meydana gir' + I.ok + '</span></span></button>';
    }
    var gruplar = KANAL_GRUP.map(function (gr) {
      var ic = gr[1].map(function (kod) { return kanalSatir(bul(kod)); }).join('');
      if (q && g && gr[0] === 'Herkese açık') ic = kanalSatir(g) + ic;
      return ic ? '<div class="sh-bas"><h3>' + gr[0] + '</h3></div><div class="sh-liste">' + ic + '</div>' : '';
    }).join('');
    return meydan + (gruplar || '<div class="sh-bos kucuk"><p>Bu aramaya uyan kanal yok.</p></div>') +
      '<p class="sh-kural">' + I.bayrak + '<span>Hakaret, küfür, nefret söylemi ve spam yasaktır. Bir mesaja dokunup şikâyet edebilir, oyuncuyu engelleyebilirsin. Kilitli kanallar ilgili göreve gelince açılır.</span></p>';
  }
  function iskeletSatir(k) { var h = ''; for (var i = 0; i < k; i++) h += '<div class="sh-hayal"><span class="a"></span><span class="b"><i></i><i></i></span></div>'; return '<div class="sh-liste">' + h + '</div>'; }
  function govdeHtml() { return ST.seg === 'kanal' ? kanalGovde() : (ST.dm ? ozelGovde() : '<div class="sh-hikaye">' + '<span class="sh-hayal-h"></span>'.repeat(5) + '</div>' + iskeletSatir(6)); }
  function segHtml() {
    var a = dmOkunmamis(ST.dm), b = kanalOkunmamis(ST.oz);
    return '<div class="sh-seg" role="tablist" style="--i:' + (ST.seg === 'kanal' ? 1 : 0) + '"><span class="sh-seg-kay" aria-hidden="true"></span>' +
      '<button type="button" role="tab" aria-selected="' + (ST.seg === 'ozel') + '" class="' + (ST.seg === 'ozel' ? 'on' : '') + '" data-sh="seg" data-v="ozel">' + I.ucak + 'Özel' + rozet(a) + '</button>' +
      '<button type="button" role="tab" aria-selected="' + (ST.seg === 'kanal') + '" class="' + (ST.seg === 'kanal' ? 'on' : '') + '" data-sh="seg" data-v="kanal">' + I.kisiler + 'Kanallar' + rozet(b) + '</button></div>';
  }
  function baslikHtml() {
    return '<span class="sh-baslik"><span class="sh-logo" aria-hidden="true">' + I.ucak + '</span><span>Mesajlar</span></span>';
  }
  function sagHtml() {
    var ok = (typeof D !== 'undefined' && D.okunmamis) || {}, p = profil();
    var zil = n(ok.bildirim);
    return '<div class="sh-sag">' +
      '<button type="button" class="sh-ust-b" data-sh="araOyuncu" aria-label="Oyuncu ara">' + I.ara + '</button>' +
      '<button type="button" class="sh-ust-b" onclick="ekranAc(bildirimEkrani)" aria-label="Bildirimler">' + I.zil + '<span id="zilSayi">' + (zil ? '<span class="sayi">' + (zil > 99 ? '99+' : zil) + '</span>' : '') + '</span></button>' +
      (p ? '<button type="button" class="sh-ust-b sh-ust-av" onclick="sekmeAc(\'ben\')" aria-label="Profilim">' + av(p.kad, p.parti && p.parti.renk, 32) + '</button>' : '') + '</div>';
  }
  function anaVar() { return !!document.querySelector('#icerik .sh[data-sh-ekran="ana"]'); }
  function anaCiz() {
    iskelet(baslikHtml(), '<div class="sh" data-sh-ekran="ana">' +
      '<label class="sh-ara">' + I.ara + '<input id="shAra" type="search" enterkeyhint="search" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="Kişi, mesaj ya da kanal ara" value="' + esc(ST.ara) + '"><button type="button" class="sh-ara-sil" data-sh="araSil" aria-label="Aramayı temizle"' + (ST.ara ? '' : ' hidden') + '>' + I.kapat + '</button></label>' +
      '<div id="shSeg">' + segHtml() + '</div><div id="shGovde" class="sh-govde">' + govdeHtml() + '</div></div>', { ikonsuz: true, sag: sagHtml() });
    var app = document.getElementById('app');
    if (app && !app.querySelector('.sh-fab')) {
      var b = document.createElement('button'); b.type = 'button'; b.className = 'sh-fab'; b.setAttribute('aria-label', 'Yeni mesaj');
      b.innerHTML = I.yeni; b.onclick = function () { hafif(); yeniMesaj(); };
      app.appendChild(b);
    }
    var ara = document.getElementById('shAra');
    if (ara) ara.addEventListener('input', function () {
      ST.ara = ara.value.trim();
      var s = document.querySelector('.sh-ara-sil'); if (s) s.hidden = !ST.ara;
      govdeTazele(true);
    });
    var k = document.getElementById('icerik'); if (k) avTazele(k);
    ST.sonCiz = govdeHtml();
  }
  function govdeTazele(zorla) {
    if (!anaVar()) return;
    var g = document.getElementById('shGovde'), s = document.getElementById('shSeg');
    var html = govdeHtml();
    if (s) { var sh = segHtml(); if (s.innerHTML !== sh) s.innerHTML = sh; }
    if (g && (zorla || html !== ST.sonCiz)) {
      var kh = g.querySelector('.sh-hikaye'), sl = kh ? kh.scrollLeft : 0;
      g.innerHTML = html; ST.sonCiz = html;
      var kh2 = g.querySelector('.sh-hikaye'); if (kh2 && sl) kh2.scrollLeft = sl;
      avTazele(g);
    }
  }
  async function veriGetir() {
    var r = await Promise.all([API.rpc('ozel_liste'), API.rpc('sohbet_ozet')]);
    ST.dm = Array.isArray(r[0]) ? r[0] : []; ST.oz = r[1] || { kanallar: [] };
    try { SON_SOHBET_OZET(ST.oz); } catch (e) {}
    // Sunucu çevrimiçi bilgisini göndermiyorsa (eski sürüm) portre kimliklerinden al
    if (ST.dm.length && ST.dm[0].aktif === undefined && typeof kimlikYukle === 'function') {
      try { await kimlikYukle(ST.dm.map(function (x) { return x.kad; })); } catch (e) {}
    }
  }
  function SON_SOHBET_OZET(oz) { try { if (window.SO_PREMIUM && window.SO_PREMIUM.son) window.SO_PREMIUM.son.sohbet_ozet = oz; } catch (e) {} }
  async function anaEkran() {
    canliDurdur();
    anaCiz();                              // önbellekle hemen çiz; tazesi gelince yerinde güncelle
    try {
      await Promise.all([veriGetir(), (async function () { try { await durumYenile(); } catch (e) {} })()]);
    } catch (err) {
      var g = document.getElementById('shGovde');
      if (g) g.innerHTML = '<div class="sh-bos kucuk"><p>' + esc(hataYaz(err)) + '</p><button type="button" class="sh-btn" data-sh="yenile">Tekrar dene</button></div>';
      return;
    }
    if (!anaVar()) return;
    govdeTazele(true);
    try { rozetGuncelle(Object.assign({}, D.okunmamis || {})); } catch (e) {}
    D.canli = setInterval(function () { if (!document.hidden && otomatik()) anaYokla(); }, 9000 + Math.floor(Math.random() * 2000));
  }
  var yoklaniyor = false;
  async function anaYokla() {
    if (yoklaniyor || !anaVar() || (D.yigin && D.yigin.length)) return;
    yoklaniyor = true;
    try { await veriGetir(); govdeTazele(false); } catch (e) {} finally { yoklaniyor = false; }
  }

  /* Gelen kutusu etkileşimleri (tek dinleyici, olay yetkilendirmesi) */
  document.addEventListener('click', function (ev) {
    var el = ev.target.closest && ev.target.closest('[data-sh]');
    if (!el || !el.closest('#app, #modal')) return;
    var a = el.getAttribute('data-sh');
    switch (a) {
      case 'dm': hafif(); var kad = el.getAttribute('data-kad'); ekranAc(function () { return ozelEkrani(kad); }); break;
      case 'kanal': hafif(); var kn = el.getAttribute('data-kanal'); ekranAc(function () { return sohbetEkrani(kn); }); break;
      case 'kilit': tst(el.getAttribute('data-kilit') || 'Bu kanal şimdilik kilitli.'); break;
      case 'seg': if (ST.seg !== el.getAttribute('data-v')) { hafif(); ST.seg = el.getAttribute('data-v'); try { sessionStorage.setItem('shSeg', ST.seg); } catch (e) {} govdeTazele(true); var ic = document.getElementById('icerik'); if (ic) ic.scrollTop = 0; } break;
      case 'suz': ST.yalnizYeni = el.getAttribute('data-v') === '1'; govdeTazele(true); break;
      case 'yeni': hafif(); yeniMesaj(); break;
      case 'cevrimici': hafif(); if (typeof cevrimiciListeAc === 'function') cevrimiciListeAc(); else if (typeof oyuncuAramaAc === 'function') oyuncuAramaAc(); break;
      case 'araOyuncu': if (typeof oyuncuAramaAc === 'function') oyuncuAramaAc(); else yeniMesaj(); break;
      case 'araSil': var i = document.getElementById('shAra'); if (i) { i.value = ''; ST.ara = ''; el.hidden = true; govdeTazele(true); i.focus(); } break;
      case 'yenile': anaEkran(); break;
    }
  });

  /* =====================================================================
     YENİ MESAJ (kişi seçici)
     ===================================================================== */
  function yeniMesaj() {
    var m = modal('<div class="sh-yeni"><h3>Yeni mesaj</h3>' +
      '<label class="sh-ara sh-ara-m">' + I.ara + '<input id="shKime" type="search" autocomplete="off" autocapitalize="off" spellcheck="false" enterkeyhint="go" placeholder="Kullanıcı adı yaz"></label>' +
      '<div class="sh-yeni-liste" id="shKimeListe"></div></div>');
    var inp = $1('#shKime', m), liste = $1('#shKimeListe', m), no = 0, zz = 0;
    function satir(k, alt) {
      return '<button type="button" class="sh-ys" data-kad="' + esc(k.kad) + '"><span class="sh-k-av' + (k.aktif === 'cevrimici' ? ' cev' : '') + '">' + av(k.kad, k.parti && k.parti.renk, 44) + '</span>' +
        '<span class="sh-k-orta"><span class="sh-k-ust"><b>' + esc(k.kad) + '</b>' + nisan(k.unvan) + '</span><span class="sh-ys-alt">' + esc(alt || '') + '</span></span><span class="sh-ys-git">' + I.mesaj + '</span></button>';
    }
    function sonKisiler() {
      var dm = dmSirala(ST.dm || []).slice(0, 8);
      liste.innerHTML = dm.length ? '<div class="sh-ys-bas">Son konuştukların</div>' + dm.map(function (x) { return satir(x, x.unvan || (x.parti ? x.parti.ad : 'Bağımsız')); }).join('') :
        '<div class="sh-ys-bos">Yazmak istediğin oyuncunun adını yaz. Oyunda biriyle tanışmadıysan <button type="button" class="sh-link" data-sh="cevrimici">çevrimiçi oyunculara</button> göz at.</div>';
      avTazele(liste);
    }
    async function ara() {
      var q = inp.value.trim(), benim = ++no;
      if (q.length < 2) { sonKisiler(); return; }
      liste.innerHTML = '<div class="sh-ys-bas">Aranıyor…</div>';
      try {
        var r = await API.rpc('oyuncu_arama', { p_aranan: q, p_il: null, p_parti: null, p_limit: 12, p_offset: 0 });
        if (benim !== no || !m.isConnected) return;
        var o = (r && r.oyuncular) || [], ben = profil();
        o = o.filter(function (k) { return !ben || k.kad !== ben.kad; });
        liste.innerHTML = o.length ? '<div class="sh-ys-bas">Oyuncular</div>' + o.map(function (k) { return satir(k, [k.il_ad, k.parti ? k.parti.kisa : 'Bağımsız', k.unvan].filter(Boolean).join(' · ')); }).join('')
          : '<div class="sh-ys-bos">“' + esc(q) + '” adında oyuncu bulunamadı.</div>';
        avTazele(liste);
      } catch (err) {
        if (benim !== no || !m.isConnected) return;
        // Arama yoksa tam ad ile doğrudan dene
        liste.innerHTML = '<button type="button" class="sh-ys" data-kad="' + esc(q) + '"><span class="sh-k-av">' + av(q, null, 44) + '</span><span class="sh-k-orta"><b>' + esc(q) + '</b><span class="sh-ys-alt">Bu kullanıcıya yaz</span></span><span class="sh-ys-git">' + I.mesaj + '</span></button>';
      }
    }
    inp.addEventListener('input', function () { clearTimeout(zz); zz = setTimeout(ara, 260); });
    inp.addEventListener('keydown', function (ev) { if (ev.key === 'Enter') { ev.preventDefault(); var b = liste.querySelector('.sh-ys'); if (b) b.click(); } });
    liste.addEventListener('click', async function (ev) {
      var b = ev.target.closest('.sh-ys'); if (!b) return;
      var kad = b.getAttribute('data-kad'); b.disabled = true;
      try { await API.rpc('oyuncu_kart', { p_kad: kad }); modalKapat(); ekranAc(function () { return ozelEkrani(kad); }); }
      catch (err) { b.disabled = false; tst(hataYaz(err), true); }
    });
    sonKisiler();
    setTimeout(function () { try { inp.focus(); } catch (e) {} }, 60);
  }

  /* =====================================================================
     KONUŞMA KABUĞU (özel ve kanal ortak)
     ===================================================================== */
  function kabuk(o) {
    canliDurdur(); modalKapat();
    var app = document.getElementById('app');
    app.innerHTML = '<div class="sohbet shk' + (o.ozel ? ' shk-dm' : ' shk-kanal') + '" data-shk="' + (o.ozel ? 'dm' : 'kanal') + '">' +
      '<header class="shk-ust"><button type="button" class="shk-geri" onclick="geriGit()" aria-label="Geri">' + I.geri + '</button>' +
      '<button type="button" class="shk-kim" id="shkKim">' + o.av + '<span class="shk-kim-m"><b id="sbBaslik">' + o.baslik + '</b><small id="shkDurum">' + (o.alt || '') + '</small></span></button>' +
      (o.sag || '') + '</header>' +
      '<div class="akis shk-akis" id="akis" role="log" aria-live="polite"><div class="shk-yuk"><span></span><span></span><span></span></div></div>' +
      '<button type="button" class="shk-asagi" id="shkAsagi" hidden aria-label="En yeni mesajlara in">' + I.asagi + '<i id="shkAsagiSay" hidden></i></button>' +
      '<div class="yazbar shk-yaz" id="yazbar"><div class="shk-kutu"><textarea id="yaz" rows="1" maxlength="' + (o.ozel ? 1000 : 500) + '" placeholder="' + (o.ozel ? 'Mesaj yaz' : 'Bu kanala yaz') + '" enterkeyhint="send"></textarea></div>' +
      '<button type="button" id="gonder" class="shk-gonder" aria-label="Gönder" disabled>' + I.gonder + '</button></div></div>';
    var ta = $1('#yaz'), gb = $1('#gonder');
    ta.addEventListener('input', function () {
      ta.style.height = 'auto'; ta.style.height = Math.min(132, ta.scrollHeight) + 'px';
      gb.disabled = !ta.value.trim(); gb.classList.toggle('hazir', !!ta.value.trim());
    });
    return $1('#akis');
  }
  function altta(akis) { return akis.scrollHeight - akis.scrollTop - akis.clientHeight < 90; }
  function asagiKur(akis, S) {
    var b = $1('#shkAsagi'), say = $1('#shkAsagiSay');
    akis.addEventListener('scroll', function () {
      if (altta(akis)) { S.bekleyen = 0; if (b) b.hidden = true; if (say) say.hidden = true; }
      else if (b && akis.scrollHeight - akis.scrollTop - akis.clientHeight > 320) b.hidden = false;
    }, { passive: true });
    if (b) b.onclick = function () { hafif(); akis.scrollTo({ top: akis.scrollHeight, behavior: 'smooth' }); };
  }
  function asagiSay(S) {
    var b = $1('#shkAsagi'), say = $1('#shkAsagiSay');
    if (!b || !say) return;
    b.hidden = false; say.hidden = !S.bekleyen; say.textContent = S.bekleyen > 99 ? '99+' : S.bekleyen;
  }

  /* Akışı çiz: gün ayraçları, ardışık gruplama, emoji-only */
  function akisHtml(S) {
    var h = '', onceki = null, sonGun = '';
    var L = S.liste;
    for (var i = 0; i < L.length; i++) {
      var m = L[i], sonraki = L[i + 1];
      var gun = gunAnahtar(m.zaman);
      if (gun !== sonGun) {
        if (S.resmi) { var tam = RESMI_GUNF.format(new Date(m.zaman)); h += '<div class="shr-gun"><i></i><span><b>' + esc(S.resmi.gun) + '</b>' + esc(tam) + '</span><i></i></div>'; }
        else h += '<div class="shm-gun"><span>' + esc(gunBaslik(m.zaman)) + '</span></div>';
        sonGun = gun; onceki = null;
      }
      var kim = m.benim ? '__ben' : String(m.kad || S.kad || '');
      var ayni = function (a, b) { return a && b && (a.benim ? '__ben' : String(a.kad || S.kad || '')) === (b.benim ? '__ben' : String(b.kad || S.kad || '')) && Math.abs(new Date(b.zaman) - new Date(a.zaman)) < 5 * 60e3 && gunAnahtar(a.zaman) === gunAnahtar(b.zaman); };
      var ilk = !ayni(onceki, m), son = !ayni(m, sonraki);
      h += balon(m, S, ilk, son);
      onceki = m;
    }
    if (!L.length) h = S.bosHtml || '';
    return h;
  }
  function tikHtml(m, S) {
    if (!m.benim) return '';
    if (m._bekle) return '<span class="shm-tik bekle" aria-label="Gönderiliyor">' + I.saat + '</span>';
    if (m._hata) return '<span class="shm-tik hata" aria-label="Gönderilemedi">' + I.unlem + '</span>';
    if (!S.ozel) return '';
    if (S.okunduSon != null && n(m.id) <= n(S.okunduSon)) return '<span class="shm-tik on" aria-label="Okundu">' + I.ciftTik + '</span>';
    return '<span class="shm-tik" aria-label="Gönderildi">' + I.tik + '</span>';
  }
  function balon(m, S, ilk, son) {
    if (S.resmi) return resmiKayit(m, S, ilk, son);
    var em = emojiSayisi(m.metin), renk = (m.parti && m.parti.renk) || '#9aa6cc';
    var kanalBaskasi = !S.ozel && !m.benim;
    var cls = 'shm' + (m.benim ? ' benim' : '') + (ilk ? ' ilk' : '') + (son ? ' son' : '') + (em ? ' emoji e' + Math.min(em, 4) : '') + (m._bekle ? ' bekle' : '') + (m._hata ? ' hata' : '');
    var h = '<div class="' + cls + '" data-id="' + esc(m.id) + '" data-kad="' + esc(m.kad || S.kad || '') + '">';
    if (kanalBaskasi) h += '<span class="shm-av">' + (son ? av(m.kad, renk, 32) : '') + '</span>';
    h += '<div class="shm-b">';
    if (kanalBaskasi && ilk) h += '<div class="shm-kim"><b style="color:' + esc(renkAcik(renk)) + '">' + esc(m.kad) + '</b>' + nisan(m.unvan) + (m.unvan ? '<small>' + esc(m.unvan) + '</small>' : m.parti && m.parti.kisa ? '<small>' + esc(m.parti.kisa) + '</small>' : '') + '</div>';
    h += '<span class="shm-tx">' + (em ? esc(m.metin) : metinHtml(m.metin)) + '</span><span class="shm-ne"><time>' + esc(saat(m.zaman)) + '</time>' + tikHtml(m, S) + '</span></div></div>';
    return h;
  }
  // Koyu zeminde okunabilsin diye parti rengini aç
  function renkAcik(hex) {
    if (!/^#[0-9a-f]{6}$/i.test(hex || '')) return '#b9c3e6';
    var r = parseInt(hex.substr(1, 2), 16), g = parseInt(hex.substr(3, 2), 16), b = parseInt(hex.substr(5, 2), 16);
    var l = (0.299 * r + 0.587 * g + 0.114 * b);
    if (l > 150) return hex;
    var k = (150 - l) / 255 + .25;
    var f = function (x) { return Math.round(x + (255 - x) * Math.min(.7, k)).toString(16).padStart(2, '0'); };
    return '#' + f(r) + f(g) + f(b);
  }
  function akisCiz(akis, S, mod) {
    var eskiY = akis.scrollHeight, eskiTop = akis.scrollTop, dipte = altta(akis);
    akis.innerHTML = akisHtml(S);
    avTazele(akis);
    if (mod === 'ilk') akis.scrollTop = akis.scrollHeight;
    else if (mod === 'basa') akis.scrollTop = eskiTop + (akis.scrollHeight - eskiY);
    else if (mod === 'ben' || dipte) akis.scrollTop = akis.scrollHeight;
    else akis.scrollTop = eskiTop;
    tepkiCiz(akis, S);
  }

  /* ---------- TEPKİLER (30.10.2026): her mesaja emoji tepkisi ---------- */
  var TP_GENEL = ['👍', '❤️', '😂', '🔥', '👏', '😮', '😢'], TP_RESMI = ['👏', '👍', '🤝', '🇹🇷', '📌'];
  function tpListe(S) { return S.resmi ? TP_RESMI : TP_GENEL; }
  function tpKanal(S) { return S.ozel ? 'ozel' : S.kanal; }
  function tepkiCiz(akis, S) {
    if (!akis || !S || !S.tepki) return;
    akis.querySelectorAll('.shm[data-id]').forEach(function (el) {
      var id = el.getAttribute('data-id'), t = S.tepki[id], kap = el.querySelector('.shm-b') || el.querySelector('.shr-metin');
      if (!kap) return;
      var eski = kap.querySelector('.shm-tp');
      var say = t && t.say ? Object.keys(t.say).filter(function (k) { return n(t.say[k]) > 0; }) : [];
      if (!say.length) { if (eski) eski.remove(); kap.classList.remove('tp-var'); return; }
      var h = say.sort(function (a, b) { return n(t.say[b]) - n(t.say[a]); }).map(function (em) {
        return '<button type="button" class="' + (t.ben === em ? 'ben' : '') + '" data-tp="' + esc(em) + '" aria-label="' + esc(em) + ' tepkisi, ' + n(t.say[em]) + '">' + esc(em) + '<i>' + n(t.say[em]) + '</i></button>';
      }).join('');
      if (eski && eski.innerHTML === h) return;
      if (!eski) { eski = document.createElement('span'); eski.className = 'shm-tp'; var ne = kap.querySelector('.shm-ne'); kap.insertBefore(eski, ne || null); }
      eski.innerHTML = h; kap.classList.add('tp-var');
    });
  }
  async function tepkiYukle(S, akis) {
    try {
      var ids = S.liste.filter(function (x) { return !x._bekle && !x._hata && n(x.id) > 0; }).slice(-80).map(function (x) { return n(x.id); });
      if (!ids.length) return;
      var r = await API.rpc('mesaj_tepkileri', { p_kanal: tpKanal(S), p_idler: ids });
      S.tepki = r || {}; tepkiCiz(akis, S);
    } catch (e) {}
  }
  function tepkiPatlat(el, em) {
    try {
      var r = el.getBoundingClientRect(), d = document.createElement('span');
      d.className = 'sh-tp-patla'; d.textContent = em;
      d.style.left = (r.left + r.width / 2) + 'px'; d.style.top = (r.top + 6) + 'px';
      document.body.appendChild(d); setTimeout(function () { d.remove(); }, 900);
    } catch (e) {}
  }
  async function tepkiVer(S, akis, id, em) {
    var el = akis.querySelector('.shm[data-id="' + id + '"]');
    // iyimser güncelleme
    var t = S.tepki = S.tepki || {}, x = t[id] = t[id] || { say: {}, ben: null };
    if (x.ben) { x.say[x.ben] = Math.max(0, n(x.say[x.ben]) - 1); }
    if (x.ben === em) x.ben = null; else { x.ben = em; x.say[em] = n(x.say[em]) + 1; if (el) tepkiPatlat(el, em); }
    tepkiCiz(akis, S); hafif();
    try { var r = await API.rpc('mesaj_tepki_ver', { p_kanal: tpKanal(S), p_mesaj: n(id), p_emoji: em }); if (r) { S.tepki[id] = r[String(id)] || { say: {}, ben: null }; tepkiCiz(akis, S); } }
    catch (err) { tst(hataYaz(err), true); tepkiYukle(S, akis); }
  }
  function yeniEkle(akis, S, yeni) {
    if (!yeni || !yeni.length) return;
    var gor = {}; S.liste.forEach(function (x) { gor[x.id] = 1; });
    yeni = yeni.filter(function (x) { return !gor[x.id]; });
    if (!yeni.length) return;
    S.liste = S.liste.filter(function (x) { return !x._bekle; }).concat(yeni);
    var dipte = altta(akis), benden = yeni.some(function (x) { return x.benim; });
    akisCiz(akis, S, benden ? 'ben' : null);
    if (!dipte && !benden) { S.bekleyen = (S.bekleyen || 0) + yeni.filter(function (x) { return !x.benim; }).length; asagiSay(S); }
    if (!benden) { try { HAPTIK.hafif(); } catch (e) {} }
  }

  /* Balona dokununca eylem sayfası */
  function eylemSayfasi(S, el) {
    var id = el.getAttribute('data-id'), kad = el.getAttribute('data-kad');
    var m = S.liste.find(function (x) { return String(x.id) === String(id); }); if (!m) return;
    if (m._hata) { tekrarGonder(S, m); return; }
    if (m._bekle) return;
    var benim = !!m.benim, ozel = S.ozel;
    var sat = function (k, ik, ad, cls) { return '<button type="button" class="sh-es' + (cls ? ' ' + cls : '') + '" data-es="' + k + '">' + ik + '<span>' + ad + '</span></button>'; };
    var md = modal('<div class="sh-sayfa"><div class="sh-sayfa-onizle"><div class="shm-mini' + (benim ? ' benim' : '') + '">' + esc(String(m.metin).slice(0, 220)) + (String(m.metin).length > 220 ? '…' : '') + '</div><small>' + (benim ? 'Sen' : esc(kad)) + ' · ' + esc(gunBaslik(m.zaman)) + ' ' + esc(saat(m.zaman)) + '</small></div>' +
      (m.id && n(m.id) > 0 ? '<div class="sh-tp-sec" role="group" aria-label="Tepki ver">' + tpListe(S).map(function (em) { var bn = S.tepki && S.tepki[id] && S.tepki[id].ben === em; return '<button type="button" class="' + (bn ? 'ben' : '') + '" data-es="tp" data-em="' + esc(em) + '">' + esc(em) + '</button>'; }).join('') + '</div>' : '') +
      '<div class="sh-es-grup">' + sat('kopya', I.kopya, 'Metni kopyala') +
      (!benim && !ozel ? sat('dm', I.mesaj, kad + ' kişisine özel mesaj') + sat('kart', I.kart, 'Oyuncu kartı') : '') +
      (!benim && ozel ? sat('kart', I.kart, 'Oyuncu kartı') : '') + '</div>' +
      (!benim ? '<div class="sh-es-grup">' + sat('sikayet', I.bayrak, 'Mesajı şikâyet et', 'kirmizi') + '</div>' : '') +
      '<button type="button" class="sh-es-vaz" data-es="vaz">Vazgeç</button></div>');
    md.addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-es]'); if (!b) return;
      var k = b.getAttribute('data-es');
      if (k === 'vaz') { modalKapat(); return; }
      if (k === 'tp') { modalKapat(); var ak = $1('#akis'); if (ak) tepkiVer(S, ak, id, b.getAttribute('data-em')); return; }
      if (k === 'kopya') {
        modalKapat();
        try { navigator.clipboard.writeText(m.metin).then(function () { tst('Mesaj kopyalandı.'); }, function () { tst('Kopyalanamadı.', true); }); } catch (e) { tst('Kopyalanamadı.', true); }
      }
      if (k === 'dm') { modalKapat(); ekranAc(function () { return ozelEkrani(kad); }); }
      if (k === 'kart') { modalKapat(); oyuncuKart(kad); }
      if (k === 'sikayet') { sikayetModal(ozel ? 'ozel' : 'mesaj', +id, kad, el); }
    });
  }

  /* Gönderim: anında görünür, sunucu onaylayınca gerçek mesajla yer değiştirir */
  var gecici = 0;
  async function gonderAkisi(S, akis) {
    var ta = $1('#yaz'); if (!ta) return;
    var metin = ta.value.trim(); if (!metin) return;
    var m = { id: 'g' + (++gecici), metin: metin, zaman: new Date(suan()).toISOString(), benim: true, _bekle: true };
    S.liste.push(m); akisCiz(akis, S, 'ben');
    ta.value = ''; ta.style.height = 'auto'; var gb = $1('#gonder'); if (gb) { gb.disabled = true; gb.classList.remove('hazir'); }
    try { ta.focus(); } catch (e) {}
    hafif();
    await gercektenGonder(S, akis, m);
  }
  async function gercektenGonder(S, akis, m) {
    try {
      await S.yaz(m.metin);
      await S.yeniGetir();
      S.liste = S.liste.filter(function (x) { return x !== m; });
      akisCiz(akis, S, 'ben');
    } catch (err) {
      m._bekle = false; m._hata = true; akisCiz(akis, S, null);
      tst(hataYaz(err), true);
    }
  }
  function tekrarGonder(S, m) {
    var akis = $1('#akis'); if (!akis) return;
    var md = modal('<div class="sh-sayfa"><div class="sh-sayfa-onizle"><div class="shm-mini benim">' + esc(m.metin) + '</div><small>Bu mesaj gönderilemedi.</small></div>' +
      '<div class="sh-es-grup"><button type="button" class="sh-es" data-es="tekrar">' + I.gonder + '<span>Tekrar gönder</span></button>' +
      '<button type="button" class="sh-es kirmizi" data-es="sil">' + I.kapat + '<span>Mesajı sil</span></button></div><button type="button" class="sh-es-vaz" data-es="vaz">Vazgeç</button></div>');
    md.addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-es]'); if (!b) return;
      var k = b.getAttribute('data-es'); modalKapat();
      if (k === 'tekrar') { m._hata = false; m._bekle = true; akisCiz(akis, S, 'ben'); gercektenGonder(S, akis, m); }
      if (k === 'sil') { S.liste = S.liste.filter(function (x) { return x !== m; }); akisCiz(akis, S, null); }
    });
  }
  function yazmaKur(S, akis) {
    akis.addEventListener('click', function (ev) {
      var b = ev.target.closest('.shm-tp [data-tp]'); if (!b) return;
      ev.stopPropagation(); ev.preventDefault();
      var m = b.closest('.shm'); if (m) tepkiVer(S, akis, m.getAttribute('data-id'), b.getAttribute('data-tp'));
    }, true);
    S._tpSay = 0; tepkiYukle(S, akis);
    if (typeof S.yeniGetir === 'function' && !S.yeniGetir._tp) {
      var eskiYG = S.yeniGetir;
      S.yeniGetir = async function () { var r = await eskiYG.apply(this, arguments); S._tpSay = (S._tpSay + 1) % 2; if (!S._tpSay) tepkiYukle(S, akis); return r; };
      S.yeniGetir._tp = true;
    }
    var gb = $1('#gonder'), ta = $1('#yaz');
    if (gb) gb.onclick = function () { gonderAkisi(S, akis); };
    if (ta) ta.addEventListener('keydown', function (ev) { if (ev.key === 'Enter' && !ev.shiftKey && window.innerWidth > 700) { ev.preventDefault(); gonderAkisi(S, akis); } });
    akis.addEventListener('click', function (ev) {
      var b = ev.target.closest('.shm'); if (!b) return;
      if (ev.target.closest('.shm-av') && b.getAttribute('data-kad')) { oyuncuKart(b.getAttribute('data-kad')); return; }
      eylemSayfasi(S, b);
    });
  }

  /* =====================================================================
     ÖZEL MESAJ EKRANI
     ===================================================================== */
  function durumYazi(aktif, unvan) {
    var a = aktif ? '<span class="shk-d ' + aktif + '">' + (aktif === 'cevrimici' ? '<span class="sh-nokta"></span>' : '') + esc(AKTIF[aktif] || '') + '</span>' : '';
    return a + (unvan ? (a ? '<span class="shk-ayr">·</span>' : '') + '<span class="shk-unv">' + esc(unvan) + '</span>' : '');
  }
  async function ozelEkrani(kad) {
    var bilinen = (ST.dm || []).find(function (x) { return String(x.kad).toLocaleLowerCase('tr-TR') === String(kad).toLocaleLowerCase('tr-TR'); }) || {};
    var akis = kabuk({ ozel: true, baslik: esc(kad) + nisan(bilinen.unvan),
      av: '<span class="shk-av' + (aktifMi(bilinen.kad ? bilinen : { kad: kad }) ? ' cev' : '') + '" id="shkAv">' + av(kad, bilinen.parti && bilinen.parti.renk, 40) + '</span>',
      alt: durumYazi(bilinen.aktif || kimlikAktif(kad), bilinen.unvan),
      sag: '<button type="button" class="shk-b" id="shkKart" aria-label="Oyuncu kartı">' + I.kart + '</button><button type="button" class="shk-b" id="dmMenu" aria-label="Seçenekler">' + I.menu + '</button>' });
    var S = { ozel: true, kad: kad, liste: [], sonId: null, okunduSon: null, bekleyen: 0,
      bosHtml: '<div class="shm-bos">' + av(kad, bilinen.parti && bilinen.parti.renk, 76) + '<b>' + esc(kad) + '</b><p>Bu konuşma yalnızca ikinizin arasında. Selam vererek başla.</p><div class="shm-hizli">' +
        ['Merhaba 👋', 'İttifak konuşalım mı?', 'Tebrikler! 🎉'].map(function (t) { return '<button type="button" data-hizli="' + esc(t) + '">' + esc(t) + '</button>'; }).join('') + '</div></div>' };
    var ilk = true;
    S.yaz = function (metin) { return API.rpc('ozel_yaz', { p_kad: kad, p_metin: metin }); };
    S.yeniGetir = async function () {
      var r = await API.rpc('ozel_oku', { p_kad: kad, p_sonra: S.sonId });
      if (!$1('.shk-dm')) return;
      if (r.okundu_son !== undefined && r.okundu_son !== S.okunduSon) {
        S.okunduSon = r.okundu_son;
        if (!ilk) akis.querySelectorAll('.shm.benim').forEach(function (b) {
          var id = n(b.getAttribute('data-id')); var t = b.querySelector('.shm-tik');
          if (t && id && S.okunduSon != null && id <= n(S.okunduSon) && !t.classList.contains('on')) { t.classList.add('on'); t.innerHTML = I.ciftTik; t.setAttribute('aria-label', 'Okundu'); }
        });
      }
      if (r.aktif) durumGuncelle(r.aktif, r.unvan);
      if (r.mesajlar && r.mesajlar.length) { S.sonId = r.mesajlar[r.mesajlar.length - 1].id; if (!ilk) yeniEkle(akis, S, r.mesajlar); }
      return r;
    };
    function durumGuncelle(aktif, unvan) {
      var d = $1('#shkDurum'); if (d) { var h = durumYazi(aktif, unvan); if (d.innerHTML !== h) d.innerHTML = h; }
      var a = $1('#shkAv'); if (a) a.classList.toggle('cev', aktif === 'cevrimici');
    }
    try {
      var r = await S.yeniGetir();
      if (!$1('.shk-dm')) return;
      ilk = false;
      S.liste = r.mesajlar || [];
      $1('#sbBaslik').innerHTML = esc(r.kad) + nisan(r.unvan);
      var aktif = r.aktif;
      if (!aktif && typeof kimlikYukle === 'function') { try { await kimlikYukle([r.kad]); aktif = kimlikAktif(r.kad); } catch (e) {} }
      durumGuncelle(aktif, r.unvan);
      var avk = $1('#shkAv'); if (avk) { avk.innerHTML = av(r.kad, r.parti && r.parti.renk, 40); avTazele(avk); }
      akisCiz(akis, S, 'ilk');
      if (r.engelledim) $1('#yazbar').innerHTML = '<div class="shk-not">' + I.engel + '<span>Bu oyuncuyu engelledin.</span><button type="button" class="sh-btn" id="shkEngelKaldir">Engeli kaldır</button></div>';
      var ek = $1('#shkEngelKaldir'); if (ek) ek.onclick = function () { engelDegis(kad, false).then(function () { ozelEkrani(kad); }); };
      try { rozetGuncelle(await API.rpc('rozetler')); } catch (e) {}
      // Okundu: gelen kutusundaki satırı da sıfırla
      (ST.dm || []).forEach(function (x) { if (String(x.kad) === String(r.kad)) x.okunmamis = 0; });
    } catch (err) {
      akis.innerHTML = '<div class="shm-bos"><p>' + esc(hataYaz(err)) + '</p></div>'; var yb = $1('#yazbar'); if (yb) yb.remove(); return;
    }
    $1('#dmMenu').onclick = function () { dmMenu(kad); };
    $1('#shkKart').onclick = function () { oyuncuKart(kad); };
    $1('#shkKim').onclick = function () { oyuncuKart(kad); };
    akis.addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-hizli]'); if (!b) return;
      var ta = $1('#yaz'); if (!ta) return; ta.value = b.getAttribute('data-hizli'); ta.dispatchEvent(new Event('input')); ta.focus();
    });
    asagiKur(akis, S); yazmaKur(S, akis);
    D.canli = setInterval(function () { if (!document.hidden && otomatik()) S.yeniGetir().catch(function () {}); }, 4500 + Math.floor(Math.random() * 1500));
  }
  function dmMenu(kad) {
    var sat = function (k, ik, ad, cls) { return '<button type="button" class="sh-es' + (cls ? ' ' + cls : '') + '" data-es="' + k + '">' + ik + '<span>' + ad + '</span></button>'; };
    var md = modal('<div class="sh-sayfa"><div class="sh-sayfa-kisi">' + av(kad, null, 56) + '<b>' + esc(kad) + '</b></div>' +
      '<div class="sh-es-grup">' + sat('kart', I.kart, 'Oyuncu kartı') + (typeof window.kursuProfilEkrani === 'function' ? sat('kursu', I.kursu, 'Kürsü profili') : '') + '</div>' +
      '<div class="sh-es-grup">' + sat('engel', I.engel, 'Engelle', 'kirmizi') + sat('sikayet', I.bayrak, 'Oyuncuyu şikâyet et', 'kirmizi') + '</div>' +
      '<button type="button" class="sh-es-vaz" data-es="vaz">Vazgeç</button></div>');
    avTazele(md);
    md.addEventListener('click', async function (ev) {
      var b = ev.target.closest('[data-es]'); if (!b) return;
      var k = b.getAttribute('data-es');
      if (k === 'vaz') modalKapat();
      if (k === 'kart') { modalKapat(); oyuncuKart(kad); }
      if (k === 'kursu') { modalKapat(); ekranAc(function () { return window.kursuProfilEkrani(kad); }); }
      if (k === 'sikayet') sikayetModal('oyuncu', null, kad, null);
      if (k === 'engel') {
        modalKapat();
        if (await onayla('Engellensin mi?', esc(kad) + ' sana mesaj gönderemez; sen de onun mesajlarını ve yayınlarını görmezsin.', 'Engelle', true)) { await engelDegis(kad, true); ozelEkrani(kad); }
      }
    });
  }

  /* =====================================================================
     KANAL EKRANI
     ===================================================================== */
  async function kanalEkrani(kanal) {
    var oz = ST.oz && (ST.oz.kanallar || []).find(function (k) { return k.kanal === kanal; });
    var cevYaz = function (k) { return k && k.cevrimici != null ? '<span class="shk-d cevrimici"><span class="sh-nokta"></span>' + k.cevrimici + ' çevrimiçi</span><span class="shk-ayr">·</span><span class="shk-unv">' + esc(KANAL_ALT[kanal] || '') + '</span>' : '<span class="shk-unv">' + esc(KANAL_ALT[kanal] || '') + '</span>'; };
    var R = RESMI[kanal] || null;
    if (R) cevYaz = function (k) { return '<span class="shk-unv">' + esc(R.gizlilik) + '</span>' + (k && k.cevrimici != null ? '<span class="shk-ayr">·</span><span class="shk-d cevrimici"><span class="sh-nokta"></span>' + k.cevrimici + ' üye hazır</span>' : ''); };
    var akis = kabuk({ ozel: false, baslik: esc((oz && oz.baslik) || (R && R.oturum) || 'Sohbet'), av: R ? '<span class="shr-arma" style="--ar:' + R.renk + '">' + ARMA + '</span>' : kanalIkon(kanal, 40), alt: cevYaz(oz),
      sag: '<button type="button" class="shk-b" id="shkCev" aria-label="' + (R ? 'Hazır bulunan üyeler' : 'Çevrimiçi oyuncular') + '">' + I.kisiler + '</button>' });
    var S = { ozel: false, kanal: kanal, liste: [], sonId: null, ilkId: null, bitti: false, bekleyen: 0, resmi: R };
    if (!R) temaKur(kanal, oz);
    if (R) {
      var kok = $1('.shk-kanal'); if (kok) kok.classList.add('shk-resmi', 'shr-' + kanal);
      var ust = $1('.shk-ust'); if (ust) ust.insertAdjacentHTML('afterend', '<div class="shr-serit" style="--ar:' + R.renk + '"><span>' + esc(R.kurum) + '</span><b>' + esc(R.oturum) + '</b></div>');
      var ta0 = $1('#yaz'); if (ta0) { ta0.placeholder = R.yer; ta0.maxLength = 500; }
    }
    S.yaz = function (metin) { return API.rpc('sohbet_yaz', { p_kanal: kanal, p_metin: metin }); };
    S.yeniGetir = async function () {
      var r = await API.rpc('sohbet_oku', { p_kanal: kanal, p_once: null, p_sonra: S.sonId });
      if (!$1('.shk-kanal')) return r;
      if (r.mesajlar && r.mesajlar.length) { S.sonId = r.mesajlar[r.mesajlar.length - 1].id; yeniEkle(akis, S, r.mesajlar); }
      return r;
    };
    try {
      var r = await API.rpc('sohbet_oku', { p_kanal: kanal, p_once: null, p_sonra: null });
      if (!$1('.shk-kanal')) return;
      $1('#sbBaslik').textContent = r.baslik || (oz && oz.baslik) || 'Sohbet';
      S.liste = r.mesajlar || [];
      if (S.liste.length) { S.sonId = S.liste[S.liste.length - 1].id; S.ilkId = S.liste[0].id; }
      if (S.liste.length < 40) S.bitti = true;
      S.bosHtml = R ? '<div class="shm-bos shr-bos" style="--ar:' + R.renk + '"><span class="shr-arma buyuk">' + ARMA + '</span><small>' + esc(R.kurum) + '</small><b>' + esc(r.baslik || R.oturum) + '</b><p>' + esc(R.bos) + '</p></div>'
        : '<div class="shm-bos">' + kanalIkon(kanal, 76) + '<b>' + esc(r.baslik || '') + '</b><p>' + (r.yazabilir ? 'Henüz kimse yazmadı. İlk sözü sen al!' : 'Henüz kimse söz almadı. Burada konuşulanları izleyebilirsin.') + '</p></div>';
      akisCiz(akis, S, 'ilk');
      if (R && r.yazabilir) {
        var yb0 = $1('#yazbar');
        if (yb0) {
          yb0.insertAdjacentHTML('beforebegin', '<div class="shr-hitap" role="group" aria-label="Hitap kalıpları">' + R.hitap.map(function (t) { return '<button type="button" data-hitap="' + esc(t) + '">' + esc(t.trim()) + '</button>'; }).join('') + '</div>');
          var hb = $1('.shr-hitap');
          if (hb) hb.addEventListener('click', function (ev) {
            var b = ev.target.closest('[data-hitap]'); if (!b) return; hafif();
            var ta = $1('#yaz'); if (!ta) return;
            var t = b.getAttribute('data-hitap'), v = ta.value;
            ta.value = /[;:]\s*$|\s$/.test(t) ? t + v.replace(/^\s+/, '') : (v ? v.replace(/\s*$/, ' ') : '') + t;
            ta.dispatchEvent(new Event('input')); ta.focus();
            try { ta.setSelectionRange(ta.value.length, ta.value.length); } catch (e) {}
          });
        }
      }
      if (R && !r.yazabilir) {
        $1('#yazbar').innerHTML = '<div class="shk-not shr-izle">' + I.goz + '<span>' + esc(R.izle) + '</span></div>';
      } else if (!r.yazabilir) {
        $1('#yazbar').innerHTML = '<div class="shk-not">' + I.goz + '<span>' + (kanal === 'belediye' ? 'Belediye meclisinde yalnızca o ilin belediye başkanı ve milletvekilleri söz alabilir.' : kanal === 'meclis' ? 'Genel Kurul\'da yalnızca milletvekilleri, bakanlar ve cumhurbaşkanı söz alabilir.' : 'Bu kanalda söz hakkın yok.') + ' Sen izleyebilirsin.</span></div>';
      }
      try { rozetGuncelle(await API.rpc('rozetler')); } catch (e) {}
    } catch (err) {
      akis.innerHTML = '<div class="shm-bos"><p>' + esc(hataYaz(err)) + '</p></div>'; var yb = $1('#yazbar'); if (yb) yb.remove(); return;
    }
    var cb = $1('#shkCev'); if (cb) cb.onclick = function () { if (typeof cevrimiciListeAc === 'function') cevrimiciListeAc(); };
    var kb = $1('#shkKim'); if (kb) kb.onclick = function () { tst(R ? R.kurum + ' · ' + R.oturum + ' — ' + (KANAL_ALT[kanal] || '') : (KANAL_ALT[kanal] || 'Sohbet kanalı')); };
    var yukluyor = false;
    akis.addEventListener('scroll', async function () {
      if (akis.scrollTop > 60 || yukluyor || S.bitti || !S.ilkId) return;
      yukluyor = true;
      akis.insertAdjacentHTML('afterbegin', '<div class="shk-yuk ust"><span></span><span></span><span></span></div>');
      try {
        var r2 = await API.rpc('sohbet_oku', { p_kanal: kanal, p_once: S.ilkId, p_sonra: null });
        var y = (r2 && r2.mesajlar) || [];
        if (y.length) { S.ilkId = y[0].id; S.liste = y.concat(S.liste); }
        if (y.length < 40) S.bitti = true;
        var u = akis.querySelector('.shk-yuk.ust'); if (u) u.remove();
        akisCiz(akis, S, 'basa');
      } catch (e) { var u2 = akis.querySelector('.shk-yuk.ust'); if (u2) u2.remove(); }
      yukluyor = false;
    }, { passive: true });
    asagiKur(akis, S); yazmaKur(S, akis);
    D.canli = setInterval(function () { if (!document.hidden && otomatik()) S.yeniGetir().catch(function () {}); }, 5500 + Math.floor(Math.random() * 1500));
  }

  /* =====================================================================
     ÜST ÇUBUKTA MESAJ KISAYOLU (her ana ekranda, zilin yanında)
     ===================================================================== */
  function ustKisayol() {
    var hd = document.querySelector('#app > header.ust'); if (!hd || hd.querySelector('.sh-ust-dm')) return;
    if (typeof D !== 'undefined' && D.sekme === 'sohbet' && !(D.yigin && D.yigin.length)) return;
    var zil = hd.querySelector('button[aria-label="Bildirimler"]'); if (!zil) return;
    var say = 0; try { say = sohbetOkunmamisSayi(D.okunmamis); } catch (e) {}
    var b = document.createElement('button');
    b.type = 'button'; b.className = 'ikon sh-ust-dm'; b.setAttribute('aria-label', 'Mesajlar' + (say ? ', ' + say + ' okunmamış' : ''));
    b.innerHTML = I.ucak + '<span class="sh-ust-dm-say"' + (say ? '' : ' hidden') + '>' + (say > 99 ? '99+' : say) + '</span>';
    b.onclick = function () { hafif(); ST.seg = 'ozel'; sekmeAc('sohbet'); };
    zil.parentNode.insertBefore(b, zil);
  }
  function kisayolSay() {
    var say = 0; try { say = sohbetOkunmamisSayi(D.okunmamis); } catch (e) {}
    document.querySelectorAll('.sh-ust-dm-say').forEach(function (s) { s.hidden = !say; s.textContent = say > 99 ? '99+' : say; });
  }
  function izleyiciKur() {
    var app = document.getElementById('app'); if (!app) return;
    var z = 0;
    new MutationObserver(function () { if (z) return; z = requestAnimationFrame(function () { z = 0; ustKisayol(); }); }).observe(app, { childList: true });
    ustKisayol();
  }

  /* =====================================================================
     ESKİ ADLARIN YERİNE GEÇ (diğer modüller bu adları çağırıyor)
     ===================================================================== */
  function kur() {
    window.sohbetListe = sohbetListe = anaEkran;
    try { if (typeof EKRAN !== 'undefined') EKRAN.sohbet = anaEkran; } catch (e) {}
    window.ozelEkrani = ozelEkrani = ozelEkrani_;
    window.sohbetEkrani = sohbetEkrani = kanalEkrani_;
    window.yeniOzelModal = yeniOzelModal = yeniMesaj;
    // Eski 45 sn'lik yoklama bu adları çağırır: yeni gelen kutusunu tazelesin
    window.ozelListeTazele = ozelListeTazele = function () { return anaVar() ? anaYokla() : Promise.resolve(); };
    window.sohbetKanallariTazele = sohbetKanallariTazele = function () { return Promise.resolve(); };
    if (typeof rozetGuncelle === 'function' && !rozetGuncelle._sh) {
      var eski = rozetGuncelle;
      var yeni = function () { var r = eski.apply(this, arguments); try { kisayolSay(); } catch (e) {} return r; };
      yeni._sh = true;
      window.rozetGuncelle = rozetGuncelle = yeni;
    }
    try { var s = sessionStorage.getItem('shSeg'); if (s === 'ozel' || s === 'kanal') ST.seg = s; } catch (e) {}
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', izleyiciKur); else izleyiciKur();
  }
  var ozelEkrani_ = ozelEkrani, kanalEkrani_ = kanalEkrani;
  window.sohbetTasarim = { ana: anaEkran, ozel: ozelEkrani, kanal: kanalEkrani, yeni: yeniMesaj, emojiSayisi: emojiSayisi };

  /* =====================================================================
     STİL
     ===================================================================== */
  var DESEN = "data:image/svg+xml;utf8," + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="180" height="180" viewBox="0 0 180 180" fill="none" stroke="#a9b8ff" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" opacity=".055">' +
    '<path d="M28 30a10 10 0 1 0 6 18 8 8 0 1 1 0-18 10 10 0 0 0-6 0z"/><path d="M44 36l2 4 4 .5-3 2.7.8 4.3-3.8-2-3.8 2 .8-4.3-3-2.7 4-.5z"/>' +
    '<rect x="112" y="22" width="34" height="24" rx="3"/><path d="M120 22v-6h18v6M124 34h10"/>' +
    '<path d="M70 92h40M74 92v-16h32v16M90 76v-8"/><circle cx="90" cy="64" r="4"/>' +
    '<path d="M18 132l14 8 14-8M18 132v18l14 8 14-8v-18"/>' +
    '<path d="M128 120c6-10 22-10 28 0-6 10-22 10-28 0z"/><circle cx="142" cy="120" r="3.5"/>' +
    '<path d="M70 150h22l-4 10H74zM81 150v-8M75 142h12"/><path d="M150 70l6 6-6 6M150 76h-14"/></svg>');
  var KUYRUK_SOL = "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 11 16"><path d="M11 0v16H1.2C.3 16-.2 15 .4 14.3 3.6 11 7 7.2 11 0z" fill="#1e2850"/></svg>');
  var KUYRUK_SAG = "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 11 16"><path d="M0 0v16h9.8c.9 0 1.4-1 .8-1.7C7.4 11 4 7.2 0 0z" fill="#c24ba2"/></svg>');
  var css = [
    ':root{--sh-mor:#8b6cff;--sh-pembe:#ff4f8b;--sh-yesil:#22d39a;--sh-mavi:#4cc3ff;--sh-cizgi:rgba(164,184,255,.11);--sh-soluk:#8f9bbd;--sh-yuzey:#141c3a;--sh-grad:linear-gradient(135deg,#8b6cff,#ff4f8b)}',
    /* başlık */
    '.sh-baslik{display:inline-flex;align-items:center;gap:10px;font-family:var(--disp);font-weight:800;letter-spacing:.2px}',
    '.sh-logo{width:30px;height:30px;border-radius:10px;background:var(--sh-grad);display:grid;place-items:center;color:#fff;flex:none;box-shadow:0 6px 16px -6px rgba(255,79,139,.7)}.sh-logo svg{width:17px;height:17px;transform:translate(-1px,1px)}',
    '.sh-sag{display:flex;gap:2px;align-items:center;flex:none}',
    '.sh-ust-b{position:relative;width:38px;height:38px;border-radius:50%;display:grid;place-items:center;color:var(--txt2);background:none;border:0;cursor:pointer;-webkit-tap-highlight-color:transparent}',
    '.sh-ust-b svg{width:22px;height:22px}.sh-ust-b:active{transform:scale(.92)}.sh-ust-b .sayi{position:absolute;top:1px;right:0}',
    '.sh-ust-av .portre,.sh-ust-av svg.portre{width:32px!important;height:32px!important;border-radius:50%}',
    /* üst çubuk mesaj kısayolu */
    '.ust .sh-ust-dm{color:var(--txt)}.ust .sh-ust-dm svg{width:19px;height:19px;transform:translate(-1px,1px)}',
    '.sh-ust-dm-say{position:absolute;top:-5px;right:-6px;min-width:18px;height:18px;padding:0 5px;border-radius:9px;background:var(--sh-grad);color:#fff;font:800 10.5px/18px system-ui;text-align:center;box-shadow:0 0 0 2px var(--bg);animation:shNabiz 2.4s ease-in-out infinite}',
    '@keyframes shNabiz{0%,100%{transform:scale(1)}50%{transform:scale(1.12)}}',
    /* gövde */
    '.sh [hidden],.shk [hidden],.sh-ust-dm-say[hidden]{display:none!important}',
    '.sh{margin:-14px -16px 0;min-height:70vh;padding-bottom:110px;color:var(--txt);font-size:15px}',
    '.sh button{font:inherit;color:inherit;-webkit-tap-highlight-color:transparent;cursor:pointer}',
    '.sh-ara{display:flex;align-items:center;gap:9px;margin:12px 16px 0;height:42px;padding:0 6px 0 14px;border-radius:14px;background:rgba(255,255,255,.055);border:1px solid var(--sh-cizgi);color:var(--sh-soluk);transition:border-color .2s,background .2s}',
    '.sh-ara:focus-within{border-color:rgba(139,108,255,.6);background:rgba(139,108,255,.08)}.sh-ara>svg{width:18px;height:18px;flex:none}',
    '.sh-ara input{flex:1;min-width:0;height:100%;background:none;border:0;outline:none;color:var(--txt);font:inherit;font-size:16px;-webkit-appearance:none;appearance:none}.sh-ara input::-webkit-search-cancel-button{display:none}',
    '.sh-ara input::placeholder{color:var(--sh-soluk)}',
    '.sh-ara-sil{width:30px;height:30px;border:0;border-radius:50%;background:rgba(255,255,255,.08);display:grid;place-items:center;flex:none}.sh-ara-sil svg{width:14px;height:14px}',
    /* sekmeler (kayan hap) */
    '.sh-seg{position:relative;display:grid;grid-template-columns:1fr 1fr;margin:12px 16px 4px;padding:4px;border-radius:16px;background:rgba(255,255,255,.045);border:1px solid var(--sh-cizgi)}',
    '.sh-seg-kay{position:absolute;top:4px;bottom:4px;left:4px;width:calc(50% - 4px);border-radius:12px;background:linear-gradient(135deg,rgba(139,108,255,.95),rgba(255,79,139,.88));box-shadow:0 8px 22px -10px rgba(255,79,139,.8);transform:translateX(calc(var(--i) * 100%));transition:transform .32s cubic-bezier(.3,1.3,.5,1)}',
    '.sh-seg button{position:relative;z-index:1;height:38px;border:0;background:none;border-radius:12px;display:flex;align-items:center;justify-content:center;gap:7px;font-weight:700!important;font-size:14.5px!important;color:var(--sh-soluk)!important;transition:color .2s}',
    '.sh-seg button.on{color:#fff!important}.sh-seg button svg{width:17px;height:17px}',
    '.sh-say{font-style:normal;min-width:19px;height:19px;padding:0 6px;border-radius:10px;background:var(--sh-pembe);color:#fff;font:800 11px/19px system-ui;text-align:center}',
    '.sh-seg button.on .sh-say{background:#fff;color:#c43c7a}',
    /* hikâye şeridi */
    '.sh-hikaye{display:flex;gap:14px;overflow-x:auto;padding:12px 16px 10px;scrollbar-width:none;scroll-snap-type:x proximity;scroll-padding-inline:16px}.sh-hikaye::-webkit-scrollbar{display:none}',
    '.sh-h{flex:none;width:66px;display:flex;flex-direction:column;align-items:center;gap:6px;background:none;border:0;padding:0;scroll-snap-align:start}',
    '.sh-h small{max-width:66px;font-size:12px;color:var(--txt2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-weight:600}',
    '.sh-h-hal{position:relative;width:64px;height:64px;border-radius:50%;display:grid;place-items:center;background:rgba(255,255,255,.07)}',
    '.sh-h-hal .portre,.sh-h-hal svg.portre{width:56px!important;height:56px!important;border-radius:50%;box-shadow:0 0 0 3px var(--bg)}',
    '.sh-h.halka .sh-h-hal{background:conic-gradient(from 210deg,#8b6cff,#ff4f8b,#ffa24c,#8b6cff)}',
    '.sh-h.halka small{color:#fff;font-weight:800}',
    '.sh-h.cev .sh-h-hal::after{content:"";position:absolute;right:3px;bottom:3px;width:15px;height:15px;border-radius:50%;background:var(--sh-yesil);box-shadow:0 0 0 3px var(--bg)}',
    '.sh-h-ic{width:56px;height:56px;border-radius:50%;display:grid;place-items:center;background:var(--sh-yuzey);border:1.5px dashed rgba(164,184,255,.35);color:#cfd6ff}.sh-h-ic svg{width:24px;height:24px}',
    '.sh-h-yeni .sh-h-ic{background:var(--sh-grad);border:0;color:#fff;box-shadow:0 10px 22px -10px rgba(255,79,139,.9)}',
    '.sh-h-cev .sh-h-hal em{position:absolute;right:-2px;bottom:0;min-width:22px;height:20px;padding:0 6px;border-radius:10px;background:var(--sh-yesil);color:#06261b;font:800 11px/20px system-ui;font-style:normal;box-shadow:0 0 0 3px var(--bg)}.sh-h-cev .sh-h-hal em:empty{display:none}',
    /* bölüm başlığı ve çipler */
    '.sh-bas{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:14px 16px 6px}',
    '.sh-bas h3{margin:0;font-family:var(--disp);font-size:19px;font-weight:800;letter-spacing:.2px}',
    '.sh-cipler{display:flex;gap:6px}',
    '.sh-cip{height:30px;padding:0 11px;border-radius:999px;border:1px solid var(--sh-cizgi);background:none;font-size:13px!important;font-weight:700!important;color:var(--sh-soluk)!important;display:inline-flex;align-items:center;gap:5px}',
    '.sh-cip small{font-size:11.5px;opacity:.75}.sh-cip.on{background:rgba(139,108,255,.18);border-color:rgba(139,108,255,.55);color:#fff!important}',
    '.sh-ipucu{display:flex;align-items:center;gap:8px;margin:2px 16px 4px;padding:8px 12px;border-radius:12px;background:rgba(34,211,154,.08);color:#9fe9cf;font-size:13px;font-weight:600}',
    '.sh-nokta{width:8px;height:8px;border-radius:50%;background:var(--sh-yesil);display:inline-block;flex:none;box-shadow:0 0 0 0 rgba(34,211,154,.6);animation:shYan 2s infinite}',
    '@keyframes shYan{0%{box-shadow:0 0 0 0 rgba(34,211,154,.55)}70%{box-shadow:0 0 0 7px rgba(34,211,154,0)}100%{box-shadow:0 0 0 0 rgba(34,211,154,0)}}',
    /* konuşma satırı */
    '.sh-liste{display:flex;flex-direction:column}',
    '.sh-k,.sh-c{position:relative;display:flex;align-items:center;gap:13px;width:100%;padding:11px 16px;background:none;border:0;text-align:left;transition:background .15s}',
    '.sh-k:active,.sh-c:active{background:rgba(255,255,255,.04)}',
    '.sh-k+.sh-k::before,.sh-c+.sh-c::before{content:"";position:absolute;top:0;left:83px;right:0;height:1px;background:var(--sh-cizgi)}',
    '.sh-k-av{position:relative;flex:none;width:54px;height:54px;display:block}',
    '.sh-k-av .portre,.sh-k-av svg.portre,.sh-k-av .sh-av-bos{width:54px!important;height:54px!important;max-width:54px;border-radius:50%;display:block;overflow:hidden}',
    '.sh-k-av.cev::after,.shk-av.cev::after{content:"";position:absolute;right:1px;bottom:1px;width:14px;height:14px;border-radius:50%;background:var(--sh-yesil);box-shadow:0 0 0 3px var(--bg)}',
    '.sh-av-bos{display:grid!important;place-items:center;background:#2a3566;color:#fff;font-weight:800;font-size:15px;border-radius:50%}',
    '.sh-k-orta{flex:1;min-width:0;display:flex;flex-direction:column;gap:3px}',
    '.sh-k-ust{display:flex;align-items:center;gap:5px;min-width:0}',
    '.sh-k-ust b{font-size:16px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}',
    '.sh-k-ust time{margin-left:auto;flex:none;padding-left:8px;font-size:12.5px;color:var(--sh-soluk);font-variant-numeric:tabular-nums}',
    '.sh-k-alt{display:flex;align-items:center;gap:8px;min-width:0}',
    '.sh-k-m{flex:1;min-width:0;display:flex;align-items:center;gap:4px;color:var(--sh-soluk);font-size:14.5px;line-height:1.3;white-space:nowrap;overflow:hidden}',
    '.sh-k-m>span:last-child,.sh-onm{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-width:0}',
    '.sh-k-m b{color:var(--txt2);font-weight:600}',
    '.sh-onm.em{font-size:16px;line-height:1.1}',
    '.sh-sen{flex:none;color:var(--txt2);font-weight:600}',
    '.sh-tik{flex:none;display:inline-grid;color:var(--sh-soluk)}.sh-tik svg{height:11px;width:auto}.sh-tik.on{color:var(--sh-mavi)}',
    '.sh-k-say{flex:none;font-style:normal;min-width:22px;height:22px;padding:0 7px;border-radius:11px;background:var(--sh-grad);color:#fff;font:800 12px/22px system-ui;text-align:center;box-shadow:0 6px 14px -6px rgba(255,79,139,.9)}',
    '.sh-k-unv{font-size:12px;color:#b9a8ff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-weight:600}',
    '.sh-k.yeni .sh-k-ust b{font-weight:800;color:#fff}.sh-k.yeni .sh-k-m{color:var(--txt);font-weight:600}.sh-k.yeni .sh-k-ust time{color:#ff8db5;font-weight:700}',
    '.sh-k.yeni::after{content:"";position:absolute;left:0;top:18px;bottom:18px;width:3px;border-radius:0 3px 3px 0;background:var(--sh-grad)}',
    '.sh-nisan{flex:none;display:inline-grid;width:16px;height:16px}.sh-nisan svg{width:16px;height:16px}',
    /* kanallar */
    '.sh-kik{flex:none;position:relative;display:grid;place-items:center;border-radius:16px;color:var(--k);background:rgba(255,255,255,.07);background:linear-gradient(145deg,color-mix(in srgb,var(--k) 30%,transparent),color-mix(in srgb,var(--k) 10%,transparent));box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--k) 35%,transparent)}',
    '.sh-kik svg{width:46%;height:46%}',
    '.sh-c.kilit .sh-kik{filter:grayscale(.85);opacity:.55}.sh-c.kilit .sh-k-ust b{color:var(--sh-soluk)}.sh-c.kilit .sh-k-m{font-size:13px}',
    '.sh-c-kilit{position:absolute;left:52px;top:44px;width:22px;height:22px;border-radius:50%;background:#2a3462;color:#cfd6ff;display:grid;place-items:center;box-shadow:0 0 0 3px var(--bg)}.sh-c-kilit svg{width:12px;height:12px}',
    '.sh-c-alt{display:flex;gap:8px;align-items:center;flex-wrap:wrap}',
    '.sh-c-cev{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:700;color:#7fe3bf}.sh-c-cev .sh-nokta{width:7px;height:7px}',
    '.sh-c-izle{display:inline-flex;align-items:center;gap:4px;font-size:12px;font-weight:700;color:var(--sh-soluk)}.sh-c-izle svg{width:13px;height:13px}',
    '.sh-c.yeni .sh-k-ust b{font-weight:800;color:#fff}.sh-c.yeni .sh-k-m{color:var(--txt)}',
    /* meydan kartı */
    '.sh-meydan{position:relative;overflow:hidden;display:flex;flex-direction:column;gap:6px;width:calc(100% - 32px);margin:12px 16px 4px;padding:16px 16px 14px;border:0;border-radius:22px;text-align:left;color:#fff;background:radial-gradient(120% 140% at 100% 0%,#ff4f8b 0%,rgba(255,79,139,0) 55%),linear-gradient(135deg,#6a4cf0 0%,#3b2a9a 55%,#1b2160 100%);box-shadow:0 18px 40px -18px rgba(139,108,255,.9)}',
    '.sh-meydan:active{transform:scale(.985)}',
    '.sh-meydan-desen{position:absolute;inset:0;background-image:url("' + DESEN.replace(/"/g, '%22') + '");background-size:140px;opacity:1;mix-blend-mode:screen;pointer-events:none}',
    '.sh-meydan-ust{position:relative;display:flex;align-items:center;justify-content:space-between}',
    '.sh-canli{display:inline-flex;align-items:center;gap:5px;padding:4px 9px;border-radius:999px;background:rgba(255,40,80,.9);font:800 11px/1 system-ui;letter-spacing:.8px}.sh-canli svg{width:12px;height:12px;animation:shYanip 1.4s infinite}',
    '@keyframes shYanip{50%{opacity:.35}}',
    '.sh-meydan b{position:relative;font-family:var(--disp);font-size:24px;font-weight:800;letter-spacing:.2px;line-height:1.1}',
    '.sh-meydan-alt{position:relative;font-size:14px;color:rgba(255,255,255,.86);display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;line-height:1.35}.sh-meydan-alt em{font-style:normal;font-weight:800;color:#fff}',
    '.sh-meydan-alt2{position:relative;display:flex;align-items:center;justify-content:space-between;margin-top:4px;font-size:13px;font-weight:700}.sh-meydan-alt2>span:first-child{display:inline-flex;align-items:center;gap:7px}',
    '.sh-meydan-git{display:inline-flex;align-items:center;gap:3px;padding:7px 12px;border-radius:999px;background:rgba(255,255,255,.16);-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px)}.sh-meydan-git svg{width:15px;height:15px}',
    '.sh-meydan .sh-k-say{background:#fff;color:#c43c7a;box-shadow:none}',
    '.sh-kural{display:flex;gap:10px;align-items:flex-start;margin:18px 16px 0;padding:12px 14px;border-radius:14px;background:rgba(255,255,255,.035);color:var(--sh-soluk);font-size:12.5px;line-height:1.45}.sh-kural svg{width:16px;height:16px;flex:none;margin-top:1px}',
    /* boş durum ve iskelet */
    '.sh-bos{display:flex;flex-direction:column;align-items:center;text-align:center;padding:26px 24px 10px}.sh-bos.kucuk{padding:22px 24px}',
    '.sh-bos-res svg{width:170px;height:128px;filter:drop-shadow(0 18px 30px rgba(139,108,255,.35))}',
    '.sh-bos b{font-family:var(--disp);font-size:21px;margin-top:6px}.sh-bos p{margin:8px 0 16px;color:var(--sh-soluk);line-height:1.5;max-width:300px}',
    '.sh-bos-d{display:flex;flex-direction:column;gap:9px;width:100%;max-width:300px}',
    '.sh-btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;height:46px;padding:0 18px;border-radius:14px;border:1px solid var(--sh-cizgi);background:rgba(255,255,255,.06);font-weight:700!important;font-size:15px!important}',
    '.sh-btn svg{width:18px;height:18px}.sh-btn.ana{background:var(--sh-grad);border:0;color:#fff;box-shadow:0 12px 26px -12px rgba(255,79,139,.9)}',
    '.sh-link{background:none;border:0;padding:0;color:#b9a8ff;font-weight:700;text-decoration:underline}',
    '.sh-hayal{display:flex;gap:13px;align-items:center;padding:12px 16px}.sh-hayal .a{width:54px;height:54px;border-radius:50%}.sh-hayal .b{flex:1;display:flex;flex-direction:column;gap:8px}.sh-hayal i{display:block;height:11px;border-radius:6px;width:45%}.sh-hayal i+i{width:80%}',
    '.sh-hayal .a,.sh-hayal i,.sh-hayal-h{background:linear-gradient(90deg,rgba(255,255,255,.05),rgba(255,255,255,.11),rgba(255,255,255,.05));background-size:200% 100%;animation:shParilti 1.3s linear infinite}',
    '.sh-hayal-h{flex:none;width:64px;height:64px;border-radius:50%}',
    '@keyframes shParilti{to{background-position:-200% 0}}',
    /* FAB */
    '.sh-fab{position:absolute;right:16px;bottom:calc(var(--safeB,0px) + 84px);z-index:20;width:58px;height:58px;border-radius:20px;border:0;background:var(--sh-grad);color:#fff;display:grid;place-items:center;cursor:pointer;box-shadow:0 16px 32px -10px rgba(255,79,139,.75),0 0 0 1px rgba(255,255,255,.14) inset;animation:shFab .45s cubic-bezier(.3,1.4,.5,1)}',
    '.sh-fab svg{width:25px;height:25px}.sh-fab:active{transform:scale(.92)}',
    '@keyframes shFab{from{transform:scale(.4) rotate(-20deg);opacity:0}}',
    /* yeni mesaj penceresi */
    '.sh-yeni h3{font-family:var(--disp);font-size:22px;font-weight:800;margin:2px 0 10px}',
    '.sh-ara-m{margin:0 0 6px}',
    '.sh-yeni-liste{max-height:56vh;overflow-y:auto;margin:0 -6px}',
    '.sh-ys-bas{padding:12px 6px 4px;font-size:12px;font-weight:800;letter-spacing:.6px;color:var(--sh-soluk);text-transform:uppercase}',
    '.sh-ys-bos{padding:18px 8px;color:var(--sh-soluk);line-height:1.5;text-align:center}',
    '.sh-ys{display:flex;align-items:center;gap:12px;width:100%;padding:9px 6px;border:0;border-radius:14px;background:none;text-align:left;color:inherit;font:inherit;cursor:pointer}',
    '.sh-ys:active{background:rgba(255,255,255,.05)}.sh-ys .sh-k-av,.sh-ys .sh-k-av .portre,.sh-ys .sh-k-av svg.portre,.sh-ys .sh-av-bos{width:44px!important;height:44px!important}',
    '.sh-ys-alt{font-size:12.5px;color:var(--sh-soluk);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.sh-ys-git{flex:none;width:36px;height:36px;border-radius:50%;display:grid;place-items:center;background:rgba(139,108,255,.16);color:#c8baff}.sh-ys-git svg{width:18px;height:18px}',
    /* eylem sayfası */
    '.sh-sayfa{display:flex;flex-direction:column;gap:10px}',
    '.sh-sayfa-onizle{display:flex;flex-direction:column;align-items:flex-start;gap:6px;padding:4px 2px 6px}.sh-sayfa-onizle small{color:var(--sh-soluk);font-size:12px}',
    '.shm-mini{max-width:100%;padding:9px 13px;border-radius:18px 18px 18px 6px;background:#222c55;font-size:15px;line-height:1.4;white-space:pre-wrap;overflow-wrap:anywhere}',
    '.shm-mini.benim{align-self:flex-end;border-radius:18px 18px 6px 18px;background:linear-gradient(135deg,#7356f0,#b84ad0);color:#fff}',
    '.sh-sayfa-onizle:has(.benim){align-items:flex-end}',
    '.sh-sayfa-kisi{display:flex;flex-direction:column;align-items:center;gap:8px;padding:4px 0 6px}.sh-sayfa-kisi .portre,.sh-sayfa-kisi svg.portre{width:56px!important;height:56px!important;border-radius:50%}.sh-sayfa-kisi b{font-size:18px}',
    '.sh-es-grup{display:flex;flex-direction:column;border-radius:16px;overflow:hidden;background:rgba(255,255,255,.05)}',
    '.sh-es{display:flex;align-items:center;gap:14px;width:100%;height:52px;padding:0 16px;border:0;background:none;color:var(--txt);font:inherit;font-size:16px;font-weight:600;text-align:left;cursor:pointer}',
    '.sh-es+.sh-es{border-top:1px solid var(--sh-cizgi)}.sh-es svg{width:21px;height:21px;color:#b9a8ff;flex:none}.sh-es:active{background:rgba(255,255,255,.05)}',
    '.sh-es.kirmizi,.sh-es.kirmizi svg{color:#ff6b81}',
    '.sh-es-vaz{height:50px;border:0;border-radius:16px;background:rgba(255,255,255,.08);color:var(--txt);font:inherit;font-size:16px;font-weight:700;cursor:pointer}',
    /* ===== konuşma ekranı ===== */
    '.shk{background:#0b1129}',
    '.shk::before{content:"";position:absolute;inset:0;pointer-events:none;background:radial-gradient(90% 60% at 100% 0%,rgba(139,108,255,.16),transparent 60%),radial-gradient(80% 50% at 0% 100%,rgba(255,79,139,.10),transparent 60%),url("' + DESEN.replace(/"/g, '%22') + '");background-size:auto,auto,180px}',
    '.shk-ust{position:relative;z-index:3;display:flex;align-items:center;gap:6px;padding:calc(var(--safeT,0px) + 8px) 8px 8px 6px;background:rgba(12,18,44,.82);-webkit-backdrop-filter:saturate(170%) blur(20px);backdrop-filter:saturate(170%) blur(20px);border-bottom:1px solid var(--sh-cizgi)}',
    '.shk-ust button{background:none;border:0;color:var(--txt);font:inherit;cursor:pointer;-webkit-tap-highlight-color:transparent}',
    '.shk-geri{width:38px;height:40px;display:grid;place-items:center;flex:none;border-radius:12px}.shk-geri svg{width:24px;height:24px}.shk-geri:active{background:rgba(255,255,255,.07)}',
    '.shk-kim{flex:1;min-width:0;display:flex;align-items:center;gap:10px;padding:2px 4px;border-radius:12px;text-align:left}',
    '.shk-av{position:relative;flex:none;width:40px;height:40px}.shk-av .portre,.shk-av svg.portre,.shk-av .sh-av-bos{width:40px!important;height:40px!important;border-radius:50%}',
    '.shk-av.cev::after{width:12px;height:12px;right:0;bottom:0;box-shadow:0 0 0 2.5px #0f1534}',
    '.shk-kim .sh-kik{border-radius:13px}',
    '.shk-kim-m{min-width:0;display:flex;flex-direction:column;gap:1px}',
    '.shk-kim-m b{display:flex;align-items:center;gap:5px;font-size:16.5px;font-weight:800;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.shk-kim-m small{display:flex;align-items:center;gap:5px;font-size:12.5px;color:var(--sh-soluk);white-space:nowrap;overflow:hidden;min-width:0}',
    '.shk-d{display:inline-flex;align-items:center;gap:5px;flex:none}.shk-d.cevrimici{color:#7fe3bf;font-weight:700}.shk-d .sh-nokta{width:7px;height:7px}',
    '.shk-unv{overflow:hidden;text-overflow:ellipsis;min-width:0}.shk-ayr{opacity:.6}',
    '.shk-b{width:40px;height:40px;flex:none;display:grid;place-items:center;border-radius:12px;color:var(--txt2)!important}.shk-b svg{width:22px;height:22px}.shk-b:active{background:rgba(255,255,255,.07)}',
    '.shk-akis{position:relative;z-index:1;flex:1;overflow-y:auto;overscroll-behavior:contain;-webkit-overflow-scrolling:touch;display:block!important;padding:8px 10px 14px!important;background:none!important}',
    '.shk-yuk{display:flex;justify-content:center;gap:6px;padding:40px 0}.shk-yuk.ust{padding:12px 0}.shk-yuk span{width:8px;height:8px;border-radius:50%;background:var(--sh-mor);animation:shZipla 1s infinite}.shk-yuk span:nth-child(2){animation-delay:.15s;background:#c45ce0}.shk-yuk span:nth-child(3){animation-delay:.3s;background:var(--sh-pembe)}',
    '@keyframes shZipla{0%,80%,100%{transform:translateY(0);opacity:.5}40%{transform:translateY(-7px);opacity:1}}',
    /* gün ayracı */
    '.shm-gun{position:sticky;top:6px;z-index:2;display:flex;justify-content:center;margin:12px 0 8px;pointer-events:none}',
    '.shm-gun span{padding:5px 12px;border-radius:999px;background:rgba(22,30,66,.88);-webkit-backdrop-filter:blur(10px);backdrop-filter:blur(10px);border:1px solid var(--sh-cizgi);font-size:12px;font-weight:700;color:#c5cdf0;box-shadow:0 4px 14px -6px rgba(0,0,0,.5)}',
    /* balonlar */
    '.shm{display:flex;align-items:flex-end;gap:7px;margin-top:2px;animation:shGir .28s cubic-bezier(.2,.9,.3,1.2) both}',
    '.shm.ilk{margin-top:9px}.shm.benim{justify-content:flex-end}',
    '@keyframes shGir{from{opacity:0;transform:translateY(8px) scale(.97)}}',
    '.shm-av{flex:none;width:32px;align-self:flex-end;cursor:pointer}.shm-av .portre,.shm-av svg.portre,.shm-av .sh-av-bos{width:32px!important;height:32px!important;border-radius:50%;display:block}',
    '.shm-b{position:relative;max-width:min(80%,520px);padding:7px 11px 7px 12px;border-radius:19px;background:#1e2850;color:#eef1ff;font-size:15.5px;line-height:1.4;box-shadow:0 1px 1px rgba(0,0,0,.18);cursor:pointer;-webkit-user-select:text;user-select:text;overflow-wrap:anywhere}',
    '.shm-kanal .shm-b{max-width:calc(100% - 46px)}',
    '.shm:not(.benim).ilk .shm-b{border-top-left-radius:19px}.shm:not(.benim):not(.ilk) .shm-b{border-top-left-radius:6px}.shm:not(.benim):not(.son) .shm-b{border-bottom-left-radius:6px}',
    '.shm:not(.benim).son .shm-b{border-bottom-left-radius:5px}',
    '.shm.benim .shm-b{background:linear-gradient(140deg,#7a5cf5 0%,#a14fd8 60%,#d24a9e 130%);color:#fff;box-shadow:0 6px 18px -10px rgba(170,80,220,.9)}',
    '.shm.benim:not(.ilk) .shm-b{border-top-right-radius:6px}.shm.benim:not(.son) .shm-b{border-bottom-right-radius:6px}.shm.benim.son .shm-b{border-bottom-right-radius:5px}',
    '.shm.son:not(.emoji) .shm-b::after{content:"";position:absolute;bottom:0;width:11px;height:16px;background-repeat:no-repeat;background-size:100% 100%}',
    '.shm:not(.benim).son:not(.emoji) .shm-b::after{left:-6px;background-image:url("' + KUYRUK_SOL + '")}',
    '.shm.benim.son:not(.emoji) .shm-b::after{right:-6px;background-image:url("' + KUYRUK_SAG + '")}',
    '.shm.hata.son .shm-b::after{display:none}',
    '.shm-kim{display:flex;align-items:center;gap:5px;margin-bottom:2px;font-size:13px;min-width:0}.shm-kim b{font-weight:800;white-space:nowrap}.shm-kim small{font-size:11.5px;color:var(--sh-soluk);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}',
    '.shm-kim .sh-nisan,.shm-kim .sh-nisan svg{width:14px;height:14px}',
    '.shm-tx{white-space:pre-wrap}',
    '.shm-tx::after{content:"";display:inline-block;width:42px;height:1px}.shm.benim .shm-tx::after{width:60px}.shm-kanal .shm.benim .shm-tx::after{width:42px}',
    '.shm-ne{position:absolute;right:10px;bottom:5px;display:inline-flex;align-items:center;gap:3px;font-size:11px;line-height:1;color:rgba(214,222,255,.55);font-variant-numeric:tabular-nums;pointer-events:none}',
    '.shm.benim .shm-ne{color:rgba(255,255,255,.72)}',
    '.shm-et{color:#c8baff;font-weight:700}.shm-an{color:#8fdcff;font-weight:700}.shm.benim .shm-et,.shm.benim .shm-an{color:#fff;text-decoration:underline;text-decoration-color:rgba(255,255,255,.4)}',
    '.shm-tik{display:inline-grid;color:rgba(255,255,255,.75)}.shm-tik svg{height:11px;width:auto}.shm-tik.on{color:#7fe9ff}.shm-tik.bekle svg{width:12px;height:12px;animation:shDon 1.4s linear infinite}.shm-tik.hata{color:#ffb3c0}.shm-tik.hata svg{width:13px;height:13px}',
    '@keyframes shDon{to{transform:rotate(360deg)}}',
    '.shm.bekle .shm-b{opacity:.8}.shm.hata .shm-b{background:linear-gradient(140deg,#8a2f4a,#6a2440)!important}',
    /* yalnız emoji */
    '.shm.emoji .shm-b{background:none!important;box-shadow:none!important;padding:0 2px 16px;line-height:1.15}',
    '.shm.emoji .shm-tx{display:inline-block;font-size:42px}.shm.emoji.e2 .shm-tx{font-size:36px}.shm.emoji.e3 .shm-tx,.shm.emoji.e4 .shm-tx{font-size:30px}',
    '.shm.emoji .shm-tx::after{display:none}',
    '.shm.emoji .shm-ne{right:2px;bottom:0;padding:2px 6px;border-radius:8px;background:rgba(12,18,44,.7)}',
    '.shm.emoji .shm-kim{padding:4px 8px;border-radius:10px;background:#1e2850;display:inline-flex}',
    /* boş konuşma */
    '.shm-bos{display:flex;flex-direction:column;align-items:center;text-align:center;gap:6px;padding:46px 22px 20px}',
    '.shm-bos .portre,.shm-bos svg.portre{width:76px!important;height:76px!important;border-radius:50%;box-shadow:0 0 0 4px rgba(139,108,255,.35),0 18px 40px -16px rgba(255,79,139,.7)}',
    '.shm-bos .sh-kik{border-radius:24px}',
    '.shm-bos b{font-family:var(--disp);font-size:22px;margin-top:8px}.shm-bos p{margin:0;color:var(--sh-soluk);line-height:1.5;max-width:290px}',
    '.shm-hizli{display:flex;flex-wrap:wrap;justify-content:center;gap:8px;margin-top:14px}',
    '.shm-hizli button{height:36px;padding:0 14px;border-radius:999px;border:1px solid rgba(139,108,255,.45);background:rgba(139,108,255,.12);color:#e3dcff;font:inherit;font-size:14px;font-weight:700;cursor:pointer}',
    /* aşağı in */
    '.shk-asagi{position:absolute;right:14px;bottom:calc(var(--safeB,0px) + 84px);z-index:4;width:44px;height:44px;border-radius:50%;border:1px solid var(--sh-cizgi);background:rgba(22,30,66,.92);-webkit-backdrop-filter:blur(10px);backdrop-filter:blur(10px);color:#fff;display:grid;place-items:center;box-shadow:0 10px 24px -8px rgba(0,0,0,.6);cursor:pointer;animation:shFab .3s ease}',
    '.shk-asagi svg{width:22px;height:22px}.shk-asagi i{position:absolute;top:-6px;right:-4px;min-width:20px;height:20px;padding:0 5px;border-radius:10px;background:var(--sh-grad);font:800 11px/20px system-ui;font-style:normal;text-align:center}',
    /* yazma çubuğu */
    '.shk-yaz{position:relative;z-index:3;display:flex!important;align-items:flex-end;gap:8px!important;padding:8px 10px calc(var(--safeB,0px) + 8px)!important;background:rgba(12,18,44,.86)!important;-webkit-backdrop-filter:saturate(170%) blur(20px);backdrop-filter:saturate(170%) blur(20px);border-top:1px solid var(--sh-cizgi)!important}',
    '.shk-kutu{flex:1;min-width:0;display:flex;align-items:flex-end;border-radius:23px;background:rgba(255,255,255,.07);border:1px solid rgba(164,184,255,.16);transition:border-color .2s,background .2s}',
    '.shk-kutu:focus-within{border-color:rgba(139,108,255,.6);background:rgba(139,108,255,.08)}',
    '.shk-yaz textarea{flex:1;width:100%;min-height:44px!important;max-height:132px;padding:11px 16px!important;border:0!important;border-radius:23px!important;background:none!important;outline:none;resize:none;color:var(--txt);font:inherit;font-size:16px!important;line-height:1.4}',
    '.shk-yaz textarea::placeholder{color:var(--sh-soluk)}',
    '.shk-gonder{width:46px!important;height:46px!important;flex:none;border:0;border-radius:50%!important;display:grid;place-items:center;background:rgba(255,255,255,.08)!important;color:var(--sh-soluk)!important;cursor:pointer;transition:transform .25s cubic-bezier(.3,1.5,.5,1),background .2s,color .2s}',
    '.shk-gonder svg{width:21px;height:21px;transform:translateX(1px)}',
    '.shk-gonder.hazir{background:var(--sh-grad)!important;color:#fff!important;transform:rotate(-12deg) scale(1.04);box-shadow:0 10px 22px -10px rgba(255,79,139,.95)}.shk-gonder.hazir:active{transform:scale(.9)}',
    '.shk-gonder:disabled{opacity:1!important}',
    '.shk-not{flex:1;display:flex;align-items:center;gap:10px;flex-wrap:wrap;padding:10px 12px;border-radius:16px;background:rgba(255,255,255,.05);color:var(--sh-soluk);font-size:13.5px;line-height:1.4}.shk-not>svg{width:19px;height:19px;flex:none;color:#b9a8ff}.shk-not span{flex:1;min-width:160px}.shk-not .sh-btn{height:38px}',
    /* ===== resmî oturum (Devlet kanalları) ===== */
    '.shk-resmi{background:#0a0f22}',
    '.shk-resmi::before{background:radial-gradient(120% 55% at 50% -10%,rgba(217,178,91,.10),transparent 60%),linear-gradient(180deg,rgba(255,255,255,.012),transparent 40%)!important;background-size:auto!important}',
    '.shk-resmi::after{content:"";position:absolute;left:50%;top:52%;width:min(70vw,340px);aspect-ratio:1;transform:translate(-50%,-50%);pointer-events:none;opacity:.035;color:#d9b25b;background:url("' + ("data:image/svg+xml;utf8," + encodeURIComponent(ARMA.replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ').replace(/currentColor/g, '#d9b25b'))).replace(/"/g, '%22') + '") center/contain no-repeat}',
    '.shk-resmi .shk-ust{background:rgba(9,13,32,.92);border-bottom:1px solid rgba(217,178,91,.22)}',
    '.shk-resmi .shk-kim-m b{font-family:var(--disp);font-weight:800;letter-spacing:.2px}',
    '.shr-arma{flex:none;width:40px;height:40px;display:grid;place-items:center;border-radius:50%;color:var(--ar,#d9b25b);background:radial-gradient(circle at 50% 35%,rgba(217,178,91,.16),rgba(217,178,91,.04));box-shadow:0 0 0 1px rgba(217,178,91,.32) inset}',
    '.shr-arma svg{width:34px;height:34px}.shr-arma.buyuk{width:84px;height:84px}.shr-arma.buyuk svg{width:72px;height:72px}',
    '.shr-serit{position:relative;z-index:3;display:flex;align-items:baseline;justify-content:center;gap:8px;padding:7px 14px;background:linear-gradient(90deg,transparent,rgba(217,178,91,.10),transparent);border-bottom:1px solid rgba(217,178,91,.16);font-size:12px;color:#c9b88f;letter-spacing:.3px;white-space:nowrap;overflow:hidden}',
    '.shr-serit b{font-family:var(--disp);font-size:13px;color:var(--ar,#d9b25b);font-weight:800;overflow:hidden;text-overflow:ellipsis}',
    '.shr-serit span::after{content:"";display:inline-block;width:4px;height:4px;margin-left:8px;border-radius:50%;background:currentColor;opacity:.6;vertical-align:middle}',
    '.shk-resmi .shk-akis{padding:6px 16px 18px!important}',
    '.shr-gun{display:flex;align-items:center;gap:10px;margin:18px 0 6px;color:#c9b88f}',
    '.shr-gun i{flex:1;height:1px;background:linear-gradient(90deg,transparent,rgba(217,178,91,.4))}.shr-gun i:last-child{background:linear-gradient(90deg,rgba(217,178,91,.4),transparent)}',
    '.shr-gun span{display:flex;flex-direction:column;align-items:center;gap:1px;font-size:11.5px;text-align:center}.shr-gun b{font-family:var(--disp);font-size:14px;color:#e6cf93;font-weight:800;letter-spacing:.4px}',
    '.shm.shr{display:block;margin:0;padding:0 0 0 12px;border-left:2px solid color-mix(in srgb,var(--pr) 70%,transparent);animation:shrGir .3s ease both;cursor:pointer}',
    '.shm.shr.ilk{margin-top:16px;padding-top:2px}.shm.shr:not(.son){padding-bottom:6px}',
    '@keyframes shrGir{from{opacity:0;transform:translateY(4px)}}',
    '.shm.shr.benim{border-left-color:#d9b25b}',
    '.shr-kim{display:flex;align-items:center;gap:10px;margin-bottom:6px}',
    '.shr-kim .shm-av{width:34px;align-self:center}.shr-kim .shm-av .portre,.shr-kim .shm-av svg.portre,.shr-kim .shm-av .sh-av-bos{width:34px!important;height:34px!important}',
    '.shr-ad{flex:1;min-width:0;display:flex;flex-wrap:wrap;align-items:center;column-gap:5px}',
    '.shr-ad b{font-family:var(--disp);font-size:15.5px;font-weight:800;color:#f1ecdf;letter-spacing:.2px}',
    '.shr-ad em{font-style:normal;font-size:10.5px;font-weight:800;padding:1px 6px;border-radius:5px;color:#1b1607;background:#d9b25b}',
    '.shr-ad .sh-nisan,.shr-ad .sh-nisan svg{width:14px;height:14px}',
    '.shr-ad small{flex-basis:100%;font-size:12px;color:#a9b2cf;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.shr-kim time{flex:none;align-self:flex-start;margin-top:3px;font-size:11.5px;color:#8a93b3;font-variant-numeric:tabular-nums}',
    '.shr-metin{font-family:Georgia,"Iowan Old Style","Times New Roman",serif;font-size:16.5px;line-height:1.62;color:#e9ebf3;overflow-wrap:anywhere;-webkit-user-select:text;user-select:text}',
    '.shr-metin .shm-tx::after{display:none}',
    '.shr-metin .shm-et{color:#e6cf93}.shr-metin .shm-an{color:#b9cdfa}',
    '.shm.shr.bekle .shr-metin{opacity:.65}.shm.shr.hata{border-left-color:#ff6b81}',
    '.shr-dur{display:flex;align-items:center;gap:5px;margin-top:3px;font-family:inherit;font-size:11.5px;color:#8a93b3}.shr-dur .shm-tik{color:inherit}',
    '.shr-bos{padding-top:54px}.shr-bos small{font-size:12px;letter-spacing:.6px;color:#c9b88f;margin-top:6px}.shr-bos b{color:#f1ecdf}.shr-bos p{font-family:Georgia,serif;font-size:15px}',
    '.shr-hitap{position:relative;z-index:3;display:flex;gap:7px;overflow-x:auto;scrollbar-width:none;padding:8px 10px 0;background:rgba(9,13,32,.92);border-top:1px solid rgba(217,178,91,.18)}.shr-hitap::-webkit-scrollbar{display:none}',
    '.shr-hitap button{flex:none;height:32px;padding:0 12px;border-radius:9px;border:1px solid rgba(217,178,91,.32);background:rgba(217,178,91,.07);color:#e6cf93;font:inherit;font-size:13px;font-weight:600;cursor:pointer;white-space:nowrap}',
    '.shr-hitap button:active{background:rgba(217,178,91,.18)}',
    '.shk-resmi .shk-yaz{background:rgba(9,13,32,.92)!important;border-top:0!important}',
    '.shk-resmi .shk-kutu{border-radius:14px;border-color:rgba(217,178,91,.22)}.shk-resmi .shk-kutu:focus-within{border-color:rgba(217,178,91,.6);background:rgba(217,178,91,.06)}',
    '.shk-resmi .shk-yaz textarea{border-radius:14px!important;font-family:Georgia,serif;font-size:16px}',
    '.shk-resmi .shk-gonder{border-radius:14px!important}.shk-resmi .shk-gonder.hazir{background:linear-gradient(135deg,#e6cf93,#b8913f)!important;color:#1b1607!important;transform:none;box-shadow:0 10px 22px -12px rgba(217,178,91,.9)}',
    '.shk-resmi .shk-asagi{color:#e6cf93;border-color:rgba(217,178,91,.3)}',
    '.shr-izle{border:1px solid rgba(217,178,91,.18);background:rgba(217,178,91,.05)!important;color:#c9b88f!important}',
    /* ===== tepkiler ===== */
    '.shm-tp{display:flex;flex-wrap:wrap;gap:4px;margin-top:6px;padding-right:40px}',
    '.shr .shm-tp{padding-right:0}',
    '.shm-b.tp-var .shm-tx::after{display:none}',
    '.shm-tp button{display:inline-flex;align-items:center;gap:3px;height:24px;padding:0 7px 0 6px;border-radius:12px;border:1px solid rgba(255,255,255,.14);background:rgba(10,14,36,.35);color:#eef1ff;font:600 13px/1 system-ui,-apple-system,sans-serif;cursor:pointer;-webkit-tap-highlight-color:transparent;animation:tpPop .3s cubic-bezier(.3,1.6,.5,1)}',
    '.shm-tp button i{font-style:normal;font-size:11.5px;font-variant-numeric:tabular-nums;opacity:.85}',
    '.shm-tp button.ben{background:rgba(139,108,255,.35);border-color:rgba(200,186,255,.7)}',
    '.shm.benim .shm-tp button{background:rgba(255,255,255,.16);border-color:rgba(255,255,255,.28)}.shm.benim .shm-tp button.ben{background:rgba(255,255,255,.34)}',
    '.shr .shm-tp button{background:rgba(217,178,91,.08);border-color:rgba(217,178,91,.3);color:#e6cf93;font-family:system-ui,-apple-system,sans-serif}.shr .shm-tp button.ben{background:rgba(217,178,91,.24);border-color:rgba(217,178,91,.7)}',
    '@keyframes tpPop{from{transform:scale(.4);opacity:0}}',
    '.sh-tp-sec{display:flex;justify-content:space-between;gap:4px;padding:6px 8px;border-radius:999px;background:rgba(255,255,255,.07);box-shadow:inset 0 0 0 1px rgba(255,255,255,.06)}',
    '.sh-tp-sec button{width:42px;height:42px;border:0;border-radius:50%;background:none;font-size:25px;line-height:1;cursor:pointer;transition:transform .15s;-webkit-tap-highlight-color:transparent}',
    '.sh-tp-sec button:active{transform:scale(1.3)}.sh-tp-sec button.ben{background:rgba(139,108,255,.3)}',
    '.sh-tp-patla{position:fixed;z-index:9999;transform:translate(-50%,0);font-size:34px;pointer-events:none;animation:tpUc .9s cubic-bezier(.2,.8,.3,1) forwards}',
    '@keyframes tpUc{0%{transform:translate(-50%,0) scale(.3);opacity:0}25%{transform:translate(-50%,-26px) scale(1.35);opacity:1}100%{transform:translate(-50%,-90px) scale(.9);opacity:0}}',
    /* ===== kanal kimlikleri ===== */
    '.shk-tema::before{background:radial-gradient(110% 60% at 100% 0%,color-mix(in srgb,var(--tema) 22%,transparent),transparent 60%),radial-gradient(90% 55% at 0% 100%,color-mix(in srgb,var(--tema) 12%,transparent),transparent 60%),url("' + DESEN.replace(/"/g, '%22') + '")!important;background-size:auto,auto,180px!important}',
    '.shk-tema-parti::after{content:"";position:absolute;left:50%;top:50%;width:min(64vw,300px);aspect-ratio:1;transform:translate(-50%,-50%);background:var(--desen) center/contain no-repeat;opacity:.06;pointer-events:none;z-index:0}',
    '.shk-tema .shk-ust{border-bottom-color:color-mix(in srgb,var(--tema) 35%,transparent)}',
    '.shk-tema .shk-kim .sh-kik{box-shadow:0 0 0 2px color-mix(in srgb,var(--tema) 55%,transparent)}',
    '.sht-serit{position:relative;z-index:3;display:flex;align-items:baseline;justify-content:center;gap:8px;padding:7px 14px;background:linear-gradient(90deg,transparent,color-mix(in srgb,var(--tema) 16%,transparent),transparent);border-bottom:1px solid color-mix(in srgb,var(--tema) 22%,transparent);font-size:12px;white-space:nowrap;overflow:hidden}',
    '.sht-serit b{font-family:var(--disp);font-size:13.5px;font-weight:800;color:color-mix(in srgb,var(--tema) 70%,#fff);overflow:hidden;text-overflow:ellipsis}',
    '.sht-serit span{color:#a9b2cf;overflow:hidden;text-overflow:ellipsis}',
    '.shk-tema .shm.benim .shm-b{background:linear-gradient(140deg,color-mix(in srgb,var(--tema) 78%,#1a1440) 0%,color-mix(in srgb,var(--tema) 52%,#1a1440) 100%);box-shadow:0 6px 18px -10px color-mix(in srgb,var(--tema) 80%,transparent)}',
    '.shk-tema .shm.benim.son:not(.emoji) .shm-b::after{display:none}.shk-tema .shm.benim.son .shm-b{border-bottom-right-radius:6px}',
    '.shk-tema .shm-gun span{border-color:color-mix(in srgb,var(--tema) 30%,transparent)}',
    '.shk-tema .shk-gonder.hazir{background:linear-gradient(135deg,color-mix(in srgb,var(--tema) 85%,#fff),var(--tema))!important;box-shadow:0 10px 22px -10px var(--tema)}',
    '.shk-tema .shk-kutu:focus-within{border-color:color-mix(in srgb,var(--tema) 60%,transparent);background:color-mix(in srgb,var(--tema) 8%,transparent)}',
    '.shk-tema-il .shm:not(.benim) .shm-b{background:#2a2335}.shk-tema-il .shm:not(.benim).son:not(.emoji) .shm-b::after{display:none}',
    '.shk-tema-genel .shk-yaz,.shk-tema-il .shk-yaz{border-top:1px solid color-mix(in srgb,var(--tema) 25%,transparent)!important}',
    '@media (prefers-reduced-motion:reduce){.shm-tp button,.sh-tp-patla{animation:none}}',
    '@media (min-width:760px){.shk-akis{padding-left:max(10px,calc(50% - 360px))!important;padding-right:max(10px,calc(50% - 360px))!important}}',
    '@media (prefers-reduced-motion:reduce){.shm,.sh-fab,.shk-asagi{animation:none}.sh-seg-kay{transition:none}.sh-nokta,.sh-ust-dm-say{animation:none}}'
  ];
  var st = document.createElement('style'); st.id = 'sohbetTasarimStil'; st.textContent = css.join('\n');
  (document.head || document.documentElement).appendChild(st);

  // Kanal ekranında akışa sınıf ver (avatar sütunu için)
  var eskiKabuk = kabuk;
  kabuk = function (o) { var a = eskiKabuk(o); if (!o.ozel) a.classList.add('shm-kanal'); return a; };

  kur();
})();
