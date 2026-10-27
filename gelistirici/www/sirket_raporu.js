/* =====================================================================
   Seçim Online — ŞİRKET İNCELEME RAPORU (27.10.2026)
   Oyuncu isteği: "Şirket satın alırken şirket detayları, kâr oranları,
   sermaye ve şirket kasası görünsün." Satılık şirket, hisse ilanı ve
   borsadaki şirket için: sermaye, kasa (açıksa), stok, ciro, gider, net kâr,
   kâr marjı, sermaye getirisi, yıllık kâr tahmini, F/K ve PD/DD.
   Sunucu: public.sirket_satis_raporu(p_sirket), public.ilan_sirket_raporu(p_ilan).
   ===================================================================== */
(function () {
  "use strict";
  if (window.SO_SIRKET_RAPORU_V1) return;
  window.SO_SIRKET_RAPORU_V1 = true;

  var esc = function (x) {
    return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  };
  var tl = function (n) { return n == null ? "—" : (typeof tlYaz === "function" ? tlYaz(n) : Math.round(Number(n)).toLocaleString("tr-TR") + " ₺"); };
  var sayi = function (n, d) { return Number(n || 0).toLocaleString("tr-TR", { minimumFractionDigits: d || 0, maximumFractionDigits: d || 0 }); };
  var yuzde = function (n) { return n == null ? "—" : "%" + sayi(n, 1); };
  var HUKUKI = { ltd: "Limited şirket", as: "Anonim şirket", sahis: "Şahıs şirketi", kollektif: "Kollektif şirket", koop: "Kooperatif" };
  var DURUM = { satilik: "Şirketin tamamı satılık", hisse_ilani: "Hisse ilanı", borsa: "Borsada işlem görüyor", ortak: "Ortağısın" };

  (function () {
    if (document.getElementById("sr-stil")) return;
    var css = [
      ".sr-izgara{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:8px 0 4px}",
      ".sr-izgara>div{background:var(--panel2);border-radius:12px;padding:10px 12px;min-width:0}",
      ".sr-izgara small{display:block;font-size:12px;color:var(--mut)}",
      ".sr-izgara b{display:block;font-variant-numeric:tabular-nums;font-size:15.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".sr-izgara b.iyi{color:var(--good)}.sr-izgara b.kotu{color:var(--al2)}",
      ".sr-kay{overflow-x:auto;margin:0 -4px}",
      ".sr-tablo{width:100%;border-collapse:collapse;font-size:12.5px;margin:6px 0 2px;font-variant-numeric:tabular-nums}",
      ".sr-tablo th{font-weight:600;color:var(--mut);font-size:11.5px;text-align:right;padding:6px 3px;border-bottom:1px solid var(--line)}",
      ".sr-tablo th:first-child,.sr-tablo td:first-child{text-align:left}",
      ".sr-tablo td{padding:8px 3px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap}",
      ".sr-tablo tr:last-child td{border-bottom:0}",
      ".sr-not{font-size:12.5px;color:var(--mut);line-height:1.5;margin:8px 0 0}",
      ".sr-rozet{display:inline-block;padding:3px 9px;border-radius:8px;font-size:12px;font-weight:700;background:var(--inkbg);color:var(--txt2);margin:2px 4px 2px 0}"
    ].join("\n");
    var st = document.createElement("style"); st.id = "sr-stil"; st.textContent = css; document.head.appendChild(st);
  })();

  // Kartlar (kart sınıfı oyunun genel kartıdır). kisa=true: satın alma ekranına gömülü özet
  function raporHtml(r, kisa) {
    if (!r) return "";
    var s30 = r.son30 || {}, s7 = r.son7 || {}, top = r.toplam || {};
    var h = "";
    var net30 = Number(s30.net || 0);
    h += '<section class="kart"><h2>' + (kisa ? "Kârlılık ve kasa" : "Mali durum") + '</h2>' +
      (kisa ? "" : '<div>' + '<span class="sr-rozet">' + esc(DURUM[r.durum] || r.durum) + '</span>' + (r.hukuki ? '<span class="sr-rozet">' + esc(HUKUKI[r.hukuki] || r.hukuki) + '</span>' : "") + (r.il ? '<span class="sr-rozet">' + esc(r.il) + '</span>' : "") + '</div>') +
      '<div class="sr-izgara">' +
      '<div><small>Sermaye</small><b>' + tl(r.sermaye) + '</b></div>' +
      '<div><small>Şirket kasası</small><b>' + (r.kasa_gizli ? "Gizli" : tl(r.kasa)) + '</b></div>' +
      '<div><small>Stok değeri</small><b>' + tl(r.stok_degeri) + '</b></div>' +
      '<div><small>Şube</small><b>' + sayi(r.sube) + '</b></div>' +
      '<div><small>Son 30 gün net kâr</small><b class="' + (net30 > 0 ? "iyi" : net30 < 0 ? "kotu" : "") + '">' + (net30 > 0 ? "+" : "") + tl(net30) + '</b></div>' +
      '<div><small>Kâr marjı (30 gün)</small><b>' + yuzde(s30.marj) + '</b></div>' +
      '<div><small>Sermaye getirisi (30 gün)</small><b>' + yuzde(r.sermaye_getirisi_30) + '</b></div>' +
      '<div><small>Yıllık kâr tahmini</small><b>' + tl(r.yillik_net_tahmini) + '</b></div>' +
      (r.fiyat != null ? '<div><small>İstenen fiyat' + (r.pay && Number(r.pay) < 100 ? " (%" + sayi(r.pay, 0) + ")" : "") + '</small><b>' + tl(r.fiyat) + '</b></div>' +
        '<div><small>F/K · PD/DD</small><b>' + (r.fiyat_kazanc != null ? sayi(r.fiyat_kazanc, 1) + " yıl" : "kâr yok") + ' · ' + (r.fiyat_defter != null ? sayi(r.fiyat_defter, 2) + "×" : "—") + '</b></div>' : "") +
      '</div>' +
      (r.kasa_gizli ? '<p class="sr-not">Satıcı şirket kasasını paylaşmadı; ciro ve kâr bilgisi yine de açıktır. Teklif notunda kasayı sorabilirsin.</p>' : "") +
      '</section>';
    h += '<section class="kart"><h2>Gelir tablosu</h2><div class="sr-kay"><table class="sr-tablo"><thead><tr><th></th><th>Son 7 gün</th><th>Son 30 gün</th><th>Toplam</th></tr></thead><tbody>' +
      '<tr><td>Ciro (gelir)</td><td>' + tl(s7.gelir) + '</td><td>' + tl(s30.gelir) + '</td><td>' + tl(top.gelir) + '</td></tr>' +
      '<tr><td>Gider</td><td>' + tl(s7.gider) + '</td><td>' + tl(s30.gider) + '</td><td>—</td></tr>' +
      '<tr><td><b>Net kâr</b></td><td><b>' + tl(s7.net) + '</b></td><td><b>' + tl(s30.net) + '</b></td><td><b>' + tl(top.net) + '</b></td></tr>' +
      '<tr><td>Kâr marjı</td><td>' + yuzde(s7.marj) + '</td><td>' + yuzde(s30.marj) + '</td><td>' + yuzde(top.marj) + '</td></tr>' +
      '<tr><td>Ortaklara dağıtılan</td><td>—</td><td>—</td><td>' + tl(top.dagitilan) + '</td></tr>' +
      '</tbody></table></div>' +
      '<p class="sr-not">' + (r.donem_kaynak === "rekabetci_pazar" ? "Rakamlar şirketin pazar raporlarından (satış, maliyet, ruhsat, ceza, vergi) hesaplanır." : "Rakamlar şirketin faaliyet hareketlerinden hesaplanır.") +
      ' F/K: istenen fiyatın yıllık kâra oranı (kaç yılda geri döner); PD/DD: fiyatın kasa + stok değerine oranı. Geçmiş kâr gelecekteki kârı garanti etmez.</p></section>';
    if (!kisa) {
      var ort = (r.ortaklar || []).map(function (o) { return esc(o.kad) + " %" + sayi(o.pay, 0); }).join(", ");
      h += '<section class="kart"><h2>Şirket</h2>' +
        '<div class="kv"><span class="k">Kurucu</span><span class="v">' + esc(r.kurucu || "—") + '</span></div>' +
        '<div class="kv"><span class="k">Ortaklar</span><span class="v" style="white-space:normal;text-align:right">' + (ort || "—") + '</span></div>' +
        '<div class="kv"><span class="k">Kuruluş</span><span class="v">' + (r.kurulus ? new Date(r.kurulus).toLocaleDateString("tr-TR") : "—") + '</span></div>' +
        (r.not ? '<p class="sr-not">' + esc(r.not) + '</p>' : "") + '</section>';
    }
    return h;
  }
  window.sirketRaporuHtml = raporHtml;

  async function raporEkrani(sirketId, ilanId) {
    yukleniyor("İnceleme raporu");
    try {
      var r = ilanId ? await API.rpc("ilan_sirket_raporu", { p_ilan: Number(ilanId) }) : await API.rpc("sirket_satis_raporu", { p_sirket: Number(sirketId) });
      iskelet(r.ad ? esc(String(r.ad).slice(0, 28)) : "İnceleme raporu", raporHtml(r, false), { geri: true });
    } catch (err) {
      iskelet("İnceleme raporu", '<div class="kart"><p class="alt">' + esc(typeof hataCevir === "function" ? hataCevir(err.message) : err.message) + '</p></div>', { geri: true });
    }
  }
  window.sirketRaporuEkrani = raporEkrani;
})();
