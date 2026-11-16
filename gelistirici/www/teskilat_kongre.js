/* Seçim Simülasyonu Online · Genel başkan yardımcısı yetkileri ve il kongresi (2026.11.16)
   Sunucu: parti_yetki_durum, gby_yetki_ver, gby_yetki_al, parti_tuzuk_ayarla, il_teskilat_detay, il_kongre_ac,
   il_gecici_baskan_ata, il_baskan_gorevden_al, il_kongre_aday_ol, il_kongre_cekil, il_kongre_oy, il_yk_ekle, il_yk_cikar.
   Yetki her zaman sunucuda doğrulanır; düğmeler yalnız kolaylık içindir. */
(function () {
  "use strict";
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  function rpc(fn, a) { return API.rpc(fn, a || {}); }
  function hata(err) { var m = (err && err.message) || String(err); if (typeof hataCevir === "function") m = hataCevir(m); toast(m, true); }
  function saat(t) { if (!t) return "—"; try { return new Date(t).toLocaleString("tr-TR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (e) { return String(t); } }
  function $$(s, k) { return (k || document).querySelector(s); }
  var CSS = '<style>.tk-satir{display:flex;flex-direction:column;gap:6px;padding:10px 0;border-bottom:1px solid rgba(255,255,255,.08)}' +
    '.tk-cipler{display:flex;flex-wrap:wrap;gap:6px}.tk-cip{font-size:14px;padding:4px 10px;border-radius:999px;background:rgba(255,255,255,.08)}' +
    '.tk-alan{display:flex;flex-direction:column;gap:6px;margin:8px 0}.tk-alan input,.tk-alan select,.tk-alan textarea{width:100%;min-width:0;box-sizing:border-box;font-size:16px;color-scheme:dark}' +
    '.tk-not{font-size:14px;opacity:.85;line-height:1.45}</style>';

  /* ---------- Genel başkan yardımcıları ve yetkiler ---------- */
  async function gbyEkrani(pid) {
    var y, p;
    try { y = await rpc("parti_yetki_durum", { p_parti: pid }); p = await rpc("parti_detay", { p_parti: pid }); } catch (err) { return hata(err); }
    var azami = (y.tuzuk && y.tuzuk.gby_azami) || 6;
    var uyeler = (p.uyeler || []).filter(function (u) { return u.kad !== p.gb; });
    var deger = function (i) { return ((p.gby || []).find(function (g) { return g.sira === i; }) || {}).kad || ""; };
    var siralar = []; for (var i = 1; i <= azami; i++) siralar.push(i);
    var h = CSS + '<h3 style="font-size:19px;font-weight:800">Genel Başkan Yardımcıları</h3>' +
      '<p class="tk-not">Parti tüzüğüne göre en fazla <b>' + azami + '</b> yardımcı atanabilir. Yardımcının yetkisi unvandan değil, aşağıda verdiğin yetki kayıtlarından gelir; dilediğin yetkiyi tek tek geri alabilirsin.</p>';
    if (y.genel_baskan) {
      h += siralar.map(function (i) {
        return '<div class="tk-alan"><label for="tkG' + i + '">' + i + '. Yardımcı</label><select id="tkG' + i + '"><option value="">— Boş —</option>' +
          uyeler.map(function (u) { return '<option ' + (u.kad === deger(i) ? "selected" : "") + '>' + esc(u.kad) + '</option>'; }).join("") + '</select></div>';
      }).join("") + '<button class="btn" id="tkGKaydet">Yardımcıları kaydet</button>';
    }
    h += '<h4 style="margin-top:16px">Yetkiler</h4>' + (y.yardimcilar || []).map(function (g) {
      var var_ = {}; (g.yetkiler || []).forEach(function (x) { var_[x.yetki] = x; });
      return '<div class="tk-satir"><b>' + esc(g.kad) + (g.gorev ? ' · ' + esc(g.gorev) : '') + '</b><div class="tk-cipler">' +
        (y.katalog || []).map(function (k) {
          var a = var_[k.kod];
          return '<span class="tk-cip">' + (a ? '✅ ' : '▫️ ') + esc(k.ad) + (a && a.gunluk_limit != null ? ' · günlük ' + esc(tlYaz(a.gunluk_limit)) : '') + '</span>' +
            (y.genel_baskan ? (a ? '<button class="btn ikinci" data-tk-al="' + esc(g.kad) + '|' + esc(k.kod) + '">Geri al</button>'
                                : '<button class="btn ikinci" data-tk-ver="' + esc(g.kad) + '|' + esc(k.kod) + '|' + (k.limitli ? 1 : 0) + '">Ver</button>') : '');
        }).join("") + '</div></div>';
    }).join("") || '<p class="tk-not">Henüz yardımcı yok.</p>';
    if (y.genel_baskan) {
      var t = y.tuzuk || {};
      h += '<details style="margin-top:14px"><summary>Parti tüzüğü ayarları</summary>' +
        alan("tkT1", "Genel başkan yardımcısı sayısı (1–20)", t.gby_azami) + alan("tkT2", "Seçilmiş il başkanı görev süresi (gün, 14–730)", t.il_baskan_donem_gun) +
        alan("tkT3", "İl kongresi aday başvuru süresi (saat)", t.il_kongre_aday_saat) + alan("tkT4", "İl kongresi oy süresi (saat)", t.il_kongre_oy_saat) +
        alan("tkT5", "Geçici il başkanlığı en uzun süre (gün)", t.il_gecici_azami_gun) + alan("tkT6", "İl yönetim kurulu üye sınırı (3–25)", t.il_yk_azami) +
        '<button class="btn altin" id="tkTKaydet">Tüzüğü kaydet</button></details>';
    }
    if ((y.gecmis || []).length) {
      h += '<details style="margin-top:10px"><summary>Yetki işlem geçmişi</summary>' + y.gecmis.map(function (x) {
        return '<div class="tk-not">' + esc(saat(x.zaman)) + ' · ' + esc(x.kad || '') + ' · ' + esc(x.yetki || '') + ' · ' + esc(x.islem) + (x.tutar != null ? ' · ' + esc(tlYaz(x.tutar)) : '') + '</div>';
      }).join("") + '</details>';
    }
    h += '<button class="btn ikinci" onclick="modalKapat()">Kapat</button>';
    var m = modal(h);
    var k = $$("#tkGKaydet", m);
    if (k) k.onclick = async function () {
      var yeni = siralar.map(function (i) { return $$("#tkG" + i, m).value; });
      var dolu = yeni.filter(Boolean);
      if (new Set(dolu).size !== dolu.length) return toast("Aynı kişi iki sıraya atanamaz.", true);
      k.disabled = true;
      try {
        for (var i = 1; i <= azami; i++) if (deger(i) !== yeni[i - 1] && !yeni[i - 1]) await rpc("gby_ata", { p_sira: i, p_kad: null });
        for (var j = 1; j <= azami; j++) if (deger(j) !== yeni[j - 1] && yeni[j - 1]) await rpc("gby_ata", { p_sira: j, p_kad: yeni[j - 1] });
        toast("Yardımcılar güncellendi."); modalKapat(); gbyEkrani(pid);
      } catch (err) { k.disabled = false; hata(err); }
    };
    var tk = $$("#tkTKaydet", m);
    if (tk) tk.onclick = async function () {
      var v = function (id) { var x = $$("#" + id, m).value; return x === "" ? null : Number(x); };
      try {
        await rpc("parti_tuzuk_ayarla", { p_ayar: { gby_azami: v("tkT1"), il_baskan_donem_gun: v("tkT2"), il_kongre_aday_saat: v("tkT3"), il_kongre_oy_saat: v("tkT4"), il_gecici_azami_gun: v("tkT5"), il_yk_azami: v("tkT6") } });
        toast("Tüzük güncellendi."); modalKapat(); gbyEkrani(pid);
      } catch (err) { hata(err); }
    };
    m.addEventListener("click", async function (ev) {
      var b = ev.target.closest("[data-tk-ver],[data-tk-al]"); if (!b) return;
      try {
        if (b.hasAttribute("data-tk-ver")) {
          var q = b.getAttribute("data-tk-ver").split("|"), lim = null;
          if (q[2] === "1") { var g = window.prompt("Günlük harcama sınırı (₺). Sınırsız için boş bırak:", ""); if (g === null) return; lim = g.trim() === "" ? null : Number(g.replace(/\D/g, "")); }
          await rpc("gby_yetki_ver", { p_kad: q[0], p_yetki: q[1], p_gunluk_limit: lim });
        } else {
          var r = b.getAttribute("data-tk-al").split("|");
          await rpc("gby_yetki_al", { p_kad: r[0], p_yetki: r[1] });
        }
        modalKapat(); gbyEkrani(pid);
      } catch (err) { hata(err); }
    });
  }
  function alan(id, etiket, d) { return '<div class="tk-alan"><label for="' + id + '">' + esc(etiket) + '</label><input id="' + id + '" type="number" inputmode="numeric" value="' + esc(d == null ? "" : d) + '"></div>'; }
  window.gbyModal = gbyEkrani;
  window.gbyYetkiEkrani = gbyEkrani;

  /* ---------- İl başkanlığı ve kongre ---------- */
  var DURUM = { aday: "Aday başvurusu", oy: "Oylama", tamam: "Tamamlandı", sonucsuz: "Sonuçsuz", iptal: "İptal" };
  var TUR = { ilk: "İlk kongre", olagan: "Olağan kongre", olaganustu: "Olağanüstü kongre" };
  async function ilEkrani(pid, il) {
    var d; try { d = await rpc("il_teskilat_detay", { p_parti: pid, p_il: il }); } catch (err) { return hata(err); }
    var b = d.baskan, k = d.kongre, h = CSS + '<h3 style="font-size:19px;font-weight:800">' + esc(d.il) + ' il teşkilatı</h3>';
    h += '<div class="tk-satir"><b>İl Başkanı</b><div>' + (b ? esc(b.kad) + ' · ' + (b.statu === "secilmis" ? "Kongrede seçildi" + (b.donem_bit ? " (dönem sonu " + esc(saat(b.donem_bit)) + ")" : "") : "Geçici görevli") : "Boş") + '</div>' +
      '<div class="tk-not">İl başkanını il kongresinde, kongre açılmadan önce bu ilde partiye üye ve kayıtlı olan üyeler seçer. Geçici görevlendirme kongreye kadar sürer.</div></div>';
    if (k && (k.durum === "aday" || k.durum === "oy")) {
      var oyAcik = Date.now() >= new Date(k.aday_bit).getTime();
      h += '<div class="tk-satir"><b>' + esc(TUR[k.tur] || k.tur) + ' · ' + esc(oyAcik ? "Oylama" : "Aday başvurusu") + '</b>' +
        '<div class="tk-not">Aday başvurusu ' + esc(saat(k.aday_bit)) + '\'e kadar · oylama ' + esc(saat(k.oy_bit)) + '\'e kadar · kullanılan oy: ' + esc(k.oy_sayisi) + '</div>' +
        (k.adaylar || []).map(function (a) {
          return '<div class="tk-satir"><b>' + esc(a.kad) + '</b>' + (a.vaat ? '<div class="tk-not">' + esc(a.vaat) + '</div>' : '') +
            (oyAcik && k.secmen_mi && !k.oy_verdim ? '<button class="btn altin" data-ik-oy="' + esc(a.kad) + '">Oy ver</button>' : '') + '</div>';
        }).join("") +
        (!k.secmen_mi ? '<p class="tk-not">Bu kongrede oy ve adaylık hakkın yok.</p>' : k.oy_verdim ? '<p class="tk-not">Oyunu kullandın.</p>' : '') +
        (!oyAcik && k.secmen_mi && !k.adayim ? '<div class="tk-alan"><label for="ikVaat">Adaylık vaadin (isteğe bağlı)</label><textarea id="ikVaat" maxlength="600"></textarea></div><button class="btn" id="ikAday">Aday ol</button>' : '') +
        (k.adayim ? '<button class="btn ikinci" id="ikCekil">Adaylıktan çekil</button>' : '') + '</div>';
    } else if (k) {
      h += '<div class="tk-satir"><b>Son kongre: ' + esc(DURUM[k.durum] || k.durum) + '</b>' + (k.kazanan ? '<div>Kazanan: ' + esc(k.kazanan) + '</div>' : '') +
        ((k.adaylar || []).map(function (a) { return '<div class="tk-not">' + esc(a.kad) + ': ' + esc(a.oy == null ? "—" : a.oy) + ' oy</div>'; }).join("")) + '</div>';
    }
    h += '<div class="tk-satir"><b>İl yönetim kurulu</b>' + ((d.yonetim_kurulu || []).map(function (y) {
      return '<div>' + esc(y.kad) + (y.gorev ? ' · ' + esc(y.gorev) : '') + ((d.il_baskaniyim || d.yonetebilir) ? ' <button class="btn ikinci" data-ik-ykcikar="' + esc(y.kad) + '">Çıkar</button>' : '') + '</div>';
    }).join("") || '<div class="tk-not">Henüz üye yok.</div>') +
      ((d.il_baskaniyim || d.yonetebilir) && b ? '<div class="tk-alan"><label for="ikYkKad">Üye kullanıcı adı</label><input id="ikYkKad" maxlength="20" autocomplete="off"></div>' +
        '<div class="tk-alan"><label for="ikYkGorev">Görevi (isteğe bağlı)</label><input id="ikYkGorev" maxlength="60" placeholder="Örn. Seçim İşleri"></div><button class="btn" id="ikYkEkle">Yönetim kuruluna ekle / görev ver</button>' : '') + '</div>';
    if (d.yonetebilir) {
      h += '<details style="margin-top:10px"><summary>Genel merkez işlemleri</summary>' +
        (!k || (k.durum !== "aday" && k.durum !== "oy") ? '<button class="btn altin" id="ikKongreAc">İl kongresini aç</button>' : '') +
        (!b || b.statu !== "secilmis" ? '<div class="tk-alan"><label for="ikGecKad">Geçici il başkanı (kullanıcı adı)</label><input id="ikGecKad" maxlength="20" autocomplete="off"></div><button class="btn" id="ikGecAta">Geçici il başkanı görevlendir</button>' : '') +
        (b ? '<div class="tk-alan"><label for="ikAlGer">Görevden alma gerekçesi (en az 20 karakter)</label><textarea id="ikAlGer" maxlength="300"></textarea></div><button class="btn ikinci" id="ikAl">İl başkanını görevden al ve olağanüstü kongre aç</button>' : '') +
        '</details>';
    }
    h += '<button class="btn ikinci" onclick="modalKapat()">Kapat</button>';
    var m = modal(h);
    var yap = async function (fn) { try { await fn(); modalKapat(); ilEkrani(pid, il); if (typeof teskilatKartCiz === "function") teskilatKartCiz(pid); } catch (err) { hata(err); } };
    var on = function (id, fn) { var x = $$("#" + id, m); if (x) x.onclick = function () { yap(fn); }; };
    on("ikAday", function () { return rpc("il_kongre_aday_ol", { p_kongre: k.id, p_vaat: $$("#ikVaat", m).value }); });
    on("ikCekil", function () { return rpc("il_kongre_cekil", { p_kongre: k.id }); });
    on("ikKongreAc", function () { return rpc("il_kongre_ac", { p_il: il }); });
    on("ikGecAta", function () { return rpc("il_gecici_baskan_ata", { p_il: il, p_kad: $$("#ikGecKad", m).value.trim() }); });
    on("ikAl", function () { if (!window.confirm("İl başkanını görevden almak ve olağanüstü kongre açmak istiyor musun?")) return Promise.reject(new Error("Vazgeçildi")); return rpc("il_baskan_gorevden_al", { p_il: il, p_gerekce: $$("#ikAlGer", m).value }); });
    on("ikYkEkle", function () { return rpc("il_yk_ekle", { p_il: il, p_kad: $$("#ikYkKad", m).value.trim(), p_gorev: $$("#ikYkGorev", m).value }); });
    m.addEventListener("click", function (ev) {
      var o = ev.target.closest("[data-ik-oy]");
      if (o) { if (window.confirm(o.getAttribute("data-ik-oy") + " adayına oy vermek istiyor musun? Oy değiştirilemez.")) yap(function () { return rpc("il_kongre_oy", { p_kongre: k.id, p_aday_kad: o.getAttribute("data-ik-oy") }); }); return; }
      var c = ev.target.closest("[data-ik-ykcikar]");
      if (c) yap(function () { return rpc("il_yk_cikar", { p_il: il, p_kad: c.getAttribute("data-ik-ykcikar") }); });
    });
  }
  window.ilTeskilatEkrani = ilEkrani;

  // Teşkilat kartına "İl başkanlığı ve kongre" seçicisi eklenir; eski "İl Başkanı ata" penceresi geçici görevlendirmeye yönlenir.
  var eskiKart = window.teskilatKartCiz;
  if (typeof eskiKart === "function") {
    window.teskilatKartCiz = async function (pid) {
      await eskiKart(pid);
      var el = document.getElementById("teskilatKart"), t = window.D && D._teskilat; if (!el || !t) return;
      var kart = el.querySelector(".kart"); if (!kart || kart.querySelector("#ikSec")) return;
      var iller = (t.iller || []).slice().sort(function (a, b) { return String(a.ad).localeCompare(String(b.ad), "tr"); });
      if (!iller.length) return;
      var kutu = document.createElement("div");
      kutu.innerHTML = '<div class="tk-alan" style="margin-top:10px"><label for="ikSec">İl başkanlığı, kongre ve il yönetim kurulu</label><select id="ikSec">' +
        iller.map(function (x) { return '<option value="' + esc(x.il_id) + '">' + esc(x.ad) + '</option>'; }).join("") + '</select></div><button class="btn ikinci" id="ikAc">İl teşkilatını aç</button>';
      kart.appendChild(kutu);
      kutu.querySelector("#ikAc").onclick = function () { ilEkrani(pid, Number(kutu.querySelector("#ikSec").value)); };
    };
  }
  window.teskilatGorevModal = function (pid) {
    var il = (window.D && D.durum && D.durum.profil && D.durum.profil.il_id) || ((D._teskilat && D._teskilat.iller && D._teskilat.iller[0]) || {}).il_id;
    if (!il) return toast("Önce bir il teşkilatı açılmalı.", true);
    ilEkrani(pid, il);
  };
})();
