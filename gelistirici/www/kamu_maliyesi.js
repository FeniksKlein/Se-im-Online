/* =====================================================================
   Kamu Maliyesi 2.0 (31.10.2026, sunucu modülü 158)
   - "Bütçe ve Ekonomi" ekranı: Hazine, Türkiye Varlık Fonu, gerçekleşen
     gelir/gider kalemleri, bakanlıkların harcamaları, bütçe dengesi →
     enflasyon bileşenleri, borç ve faiz, son Hazine hareketleri.
   - Yürütme için Varlık Fonu aktarımı.
   - Devlet › Hükümet kartı, menü araması, bildirim bağlantısı.
   bakanlik_masasi.js'in .bkm stillerini kullanır (ondan sonra yüklenir).
   ===================================================================== */
(function () {
  "use strict";
  if (window.SO_KAMU_MALIYESI_V1) return;
  window.SO_KAMU_MALIYESI_V1 = true;

  var esc = function (x) {
    return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  };
  var sayi = function (n, d) {
    return Number(n || 0).toLocaleString("tr-TR", { minimumFractionDigits: d || 0, maximumFractionDigits: d || 0 });
  };
  var isaretli = function (n, d) { var v = Number(n || 0); return (v > 0 ? "+" : v < 0 ? "−" : "") + sayi(Math.abs(v), d == null ? 1 : d); };
  var mr = function (n, d) { return sayi(n, d == null ? 1 : d) + " milyar ₺"; };
  var zaman = function (ts) {
    if (!ts) return "—";
    try { return typeof tarihSaat === "function" ? tarihSaat(ts) : new Date(ts).toLocaleString("tr-TR"); } catch (_) { return String(ts); }
  };
  var hata = function (err) {
    var m = err && err.message ? err.message : String(err || "Beklenmeyen hata");
    return typeof hataCevir === "function" ? hataCevir(m) : m;
  };
  var bildir = function (m, h) { if (typeof toast === "function") toast(m, h); };
  var rpc = function (ad, arg) { return API.rpc(ad, arg || {}); };

  var BAKANLIK_TUR = {
    icraat: "İcraatlar", etkinlik: "Etkinlikler", ziyaret: "Saha ziyaretleri", ihale: "Kamu ihaleleri", tesvik: "Teşvikler",
    denetim: "Denetim ve soruşturma", dava: "Dava ve icra", gider: "Diğer harcamalar", gelir: "Diğer gelirler"
  };
  var BILESEN = [
    ["taban", "Yapısal enflasyon (taban)"], ["buyume", "Büyümenin talep baskısı"], ["ucret", "Asgari ücret baskısı"],
    ["kidem", "Kıdem primi"], ["destek", "Sosyal destek"], ["mevzuat", "Kanunlar"],
    ["butce", "Bütçe açığı / fazlası"], ["parasal", "Merkez Bankası finansmanı"]
  ];
  var IK = {
    hazine: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10 12 4l9 6"/><path d="M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 21h18"/></svg>',
    fon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="6" rx="7" ry="3"/><path d="M5 6v6c0 1.7 3.1 3 7 3s7-1.3 7-3V6"/><path d="M5 12v6c0 1.7 3.1 3 7 3s7-1.3 7-3v-6"/></svg>'
  };

  (function stil() {
    if (document.getElementById("km-stil")) return;
    var css = [
      ".km .km-seg{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;background:var(--panel);border-radius:12px;padding:4px;margin:0 0 12px}",
      ".km .km-seg button{padding:9px 4px;border-radius:9px;font-size:13.5px;font-weight:700;color:var(--txt2)}",
      ".km .km-seg button.on{background:var(--txt);color:var(--bg)}",
      ".km .km-kalem{padding:10px 0;border-top:1px solid var(--line)}",
      ".km .bkm-kutu>h3+.km-kalem{border-top:0}",
      ".km .km-kb{display:flex;justify-content:space-between;gap:10px;font-size:14px}",
      ".km .km-kb span{min-width:0}",
      ".km .km-kb b{font-variant-numeric:tabular-nums;white-space:nowrap}",
      ".km .km-kalem small{display:block;color:var(--mut);font-size:12px;margin-top:2px;line-height:1.4}",
      ".km .km-bar{height:6px;border-radius:6px;background:var(--panel2);overflow:hidden;margin-top:6px}",
      ".km .km-bar i{display:block;height:100%;border-radius:6px;background:var(--good)}",
      ".km .km-bar.gider i{background:var(--al)}.km .km-bar.fin i{background:var(--ink2,#8b7bd8)}.km .km-bar.notr i{background:var(--mut)}",
      ".bkm .km-gunbas{font-size:11px;opacity:.78;margin-top:12px;letter-spacing:.02em}",
      ".km .km-top{display:flex;justify-content:space-between;gap:10px;padding:11px 0;border-top:1px solid var(--line);font-weight:800;font-size:14.5px}",
      ".km .km-top b{font-variant-numeric:tabular-nums}",
      ".km .km-arti{color:var(--good)}.km .km-eksi{color:var(--al2,#e0565b)}",
      ".km .km-buyuk{display:flex;align-items:baseline;gap:8px;padding:12px 0 4px;flex-wrap:wrap}",
      ".km .km-buyuk b{font-family:var(--disp);font-size:30px;line-height:1;font-variant-numeric:tabular-nums}",
      ".km .km-buyuk span{color:var(--mut);font-size:13px}",
      ".km .km-not{font-size:13.5px;color:var(--txt2);line-height:1.55;padding:4px 0 12px;margin:0}",
      ".km .km-bil{display:grid;grid-template-columns:1fr auto;gap:2px 10px;align-items:center;padding:8px 0;border-top:1px solid var(--line);font-size:13.5px}",
      ".km .km-bil b{font-variant-numeric:tabular-nums;text-align:right}",
      ".km .km-bil .km-bar{grid-column:1/3;margin-top:4px}",
      ".km .km-grafik{width:100%;height:auto;display:block;margin:8px 0 4px}",
      ".km .km-lejant{display:flex;gap:14px;flex-wrap:wrap;font-size:12px;color:var(--mut);padding-bottom:12px}",
      ".km .km-lejant i{display:inline-block;width:10px;height:10px;border-radius:3px;margin-right:5px;vertical-align:-1px}",
      ".km .km-har{display:flex;gap:10px;align-items:flex-start;padding:10px 0;border-top:1px solid var(--line)}",
      ".km .bkm-kutu>h3+.km-har{border-top:0}",
      ".km .km-har .km-ho{flex:1;min-width:0}.km .km-har .km-ho b{display:block;font-size:13.5px;font-weight:600}",
      ".km .km-har .km-ho small{display:block;color:var(--mut);font-size:12px;margin-top:2px}",
      ".km .km-har .km-hs{text-align:right;font-variant-numeric:tabular-nums;font-weight:800;white-space:nowrap;font-size:14px}",
      ".km .km-har .km-hs small{display:block;font-weight:500;color:var(--mut);font-size:11.5px}",
      ".km .km-dugmeler{display:grid;grid-template-columns:1fr 1fr;gap:8px;padding:4px 0 14px}",
      ".km-kart{display:flex;align-items:center;gap:12px;border-radius:16px;padding:13px 14px;margin:0 0 12px;background:var(--panel);box-shadow:inset 0 0 0 1px var(--line2);cursor:pointer;width:100%;text-align:left;color:var(--txt)}",
      ".km-kart .km-ki{flex:none;width:42px;height:42px;border-radius:12px;display:grid;place-items:center;color:#fff;background:linear-gradient(145deg,#b9862a,#3a2808)}",
      ".km-kart .km-ki svg{width:21px;height:21px}",
      ".km-kart .km-ko{flex:1;min-width:0}.km-kart .km-ko b{display:block;font-size:15px}",
      ".km-kart .km-ko small{display:block;color:var(--mut);font-size:12.5px;margin-top:2px;line-height:1.4}",
      ".km-kart .km-ok{color:var(--mut);font-size:20px}",
      ".bkm .km-serit{display:block;background:var(--panel);border-radius:14px;padding:12px 14px;margin-bottom:12px;font-size:13.5px;line-height:1.5;color:var(--txt2)}",
      ".bkm .km-serit b{color:var(--txt)}",
      ".bkm .km-serit button{display:block;margin-top:10px;width:100%;padding:11px;border-radius:12px;background:var(--panel2);font-weight:800;color:var(--txt)}"
    ].join("\n");
    var st = document.createElement("style"); st.id = "km-stil"; st.textContent = css;
    (document.head || document.documentElement).appendChild(st);
  })();

  var kutu = function (baslik, ic, sag) { return '<section class="bkm-kutu">' + (baslik ? '<h3><span>' + baslik + '</span>' + (sag || "") + '</h3>' : "") + ic + '</section>'; };

  /* ---------------- Ekran ---------------- */
  var KM = { gun: 7, v: null };

  async function ekran(gun) {
    if (gun) KM.gun = gun;
    try { yukleniyor("Bütçe ve Ekonomi"); } catch (_) {}
    try { KM.v = await rpc("butce_raporu", { p_gun: KM.gun }); ciz(); }
    catch (err) { iskelet("Bütçe ve Ekonomi", '<div class="kart"><p class="alt">' + esc(hata(err)) + '</p></div>', { geri: true }); }
  }
  window.butceEkonomiEkrani = function () { return ekran(); };
  window.kmDonem = function (g) { ekran(g); };

  function kalemListe(ls, tur) {
    if (!ls || !ls.length) return '<div class="bkm-bos">Bu dönemde kayıt yok.</div>';
    var mx = Math.max.apply(null, ls.map(function (x) { return Math.abs(Number(x.tutar)); })) || 1;
    return ls.map(function (x) {
      var v = Number(x.tutar);
      return '<div class="km-kalem"><div class="km-kb"><span>' + esc(x.ad || BAKANLIK_TUR[x.tur] || x.tur) + '</span><b class="' + (v >= 0 ? "km-arti" : "km-eksi") + '">' + isaretli(v, Math.abs(v) < 10 ? 2 : 1) + '</b></div>' +
        (x.aciklama ? '<small>' + esc(x.aciklama) + '</small>' : "") +
        '<div class="km-bar ' + (tur || "") + '"><i style="width:' + Math.max(2, Math.round(Math.abs(v) / mx * 100)) + '%"></i></div></div>';
    }).join("");
  }
  var toplam = function (ls) { return (ls || []).reduce(function (s, x) { return s + Number(x.tutar || 0); }, 0); };

  function grafik(g) {
    if (!g || g.length < 2) return '<p class="km-not">Grafik için en az iki tam günlük veri gerekir. İlk tam gün, reformun ertesi gecesi kapanır.</p>';
    var W = 340, H = 130, P = 6, n = g.length, bw = (W - P * 2) / n;
    var mx = Math.max.apply(null, g.map(function (x) { return Math.abs(Number(x.denge)); })) || 1;
    var enf = g.map(function (x) { return x.enflasyon == null ? null : Number(x.enflasyon); });
    var ev = enf.filter(function (x) { return x != null; });
    var emin = ev.length ? Math.min.apply(null, ev) - 1 : 0, emax = ev.length ? Math.max.apply(null, ev) + 1 : 1;
    var orta = H / 2, s = '<svg class="km-grafik" viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="Günlük bütçe dengesi ve enflasyon">';
    s += '<line x1="0" x2="' + W + '" y1="' + orta + '" y2="' + orta + '" stroke="var(--line2)" stroke-width="1"/>';
    g.forEach(function (x, i) {
      var v = Number(x.denge), h = Math.abs(v) / mx * (orta - P), y = v >= 0 ? orta - h : orta;
      s += '<rect x="' + (P + i * bw + bw * 0.15).toFixed(1) + '" y="' + y.toFixed(1) + '" width="' + (bw * 0.7).toFixed(1) + '" height="' + Math.max(1, h).toFixed(1) + '" rx="2" fill="' + (v >= 0 ? "var(--good)" : "var(--al)") + '"><title>' + esc(x.gun) + ': ' + isaretli(v, 1) + ' milyar ₺</title></rect>';
    });
    var nok = [];
    enf.forEach(function (e, i) { if (e != null) nok.push((P + i * bw + bw / 2).toFixed(1) + "," + (H - P - (e - emin) / (emax - emin) * (H - P * 2)).toFixed(1)); });
    if (nok.length > 1) s += '<polyline points="' + nok.join(" ") + '" fill="none" stroke="var(--warn,#f2b33d)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>';
    return s + '</svg><div class="km-lejant"><span><i style="background:var(--good)"></i>Bütçe fazlası</span><span><i style="background:var(--al)"></i>Bütçe açığı</span><span><i style="background:var(--warn,#f2b33d)"></i>Enflasyon (%' + sayi(emin + 1, 1) + '–' + sayi(emax - 1, 1) + ')</span></div>';
  }

  function ciz() {
    var v = KM.v || {}, o = v.ozet || {}, b = o.bugun || {}, s7 = o.son7 || {}, vf = v.varlik_fonu || {}, br = v.borc || {}, fz = v.faiz || {};
    var yur = v.sistem === "parlamenter" ? "Başbakan" : "Cumhurbaşkanı";
    var hz = Number(o.hazine), gg = Math.max(1, Number(o.gun_gider || 1));
    var h = '<div class="bkm km" style="--a:#b9862a;--b:#2a1d06">';
    h += '<section class="bkm-kimlik"><div class="bkm-ust"><span class="bkm-amb">' + IK.hazine + '</span><div><h2>Bütçe ve Ekonomi</h2><div class="bkm-alt">T.C. Hazinesi · gerçekleşen bütçe</div></div></div>' +
      '<div class="bkm-kasa"><div><small>Hazine nakdi</small><b>' + sayi(hz, 1) + ' <span>milyar ₺</span></b></div>' +
      '<div style="text-align:right"><small>Varlık Fonu</small><b style="font-size:17px">' + sayi(o.varlik_fonu, 0) + '</b></div></div>' +
      '<div class="km-gunbas">Bugün (milyar ₺)</div><div class="bkm-uc" style="margin-top:6px"><div><small>Gelir</small><b>' + isaretli(b.gelir, 2) + '</b></div><div><small>Harcama</small><b>' + sayi(b.harcama, 2) + '</b></div>' +
      '<div><small>Denge</small><b>' + isaretli(b.denge, 2) + '</b></div></div></section>';

    if (hz < 0) h += '<div class="bkm-uyari"><b>Hazine eksi.</b> Açık Merkez Bankası kaynağıyla kapanıyor: enflasyon her gün ek olarak yükselir, bakanlık ödenekleri yarıya iner, tahvil faizine risk primi eklenir. Takdire bağlı harcama (kararname, resmî program) yapılamaz.</div>';
    else if (hz < 15 * gg) h += '<div class="bkm-uyari">Hazine nakdi azaldı: kasada yaklaşık ' + Math.round(hz / gg) + ' günlük cari gider kadar para var.</div>';

    // Bütçe dengesi → enflasyon
    var ao = o.acik_orani == null ? null : Number(o.acik_orani), bil = o.enf_bilesen || {}, bs = Number(bil.butce || 0);
    var dengeMetin;
    if (!s7.gun) {
      dengeMetin = 'Reformdan sonraki ilk tam gün henüz kapanmadı. Her gece dünün gelir ve harcamaları hesaplanır; 7 günlük ortalama bütçe dengesi enflasyonu, büyümeyi ve tahvil faizini etkiler.';
    } else {
      var ort = Number(s7.ortalama || 0);
      dengeMetin = 'Son ' + s7.gun + ' tam günde devlet ' + (ort < 0 ? 'gelirinden günde ortalama <b>' + mr(-ort, 1) + ' fazla harcadı</b>' : 'günde ortalama <b>' + mr(ort, 1) + ' fazla verdi</b>') +
        (ao != null ? ' (GSYH\'nin %' + sayi(Math.abs(ao), 1) + '\'i).' : '.') +
        ' Bu, enflasyon hedefini <b>' + (bs >= 0 ? '+' : '−') + sayi(Math.abs(bs), 1) + ' puan</b> ' + (bs >= 0 ? 'yukarı' : 'aşağı') + ' itiyor.';
    }
    var hedef = o.enf_hedef == null ? null : Number(o.enf_hedef), enf = Number(o.enflasyon);
    h += kutu("Bütçe dengesi ve enflasyon",
      '<div class="km-buyuk"><b>%' + sayi(enf, 1) + '</b><span>yıllık enflasyon' + (hedef != null ? ' · hedefe gidiyor: %' + sayi(hedef, 1) + (hedef > enf + 0.05 ? ' ▲' : hedef < enf - 0.05 ? ' ▼' : '') : '') + '</span></div>' +
      '<p class="km-not">' + dengeMetin + '</p>');

    if (o.enf_bilesen) {
      var mxb = Math.max.apply(null, BILESEN.map(function (k) { return Math.abs(Number(bil[k[0]] || 0)); })) || 1;
      h += kutu("Enflasyonu ne belirliyor?", BILESEN.map(function (k) {
        var x = Number(bil[k[0]] || 0);
        if (k[0] !== "taban" && Math.abs(x) < 0.005) return "";
        return '<div class="km-bil"><span>' + k[1] + '</span><b class="' + (k[0] === "taban" ? "" : x > 0 ? "km-eksi" : "km-arti") + '">' + (k[0] === "taban" ? sayi(x, 1) : isaretli(x, 2)) + '</b>' +
          '<div class="km-bar ' + (k[0] === "taban" ? "notr" : x > 0 ? "gider" : "") + '"><i style="width:' + Math.max(2, Math.round(Math.abs(x) / mxb * 100)) + '%"></i></div></div>';
      }).join("") + '<p class="km-not">Toplam hedef %' + sayi(hedef, 1) + '. Enflasyon her gün bu hedefe doğru yaklaşık %3 yaklaşır. Merkez Bankası politika faizi ve bakanlık icraatları (ihracat seferberliği, fiyat denetimi gibi) enflasyonu ayrıca doğrudan etkiler.</p>');
    }

    // Dönem seçimi + kalemler
    h += '<div class="km-seg">' + [[1, "Bugün"], [7, "7 gün"], [30, "30 gün"]].map(function (x) {
      return '<button type="button" class="' + (Number(v.gun) === x[0] ? "on" : "") + '" onclick="kmDonem(' + x[0] + ')">' + x[1] + '</button>';
    }).join("") + '</div>';
    var tg = toplam(v.gelirler), td = toplam(v.giderler), tb = toplam(v.bakanlik_harcama), tf = toplam(v.finansman);
    var donem = Number(v.gun) === 1 ? "bugün" : "son " + v.gun + " gün";
    h += kutu("Gelirler · " + donem, kalemListe(v.gelirler, "") + '<div class="km-top"><span>Toplam gelir</span><b class="km-arti">' + isaretli(tg, 2) + '</b></div>');
    h += kutu("Hazine giderleri · " + donem, kalemListe(v.giderler, "gider") + '<div class="km-top"><span>Toplam</span><b class="km-eksi">' + isaretli(td, 2) + '</b></div>' +
      '<p class="km-not">Bakanlık ödenekleri Hazine\'den bakanlık kasalarına aktarılan paradır; asıl harcama bakanlık kasasından yapılır (aşağıda). Kasalarda şu an toplam ' + mr(v.bakanlik_kasa, 1) + ' duruyor.</p>');
    h += kutu("Bakanlıkların harcamaları · " + donem, kalemListe(v.bakanlik_harcama, "gider") + '<div class="km-top"><span>Toplam</span><b class="km-eksi">' + isaretli(tb, 2) + '</b></div>');
    var genel = tg + td + tb + Number(v.bakanlik_transfer || 0);
    h += kutu("Genel devlet dengesi · " + donem,
      '<div class="km-buyuk"><b class="' + (genel >= 0 ? "km-arti" : "km-eksi") + '">' + isaretli(genel, 1) + '</b><span>milyar ₺</span></div>' +
      '<p class="km-not">Gelirler eksi bütün harcamalar (Hazine giderleri + bakanlıkların kendi kasalarından yaptığı harcamalar; Hazine ile bakanlık arasındaki aktarımlar birbirini götürür). Borçlanma, özelleştirme ve Varlık Fonu aktarımları finansmandır, gelir sayılmaz.</p>');
    if (v.finansman && v.finansman.length) h += kutu("Finansman · " + donem, kalemListe(v.finansman, "fin") + '<div class="km-top"><span>Net</span><b>' + isaretli(tf, 2) + '</b></div>');

    // Varlık Fonu
    var vfIc = '<div class="bkm-tablo" style="margin-top:10px"><div><small>Fon varlığı</small><b>' + sayi(vf.bakiye, 0) + '</b></div><div><small>Hazine\'ye temettü</small><b>+' + sayi(vf.gunluk_temettu, 2) + '/gün</b></div>' +
      '<div><small>' + Number(vf.aktarim_gun || 30) + ' günlük çekim hakkı</small><b>' + sayi(vf.kalan_hak, 1) + ' / ' + sayi(vf.aktarim_tavan, 0) + '</b></div><div><small>Son aktarım</small><b style="font-size:13px">' + (vf.son_islem ? zaman(vf.son_islem) : "—") + '</b></div></div>' +
      '<p class="km-not">Eski hesap hatasından Hazine\'de biriken fazla nakit silinmedi, bu fonda duruyor. Fon her gün Hazine\'ye temettü öder. ' + yur + ' fondan ' + Number(vf.aktarim_gun || 30) + ' günde en çok ' + sayi(vf.aktarim_tavan, 0) + ' milyar ₺ çekebilir ya da bütçe fazlasını fona yatırabilir (24 saatte bir, Resmî Gazete\'de yayımlanır).</p>';
    if (v.yetkili) vfIc += '<div class="km-dugmeler"><button class="bkm-mini" onclick="kmFonModal(\'cek\')">Fondan Hazine\'ye</button><button class="bkm-mini ikinci" onclick="kmFonModal(\'yatir\')">Hazine\'den fona</button></div>';
    var vfh = vf.hareketler || [];
    if (vfh.length) vfIc += vfh.slice(0, 5).map(function (x) {
      var ad = { devir: "Reform devri", cek: "Hazine'ye aktarım", yatir: "Fona yatırım" }[x.tur] || x.tur;
      return '<div class="km-har"><div class="km-ho"><b>' + ad + '</b><small>' + zaman(x.zaman) + ' · ' + esc(x.aciklama || "") + '</small></div><div class="km-hs">' + sayi(x.tutar, 1) + '</div></div>';
    }).join("");
    h += kutu("Türkiye Varlık Fonu", vfIc);

    // Borç ve faiz
    h += kutu("Borç ve faiz",
      '<div class="bkm-tablo" style="margin-top:10px"><div><small>İç borç stoku</small><b>' + mr(br.stok, 1) + '</b></div><div><small>Günlük borç servisi</small><b>' + sayi(br.gunluk, 2) + '</b></div>' +
      '<div><small>Tahvil faizi</small><b>%' + sayi(fz.tahvil, 1) + '</b></div><div><small>Politika faizi</small><b>%' + sayi(fz.politika, 1) + '</b></div></div>' +
      '<p class="km-not">Tahvil faizi enflasyona bağlıdır; bütçe açığı GSYH\'nin %3\'ünü aşınca ve Hazine eksideyken risk primi eklenir (şu an +' + sayi(fz.risk_primi, 1) + ' puan). Borç servisinin faiz kısmı bütçe gideridir, anapara kısmı finansmandır.</p>');

    // Geçmiş
    h += kutu("Son günler", grafik(v.gecmis));

    // Hareketler
    var hr = v.hareketler || [];
    h += kutu("Son Hazine hareketleri", hr.length ? hr.slice(0, 25).map(function (x) {
      var f = Number(x.fark), sinif = { gelir: "gelir", gider: "gider", finansman: "finansman" }[x.sinif] || "";
      return '<div class="km-har"><div class="km-ho"><b>' + esc(x.aciklama) + '</b><small>' + zaman(x.zaman) + (sinif ? ' · ' + sinif : '') + '</small></div>' +
        '<div class="km-hs ' + (f >= 0 ? "km-arti" : "km-eksi") + '">' + isaretli(f, Math.abs(f) < 1 ? 3 : 1) + '<small>' + sayi(x.sonraki, 1) + '</small></div></div>';
    }).join("") : '<div class="bkm-bos">Henüz hareket yok.</div>');

    h += '<details class="bkm-acil"><summary>Devlet ekonomisi nasıl işler?</summary><p>' +
      '<b>Gelirler Hazine\'ye akar:</b> ülke genelindeki gelir vergisi ve KDV/ÖTV her gece; oyuncuların maaşından kesilen gelir vergisi ertesi gece; şirket ve işletme vergileri, harçlar, cezalar ve kira vergileri anında. ' +
      '<b>Giderler Hazine\'den düşer:</b> bakanlık ödenekleri, belediye payı, sosyal destek, partilere Hazine yardımı, faiz; ' + yur + '\'nun ek ödenek, kararname, resmî program ve kriz kararları. ' +
      'Bakanlıklar kendi kasalarından harcar; kasa yetmezse ek ödenek ister. ' +
      '<b>Sonuç:</b> 7 günlük ortalama genel devlet dengesi enflasyon hedefini iter: açık GSYH\'nin her %1\'i için yaklaşık +' + sayi(o.k_acik, 1) + ' puan (en çok +' + sayi(o.enf_tavan, 0) + '), fazla için −' + sayi(o.k_fazla, 1) + ' puan (en çok −' + sayi(o.enf_taban, 0) + '). Ilımlı açık kısa vadede büyümeyi artırır, büyük açık faizi yükseltip büyümeyi düşürür. ' +
      'Hazine eksiye düşerse açık Merkez Bankası kaynağıyla kapanır: enflasyon her gün ek olarak yükselir, bakanlık ödenekleri yarıya iner. Takdire bağlı harcamalar Hazine\'yi eksiye düşüremez. ' +
      'Günlük GSYH şu an yaklaşık ' + mr(o.gsyh_gunluk, 0) + '; fiyatlar ve büyümeyle artar.</p></details>';
    if (typeof devletButcesiEkrani === "function") h += '<button class="btn ikinci" onclick="ekranAc(devletButcesiEkrani)">Devlet bütçesi: bakanlık kasaları ve ödenek talepleri</button>';
    h += '</div>';
    iskelet("Bütçe ve Ekonomi", h, { geri: true });
  }

  window.kmFonModal = function (yon) {
    var v = KM.v || {}, vf = v.varlik_fonu || {}, o = v.ozet || {};
    var cek = yon === "cek";
    var ust = cek ? Number(vf.kalan_hak || 0) : Math.max(0, Number(o.hazine || 0));
    var m = modal('<div class="bkm-modal"><h3 style="font-size:19px;font-weight:800">' + (cek ? "Varlık Fonu'ndan Hazine'ye aktarım" : "Hazine'den Varlık Fonu'na aktarım") + '</h3>' +
      '<div class="bkm-ozet">' + (cek ? 'Bu dönem kalan çekim hakkı: <b>' + mr(vf.kalan_hak, 1) + '</b>. Aktarım finansmandır: Hazine nakdini artırır ama bütçe açığını kapatmaz; açık sürerse enflasyon baskısı devam eder.'
        : 'Hazine nakdi: <b>' + mr(o.hazine, 1) + '</b>. Bütçe fazlasını fona yatırmak nakdi korur; fon Hazine\'ye temettü öder.') + '</div>' +
      '<div class="alan"><label>Tutar (milyar ₺)</label><input id="kmFT" type="number" min="1" step="1" value="' + Math.max(1, Math.min(10, Math.floor(ust))) + '" inputmode="decimal"></div>' +
      '<div class="alan"><label>Gerekçe (Resmî Gazete\'de yayımlanır, isteğe bağlı)</label><input id="kmFG" maxlength="500"></div>' +
      '<button class="btn altin" id="kmFOk">Kararı imzala</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button></div>');
    m.querySelector("#kmFOk").onclick = async function () {
      var t = Number(m.querySelector("#kmFT").value);
      if (!(t >= 1)) { bildir("Tutar en az 1 milyar ₺ olmalı.", true); return; }
      this.disabled = true;
      try {
        KM.v = await rpc("varlik_fonu_aktar", { p_yon: yon, p_tutar: t, p_gerekce: m.querySelector("#kmFG").value || null });
        if (typeof modalKapat === "function") modalKapat();
        bildir(cek ? "Varlık Fonu'ndan Hazine'ye aktarıldı." : "Hazine'den Varlık Fonu'na aktarıldı.");
        KM.gun = Number(KM.v && KM.v.gun) || 7; ciz();
      } catch (err) { bildir(hata(err), true); this.disabled = false; }
    };
  };

  /* ---------------- Devlet › Hükümet kartı ---------------- */
  var sonKart = 0;
  function hukumetKart() {
    var ic = document.getElementById("icerik"); if (!ic || document.getElementById("kmHukumetKart")) return;
    var seg = ic.querySelector(".segment .aktif"); if (!seg || !/Hükümet/.test(seg.textContent)) return;
    if (Date.now() - sonKart < 1200) return; sonKart = Date.now();
    rpc("butce_raporu", { p_gun: 1 }).then(function (v) {
      var ic2 = document.getElementById("icerik"); if (!ic2 || document.getElementById("kmHukumetKart")) return;
      var o = (v && v.ozet) || {}, b = o.bugun || {}, bil = o.enf_bilesen || {};
      var el = document.createElement("button"); el.type = "button"; el.id = "kmHukumetKart"; el.className = "km-kart";
      el.onclick = function () { ekranAc(window.butceEkonomiEkrani); };
      var etk = o.enf_bilesen ? ' · bütçenin enflasyona etkisi ' + isaretli(bil.butce, 1) + ' puan' : '';
      el.innerHTML = '<span class="km-ki">' + IK.hazine + '</span><span class="km-ko"><b>Bütçe ve ekonomi</b><small>Hazine ' + mr(o.hazine, 1) + ' · bugün ' + (Number(b.denge) >= 0 ? 'fazla ' : 'açık ') + sayi(Math.abs(Number(b.denge || 0)), 1) + etk + '</small></span><span class="km-ok">›</span>';
      var bm = document.getElementById("bmHukumetKart");
      if (bm && bm.parentNode) bm.parentNode.insertBefore(el, bm);
      else { var s2 = ic2.querySelector(".segment"); var ilk = s2 ? s2.nextElementSibling : ic2.firstElementChild; if (ilk && ilk.nextSibling) ic2.insertBefore(el, ilk.nextSibling); else ic2.appendChild(el); }
    }).catch(function () {});
  }

  /* ---------------- Devlet bütçesi ekranına özet şerit ---------------- */
  function butceSerit() {
    var ic = document.getElementById("icerik"); if (!ic || ic.querySelector(".km-serit")) return;
    var kim = ic.querySelector(".bkm .bkm-kimlik"); if (!kim) return;
    rpc("butce_raporu", { p_gun: 7 }).then(function (v) {
      var ic2 = document.getElementById("icerik"); if (!ic2 || ic2.querySelector(".km-serit")) return;
      var kim2 = ic2.querySelector(".bkm .bkm-kimlik"); if (!kim2) return;
      var o = (v && v.ozet) || {}, s7 = o.son7 || {}, bil = o.enf_bilesen || {};
      var el = document.createElement("div"); el.className = "km-serit";
      el.innerHTML = (s7.gun ? 'Son ' + s7.gun + ' günde genel devlet dengesi <b>' + isaretli(s7.denge, 1) + ' milyar ₺</b>' +
          (o.enf_bilesen ? '; bütçenin enflasyon hedefine etkisi <b>' + isaretli(bil.butce, 1) + ' puan</b>.' : '.')
        : 'Bütçe dengesi her gece hesaplanır; açık enflasyonu yükseltir, fazla düşürür.') +
        ' Varlık Fonu: <b>' + sayi(o.varlik_fonu, 0) + ' milyar ₺</b>.<button type="button">Gelir-gider kalemleri ve enflasyon</button>';
      el.querySelector("button").onclick = function () { ekranAc(window.butceEkonomiEkrani); };
      kim2.parentNode.insertBefore(el, kim2.nextSibling);
    }).catch(function () {});
  }

  /* ---------------- Bildirim bağlantısı ---------------- */
  function bildirimBagla() {
    var ic = document.getElementById("icerik"); if (!ic) return;
    ic.querySelectorAll(".kisisel").forEach(function (k) {
      if (k.querySelector(".km-bag") || !/^\s*Hazine:|Kamu Maliyesi Reformu|Varlık Fonu/.test(k.textContent || "")) return;
      var btn = document.createElement("button"); btn.type = "button"; btn.className = "er-bag km-bag"; btn.textContent = "Bütçe ve ekonomi ›";
      btn.onclick = function (ev) { ev.stopPropagation(); ekranAc(window.butceEkonomiEkrani); };
      var alt = k.querySelector(".bildirim-alt");
      (alt && alt.parentNode ? alt.parentNode : k).appendChild(btn);
    });
  }

  if (typeof iskelet === "function") {
    var eskiIskelet = iskelet;
    iskelet = window.iskelet = function (baslik) {
      var r = eskiIskelet.apply(this, arguments);
      try {
        if (baslik === "Devlet" && typeof D === "object" && D && (D.devletSekme || "hukumet") === "hukumet") setTimeout(hukumetKart, 80);
        else if (baslik === "Devlet bütçesi") setTimeout(butceSerit, 40);
        else if (baslik === "Bildirimler") setTimeout(bildirimBagla, 40);
      } catch (_) {}
      return r;
    };
  }

  /* ---------------- Menü araması ---------------- */
  function aramaEkle() {
    var ind = window.SO_MENU_ARAMA_INDEKSI; if (!ind) return false;
    var hedef = ind.ekonomi || ind.siyaset; if (!hedef) return false;
    if (!hedef.some(function (x) { return x[1] === "Bütçe ve Ekonomi"; }))
      hedef.unshift(["🏛️", "Bütçe ve Ekonomi", "Hazine, Varlık Fonu, gelir-gider kalemleri, bütçe açığı ve enflasyon", "soMenuGit('butceEkonomiEkrani')",
        "bütçe hazine varlık fonu gelir gider vergi açık fazla enflasyon faiz borç tahvil gsyh ödenek maliye devlet ekonomisi"]);
    return true;
  }
  if (!aramaEkle()) setTimeout(aramaEkle, 1500);
})();
