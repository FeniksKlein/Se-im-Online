/* =====================================================================
   EKONOMİ 3.0 (2026-10-15) — Piyasa panosu, şirket karnesi, genel kurul
   Arka uç: gelistirici/sql/99_ekonomi3_*.sql
   RPC: piyasa_panosu, sirket_karnesi, genel_kurul_ac, genel_kurul_oy,
        sirket_as_donustur, sirket_reklam_ayarla, pazar_ayarla
   Bu dosya en son yüklenir: Ekonomi sekmesine piyasa kartı, Şirketlerim ve
   rekabetçi şirket ekranlarına "Şirket karnesi" girişi ekler.
   ===================================================================== */
(function(){
  "use strict";
  if (window.EKONOMI3_MODUL) return;
  window.EKONOMI3_MODUL = true;

  const E3 = { pano: null, karne: null };
  const n = (x) => +x || 0;
  const tl = (x) => tlYaz(Math.round(n(x)));
  const kisa = (x) => {
    const v = n(x), a = Math.abs(v), s = v < 0 ? "−" : "";
    if (a >= 1e9) return s + fmt(a / 1e9, 2) + " Mr ₺";
    if (a >= 1e6) return s + fmt(a / 1e6, a >= 1e7 ? 1 : 2) + " Mn ₺";
    if (a >= 1e4) return s + fmt(a / 1e3, 0) + " B ₺";
    return s + fmt(a) + " ₺";
  };
  const isaretli = (x) => (n(x) > 0 ? "+" : n(x) < 0 ? "−" : "") + kisa(Math.abs(n(x)));
  const renk = (x) => n(x) > 0 ? "var(--good)" : n(x) < 0 ? "var(--al2)" : "var(--txt2)";
  const degisim = (x) => x == null ? '<span class="e3-dg">—</span>'
    : `<span class="e3-dg ${n(x) > 0 ? "art" : n(x) < 0 ? "dus" : ""}">${n(x) > 0 ? "▲" : n(x) < 0 ? "▼" : "="} %${fmt(Math.abs(n(x)), 1)}</span>`;
  const SEKTOR_AD = { banka: "Bankacılık", ajans: "Reklam ve anket ajansı" };
  const sekAd = (kod, ad) => SEKTOR_AD[kod] || (ad && ad !== kod ? ad : kod);
  const tesvikYazi = (b) => !b || (!n(b.vergi_indirim) && !n(b.sgk_destek)) ? "teşvik yok (gelişmiş bölge)"
    : `vergi −%${fmt(n(b.vergi_indirim))}${n(b.sgk_destek) ? ` · SGK −%${fmt(n(b.sgk_destek))}` : ""}`;
  const turRozet = (t) => t === "as" ? '<span class="rozet altin">A.Ş.</span>' : '<span class="rozet">Ltd. Şti.</span>';
  const hata = (baslik, err) => iskelet(baslik, `<div class="kart"><p>${e(hataCevir(err.message))}</p><button class="btn ikinci" onclick="geriGit()">Geri dön</button></div>`, { geri: true });

  try {
    if (!document.getElementById("e3Css")) {
      const st = document.createElement("style"); st.id = "e3Css";
      st.textContent = `
.e3-sahne{background:linear-gradient(160deg,var(--panel2),var(--panel));border:1px solid var(--line2);border-radius:16px;padding:16px;margin-bottom:12px;position:relative;overflow:hidden}
.e3-sahne .ust-yazi{font-size:12px;color:var(--txt2);font-weight:700;letter-spacing:.3px}
.e3-buyuk{font-family:var(--disp);font-size:44px;line-height:1;margin:6px 0 2px;font-variant-numeric:tabular-nums}
.e3-orta{font-family:var(--disp);font-size:26px;line-height:1.05;font-variant-numeric:tabular-nums}
.e3-dg{display:inline-block;font-weight:800;font-size:13px;color:var(--txt2);font-variant-numeric:tabular-nums;white-space:nowrap}
.e3-dg.art{color:var(--good)} .e3-dg.dus{color:var(--al2)}
.e3-spark{display:block;width:100%;height:56px;margin-top:10px}
.e3-izgara{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:10px}
.e3-kutu{background:var(--panel2);border-radius:12px;padding:10px 12px;min-width:0}
.e3-kutu small{display:block;font-size:11.5px;color:var(--txt2);font-weight:700}
.e3-kutu b{display:block;font-family:var(--disp);font-size:21px;line-height:1.15;margin-top:2px;overflow-wrap:anywhere;font-variant-numeric:tabular-nums}
.e3-kutu span{display:block;font-size:11.5px;color:var(--txt2);margin-top:2px}
.e3-sira{display:flex;align-items:center;gap:10px;padding:11px 0;border-bottom:1px solid var(--line);width:100%;text-align:left;background:none;color:var(--txt)}
.e3-sira:last-child{border-bottom:0}
.e3-sira .no{font-family:var(--disp);font-size:20px;width:26px;flex:none;color:var(--ink2);text-align:center}
.e3-sira .orta{flex:1;min-width:0}
.e3-sira .orta b{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.e3-sira .orta .kucuk{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.e3-sira .sag{text-align:right;flex:none}
.e3-sira .sag b{display:block;font-family:var(--disp);font-size:18px;font-variant-numeric:tabular-nums}
.e3-cubuk{height:8px;border-radius:5px;background:var(--panel2);overflow:hidden;margin:6px 0 2px}
.e3-cubuk i{display:block;height:100%;border-radius:5px;background:var(--ink2)}
.e3-cubuk.iki{display:flex}.e3-cubuk.iki i{border-radius:0}
.e3-cip{display:inline-flex;gap:6px;align-items:center;background:var(--panel2);border-radius:20px;padding:6px 10px;margin:4px 6px 0 0;font-size:13px;font-weight:700}
.e3-sec{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px;margin:6px 0 12px}
.e3-sec.uc{grid-template-columns:repeat(3,minmax(0,1fr))}
.e3-sec button{padding:10px 4px;border-radius:10px;background:var(--panel2);color:var(--txt);font-weight:700;font-size:13px;border:1.5px solid transparent;line-height:1.2}
.e3-sec button small{display:block;font-size:10.5px;color:var(--txt2);font-weight:600;margin-top:2px}
.e3-sec button.secili{border-color:var(--ink2);color:var(--ink2)}
.e3-sec button:disabled{opacity:.55}
.e3-etiket{font-size:12.5px;font-weight:800;color:var(--txt2);margin-top:4px}
.e3-not{font-size:13px;color:var(--txt2);line-height:1.5;margin-top:8px}
.e3-bolge{display:grid;grid-template-columns:44px 1fr auto;gap:8px;align-items:center;padding:9px 0;border-bottom:1px solid var(--line)}
.e3-bolge:last-child{border-bottom:0}
.e3-bolge .bno{font-family:var(--disp);font-size:20px;color:var(--ink2);text-align:center}
.e3-bolge.ben{background:var(--inkbg);border-radius:10px;padding:9px 8px;border-bottom:0}
.e3-kurul{background:var(--panel2);border-radius:12px;padding:12px;margin-top:10px}
.e3-kurul .ikili{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px}
.e3-kurul .ikili .btn{margin:0}
.e3-giris{display:flex;align-items:center;gap:12px;width:100%;text-align:left;color:var(--txt);background:linear-gradient(160deg,var(--panel2),var(--panel));border:1px solid var(--line2);border-radius:16px;padding:14px;margin-bottom:12px}
.e3-giris .sol{flex:1;min-width:0}
.e3-giris .sag{flex:none;width:96px}
.e3-tablo{width:100%;border-collapse:collapse;font-size:12.5px;font-variant-numeric:tabular-nums}
.e3-tablo th{color:var(--txt2);font-weight:700;text-align:right;padding:6px 4px;border-bottom:1px solid var(--line2)}
.e3-tablo th:first-child,.e3-tablo td:first-child{text-align:left}
.e3-tablo td{text-align:right;padding:7px 4px;border-bottom:1px solid var(--line)}
.e3-kaydir{overflow-x:auto;-webkit-overflow-scrolling:touch}
.e3-karne-btn{margin-top:8px}`;
      document.head.appendChild(st);
    }
  } catch (_) {}

  /* --------- küçük grafikler (SVG, tema değişkenleriyle) --------- */
  function spark(seri, opt){
    opt = opt || {};
    const v = (seri || []).map(n);
    const w = 300, h = opt.h || 56;
    if (v.length < 2) return `<svg class="e3-spark" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none"><line x1="0" y1="${h / 2}" x2="${w}" y2="${h / 2}" stroke="var(--line2)" stroke-width="2" stroke-dasharray="4 4"/></svg>`;
    const min = Math.min(...v), max = Math.max(...v), ar = max - min || 1;
    const p = v.map((y, i) => [i * w / (v.length - 1), h - 4 - (y - min) / ar * (h - 8)]);
    const yol = p.map((q, i) => (i ? "L" : "M") + q[0].toFixed(1) + " " + q[1].toFixed(1)).join(" ");
    const r = v[v.length - 1] >= v[0] ? "var(--good)" : "var(--al2)";
    return `<svg class="e3-spark" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" aria-hidden="true">
      <path d="${yol} L${w} ${h} L0 ${h} Z" fill="${r}" opacity=".12"/>
      <path d="${yol}" fill="none" stroke="${r}" stroke-width="2.5" vector-effect="non-scaling-stroke" stroke-linejoin="round"/></svg>`;
  }
  function barlar(gunler){
    const v = (gunler || []).map(g => n(g.net));
    if (!v.length) return '<p class="alt">İlk günlük hesap kesildiğinde burada çubuklar belirir.</p>';
    const w = 300, h = 90, max = Math.max(1, ...v.map(Math.abs)), adim = w / v.length, sifir = v.some(x => x < 0) ? h / 2 : h - 4;
    const ol = v.map((x, i) => {
      const y = Math.abs(x) / max * (sifir - 4), bx = i * adim + adim * 0.18, bw = adim * 0.64;
      return `<rect x="${bx.toFixed(1)}" y="${(x >= 0 ? sifir - y : sifir).toFixed(1)}" width="${bw.toFixed(1)}" height="${Math.max(1.5, y).toFixed(1)}" rx="2" fill="${x >= 0 ? "var(--good)" : "var(--al2)"}"/>`;
    }).join("");
    return `<svg viewBox="0 0 ${w} ${h}" style="width:100%;height:90px;display:block;margin-top:8px" aria-hidden="true">
      <line x1="0" y1="${sifir}" x2="${w}" y2="${sifir}" stroke="var(--line2)"/>${ol}</svg>`;
  }
  const gunAd = (g) => { const d = new Date(g + "T12:00:00"); return isNaN(d) ? g : d.toLocaleDateString("tr-TR", { day: "numeric", month: "short" }); };

  /* ===================================================================
     PİYASA PANOSU
     =================================================================== */
  async function piyasaPanosuEkrani(){
    yukleniyor("Piyasa panosu");
    let p;
    try { p = E3.pano = await API.rpc("piyasa_panosu"); } catch (err) { return hata("Piyasa panosu", err); }
    const en = p.endeks || {}, ben = p.benim || {}, z = p.zincir || {};
    const benimBolge = (ben.bolge || {}).bolge;
    const buyukler = p.buyukler || [], sektorler = p.sektorler || [];
    const maxSek = Math.max(1, ...sektorler.map(s => Math.abs(n(s.kar7))));
    const zToplam = n(z.elektrik) + n(z.lojistik) + n(z.reklam) + n(z.npc);
    iskelet("Piyasa panosu", `
      <section class="e3-sahne">
        <div class="ust-yazi">Şirketler Endeksi</div>
        <div class="e3-buyuk">${fmt(n(en.deger), 2)}</div>
        <div>${degisim(en.degisim)} <span class="kucuk">dünkü kapanışa göre</span></div>
        ${spark((p.seri || []).map(x => x.deger))}
        <div class="kucuk" style="margin-top:6px">${fmt(n(en.sirket))} şirket · toplam değer ${kisa(en.toplam)} · her gün 18.00'de kapanış</div>
      </section>

      <div class="kart"><h2>Senin şirketlerin</h2>
        <div class="e3-izgara">
          <div class="e3-kutu"><small>Paylarının değeri</small><b>${kisa(ben.portfoy)}</b></div>
          <div class="e3-kutu"><small>Bugünkü kâr payın</small><b style="color:${renk(ben.bugun)}">${isaretli(ben.bugun)}</b></div>
          <div class="e3-kutu"><small>Son 7 gün</small><b style="color:${renk(ben.hafta)}">${isaretli(ben.hafta)}</b></div>
          <div class="e3-kutu"><small>İkamet ilin</small><b>${benimBolge ? benimBolge + ". bölge" : "—"}</b><span>${benimBolge ? tesvikYazi(ben.bolge) : ""}</span></div>
        </div>
        ${(ben.sirketler || []).length ? (ben.sirketler || []).map(s => `
          <button class="e3-sira" onclick="sirketKarnesiAc(${+s.id})">
            <span class="orta"><b>${e(s.ad)}</b><span class="kucuk">%${fmt(n(s.pay), n(s.pay) % 1 ? 1 : 0)} pay · 7 günlük kâr ${isaretli(s.kar7)}</span></span>
            <span class="sag"><b>${kisa(s.deger)}</b><span class="kucuk">şirket değeri</span></span><span class="ok">›</span>
          </button>`).join("")
          : `<p class="alt" style="margin-top:10px">Henüz şirketin yok. Bir şirket kurduğunda kârı her gün hesaplanır ve payına düşen kısım cüzdanına gelir.</p>
             ${typeof sirketYonetimEkrani === "function" ? `<button class="btn" onclick="ekranAc(sirketYonetimEkrani)">Şirket kur</button>` : ""}`}
      </div>

      <div class="bolum-bas"><h2>Türkiye'nin en değerli şirketleri</h2><span class="kucuk">Değer = varlıklar + 7 günlük kâr × 10</span></div>
      <div class="kart">${buyukler.length ? buyukler.map((s, i) => `
        <button class="e3-sira" onclick="sirketKarnesiAc(${+s.id})">
          <span class="no">${i + 1}</span>
          <span class="orta"><b>${e(s.ad)}</b><span class="kucuk">${e(sekAd(s.sektor, s.sektor_ad))}${s.il ? " · " + e(s.il) : ""} · ${e(s.sahip || "—")}</span></span>
          <span class="sag"><b>${kisa(s.deger)}</b>${degisim(s.degisim)}</span>
        </button>`).join("") : '<p class="alt">Henüz değerlenmiş şirket yok.</p>'}</div>

      ${(p.yukselenler || []).length ? `<div class="kart"><h2>Günün yükselenleri</h2>
        ${(p.yukselenler || []).map(s => `<button class="e3-cip" onclick="sirketKarnesiAc(${+s.id})">${e(s.ad)} ${degisim(s.degisim)}</button>`).join("")}</div>` : ""}

      <div class="kart"><h2>Sektörler</h2><p class="alt">Son 7 günde sektörlerin toplam net kârı.</p>
        ${sektorler.map(s => `<div style="margin-top:10px"><div class="kv" style="border:0;padding:0"><span>${e(sekAd(s.kod, s.ad))} <span class="kucuk">· ${fmt(n(s.sirket))} şirket</span></span><b style="color:${renk(s.kar7)}">${isaretli(s.kar7)}</b></div>
          <div class="e3-cubuk"><i style="width:${(Math.abs(n(s.kar7)) / maxSek * 100).toFixed(1)}%;background:${n(s.kar7) >= 0 ? "var(--good)" : "var(--al2)"}"></i></div></div>`).join("") || '<p class="alt">Veri yok.</p>'}
      </div>

      <div class="kart"><h2>Şirketler arası ticaret</h2>
        <p class="alt">Her şirket elektrik faturası, lojistik ve reklam öder. Oyuncuların kurduğu enerji, ulaşım ve medya şirketleri bu harcamaların bir kısmını kazanır; geri kalanı yurt içi tedarikçilere gider. Bu sektörlerde şirket kurarsan diğer oyuncuların giderleri senin gelirin olur.</p>
        <div class="e3-izgara">
          <div class="e3-kutu"><small>Elektrik (enerji şirketlerine)</small><b>${kisa(z.elektrik)}</b><span>son 7 gün</span></div>
          <div class="e3-kutu"><small>Lojistik (ulaşım şirketlerine)</small><b>${kisa(z.lojistik)}</b><span>son 7 gün</span></div>
          <div class="e3-kutu"><small>Reklam (medya şirketlerine)</small><b>${kisa(z.reklam)}</b><span>son 7 gün</span></div>
          <div class="e3-kutu"><small>Oyuncu dışı tedarikçiler</small><b>${kisa(z.npc)}</b><span>${zToplam ? "%" + fmt(n(z.npc) / zToplam * 100) + " pay" : ""}</span></div>
        </div></div>

      <div class="kart"><h2>Bölgesel teşvik</h2>
        <p class="alt">Gerçekteki altı bölgeli teşvik sistemi gibi: az gelişmiş illerde kurulan şirket daha az kurumlar vergisi öder, personel için SGK desteği alır. Büyük şehirde pazar büyük, doğuda teşvik yüksek; seçim senin.</p>
        ${(p.bolgeler || []).map(b => `<div class="e3-bolge ${b.bolge === benimBolge ? "ben" : ""}">
          <span class="bno">${b.bolge}.</span>
          <span><b>Vergi −%${fmt(b.vergi_indirim)}</b> · SGK −%${fmt(b.sgk_destek)}<span class="kucuk" style="display:block">${e(b.ornek || "")}${b.bolge === benimBolge ? " · senin bölgen" : ""}</span></span>
          <span class="kucuk">${b.bolge === 1 ? "gelişmiş" : b.bolge === 6 ? "öncelikli" : ""}</span></div>`).join("")}
      </div>

      <div class="kart"><h2>Nasıl işler?</h2>
        <p class="e3-not"><b>Her gün hesap kesilir.</b> Şirketin ilinde fiyat, kalite, marka ve rakiplerle yarışır; günün net kârı payın oranında cüzdanına gelir (istersen kasada biriktirirsin). Akşam 20.00'de günün bilançosu bildirim olarak gelir.</p>
        <p class="e3-not"><b>Vergi gerçek usulle.</b> Kurumlar vergisi %${fmt(n(p.kurumlar))} (Meclis değiştirebilir), bölgesel teşvik indirimi düşülür; vergiler hazineye, ruhsat harçları belediyeye gider. Politika faizi şu an %${fmt(n(p.politika_faizi), 1)}.</p>
        <p class="e3-not"><b>Şirket değeri</b> varlıklar (kasa, stok, arsa, bina) ile son 7 günün kârının on katıdır; borsadaki şirketlerde hisse fiyatı esas alınır. Endeks her gün yalnız iki günde de var olan şirketlerin değişimiyle zincirlenir.</p>
        <p class="e3-not"><b>Genel kurul:</b> ortaklar temettü, yönetici (CEO) ataması, ad değişikliği ve tasfiye için oy kullanır. <b>Halka arz</b> yalnız anonim şirkette yapılır (en az 250.000 ₺ sermaye).</p>
      </div>`, { geri: D.yigin.length > 0 });
  }

  /* ===================================================================
     ŞİRKET KARNESİ
     =================================================================== */
  const FIYAT = [[1, "Ucuz", "×0,8"], [2, "Normal", "×1"], [3, "Premium", "×1,3"]];
  const KALITE = [[0, "Temel", "gider yok"], [1, "İyi", "+%1"], [2, "Çok iyi", "+%2,2"], [3, "Lüks", "+%3,6"]];
  const REKLAM = [[0, "Yok", "—"], [1, "Az", "%1,5"], [2, "Orta", "%3"], [3, "Yoğun", "%5"]];

  async function sirketKarnesiEkrani(id){
    yukleniyor("Şirket karnesi");
    let k;
    try { k = E3.karne = await API.rpc("sirket_karnesi", { p_sirket: id }); } catch (err) { return hata("Şirket karnesi", err); }
    const t = k.tahmin, bol = k.bolge || {}, gunler = k.gunler || [];
    const yon = !!k.yonetici_mi && k.aktif;
    const dolu = t ? Math.min(100, n(t.talep) / Math.max(1, n(t.kapasite)) * 100) : 0;
    const acikKurul = (k.kurullar || []).filter(x => x.durum === "acik");
    const kapali = (k.kurullar || []).filter(x => x.durum !== "acik");
    const sonGunler = gunler.slice(-7).reverse();
    iskelet(k.ad, `
      <section class="e3-sahne">
        <div class="ust-yazi">${e(sekAd(k.sektor, k.sektor_ad))}${k.il ? " · " + e(k.il) : ""} ${turRozet(k.tur)} ${k.halka_acik ? '<span class="rozet yesil">Borsada</span>' : ""} ${k.aktif ? "" : '<span class="rozet">Faaliyette değil</span>'}</div>
        <div class="e3-buyuk">${kisa(k.piyasa != null ? k.piyasa : k.deger)}</div>
        <div class="kucuk">${k.piyasa != null ? "piyasa değeri (hisse fiyatı × 100)" : "tahmini şirket değeri"} · 7 günlük kâr <b style="color:${renk(k.kar7)}">${isaretli(k.kar7)}</b></div>
        ${spark((k.deger_seri || []).map(x => x.deger))}
        <div class="e3-izgara">
          <div class="e3-kutu"><small>Kasa</small><b>${kisa(k.kasa)}</b></div>
          <div class="e3-kutu"><small>Sermaye</small><b>${kisa(k.sermaye)}</b></div>
          <div class="e3-kutu"><small>Varlıklar (defter)</small><b>${kisa(k.defter)}</b></div>
          <div class="e3-kutu"><small>Bölgesel teşvik</small><b>${bol.bolge ? bol.bolge + ". bölge" : "—"}</b><span>${bol.bolge ? tesvikYazi(bol) : ""}</span></div>
        </div>
      </section>

      <div class="kart"><h2>Son günler</h2><p class="alt">Her gün kesilen hesap: gelir − gider − vergi = net.</p>
        ${barlar(gunler)}
        ${sonGunler.length ? `<div class="e3-kaydir"><table class="e3-tablo"><tr><th>Gün</th><th>Gelir</th><th>Gider</th><th>Vergi</th><th>Net</th></tr>
          ${sonGunler.map(g => `<tr><td>${gunAd(g.gun)}</td><td>${kisa(g.gelir)}</td><td>${kisa(g.gider)}</td><td>${kisa(g.vergi)}${n(g.tesvik) > 0 ? `<span class="kucuk" style="display:block;color:var(--good)">teşvik ${kisa(g.tesvik)}</span>` : ""}</td><td style="color:${renk(g.net)};font-weight:800">${isaretli(g.net)}</td></tr>`).join("")}</table></div>` : ""}
      </div>

      ${t ? `<div class="kart"><h2>Bu haftanın tahmini</h2>
        <div class="e3-orta" style="color:${renk(t.net)}">${isaretli(t.net)} <span class="kucuk">/ hafta</span></div>
        <div class="kucuk">günde yaklaşık ${isaretli(t.gunluk_net)} · sermayenin %${fmt(n(t.getiri), 1)}'i</div>
        <div class="e3-etiket" style="margin-top:12px">Talep / kapasite</div>
        <div class="e3-cubuk"><i style="width:${dolu.toFixed(1)}%;background:${dolu >= 100 ? "var(--warn)" : "var(--ink2)"}"></i></div>
        <div class="kucuk">${dolu >= 100 ? "Kapasite dolu: talep fazlası var, fiyatı artırmak kârı büyütebilir ya da sermaye artırarak büyüyebilirsin." : "Boş kapasite var: daha ucuz fiyat, daha yüksek kalite ya da reklam müşteri getirir."}</div>
        <div class="kv" style="margin-top:8px"><span>Pazar payı</span><b>%${fmt(n(t.pay), 1)} · ${n(t.rakip) ? fmt(n(t.rakip)) + " rakip" : "rakip yok"}</b></div>
        <div class="kv"><span>İlin haftalık pazarı</span><b>${kisa(t.pazar)}</b></div>
        <div class="kv"><span>Gelir</span><b>${kisa(t.gelir)}</b></div>
        <div class="kv"><span>Personel (asgari ücrete bağlı)</span><b>${kisa(t.personel)}</b></div>
        <div class="kv"><span>Sabit gider (elektrik, lojistik dahil)</span><b>${kisa(t.sabit)}</b></div>
        ${n(t.kalite_gider) ? `<div class="kv"><span>Kalite gideri</span><b>${kisa(t.kalite_gider)}</b></div>` : ""}
        ${n(t.reklam) ? `<div class="kv"><span>Reklam bütçesi</span><b>${kisa(t.reklam)}</b></div>` : ""}
        <div class="kv"><span>Kurumlar vergisi (%${fmt(n(t.kurumlar_orani))}${n(t.vergi_indirim) ? `, teşvikle −%${fmt(n(t.vergi_indirim))}` : ""})</span><b>${kisa(t.vergi)}</b></div>
        ${t.politika && t.politika !== "normal" ? `<div class="kv"><span>Bakanlık politikası</span><b>${t.politika === "tesvik" ? "Teşvik (+%15 talep)" : "Sıkı denetim"}</b></div>` : ""}
      </div>` : ""}

      ${yon && t ? `<div class="kart"><h2>Kararların</h2>
        <p class="alt">Fiyat ve kalite 10 dakikada bir değiştirilebilir; değişiklik bir sonraki günlük hesaba işler.${k.otopilot ? " Otopilot açık: fiyat ve kaliteyi her hafta otopilot seçer." : ""}</p>
        <div class="e3-etiket">Fiyat</div>
        <div class="e3-sec uc">${FIYAT.map(([v, a, s]) => `<button class="${+k.fiyat === v ? "secili" : ""}" onclick="e3Ayarla(${+k.id},'fiyat',${v})">${a}<small>${s}</small></button>`).join("")}</div>
        <div class="e3-etiket">Kalite</div>
        <div class="e3-sec">${KALITE.map(([v, a, s]) => `<button class="${+k.kalite === v ? "secili" : ""}" onclick="e3Ayarla(${+k.id},'kalite',${v})">${a}<small>${s}</small></button>`).join("")}</div>
        <div class="e3-etiket">Reklam bütçesi <span class="kucuk">(gelirin yüzdesi · medya şirketlerine akar, markayı büyütür)</span></div>
        <div class="e3-sec">${REKLAM.map(([v, a, s]) => `<button class="${+k.reklam === v ? "secili" : ""}" onclick="e3Reklam(${+k.id},${v})">${a}<small>${s}</small></button>`).join("")}</div>
        <div class="kv"><span>Marka gücü</span><b>${fmt(n(k.marka))} / 100</b></div>
        ${typeof pazarDetayEkrani === "function" ? `<button class="btn ikinci" onclick="ekranAc(()=>pazarDetayEkrani(${+k.id}))">Danışman, il taşıma ve rakipler</button>` : ""}
      </div>` : ""}

      <div class="kart"><h2>Hukuki yapı</h2>
        <div class="kv"><span>Şirket türü</span><b>${k.tur === "as" ? "Anonim şirket (A.Ş.)" : "Limited şirket (Ltd. Şti.)"}</b></div>
        <div class="kv"><span>Yönetici (CEO)</span><b>${e(k.yonetici || k.sahip || "—")}${k.yonetici ? "" : " · en büyük ortak"}</b></div>
        ${k.tur !== "as" ? `<p class="e3-not">Halka arz ve borsada işlem için anonim şirket olmak gerekir. Dönüşüm için en az ${tl(k.as_esik)} sermaye ve ${tl(k.as_harc)} ticaret sicili tescil harcı gerekir.</p>
          ${yon ? (n(k.sermaye) >= n(k.as_esik) ? `<button class="btn altin" onclick="e3AsDonustur(${+k.id},${n(k.as_harc)})">Anonim şirkete dönüştür</button>` : `<p class="kucuk">Sermaye yetersiz: önce Şirketlerim ekranından sermaye artır.</p>`) : ""}` : ""}
        ${k.aktif && typeof halkaArzEkrani === "function" ? `<button class="btn ikinci" onclick="ekranAc(()=>halkaArzEkrani(${+k.id}))">${k.halka_acik ? "Halka arz · ikincil arz ve geçmiş" : "Halka arz · SPK başvurusu"}</button>` : ""}
      </div>

      <div class="kart"><h2>Müşterilerin ve tedarikçilerin</h2><p class="alt">Son 7 günde şirketler arası ticaret.</p>
        <div class="e3-etiket">Sana ödeyen şirketler</div>
        ${(k.musteriler || []).length ? k.musteriler.map(m => `<div class="kv"><span>${e(m.ad)} <span class="kucuk">· ${e(m.kalem)}</span></span><b style="color:var(--good)">+${kisa(m.tutar)}</b></div>`).join("")
          : `<p class="kucuk">${["enerji", "ulasim", "medya"].includes(k.sektor) ? "Henüz müşteri ödemesi yok; ilk günlük hesaplardan sonra gelir." : "Bu sektör diğer şirketlere hizmet satmıyor. Enerji, ulaşım ve medya şirketleri diğer oyuncuların giderlerinden kazanır."}</p>`}
        <div class="e3-etiket" style="margin-top:10px">Ödeme yaptığın tedarikçiler</div>
        ${(k.tedarikciler || []).length ? k.tedarikciler.map(m => `<div class="kv"><span>${e(m.ad)} <span class="kucuk">· ${e(m.kalem)}</span></span><b>−${kisa(m.tutar)}</b></div>`).join("") : '<p class="kucuk">Henüz kayıt yok.</p>'}
      </div>

      <div class="kart"><h2>Ortaklar</h2>
        ${(k.ortaklar || []).map(o => `<div class="kv"><span>${e(o.kad)}</span><b>%${fmt(n(o.pay), n(o.pay) % 1 ? 2 : 0)}</b></div>`).join("") || '<p class="alt">Ortak yok.</p>'}
      </div>

      <div class="kart"><h2>Genel kurul</h2>
        <p class="alt">Ortaklar paylarıyla oy kullanır. Önerge 24 saat açık kalır; payların yarısını aşan evet ya da hayır oyu sonucu hemen belirler. Tasfiye için %75 gerekir. Yeter sayı: payların dörtte biri.</p>
        ${acikKurul.map(x => kurulKart(x, k)).join("")}
        ${k.aktif && (n(k.benim_pay) >= 5 || k.yonetici_mi) ? `<button class="btn" onclick="e3KurulModal(${+k.id})">Önerge ver</button>` : ""}
        ${kapali.length ? `<div class="e3-etiket" style="margin-top:12px">Geçmiş kararlar</div>${kapali.map(x => `<div class="kv"><span>${e(x.baslik)}<span class="kucuk" style="display:block">${e(x.sonuc || "")}</span></span><b>${x.durum === "kabul" ? '<span class="rozet yesil">Kabul</span>' : '<span class="rozet">Ret</span>'}</b></div>`).join("")}` : ""}
      </div>`, { geri: true });
  }

  function kurulKart(x, k){
    const ev = Math.min(100, n(x.evet)), hy = Math.min(100 - ev, n(x.hayir));
    const oyVar = n(k.benim_pay) > 0;
    return `<div class="e3-kurul"><b>${e(x.baslik)}</b>
      <div class="kucuk">${e(x.acan || "")} önerdi · son oy ${tarihSaat(x.bit)}</div>
      <div class="e3-cubuk iki" style="margin-top:8px"><i style="width:${ev}%;background:var(--good)"></i><i style="width:${hy}%;background:var(--al2)"></i></div>
      <div class="kucuk">Evet %${fmt(n(x.evet), 1)} · Hayır %${fmt(n(x.hayir), 1)} · katılım %${fmt(n(x.katilim), 1)}${x.benim_oy != null ? ` · oyun: <b>${x.benim_oy ? "evet" : "hayır"}</b>` : ""}</div>
      ${oyVar ? `<div class="ikili"><button class="btn ${x.benim_oy === true ? "" : "ikinci"}" onclick="e3KurulOy(${+x.id},true,${+k.id})">Evet</button><button class="btn ${x.benim_oy === false ? "tehlike" : "ikinci"}" onclick="e3KurulOy(${+x.id},false,${+k.id})">Hayır</button></div>` : ""}
    </div>`;
  }

  /* --------- işlemler --------- */
  async function e3Ayarla(id, alan, deger){
    const k = E3.karne || {};
    const f = alan === "fiyat" ? deger : +k.fiyat, q = alan === "kalite" ? deger : +k.kalite;
    try {
      const t = await API.rpc("pazar_ayarla", { p_sirket: id, p_fiyat: f, p_kalite: q, p_kaynak: null });
      toast(`Kaydedildi. Haftalık net tahmini ${isaretli(t && t.net)}.`);
      sirketKarnesiEkrani(id);
    } catch (err) { toast(hataCevir(err.message), true); }
  }
  async function e3Reklam(id, seviye){
    try {
      const t = await API.rpc("sirket_reklam_ayarla", { p_sirket: id, p_seviye: seviye });
      toast(seviye ? `Reklam bütçesi açıldı. Haftalık net tahmini ${isaretli(t && t.net)}.` : "Reklam bütçesi kapatıldı.");
      sirketKarnesiEkrani(id);
    } catch (err) { toast(hataCevir(err.message), true); }
  }
  async function e3AsDonustur(id, harc){
    if (!await onayla("Anonim şirkete dönüşüm", `Şirket kasasından ${tl(harc)} tescil harcı ödenecek ve şirket A.Ş. olacak. Ardından halka arz edebilirsin.`, "Dönüştür")) return;
    try { await API.rpc("sirket_as_donustur", { p_sirket: id }); toast("Şirket artık anonim şirket."); sirketKarnesiEkrani(id); }
    catch (err) { toast(hataCevir(err.message), true); }
  }
  async function e3KurulOy(kurul, oy, sirket){
    try {
      const r = await API.rpc("genel_kurul_oy", { p_kurul: kurul, p_oy: oy });
      toast(r && r.durum === "kabul" ? "Önerge kabul edildi." : r && r.durum === "ret" ? "Önerge reddedildi." : "Oyun kaydedildi.");
      sirketKarnesiEkrani(sirket);
    } catch (err) { toast(hataCevir(err.message), true); }
  }
  function e3KurulModal(id){
    const k = E3.karne || {};
    const m = modal(`<h3 style="font-size:20px;font-weight:800">Genel kurula önerge</h3>
      <p class="alt" style="margin:6px 0 10px">${e(k.ad || "")} ortaklarına bildirim gider; 24 saat oylanır.</p>
      <div class="alan"><label>Önerge türü</label><select id="e3Tur">
        <option value="temettu">Temettü dağıtımı</option>
        <option value="yonetici">Yönetici (CEO) ataması</option>
        <option value="ad">Şirketin adını değiştir</option>
        <option value="tasfiye">Şirketi tasfiye et</option></select></div>
      <div id="e3Alan"></div>
      <button class="btn" id="e3Gonder">Önergeyi aç</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    const alanCiz = () => {
      const tur = $("#e3Tur", m).value, kutu = $("#e3Alan", m);
      kutu.innerHTML = tur === "temettu" ? `<div class="alan"><label>Dağıtılacak tutar (₺)</label><input id="e3Deger" type="number" min="1000" step="1000" placeholder="Kasa ${tl(k.kasa)}"></div><p class="kucuk">Kasanın en fazla %90'ı. Kâr payı stopajı kesilir ve hazineye gider; kalanı ortaklara pay oranında ödenir.</p>`
        : tur === "yonetici" ? `<div class="alan"><label>Yönetici olacak oyuncunun kullanıcı adı</label><input id="e3Deger" type="text" autocomplete="off" placeholder="kullanıcı adı"></div><p class="kucuk">Yönetici ortak olmak zorunda değil. Fiyat, kalite, reklam ve tür kararlarını verir; %50 ve üstü pay sahipleri yetkisini korur.</p>`
        : tur === "ad" ? `<div class="alan"><label>Yeni şirket adı</label><input id="e3Deger" type="text" maxlength="50" placeholder="3-50 karakter"></div><p class="kucuk">Gerçek şirket ve marka adları kullanılamaz.</p>`
        : `<p class="e3-not" style="color:var(--al2)">Tasfiye kabul edilirse şirket kapanır, kasa ortaklara pay oranında dağıtılır. Geri alınamaz; payların %75'inin evet oyu gerekir.</p>`;
    };
    $("#e3Tur", m).onchange = alanCiz; alanCiz();
    $("#e3Gonder", m).onclick = async () => {
      const tur = $("#e3Tur", m).value, girdi = $("#e3Deger", m), v = girdi ? girdi.value.trim() : "";
      const veri = tur === "temettu" ? { tutar: Math.round(+v || 0) } : tur === "yonetici" ? { kad: v } : tur === "ad" ? { ad: v } : {};
      if (tur !== "tasfiye" && !v) return toast("Önergenin ayrıntısını doldur.", true);
      if (tur === "tasfiye" && !await onayla("Tasfiye önergesi", "Şirketi kapatma önergesi açılacak. Emin misin?", "Önergeyi aç", true)) return;
      const b = $("#e3Gonder", m); if (b) b.disabled = true;
      try {
        const r = await API.rpc("genel_kurul_ac", { p_sirket: id, p_tur: tur, p_veri: veri });
        modalKapat();
        toast(r && r.durum === "kabul" ? "Önerge payların çoğunluğuyla hemen kabul edildi." : "Önerge açıldı; ortaklara bildirim gitti.");
        sirketKarnesiEkrani(id);
      } catch (err) { if (b) b.disabled = false; toast(hataCevir(err.message), true); }
    };
  }

  window.piyasaPanosuEkrani = piyasaPanosuEkrani;
  window.sirketKarnesiEkrani = sirketKarnesiEkrani;
  window.sirketKarnesiAc = (id) => ekranAc(() => sirketKarnesiEkrani(id));
  window.e3Ayarla = e3Ayarla; window.e3Reklam = e3Reklam; window.e3AsDonustur = e3AsDonustur;
  window.e3KurulOy = e3KurulOy; window.e3KurulModal = e3KurulModal;

  /* ===================================================================
     GİRİŞ NOKTALARI
     =================================================================== */
  // 1) Ekonomi sekmesinin en üstüne canlı piyasa kartı
  async function ekonomiGirisKarti(){
    const ic = $("#icerik"); if (!ic || ic.querySelector(".e3-giris")) return;
    const yer = ic.querySelector("section.sahne");
    const html = `<button class="e3-giris" onclick="ekranAc(piyasaPanosuEkrani)">
      <span class="sol"><span class="kucuk" style="font-weight:700">Piyasa panosu · Şirketler Endeksi</span>
        <span class="e3-orta" id="e3GirisDeger" style="display:block;margin-top:4px">…</span>
        <span class="kucuk" id="e3GirisAlt">En değerli şirketler, günlük kâr, teşvikler</span></span>
      <span class="sag" id="e3GirisSpark"></span><span class="ok">›</span></button>`;
    if (yer) yer.insertAdjacentHTML("afterend", html); else ic.insertAdjacentHTML("afterbegin", html);
    try {
      const p = E3.pano = await API.rpc("piyasa_panosu");
      const d = $("#e3GirisDeger"), a = $("#e3GirisAlt"), s = $("#e3GirisSpark");
      if (d) d.innerHTML = `${fmt(n((p.endeks || {}).deger), 2)} ${degisim((p.endeks || {}).degisim)}`;
      if (a) a.innerHTML = n((p.benim || {}).bugun) ? `Bugün şirketlerinden payın: <b style="color:${renk(p.benim.bugun)}">${isaretli(p.benim.bugun)}</b>` : `${fmt(n((p.endeks || {}).sirket))} şirket · toplam ${kisa((p.endeks || {}).toplam)}`;
      if (s) s.innerHTML = spark((p.seri || []).map(x => x.deger), { h: 44 });
    } catch (_) { const d = $("#e3GirisDeger"); if (d) d.textContent = "Piyasa panosu"; }
  }
  // 2) Ekran gözcüsü: hangi modül hangi sürümü çizerse çizsin, çizim bittikten sonra giriş noktalarını ekler
  //    (Şirketlerim / şirket portföyü / şirket detayı / eski şirket ekranı / Ekonomi sekmesi).
  function girisleriEkle(){
    const ic = document.getElementById("icerik"); if (!ic) return;
    const h1 = document.querySelector("header.ust h1");
    if (h1 && h1.textContent.trim() === "Ekonomi" && D.sekme === "ekonomi" && !ic.querySelector(".e3-giris")) ekonomiGirisKarti();
    const karneBtn = (id, metin) => `<button class="btn altin e3-karne-btn" onclick="sirketKarnesiAc(${+id})">${metin || "Şirket karnesi, kararlar ve genel kurul"}</button>`;
    // Şirket portföyü (sirket_operasyon_merkezi): her şirket kutusu
    ic.querySelectorAll('.so-firma button[onclick*="sirketPortfoyDetay("]').forEach(b => {
      const m = /sirketPortfoyDetay\((\d+)\)/.exec(b.getAttribute("onclick") || "");
      if (!m || (b.nextElementSibling && b.nextElementSibling.classList.contains("e3-karne-btn"))) return;
      b.insertAdjacentHTML("afterend", karneBtn(m[1], "Şirket karnesi ve genel kurul"));
    });
    // Şirket detayı
    const det = ic.querySelector(".so-detail");
    if (det && !det.querySelector(".e3-karne-btn")) {
      const g = det.querySelector('button[onclick^="sirketPortfoyDetay("]');
      const m = g && /sirketPortfoyDetay\((\d+)\)/.exec(g.getAttribute("onclick") || "");
      if (m) (det.querySelector(".so-buttons") || det).insertAdjacentHTML("afterbegin", karneBtn(m[1]));
    }
    // Eski "Şirketlerim" ekranı
    ic.querySelectorAll('button[onclick^="aliciBagisModal(\'sirket\',"]').forEach(b => {
      const m = /aliciBagisModal\('sirket',(\d+)/.exec(b.getAttribute("onclick") || "");
      if (!m || (b.previousElementSibling && b.previousElementSibling.classList.contains("e3-karne-btn"))) return;
      b.insertAdjacentHTML("beforebegin", karneBtn(m[1]));
    });
    ic.querySelectorAll("p.alt").forEach(p => {
      if (p.textContent.startsWith("Haftalık hesaplama:")) p.textContent = p.textContent.replace("Haftalık hesaplama:", "Sonraki günlük hesap:");
    });
  }
  let gozBekliyor = false;
  const gozcu = new MutationObserver(() => {
    if (gozBekliyor) return; gozBekliyor = true;
    requestAnimationFrame(() => { gozBekliyor = false; try { gozcu.disconnect(); girisleriEkle(); } catch (_) {} finally { baslat(); } });
  });
  function baslat(){ const app = document.getElementById("app"); if (app) gozcu.observe(app, { childList: true, subtree: true }); }
  baslat();

  // 3) Rekabetçi şirket ekranı: günlük hesaba uygun ifadeler ve karne girişi
  if (typeof window.pazarDetayEkrani === "function") {
    const eskiDetay = window.pazarDetayEkrani;
    window.pazarDetayEkrani = async function(id){
      const r = await eskiDetay.apply(this, arguments);
      try {
        const ic = $("#icerik");
        if (ic && !ic.querySelector(".e3-karne-btn")) {
          const ilk = ic.querySelector(".kart");
          if (ilk) ilk.insertAdjacentHTML("beforeend", `<button class="btn altin e3-karne-btn" onclick="sirketKarnesiAc(${+id})">Şirket karnesi ve genel kurul</button>`);
        }
        ic && ic.querySelectorAll("p, h2, th, .kucuk").forEach(el => {
          if (el.tagName === "TH" && el.textContent === "Hafta") { el.textContent = "Gün"; return; }
          if (el.children.length > 2) return;
          el.innerHTML = el.innerHTML
            .replace("Sonraki haftalık hesap", "Sonraki günlük hesap")
            .replace("Haftalık raporlar", "Günlük raporlar")
            .replace("İlk haftalık rapor bir hafta sonra çıkar.", "İlk günlük rapor bir gün sonra çıkar.")
            .replace("bir sonraki haftalık hesaba", "bir sonraki günlük hesaba");
        });
      } catch (_) {}
      return r;
    };
    try { pazarDetayEkrani = window.pazarDetayEkrani; } catch (_) {}
  }
})();
