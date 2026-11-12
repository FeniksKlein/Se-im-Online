/* 13.11.2026 · Gözaltı ve Avukat merkezi — sunucu: supabase/migrations/20261113020000_gozalti_iletisim_avukat_kota.sql
   ve 20261113021500_gozalti_tahliye_merkezi.sql.
   • Gözaltındaki oyuncu: süre, gerekçe, avukat çağırma, barodan müdafi isteme; yalnız avukatıyla özel mesaj.
   • Avukat: çağrıları kabul/ret, müvekkille özel mesaj, müvekkil adına Kürsü açıklaması.
   • Baro başkanı: bütün gözaltılara müdafi gönderme.
   • Cumhurbaşkanı / İçişleri Bakanı: günlük kotalı gözaltı kararı ve süresinden önce tahliye.
   Yetkiler sunucuda denetlenir; bu dosya yalnız ekranı çizer. Üç gözaltı türünü (eylem, İçişleri, CB/İçişleri kararı) birlikte gösterir. */
(function () {
  "use strict";
  if (window.SO_GOZALTI_V1) return;
  window.SO_GOZALTI_V1 = true;

  var ST = { veri: null, zaman: 0, yetki: null, yetkiZaman: 0 };
  var KAYNAK = { sokak: "Eylem gözaltısı", icisleri: "İçişleri gözaltısı", yonetim: "CB / İçişleri kararı" };
  var AVDURUM = { cagrildi: "Avukat çağrıldı, yanıt bekleniyor", kabul: "Avukat görevde", ret: "Avukat reddetti", red: "Avukat reddetti" };

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  function rpc(fn, a) { return typeof API !== "undefined" && API && API.rpc ? API.rpc(fn, a || {}) : Promise.reject(new Error("Oyun bağlantısı henüz kurulmadı")); }
  function hata(err) { var m = (err && err.message) || String(err); if (typeof hataCevir === "function") m = hataCevir(m); if (typeof toast === "function") toast(m, true); else alert(m); }
  function bilgi(m) { if (typeof toast === "function") toast(m); }
  function saat(t) { if (!t) return "—"; try { return new Date(t).toLocaleString("tr-TR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (e) { return String(t); } }
  function kalan(t) {
    var ms = new Date(t).getTime() - Date.now();
    if (!(ms > 0)) return "süre doldu";
    var dk = Math.ceil(ms / 60000), sa = Math.floor(dk / 60); dk = dk % 60;
    return (sa ? sa + " sa " : "") + dk + " dk";
  }
  function ac(fn) { if (typeof ekranAc === "function") ekranAc(fn); else fn(); }
  function dmAc(kad) {
    if (!kad) return;
    if (typeof window.ozelEkrani === "function") ac(function () { return window.ozelEkrani(kad); });
    else if (typeof sekmeAc === "function") sekmeAc("sohbet");
  }
  window.gozaltiDmAc = dmAc;

  function stil() {
    if (document.getElementById("gzStil")) return;
    var s = document.createElement("style"); s.id = "gzStil";
    s.textContent = [
      ".gzx label{display:block;font-size:15px;margin:12px 0 6px;line-height:1.35}",
      ".gzx input,.gzx textarea,.gzx select{display:block;width:100%;min-width:0;box-sizing:border-box;font-size:16px;padding:12px;border-radius:12px;background:#0f1730;color:#fff;border:1px solid #4a5a82;color-scheme:dark}",
      ".gzx textarea{min-height:96px;resize:vertical;line-height:1.4}",
      ".gzx input::placeholder,.gzx textarea::placeholder{color:#9aa7c7}",
      ".gzx .btn{width:100%;min-height:48px;margin-top:10px;white-space:normal;line-height:1.25;box-sizing:border-box}",
      ".gzx p,.gzx li,.gzx small{font-size:14px;line-height:1.45}",
      ".gzx .gz-kapak{border-radius:18px;padding:16px 15px;margin:0 0 12px;background:radial-gradient(120% 90% at 100% 0%,rgba(229,72,77,.28),transparent 60%),linear-gradient(170deg,#2a1520,#141a33);border:1px solid rgba(229,72,77,.45)}",
      ".gzx .gz-kapak h2{margin:0 0 6px;font-size:22px;color:#fff;line-height:1.15}",
      ".gzx .gz-sayac{font-size:30px;font-weight:800;color:#ffd27a;margin:6px 0 2px;letter-spacing:.5px}",
      ".gzx .gz-satir{display:flex;justify-content:space-between;gap:10px;padding:7px 0;border-bottom:1px solid rgba(255,255,255,.08);font-size:14px}",
      ".gzx .gz-satir span:first-child{color:#aab6d6}.gzx .gz-satir span:last-child{text-align:right;color:#fff;overflow-wrap:anywhere}",
      ".gzx .gz-uyari{border-radius:14px;padding:12px 13px;margin:10px 0;background:rgba(255,210,122,.10);border:1px solid rgba(255,210,122,.45);color:#ffe7b3;font-size:14px;line-height:1.45}",
      ".gzx .gz-dosya{border-radius:16px;padding:13px;margin:10px 0;background:#121a35;border:1px solid #2c3a63}",
      ".gzx .gz-dosya h4{margin:0 0 4px;font-size:16px;color:#fff;overflow-wrap:anywhere}",
      ".gzx .gz-etiket{display:inline-block;font-size:12px;padding:3px 8px;border-radius:99px;background:#26345e;color:#cfe0ff;margin:2px 4px 2px 0}",
      ".gzx .gz-etiket.kirmizi{background:#5a1f2a;color:#ffc9cf}.gzx .gz-etiket.yesil{background:#16402f;color:#b9f3d5}",
      ".gzx .gz-avukat{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:10px 0;border-bottom:1px solid rgba(255,255,255,.07)}",
      ".gzx .gz-avukat b{overflow-wrap:anywhere}.gzx .gz-avukat .btn{width:auto;min-width:96px;margin:0;flex:0 0 auto}",
      ".gzx .gz-aciklama{padding:9px 11px;border-left:3px solid #c18a3e;background:rgba(193,138,62,.08);border-radius:8px;margin:8px 0;font-size:14px;line-height:1.45;overflow-wrap:anywhere}",
      ".gz-serit{display:flex;align-items:center;gap:10px;border-radius:14px;padding:10px 12px;margin:6px 10px;flex:0 0 auto;background:linear-gradient(110deg,#4a1822,#1b2142);border:1px solid rgba(229,72,77,.55);color:#fff}",
      ".gz-serit .gz-s-ik{font-size:22px;flex:0 0 auto}.gz-serit .gz-s-m{flex:1 1 auto;min-width:0;font-size:14px;line-height:1.4}",
      ".gz-serit .gz-s-m b{display:block;font-size:15px}.gz-serit button{flex:0 0 auto;min-height:44px;padding:0 12px;border-radius:12px;border:0;background:#ffd27a;color:#2a1a08;font-weight:800;font-size:14px}",
      ".gz-yazbar-not{display:flex;align-items:center;gap:10px;padding:10px 12px;margin:6px;border-radius:12px;background:#3a1822;border:1px solid rgba(229,72,77,.5);color:#ffe1e4;font-size:14px;line-height:1.4}",
      ".gz-yazbar-not button{flex:0 0 auto;min-height:44px;padding:0 12px;border-radius:10px;border:0;background:#ffd27a;color:#2a1a08;font-weight:800}"
    ].join("\n");
    document.head.appendChild(s);
  }

  async function yukle(zorla) {
    if (!zorla && ST.veri && Date.now() - ST.zaman < 20000) return ST.veri;
    var v = await rpc("gozalti_durumum");
    ST.veri = v; ST.zaman = Date.now();
    seritKur(); yazbarKur();
    return v;
  }
  function benGozaltinda() { var g = ST.veri && ST.veri.gozalti; return g && g.aktif && new Date(g.bitis).getTime() > Date.now() ? g : null; }
  function avukatlarim() { var g = benGozaltinda(); return g ? (g.yazabilecegi || []) : []; }

  /* ---------------- Ekran ---------------- */
  function satir(a, b) { return '<div class="gz-satir"><span>' + a + '</span><span>' + b + '</span></div>'; }

  function benimDosyamHtml(g) {
    var avk = (g.yazabilecegi || []);
    var h = '<div class="gz-kapak"><h2>🔒 Gözaltındasınız</h2><div class="kucuk">' + esc(g.tur_ad || KAYNAK[g.kaynak]) + ' · Dosya #' + esc(g.id) + '</div>' +
      '<div class="gz-sayac" data-gz-bitis="' + esc(g.bitis) + '">' + esc(kalan(g.bitis)) + '</div><div class="kucuk">kaldı · bitiş ' + esc(saat(g.bitis)) + '</div></div>';
    h += '<div class="gz-uyari"><b>İletişim kısıtı.</b> Gözaltı süresince hiçbir sohbete, Kürsü\'ye, gazeteye, mitinge ya da açıklamaya yazamazsınız. ' +
      (avk.length ? 'Yalnız avukatınız <b>' + avk.map(esc).join(", ") + '</b> ile oyun içi özel mesajlaşabilirsiniz. Sizin adınıza açıklamayı avukatınız yapar.'
        : 'Henüz avukatınız yok: aşağıdan bir avukat çağırın ya da barodan müdafi isteyin. Sonra yalnız avukatınızla özel mesajlaşabilirsiniz.') + '</div>';
    h += '<div class="kart gzx-kart"><h3>Dosya bilgisi</h3>' +
      satir('Tür', esc(g.tur_ad || KAYNAK[g.kaynak])) +
      (g.yetkili_kad ? satir('Kararı veren', esc(g.yetkili_kad)) : '') +
      satir('Gerekçe', esc(g.gerekce || '—')) +
      satir('Başlangıç', esc(saat(g.baslangic))) + satir('Bitiş', esc(saat(g.bitis))) +
      satir('Avukat', g.avukat_kad ? esc(g.avukat_kad) + ' · ' + esc(AVDURUM[g.avukat_durum] || g.avukat_durum || '') : 'Yok') +
      '<p class="kucuk" style="margin-top:10px">Gözaltını süresi dolmadan yalnız Cumhurbaşkanı veya İçişleri Bakanı sonlandırabilir.</p></div>';
    if (avk.length) {
      h += '<div class="kart"><h3>Avukatınızla görüşün</h3>' + avk.map(function (k) {
        return '<button class="btn altin" type="button" data-gz-dm="' + esc(k) + '">💬 ' + esc(k) + ' ile özel mesaj</button>';
      }).join('') + '</div>';
    }
    if (g.avukat_durum !== 'kabul') {
      h += '<div class="kart"><h3>Avukat çağır</h3><p>Aktif ruhsatlı bir avukat seçin. Avukat kabul edince savunmanızı üstlenir.</p>' +
        '<label for="gzAvAra">Avukat ara (kullanıcı adı)</label><input id="gzAvAra" type="search" autocomplete="off" placeholder="Örn. avukat adı">' +
        '<button class="btn ikinci" type="button" data-gz-avara>Avukatları listele</button><div id="gzAvListe"></div></div>';
      h += '<div class="kart"><h3>Barodan müdafi iste</h3><p>Baro başkanı dosyanıza bir avukat görevlendirir.</p>' +
        (g.baro_talep ? '<p><span class="gz-etiket">Baro talebiniz beklemede</span></p>' :
          '<button class="btn altin" type="button" data-gz-baroiste="' + esc(g.kaynak) + ':' + esc(g.id) + '">⚖️ Barodan müdafi iste</button>') + '</div>';
    }
    if ((g.aciklamalar || []).length) {
      h += '<div class="kart"><h3>Avukatınızın adınıza yaptığı açıklamalar</h3>' + g.aciklamalar.map(function (a) {
        return '<div class="gz-aciklama">' + esc(a.metin) + '<br><small>' + esc(a.avukat) + ' · ' + esc(saat(a.zaman)) + '</small></div>';
      }).join('') + '</div>';
    }
    return h;
  }

  function muvekkilHtml(m) {
    var anahtar = esc(m.kaynak) + ':' + esc(m.id);
    var h = '<div class="gz-dosya"><h4>' + esc(m.hedef_kad) + '</h4>' +
      '<span class="gz-etiket">' + esc(KAYNAK[m.kaynak] || m.kaynak) + ' #' + esc(m.id) + '</span>' +
      '<span class="gz-etiket kirmizi" data-gz-bitis-kisa="' + esc(m.bitis) + '">' + esc(kalan(m.bitis)) + ' kaldı</span>' +
      '<span class="gz-etiket ' + (m.avukat_durum === 'kabul' ? 'yesil' : '') + '">' + esc(AVDURUM[m.avukat_durum] || m.avukat_durum) + '</span>' +
      '<p class="kucuk" style="margin:8px 0 0">Gerekçe: ' + esc(m.gerekce || '—') + '</p>';
    if (m.avukat_durum === 'cagrildi') {
      h += '<button class="btn altin" type="button" data-gz-yanit="' + anahtar + ':1">✅ Savunmayı üstlen</button>' +
        '<button class="btn ikinci" type="button" data-gz-yanit="' + anahtar + ':0">Görevi reddet</button>';
    }
    h += '<button class="btn ikinci" type="button" data-gz-dm="' + esc(m.hedef_kad) + '">💬 Müvekkille özel mesaj</button>';
    if (m.avukat_durum === 'kabul') {
      h += '<form data-gz-aciklama="' + anahtar + '"><label>Müvekkiliniz adına Kürsü açıklaması (' + esc(m.aciklama_sayisi || 0) + '/12)</label>' +
        '<textarea name="metin" minlength="15" maxlength="850" required placeholder="Müvekkilim adına kamuoyuna açıklama…"></textarea>' +
        '<button class="btn altin" type="submit">📢 Açıklamayı yayınla</button><small>Açıklama Kürsü\'de sizin adınızla, müvekkilinizin adı belirtilerek yayınlanır. Dosya başına 10 dakikada bir, en çok 12.</small></form>';
    }
    return h + '</div>';
  }

  function baroHtml(liste) {
    if (!liste.length) return '<p>Şu an devam eden gözaltı yok.</p>';
    return liste.map(function (g) {
      var anahtar = esc(g.kaynak) + ':' + esc(g.id);
      var h = '<div class="gz-dosya"><h4>' + esc(g.hedef_kad) + '</h4>' +
        '<span class="gz-etiket">' + esc(KAYNAK[g.kaynak] || g.kaynak) + ' #' + esc(g.id) + '</span>' +
        '<span class="gz-etiket kirmizi">' + esc(kalan(g.bitis)) + ' kaldı</span>' +
        (g.baro_talep ? '<span class="gz-etiket" style="background:#5a4314;color:#ffe2a6">Müdafi istedi</span>' : '') +
        (g.avukat_kad ? '<span class="gz-etiket ' + (g.avukat_durum === 'kabul' ? 'yesil' : '') + '">' + esc(g.avukat_kad) + ' · ' + esc(AVDURUM[g.avukat_durum] || g.avukat_durum) + '</span>' : '');
      if (g.avukat_durum !== 'kabul') {
        h += '<form data-gz-barogonder="' + anahtar + '"><label>Görevlendirilecek avukatın kullanıcı adı</label>' +
          '<input name="avukat" list="gzBaroAvukatlar" autocomplete="off" required placeholder="Baroya kayıtlı avukat">' +
          '<button class="btn altin" type="submit">⚖️ Müdafi gönder</button></form>';
      }
      return h + '</div>';
    }).join('') + '<datalist id="gzBaroAvukatlar"></datalist>';
  }

  function yetkiliHtml(y) {
    var k = y.kota || {}, kalanHak = Math.max(0, (k.kota || 0) - (k.kullanilan || 0));
    var h = '<div class="kart" style="border:1px solid rgba(232,173,81,.6)"><h3>🔒 Gözaltı kararı</h3>' +
      '<p>Gözaltı <b>' + esc(k.sure_saat) + ' saat</b> sürer. Günlük kota: <b>' + esc(k.kullanilan || 0) + ' / ' + esc(k.kota) + '</b> (kalan ' + kalanHak + '). Aynı oyuncu, son gözaltısı biteli ' + esc(k.ara_saat) + ' saat olmadan yeniden gözaltına alınamaz. Görevdeki Cumhurbaşkanı gözaltına alınamaz.</p>' +
      '<form data-gz-karar><label for="gzHedef">Oyuncunun kullanıcı adı</label><input id="gzHedef" name="kad" minlength="2" maxlength="60" autocomplete="off" required placeholder="Kullanıcı adını aynen yazın">' +
      '<label for="gzGerekce">Gerekçe (zorunlu)</label><textarea id="gzGerekce" name="gerekce" minlength="10" maxlength="800" required placeholder="Somut oyun içi gerekçe"></textarea>' +
      '<button class="btn altin" type="submit"' + (kalanHak ? '' : ' disabled') + '>' + (kalanHak ? '🔒 Gözaltı kararı ver' : 'Bugünkü kota doldu') + '</button></form>' +
      '<p class="kucuk">Gözaltındaki oyuncu yalnız avukatıyla yazışabilir; baro ona müdafi gönderebilir.</p></div>';
    var ls = y.gozaltilar || [];
    h += '<div class="kart"><h3>Devam eden gözaltılar (' + ls.length + ')</h3><p class="kucuk">Süresinden önce tahliye yetkisi yalnız Cumhurbaşkanı ve İçişleri Bakanındadır.</p>';
    if (!ls.length) h += '<p>Devam eden gözaltı yok.</p>';
    ls.forEach(function (g) {
      h += '<div class="gz-dosya"><h4>' + esc(g.hedef_kad) + '</h4><span class="gz-etiket">' + esc(KAYNAK[g.kaynak] || g.kaynak) + ' #' + esc(g.id) + '</span>' +
        '<span class="gz-etiket kirmizi">' + esc(kalan(g.bitis)) + ' kaldı</span>' +
        (g.avukat_kad ? '<span class="gz-etiket">Avukat: ' + esc(g.avukat_kad) + '</span>' : '') +
        '<p class="kucuk" style="margin:8px 0 0">Gerekçe: ' + esc(g.gerekce || '—') + (g.yetkili_kad ? ' · Kararı veren: ' + esc(g.yetkili_kad) : '') + '</p>' +
        '<form data-gz-tahliye="' + esc(g.kaynak) + ':' + esc(g.id) + '"><label>Tahliye gerekçesi</label><textarea name="gerekce" minlength="10" maxlength="500" required style="min-height:70px"></textarea>' +
        '<button class="btn ikinci" type="submit">Serbest bırak</button></form></div>';
    });
    return h + '</div>';
  }

  async function ekran() {
    stil();
    if (typeof yukleniyor === "function") yukleniyor("Gözaltı ve Avukat");
    var v, b = null, y = null;
    try {
      v = await yukle(true);
      var is = [];
      if (v.baro_baskani) is.push(rpc("gozalti_baro_liste2").then(function (r) { b = r; }).catch(function () {}));
      if (v.tahliye_yetkisi) is.push(rpc("gozalti_yetkili_liste").then(function (r) { y = r; }).catch(function () {}));
      await Promise.all(is);
    } catch (err) { hata(err); return; }
    var g = benGozaltinda(), h = '<div class="gzx" id="gzEkran">';
    if (g) h += benimDosyamHtml(g);
    else h += '<div class="kart"><h3>⚖️ Gözaltı ve Avukat</h3><p>Herhangi bir sebeple gözaltına alınan oyuncu avukat çağırabilir ya da barodan müdafi isteyebilir. Gözaltı süresince yalnız avukatıyla özel mesajlaşabilir; onun adına açıklamayı avukatı yapar. Gözaltını süresinden önce yalnız Cumhurbaşkanı veya İçişleri Bakanı sonlandırabilir.</p><p><span class="gz-etiket yesil">Şu an gözaltında değilsiniz</span></p></div>';
    var mv = v.muvekkiller || [];
    if (mv.length || v.avukat_mi) {
      h += '<div class="kart"><h3>👔 Müvekkillerim (' + mv.length + ')</h3>' + (mv.length ? mv.map(muvekkilHtml).join('') : '<p>Gözaltındaki müvekkiliniz yok. Bir oyuncu sizi çağırırsa ya da baro görevlendirirse burada görünür.</p>') + '</div>';
    }
    if (b && b.baro_baskani) h += '<div class="kart"><h3>🏛️ Baro · gözaltı dosyaları</h3><p class="kucuk">Avukatı görevde olmayan dosyalara baroya kayıtlı bir avukat gönderebilirsiniz.</p>' + baroHtml(b.gozaltilar || []) + '</div>';
    if (y && y.yetkili) h += yetkiliHtml(y);
    h += '</div>';
    iskelet("Gözaltı ve Avukat", h, { geri: true });
    if (b && b.baro_baskani) baroAvukatlariDoldur();
  }
  window.gozaltiMerkeziEkrani = ekran;
  // Eski "Oyuncu Tutuklama Yetkisi" düğmeleri de bu ekrana gelir.
  window.yonetimTutuklamaAc = function () { ac(ekran); };

  async function baroAvukatlariDoldur() {
    try {
      var ls = await rpc("gozalti_avukat_ara", { p_ara: "" });
      var d = document.getElementById("gzBaroAvukatlar");
      if (d) d.innerHTML = (ls || []).filter(function (x) { return x.baro; }).map(function (x) { return '<option value="' + esc(x.kad) + '">' + esc(x.il || '') + '</option>'; }).join('');
    } catch (e) {}
  }

  /* ---------------- Eylemler ---------------- */
  function parca(s) { var p = String(s || "").split(":"); return { kaynak: p[0], id: Number(p[1]), ek: p[2] }; }
  async function islem(btn, fn) {
    if (btn) btn.disabled = true;
    try { await fn(); } catch (err) { hata(err); if (btn && btn.isConnected) btn.disabled = false; }
  }
  document.addEventListener("click", function (ev) {
    var t = ev.target.closest && ev.target.closest("[data-gz-dm],[data-gz-avara],[data-gz-cagir],[data-gz-baroiste],[data-gz-yanit],[data-gz-merkez]");
    if (!t) return;
    if (t.hasAttribute("data-gz-merkez")) { ev.preventDefault(); ac(ekran); return; }
    if (t.hasAttribute("data-gz-dm")) { ev.preventDefault(); dmAc(t.getAttribute("data-gz-dm")); return; }
    if (t.hasAttribute("data-gz-avara")) {
      ev.preventDefault();
      islem(t, async function () {
        var q = (document.getElementById("gzAvAra") || {}).value || "";
        var ls = await rpc("gozalti_avukat_ara", { p_ara: q });
        var g = benGozaltinda(), kutu = document.getElementById("gzAvListe");
        if (kutu) kutu.innerHTML = (ls || []).length ? ls.map(function (a) {
          return '<div class="gz-avukat"><span><b>' + esc(a.kad) + '</b><br><small>' + esc(a.il || '') + (a.baro ? ' · Baroya kayıtlı' : '') + '</small></span>' +
            '<button class="btn altin" type="button" data-gz-cagir="' + esc(g ? g.kaynak : '') + ':' + esc(g ? g.id : '') + ':' + esc(a.kad) + '">Çağır</button></div>';
        }).join('') : '<p>Uygun avukat bulunamadı.</p>';
        t.disabled = false;
      });
      return;
    }
    if (t.hasAttribute("data-gz-cagir")) {
      ev.preventDefault();
      var raw = t.getAttribute("data-gz-cagir"), i1 = raw.indexOf(":"), i2 = raw.indexOf(":", i1 + 1);
      var kaynak = raw.slice(0, i1), id = Number(raw.slice(i1 + 1, i2)), kad = raw.slice(i2 + 1);
      islem(t, async function () { await rpc("gozalti_avukat_cagir2", { p_kaynak: kaynak, p_id: id, p_avukat_kad: kad }); bilgi(kad + " avukat olarak çağrıldı. Artık onunla özel mesajlaşabilirsiniz."); await ekran(); });
      return;
    }
    if (t.hasAttribute("data-gz-baroiste")) {
      ev.preventDefault();
      var p = parca(t.getAttribute("data-gz-baroiste"));
      islem(t, async function () { await rpc("gozalti_baro_iste2", { p_kaynak: p.kaynak, p_id: p.id }); bilgi("Barodan müdafi istendi."); await ekran(); });
      return;
    }
    if (t.hasAttribute("data-gz-yanit")) {
      ev.preventDefault();
      var q = parca(t.getAttribute("data-gz-yanit"));
      islem(t, async function () { await rpc("gozalti_avukat_yanit2", { p_kaynak: q.kaynak, p_id: q.id, p_kabul: q.ek === "1" }); bilgi(q.ek === "1" ? "Savunmayı üstlendiniz." : "Görev reddedildi."); await ekran(); });
    }
  }, true);

  document.addEventListener("submit", function (ev) {
    var f = ev.target;
    if (!f || !f.closest || !f.closest("#gzEkran")) return;
    var btn = f.querySelector('button[type="submit"]'), d = new FormData(f);
    if (f.hasAttribute("data-gz-aciklama")) {
      ev.preventDefault(); var a = parca(f.getAttribute("data-gz-aciklama"));
      islem(btn, async function () { await rpc("gozalti_avukat_aciklama", { p_kaynak: a.kaynak, p_id: a.id, p_metin: String(d.get("metin") || "").trim() }); bilgi("Açıklama Kürsü'de yayınlandı."); await ekran(); });
    } else if (f.hasAttribute("data-gz-barogonder")) {
      ev.preventDefault(); var b = parca(f.getAttribute("data-gz-barogonder"));
      islem(btn, async function () { await rpc("gozalti_baro_gonder2", { p_kaynak: b.kaynak, p_id: b.id, p_avukat_kad: String(d.get("avukat") || "").trim() }); bilgi("Müdafi gönderildi."); await ekran(); });
    } else if (f.hasAttribute("data-gz-karar")) {
      ev.preventDefault(); var kad = String(d.get("kad") || "").trim();
      if (!window.confirm(kad + " hakkında gözaltı kararı vermek istiyor musunuz?")) return;
      islem(btn, async function () { var r = await rpc("yonetim_tutuklama_yap", { p_kullanici_adi: kad, p_gerekce: String(d.get("gerekce") || "").trim() }); bilgi("Gözaltı kararı verildi. Bugün kalan hak: " + (r && r.kalan != null ? r.kalan : "—")); await ekran(); });
    } else if (f.hasAttribute("data-gz-tahliye")) {
      ev.preventDefault(); var c = parca(f.getAttribute("data-gz-tahliye"));
      islem(btn, async function () { await rpc("gozalti_tahliye", { p_kaynak: c.kaynak, p_id: c.id, p_gerekce: String(d.get("gerekce") || "").trim() }); bilgi("Oyuncu serbest bırakıldı."); await ekran(); });
    }
  }, true);

  /* ---------------- Her ekranda gözaltı şeridi ---------------- */
  function seritHtml(g) {
    var avk = g.yazabilecegi || [];
    return '<div class="gz-serit" id="gzSerit" role="status"><span class="gz-s-ik">🔒</span><span class="gz-s-m"><b>Gözaltındasınız · <span data-gz-bitis-kisa="' + esc(g.bitis) + '">' + esc(kalan(g.bitis)) + '</span> kaldı</b>' +
      (avk.length ? 'Yalnız avukatınız ' + avk.map(esc).join(", ") + ' ile özel mesajlaşabilirsiniz.' : 'Hiçbir yere yazamazsınız. Avukat çağırın ya da barodan müdafi isteyin.') +
      '</span><button type="button" data-gz-merkez>Aç</button></div>';
  }
  // Şerit, başlığın hemen altında ve içerik alanının dışında durur: ekranlar içeriği yeniden çizse de görünür kalır.
  function seritKur() {
    var ic = document.getElementById("icerik"); if (!ic) return;
    var eski = document.getElementById("gzSerit"), g = benGozaltinda();
    if (!g || document.getElementById("gzEkran")) { if (eski) eski.remove(); return; }
    var html = seritHtml(g);
    if (eski && eski.nextElementSibling === ic) { if (eski.outerHTML !== html) eski.outerHTML = html; return; }
    if (eski) eski.remove();
    stil(); ic.insertAdjacentHTML("beforebegin", html);
  }

  /* ---------------- Sohbet yazma çubuğu: gözaltındayken kapalı ---------------- */
  var dmKad = null, gozlemci = null;
  function dmSar() {
    var f = window.ozelEkrani;
    if (typeof f !== "function" || f.__gz) return;
    var y = function (kad) { dmKad = kad; return f.apply(this, arguments); };
    y.__gz = true; window.ozelEkrani = y;
  }
  function kad(x) { return String(x || "").toLocaleLowerCase("tr-TR"); }
  function yazbarIsle() {
    var yb = document.getElementById("yazbar"); if (!yb) return;
    var g = benGozaltinda();
    var dm = !!document.querySelector(".shk-dm");
    var izinli = dm && dmKad && avukatlarim().some(function (a) { return kad(a) === kad(dmKad); });
    if (!g || izinli) {
      if (yb.getAttribute("data-gz") === "1" && yb.__gzEski != null) { yb.innerHTML = yb.__gzEski; yb.removeAttribute("data-gz"); }
      return;
    }
    if (yb.getAttribute("data-gz") === "1") return;
    yb.__gzEski = yb.innerHTML; yb.setAttribute("data-gz", "1");
    var avk = avukatlarim();
    yb.innerHTML = '<div class="gz-yazbar-not"><span>🔒 Gözaltındasınız: buraya yazamazsınız. ' + (avk.length ? 'Yalnız avukatınız ' + avk.map(esc).join(", ") + ' ile özel mesajlaşabilirsiniz.' : 'Önce avukat çağırın.') + '</span>' +
      (avk.length ? '<button type="button" data-gz-dm="' + esc(avk[0]) + '">Avukat</button>' : '<button type="button" data-gz-merkez>Aç</button>') + '</div>';
  }
  function yazbarKur() {
    dmSar();
    if (benGozaltinda()) {
      stil();
      if (!gozlemci && window.MutationObserver) {
        gozlemci = new MutationObserver(function () { if (gozlemci._b) return; gozlemci._b = true; requestAnimationFrame(function () { gozlemci._b = false; yazbarIsle(); seritKur(); }); });
        gozlemci.observe(document.getElementById("app") || document.body, { childList: true, subtree: true });
      }
      yazbarIsle();
    } else {
      if (gozlemci) { gozlemci.disconnect(); gozlemci = null; }
      yazbarIsle();
    }
  }

  /* ---------------- Geri sayım ---------------- */
  setInterval(function () {
    document.querySelectorAll("[data-gz-bitis]").forEach(function (el) { el.textContent = kalan(el.getAttribute("data-gz-bitis")); });
    document.querySelectorAll("[data-gz-bitis-kisa]").forEach(function (el) { el.textContent = kalan(el.getAttribute("data-gz-bitis-kisa")) + (el.closest(".gz-serit") ? "" : " kaldı"); });
    var g = ST.veri && ST.veri.gozalti;
    if (g && new Date(g.bitis).getTime() <= Date.now() && ST.veri.gozalti.aktif) { ST.veri.gozalti.aktif = false; seritKur(); yazbarKur(); }
  }, 15000);

  /* ---------------- iskelet sarmalayıcı: şerit + yetkili kısayolları ---------------- */
  function kisayolKur(baslik) {
    if (typeof baslik !== "string") return;
    var ic = document.getElementById("icerik"); if (!ic) return;
    if (/^(Adliye|Baro)/.test(baslik) && !document.getElementById("gzAdliyeKisayol")) {
      ic.insertAdjacentHTML("afterbegin", '<div class="kart" id="gzAdliyeKisayol"><button class="btn ikinci" type="button" data-gz-merkez style="width:100%;min-height:48px">⚖️ Gözaltı ve Avukat · müdafi, müvekkiller, baro</button></div>');
    }
    if (/^(Devlet|Yönetim|Cumhurbaşkanlığı|Cumhurbaşkanı|Bakanlık Masası|İçişleri)/i.test(baslik) && !document.getElementById("ytDevletKisayol")) {
      yetkiBak().then(function (k) {
        if (!k || !k.yetkili || !ic.isConnected || document.getElementById("ytDevletKisayol")) return;
        ic.insertAdjacentHTML("afterbegin", '<div class="kart" id="ytDevletKisayol" style="border:2px solid #e8ad51;background:linear-gradient(110deg,#3c2929,#192744)"><h3>🔒 Gözaltı kararı ve tahliye</h3><p>Günlük kota: ' + esc(k.kullanilan) + ' / ' + esc(k.kota) + ' · süre ' + esc(k.sure_saat) + ' saat. Süresinden önce tahliye yalnız Cumhurbaşkanı ve İçişleri Bakanındadır.</p><button type="button" class="btn altin" data-gz-merkez style="width:100%;min-height:50px;font-weight:850">🔒 Gözaltı paneli</button></div>');
      });
    }
  }
  function yetkiBak() {
    if (ST.yetki && Date.now() - ST.yetkiZaman < 120000) return Promise.resolve(ST.yetki);
    return rpc("yonetim_gozalti_kota").then(function (k) { ST.yetki = k; ST.yetkiZaman = Date.now(); return k; }).catch(function () { return null; });
  }
  function iskeletSar() {
    var once = window.iskelet;
    if (typeof once !== "function" || once.__gz) return;
    var yeni = function (baslik) {
      var r = once.apply(this, arguments);
      try { seritKur(); kisayolKur(baslik); yazbarIsle(); } catch (e) {}
      return r;
    };
    yeni.__gz = true;
    for (var k in once) if (Object.prototype.hasOwnProperty.call(once, k)) yeni[k] = once[k];
    window.iskelet = yeni;
    try { iskelet = yeni; } catch (e) {}
  }

  /* ---------------- Yoklama ---------------- */
  function yokla() {
    iskeletSar(); dmSar();
    if (document.hidden || typeof D === "undefined" || !(D.durum && D.durum.profil)) return;
    yukle(true).catch(function () {});
  }
  setTimeout(yokla, 2500);
  setInterval(yokla, 90000);
  document.addEventListener("visibilitychange", function () { if (!document.hidden) setTimeout(yokla, 600); });
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", function () { iskeletSar(); dmSar(); }, { once: true });
  else { iskeletSar(); dmSar(); }
})();
