/* 11.11.2026 · Ticaret Odaları ve İşveren Sendikaları — sunucu modülü 196.
   81 il odası + Türkiye Odalar Birliği: zorunlu üyelik, aidat, şirket başına 1 oy, başkanlık icraatları,
   sendikalar (yönetim / muhalefet), bildiri, kampanya, erken seçim imzası. Mevcut ekranlara dokunmaz. */
(function () {
  "use strict";
  if (window.SO_TICARET_ODASI_V1) return;
  window.SO_TICARET_ODASI_V1 = true;

  const rpc = (fn, a) => API.rpc(fn, a);
  // kesintisiz_ekran.js, kullanıcı eylemi olmadan gelen çizimleri erteleyebilir; seçim kutusu gibi düğme dışı eylemleri bildirir
  const eylem = () => { try { if (window.SO_KESINTISIZ) window.SO_KESINTISIZ.eylem = Date.now(); } catch (_) {} };
  const tl = x => (Number(x) || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺";
  const kv = (a, b) => `<div class="kv"><span class="k">${a}</span><span class="v">${b}</span></div>`;
  const bos = m => `<div class="bos" style="padding:10px 0">${m}</div>`;
  const kisi = k => k ? `<b>${e(k.kad)}</b>${k.unvan ? ` <span class="kucuk" style="color:var(--gold2)">${e(k.unvan)}</span>` : ""}` : "—";
  const hataEkran = (b, err) => iskelet(b, `<div class="bos">${e(hataCevir(err.message))}</div><button class="btn ikinci" onclick="yenidenCiz()">Tekrar dene</button>`, { geri: true });
  const sure = ts => kalan(new Date(ts).getTime() - simdi());
  const rozet = (yazi, renk) => `<span class="to-rozet" style="--r:${renk}">${e(yazi)}</span>`;
  const konumRozet = k => k === "yonetim" ? rozet("Yönetimde", "var(--ok,#2f9e64)") : rozet("Muhalefet", "var(--bad,#e5484d)");
  const ICRAAT_AD = { destek: "Üye destek fonu", fuar: "Ticaret fuarı", egitim: "Mesleki eğitim", rapor: "Açıklama", aidat: "Aidat kararı", il_destek: "İl odasına kaynak" };

  function stil() {
    if (document.getElementById("toStil")) return;
    const s = document.createElement("style"); s.id = "toStil";
    s.textContent = `
      .to-rozet{display:inline-block;padding:2px 8px;border-radius:999px;font-size:11.5px;font-weight:800;color:var(--r);border:1px solid var(--r);vertical-align:middle;white-space:nowrap}
      .to-gezin{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
      .to-gezin .btn{flex:1;min-width:130px;margin:0}
      .to-aday{padding:10px 0;border-bottom:1px solid var(--line2)}
      .to-aday:last-child{border-bottom:0}
      .to-aday p{margin:4px 0 8px;font-size:14.5px;line-height:1.45;overflow-wrap:anywhere}
      .to-satir{padding:8px 0;border-bottom:1px solid var(--line2);overflow-wrap:anywhere}
      .to-satir:last-child{border-bottom:0}
      .to-bar{height:8px;border-radius:6px;background:var(--panel2);overflow:hidden;margin:4px 0 2px}
      .to-bar i{display:block;height:100%;background:var(--gold)}
      .to-iki{display:flex;gap:8px;flex-wrap:wrap}
      .to-iki .btn{flex:1;min-width:130px;margin:0}
      .to-hub{padding-bottom:18px}
      .to-hub-kapak{padding:19px 17px 17px;border-radius:20px;border:1px solid rgba(92,211,192,.45);background:linear-gradient(135deg,#174a51,#1b2c4c 70%,#253254);margin-bottom:12px;box-shadow:0 12px 24px -19px #000}
      .to-hub-eyebrow{display:block;font-size:11px;font-weight:800;letter-spacing:.09em;color:#91e6d5;margin-bottom:9px}
      .to-hub-kapak h2{font-size:25px;line-height:1.2;margin:0 0 8px;color:#f5fffb}
      .to-hub-kapak p{font-size:13px;line-height:1.5;color:#d0e4ea;margin:0 0 12px}
      .to-hub-satir{display:flex;gap:8px;justify-content:space-between;align-items:center;padding:10px 0;border-top:1px solid rgba(173,244,231,.18);font-size:13px;color:#bdd9e3}
      .to-hub-satir b{color:#fff;text-align:right}
      .to-hub-buttons{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}
      .to-hub-buttons .btn{margin:0;min-width:0;padding:10px 8px}
      .to-hub-kpis{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-bottom:14px}
      .to-hub-kpis>div{min-width:0;background:linear-gradient(135deg,#21384b,#1c2a47);border:1px solid rgba(156,209,229,.22);border-radius:15px;padding:12px}
      .to-hub-kpis small{display:block;font-size:11px;color:#afc7d7;margin-bottom:5px}
      .to-hub-kpis b{font-size:20px;color:#f1f8ff;overflow-wrap:anywhere;font-variant-numeric:tabular-nums}
      .to-hub-panel{border-radius:18px;margin-bottom:12px}
      .to-hub-panel h2{font-size:20px;line-height:1.25;margin:0 0 8px}
      .to-hub-panel .btn{width:100%;margin:11px 0 0}
      .to-hub-uyari{font-size:12.5px;color:#f6dfaa;padding:10px;background:rgba(227,184,88,.10);border-radius:10px}
      #toKok .to-atla{display:flex;gap:8px;overflow-x:auto;scrollbar-width:none;margin:0 0 12px}
      #toKok .to-atla button{white-space:nowrap;flex:none;border:1px solid rgba(153,189,235,.3);color:#dce8f8;background:#202b49;border-radius:999px;padding:9px 12px;font-size:12px;font-weight:750}
      #toKok [id^="toBolum"]{scroll-margin-top:90px}`;
    document.head.appendChild(s);
  }

  /* ------------------------------------------------------------ oda ekranı */
  function secimHtml(d) {
    const s = d.secim, il = d.il, benimSirket = (d.benim.sirketler || []).filter(x => x.bu_oda);
    if (!s) {
      const ss = d.son_secim;
      let h = `<section class="kart" id="toBolumSecim"><h2>Başkanlık seçimi</h2>`;
      if (d.oda.baskan) h += `<p class="alt">Görev süresi 21 gündür. Sonraki seçim: <b>${tarihSaat(d.oda.donem_bitis)}</b> dolayında açılır.</p>`;
      else h += `<p class="alt">${d.oda.uye > 0 ? "Seçim birkaç dakika içinde kendiliğinden açılır" + (d.oda.sonraki_secim ? " (en erken " + tarihSaat(d.oda.sonraki_secim) + ")" : "") + "." : "Bu odanın henüz üyesi yok; ilk şirket kurulunca seçim açılır."}</p>`;
      if (ss) h += `<div class="kucuk" style="margin-top:6px">Son seçim (${tarihSaat(ss.bitis)}): ${(ss.sonuc || []).map(x => `${e(x.aday)}${x.sendika ? " (" + e(x.sendika) + ")" : ""} ${x.oy} oy`).join(" · ") || "aday çıkmadı"}</div>`;
      return h + `</section>`;
    }
    const adaylik = s.durum === "aday";
    let h = `<section class="kart" id="toBolumSecim"><h2>Başkanlık seçimi · ${adaylik ? "adaylık dönemi" : "oylama"}</h2>
      <p class="alt">${adaylik ? `Oylama <b>${tarihSaat(s.oy_bas)}</b> tarihinde başlar (kalan ${sure(s.oy_bas)}).` : `Oylama <b>${tarihSaat(s.oy_son)}</b> tarihinde biter (kalan ${sure(s.oy_son)}).`}
      Her şirketin 1 oyu vardır; oyu şirketin yöneticisi kullanır. En çok oyu alan kazanır.${s.neden ? " <i>" + e(s.neden) + "</i>" : ""}</p>`;
    if (!adaylik) h += `<div class="to-bar"><i style="width:${Math.min(100, Math.round(100 * s.kullanilan / Math.max(1, s.oy_hakki)))}%"></i></div><div class="kucuk">${s.kullanilan} / ${s.oy_hakki} şirket oy kullandı · sonuçlar oylama bitince açıklanır</div>`;
    h += (s.adaylar || []).map(a => `<div class="to-aday">${kisi(a)}${a.sendika ? " " + rozet(a.sendika, "var(--ink2,#a995ff)") : ""}
      <p>${e(a.vaat || "")}</p>
      ${!adaylik && benimSirket.length ? `<button class="btn ikinci" onclick="toOyVer(${il},'${e(a.kad)}')">Şirketlerimin oyunu ${e(a.kad)} için kullan</button>` : ""}</div>`).join("") || bos("Henüz aday yok.");
    if (!adaylik && benimSirket.length) {
      h += `<div class="kucuk" style="margin-top:8px"><b>Oylarım:</b> ${benimSirket.map(x => `${e(x.ad)} → ${x.oy ? e(x.oy) : (x.aidat_borc > 0 ? "aidat borcu var, oy kullanamaz" : "kullanılmadı")}`).join(" · ")}</div>`;
    }
    if (s.adayim) h += `<button class="btn tehlike" style="margin-top:10px" onclick="toAdayCekil(${il})">Adaylıktan çekil</button>`;
    else if (adaylik && d.benim.temsilci) {
      const sen = []; (d.benim.sirketler || []).forEach(x => { if (x.sendika && !sen.some(y => y.id === x.sendika.id)) sen.push(x.sendika); });
      h += `<div class="alan" style="margin-top:12px"><label for="toVaat">Seçim vaadin</label><textarea id="toVaat" maxlength="600" rows="3" placeholder="Üyelere ne vaat ediyorsun?"></textarea></div>
        ${sen.length ? `<div class="alan"><label for="toSen">Hangi sendikanın adayısın?</label><select id="toSen"><option value="">Bağımsız aday</option>${sen.map(x => `<option value="${x.id}">${e(x.ad)}</option>`).join("")}</select></div>` : ""}
        <button class="btn altin" onclick="toAdayOl(${il})">Başkanlığa aday ol</button>`;
    } else if (adaylik) h += `<p class="kucuk" style="margin-top:8px">Aday olmak için ${d.ulusal ? "bir ticaret odasına" : "bu odaya"} üye faal bir şirketin yöneticisi olmalısın.</p>`;
    return h + `</section>`;
  }

  function masaHtml(d) {
    if (!d.benim.baskan) return "";
    const turler = d.ulusal
      ? [["destek", "Üye destek fonu (bütün üyelere eşit)"], ["fuar", "Türkiye Ticaret Fuarı (üyesi olan illerde gelişim)"], ["il_destek", "Bir il odasına kaynak aktar"], ["rapor", "Başkanlık açıklaması yayımla"]]
      : [["destek", "Üye destek fonu (aidat borcu olmayanlara eşit)"], ["fuar", "Ticaret fuarı (il gelişimi)"], ["egitim", "Mesleki eğitim (il memnuniyeti)"], ["aidat", "Haftalık aidatı belirle"], ["rapor", "Başkanlık açıklaması yayımla"]];
    return `<section class="kart" id="toBolumMasa" style="border:2px solid var(--gold)"><h2>Başkanlık masası</h2>
      <p class="alt">Oda kasası: <b>${tl(d.oda.kasa)}</b>. Fuar ve eğitim 48 saatte bir yapılır; harcamanın %20'si KDV olarak Hazine'ye gider. Oda kasasından kişilere ödeme yapılamaz.</p>
      <div class="alan"><label for="toTur">İcraat</label><select id="toTur" onchange="toIcraatAlan()">${turler.map(x => `<option value="${x[0]}">${x[1]}</option>`).join("")}</select></div>
      <div class="alan" id="toTutarK"><label for="toTutar">Tutar (₺)</label><input id="toTutar" type="number" inputmode="numeric" min="0" step="1000"></div>
      <div class="alan" id="toHedefK" hidden><label for="toHedef">İl odası</label><select id="toHedef">${(d.iller || []).filter(x => x.il_id !== 0).map(x => `<option value="${x.il_id}">${e(x.ad)} (${x.uye} üye)</option>`).join("")}</select></div>
      <div class="alan" id="toMetinK" hidden><label for="toMetin">Açıklama metni</label><textarea id="toMetin" maxlength="1500" rows="4"></textarea></div>
      <p class="kucuk" id="toIpucu"></p>
      <button class="btn altin" onclick="toIcraatYap(${d.il})">İcraatı uygula</button></section>`;
  }
  const IPUCU = {
    destek: "En az 10.000 ₺. Tutar, aidat borcu olmayan üye şirketlerin kasasına eşit paylaştırılır.",
    fuar: "İl odası: 50.000–2.000.000 ₺ (500.000 ₺ ≈ +0,30 gelişim). Birlik: 500.000–10.000.000 ₺, üyesi olan her ilde gelişim artar.",
    egitim: "50.000–2.000.000 ₺ (400.000 ₺ ≈ +0,30 memnuniyet). Aynı hafta içinde tekrarlanan organizasyonun etkisi azalır.",
    aidat: "Şirket başına haftalık 500–25.000 ₺. Haftada bir kez değiştirilebilir; aidatın %25'i Birliğe gider.",
    il_destek: "En az 10.000 ₺. Birlik kasasından seçtiğin il odasının kasasına aktarılır.",
    rapor: "En az 20 karakter. Günde bir açıklama; Gündem'de yayımlanır."
  };
  window.toIcraatAlan = function () {
    const t = ($("#toTur") || {}).value;
    const g = (id, goster) => { const el = document.getElementById(id); if (el) el.hidden = !goster; };
    g("toTutarK", t !== "rapor"); g("toMetinK", t === "rapor"); g("toHedefK", t === "il_destek");
    const ip = $("#toIpucu"); if (ip) ip.textContent = IPUCU[t] || "";
  };

  /* ------------------------------------------------------------ Ekonomi: öne çıkan Ticaret Odası kartı (60 sn önbellek) */
  let ozetOn = { t: 0, d: null };
  function ekonomiKartVeri(d) {
    const o = { id: "toEkonomiKart", ikon: "oda", renk: "47,158,143", acik: "#8fe6d8", etiket: "Ticaret Odası", git: "Aç", onclick: "ekranAc(function(){return ticaretOdasiEkrani()})" };
    if (!d) { o.baslik = "Oda seçimleri ve işveren sendikaları"; o.alt = "Şirketlerin odanın üyesi: şirket başına 1 oyla başkanı seçersin, aday olabilirsin."; return o; }
    o.etiket = d.ad; o.onclick = "ekranAc(function(){return ticaretOdasiEkrani(" + Number(d.il) + ")})";
    const s = d.secim, benim = Number(d.sirketim) > 0;
    if (Number(d.aidat_borc) > 0) { o.baslik = "Aidat borcun var: " + tl(d.aidat_borc); o.alt = "Borçlu şirket oy kullanamaz; şirket kasasından ödeyebilirsin."; o.git = "Öde"; }
    else if (s && s.durum === "oy" && Number(d.oy_bekleyen) > 0) { o.baslik = `Oylama sürüyor: ${d.oy_bekleyen} oyun bekliyor`; o.alt = `${s.aday} aday · oylama ${tarihSaat(s.oy_son)} tarihinde biter.`; o.git = "Oy ver"; }
    else if (s && s.durum === "oy") { o.baslik = "Başkanlık oylaması sürüyor"; o.alt = `${s.aday} aday · oylama ${tarihSaat(s.oy_son)} tarihinde biter.`; }
    else if (s && s.durum === "aday") {
      o.baslik = s.adayim ? "Başkan adayısın" : "Başkanlık seçimi: adaylık açık";
      o.alt = `${s.aday} aday · oylama ${tarihSaat(s.oy_bas)} tarihinde başlar${!s.adayim && benim ? " · aday olabilirsin" : ""}.`;
      o.git = !s.adayim && benim ? "Aday ol" : "Aç";
    }
    else if (d.baskanim) { o.baslik = "Oda başkanısın"; o.alt = "Oda kasasıyla icraat yap: destek fonu, fuar, mesleki eğitim."; o.git = "Masam"; }
    else {
      o.baslik = d.baskan ? "Başkan " + d.baskan : "Başkan henüz seçilmedi";
      o.alt = (benim ? `${d.sirketim} şirketin üye · ${d.oy_hakki} oy hakkın var` : `${d.uye} üye şirket · şirket kurunca otomatik üye olursun`) + " · işveren sendikaları.";
    }
    return o;
  }
  const ekonomide = () => { try { const h = document.querySelector("header.ust h1"); return D.sekme === "ekonomi" && !(D.yigin || []).length && !!h && h.textContent.trim() === "Ekonomi"; } catch (_) { return false; } };
  function ekonomiKartKoy(d) {
    if (!window.SO_ONE_CIKAN || !ekonomide()) return;
    window.SO_ONE_CIKAN.koy(ekonomiKartVeri(d), ic => {
      const k = ic.querySelector(":scope > .so-ekonomi"); if (k) return { el: k, yer: "beforebegin" };
      return { el: ic, yer: "afterbegin" };
    });
  }
  async function ekonomiKart() {
    try {
      if (!window.SO_ONE_CIKAN) return;
      window.SO_ONE_CIKAN.tekrarla(() => ekonomiKartKoy(ozetOn.d));
      if (ozetOn.d && Date.now() - ozetOn.t < 60000) return;
      ozetOn = { t: Date.now(), d: ozetOn.d };
      const d = await rpc("oda_ozet"); ozetOn = { t: Date.now(), d }; ekonomiKartKoy(d);
    } catch (_) {}
  }
  function ekonomiBagla() {
    const asil = window.ekonomiSekmeEkrani;
    if (typeof asil !== "function") return false;
    if (asil._to) return true;
    const yeni = async function () { const r = await asil.apply(this, arguments); ekonomiKart(); return r; };
    Object.keys(asil).forEach(k => { yeni[k] = asil[k]; });      // diğer katmanların "bağlandım" işaretleri korunur
    yeni._to = true;
    window.ekonomiSekmeEkrani = yeni;
    return true;
  }
  if (!ekonomiBagla()) setTimeout(ekonomiBagla, 1500);

  window.odaSekmeHtml = async function () {
  stil();
  let d;
  try {
    d = await rpc("oda_ozet");
  } catch (err) {
    return `<section class="kart"><h2>Ticaret Odası</h2><p class="alt">${e(hataCevir(err.message))}</p>
      <button type="button" class="btn ikinci" onclick="ekranAc(function(){return ticaretOdasiEkrani()})">Ayrıntılı odayı aç</button></section>`;
  }
  const il = Number((d || {}).il) || Number((D.durum || {}).profil?.il_id) || 6;
  const ad = (d || {}).ad || "İl Ticaret Odası";
  const s = (d || {}).secim;
  const birlik = (d || {}).birlik;
  const n = x => (Number(x) || 0).toLocaleString("tr-TR");
  const odaAc = bolum => `ekranAc(function(){return ticaretOdasiEkrani(${il},'${bolum}')})`;
  const birlikAc = `ekranAc(function(){return ticaretOdasiEkrani(0)})`;
  const secimBas = !s ? "Seçim takvimini incele" : s.durum === "aday" ? "Başkanlık adaylığı açık" : "Başkanlık oylaması sürüyor";
  const secimAcik = !s
    ? "Adaylık, oylama, geçmiş sonuçlar ve erken seçim işlemleri oda ekranında."
    : s.durum === "aday"
      ? `${n(s.aday)} aday · Oylama ${tarihSaat(s.oy_bas)} tarihinde başlayacak.`
      : `${n(s.aday)} aday · Oylama ${tarihSaat(s.oy_son)} tarihinde sona erecek.`;
  const secimDugme = s && s.durum === "aday" && Number(d.sirketim) ? "Adaylık işlemlerine git"
    : s && s.durum === "oy" && Number(d.oy_bekleyen) ? "Oylarımı kullan" : "Seçim ekranını aç";
  const borc = Number((d || {}).aidat_borc) || 0;
  return `<div class="to-hub">
    <section class="to-hub-kapak">
      <span class="to-hub-eyebrow">TİCARET ODALARI · 81 İL VE TÜRKİYE ODALAR BİRLİĞİ</span>
      <h2>${e(ad)}</h2>
      <p>Şirketlerin oda üyeliğini, seçimleri, oda başkanlığını ve işveren sendikalarını buradan yönet.</p>
      <div class="to-hub-satir"><span>Oda başkanı</span><b>${e((d || {}).baskan || "Henüz seçilmedi")}</b></div>
      <div class="to-hub-buttons">
        <button type="button" class="btn altin" onclick="${odaAc("oda")}">İl odamı aç</button>
        <button type="button" class="btn ikinci" onclick="${birlikAc}">Odalar Birliği</button>
      </div>
    </section>
    <div class="to-hub-kpis">
      <div><small>Üye şirket</small><b>${n((d || {}).uye)}</b></div>
      <div><small>Şirketlerim</small><b>${n((d || {}).sirketim)}</b></div>
      <div><small>Oy hakkım</small><b>${n((d || {}).oy_hakki)}</b></div>
      <div><small>Haftalık aidat</small><b>${tl((d || {}).aidat)}</b></div>
    </div>
    <section class="kart to-hub-panel">
      <span class="to-hub-eyebrow">SEÇİM VE DEMOKRASİ</span>
      <h2>${e(secimBas)}</h2><p class="alt">${e(secimAcik)}</p>
      ${(d || {}).baskanim ? '<p class="to-hub-uyari">Oda başkanı sensin. Başkanlık masasında destek fonu, fuar, eğitim ve aidat kararlarını yönetebilirsin.</p>' : ""}
      <button type="button" class="btn altin" onclick="${odaAc("secim")}">${secimDugme}</button>
    </section>
    <section class="kart to-hub-panel">
      <span class="to-hub-eyebrow">ŞİRKETLER VE AİDATLAR</span>
      <h2>${borc ? "Ödenmemiş oda aidatı" : "Şirket üyeliklerim"}</h2>
      <p class="alt">${borc
        ? `${tl(borc)} borç bulunuyor. Borçlu şirketler oda seçimlerinde oy kullanamaz; borcu şirket kasasından ödeyebilirsin.`
        : Number((d || {}).sirketim) ? `${n(d.sirketim)} şirketin oda kaydında. Aidatları, temsil ve oy haklarını ayrıntılı gör.` : "Şirketin bulunmuyorsa, kurduğun faal şirket merkez ilinin odasına otomatik kaydedilir."}</p>
      <button type="button" class="btn ikinci" onclick="${odaAc("sirket")}">${borc ? "Aidat borçlarını öde" : "Şirket kayıtlarını incele"}</button>
    </section>
    <section class="kart to-hub-panel">
      <span class="to-hub-eyebrow">İŞVEREN SENDİKALARI</span>
      <h2>Sendikalar ve oda yönetimi</h2>
      <p class="alt">Sendika kur veya katıl, bildiri yayımla, oda başkanlığına aday göster, gerektiğinde erken seçim için imza topla.</p>
      <button type="button" class="btn ikinci" onclick="${odaAc("sendika")}">Sendikaları aç</button>
    </section>
    <section class="kart to-hub-panel">
      <span class="to-hub-eyebrow">TÜRKİYE ODALAR BİRLİĞİ</span>
      <h2>${e((d || {}).birlik_baskan || "Birlik başkanlığı")}</h2>
      <p class="alt">${birlik
        ? `Birlik seçiminde ${n(birlik.aday)} aday var. ${birlik.durum === "aday" ? "Adaylık devam ediyor." : "Oylama devam ediyor."}`
        : "İl odalarının çatı kuruluşunda başkanlık seçimi, ulusal fuar, kaynak aktarımı ve sendika faaliyetlerini incele."}</p>
      <button type="button" class="btn ikinci" onclick="${birlikAc}">Türkiye Odalar Birliğini aç</button>
    </section>
  </div>`;
};

  window.ticaretOdasiEkrani = async function (il, bolum) {
    stil();
    if (il === undefined && D._toIl !== undefined) il = D._toIl;
    if (il === undefined) il = null;
    if (!document.getElementById("toKok")) yukleniyor("Ticaret Odası");
    let d; try { d = await rpc("oda_panel", { p_il: il }); } catch (err) { return hataEkran("Ticaret Odası", err); }
    D._toIl = d.il;
    const o = d.oda, benim = d.benim.sirketler || [], evIl = (benim[0] || {}).il_id || (D.durum && D.durum.profil && D.durum.profil.il_id) || 6;
    const borclu = benim.filter(x => x.aidat_borc > 0);
    iskelet(d.ulusal ? "Odalar Birliği" : "Ticaret Odası", `<div id="toKok">
      <nav class="to-atla" aria-label="Ticaret odası bölümleri"><button type="button" onclick="toAtla('oda')">Oda</button><button type="button" onclick="toAtla('sirket')">Şirketler</button><button type="button" onclick="toAtla('secim')">Seçimler</button><button type="button" onclick="toAtla('masa')">Başkanlık</button><button type="button" onclick="toAtla('sendika')">Sendikalar</button></nav>
      <div class="to-gezin">
        <button class="btn ${d.ulusal ? "ikinci" : "altin"}" onclick="ticaretOdasiEkrani(${evIl})">İl odam</button>
        <button class="btn ${d.ulusal ? "altin" : "ikinci"}" onclick="ticaretOdasiEkrani(0)">Türkiye Odalar Birliği</button>
      </div>
      <section class="kart" id="toBolumOda"><h2>${e(d.ad)}</h2>
        <p class="alt">${d.ulusal ? "81 il odasının çatı kuruluşu. Bütün şirketler üyesidir; il odalarına ödenen aidatın %25'i Birlik kasasına gelir." : "Bu ildeki bütün faal şirketler odanın zorunlu üyesidir. Aidat her hafta şirket kasasından alınır."}</p>
        ${kv("Başkan", o.baskan ? kisi(o.baskan) + (o.baskan_sendika ? " " + rozet(o.baskan_sendika.ad, "var(--ink2,#a995ff)") : "") : "Seçilmedi")}
        ${kv("Üye şirket", o.uye + (o.borclu > 0 ? ` <span class="kucuk">(${o.borclu} aidat borçlu)</span>` : ""))}
        ${kv("Oda kasası", "<b>" + tl(o.kasa) + "</b>")}
        ${d.ulusal ? "" : kv("Haftalık aidat (şirket başına)", tl(o.aidat))}
        ${kv("Bugüne kadar toplanan / harcanan", tl(o.toplam_aidat) + " / " + tl(o.toplam_harcama))}
        ${(d.iller || []).length > 1 ? `<div class="alan" style="margin-top:10px"><label for="toIlSec">Başka bir odaya bak</label><select id="toIlSec" onchange="toIlDegis(this.value)">
          ${d.iller.map(x => `<option value="${x.il_id}" ${x.il_id === d.il ? "selected" : ""}>${e(x.ad)} · ${x.uye} üye${x.baskan ? " · " + e(x.baskan) : ""}</option>`).join("")}</select></div>` : ""}
      </section>
      ${benim.length ? `<section class="kart" id="toBolumSirket"><h2>Şirketlerim</h2>${benim.map(x => `<div class="to-satir"><b>${e(x.ad)}</b> <span class="kucuk">${e(x.il || "")} Ticaret Odası${x.sendika ? " · " + e(x.sendika.ad) : " · sendikasız"}</span>
          ${x.aidat_borc > 0 ? `<div class="kucuk" style="color:var(--bad)">Aidat borcu ${tl(x.aidat_borc)} · oy kullanamaz</div><button class="btn ikinci" onclick="toAidatOde(${x.id})">Aidat borcunu şirket kasasından öde</button>` : ""}</div>`).join("")}
          ${borclu.length ? "" : `<p class="kucuk" style="margin-top:6px">Aidat borcun yok; ${benim.filter(x => x.bu_oda).length} oy hakkın var.</p>`}</section>`
        : `<section class="kart"><p class="alt">Yöneticisi olduğun faal bir şirket yok. Şirket kurduğunda merkez ilinin odasına kendiliğinden kaydolur; şirket başına 1 oy hakkın olur.</p></section>`}
      ${secimHtml(d)}
      ${masaHtml(d)}
      ${o.baskan && !d.secim ? `<section class="kart"><h2>Erken seçim talebi</h2>
        <p class="alt">Üye şirketlerin yarısından fazlası imzalarsa başkanlık seçimi hemen açılır (başkan en az 5 gündür görevdeyse).</p>
        <div class="to-bar"><i style="width:${Math.min(100, Math.round(100 * d.imza.sayi / Math.max(1, d.imza.gereken)))}%"></i></div>
        <div class="kucuk">${d.imza.sayi} imza · gereken ${d.imza.gereken}</div>
        ${benim.some(x => x.bu_oda && !x.imza) ? `<button class="btn ikinci" style="margin-top:8px" onclick="toImza(${d.il})">Şirketlerimle imza at</button>` : ""}</section>` : ""}
      <section class="kart"><h2>İcraatlar</h2>${(d.icraatlar || []).map(x => `<div class="to-satir"><b>${e(ICRAAT_AD[x.tur] || x.tur)}</b> <span class="kucuk">${tarihSaat(x.zaman)} · ${e(x.yapan || "")}${x.tutar > 0 ? " · " + tl(x.tutar) : ""}</span>
        <div class="kucuk">${e(x.baslik)}</div>${x.metin ? `<p style="margin:4px 0 0;font-size:14.5px;overflow-wrap:anywhere">${e(x.metin)}</p>` : ""}</div>`).join("") || bos("Henüz icraat yok.")}</section>
      <section class="kart"><h2>Sendikalardan</h2>${(d.bildiriler || []).map(b => `<div class="to-satir"><b>${e(b.baslik)}</b> ${konumRozet(b.konum)}
        <div class="kucuk">${e(b.sendika)} · ${e(b.yazar || "")} · ${tarihSaat(b.zaman)}${b.tur === "kampanya" ? " · kampanya" : ""}</div>
        <p style="margin:4px 0 0;font-size:14.5px;line-height:1.45;overflow-wrap:anywhere">${e(b.metin)}</p></div>`).join("") || bos("Bu odaya yönelik sendika bildirisi yok.")}</section>
      <section class="kart" id="toBolumSendika"><h2>İşveren sendikaları</h2>
        <p class="alt">Şirketler serbestçe sendikalaşır (şirket başına tek sendika). Sendikalar oda seçimlerinde aday çıkarır; Birlik başkanlığını alamayanlar muhalefette kalır.</p>
        ${(d.sendikalar || []).map(s => `<button class="giris-satir" onclick="ekranAc(()=>sendikaEkrani(${s.id}))"><span class="orta"><b>${e(s.ad)}</b> ${konumRozet(s.konum)}<span class="kucuk">${s.uye} üye şirket · başkan ${e(s.baskan || "—")}${s.aidat > 0 ? " · aidat " + tl(s.aidat) + "/hafta" : ""}</span></span><span class="ok">›</span></button>`).join("") || bos("Henüz sendika kurulmadı.")}
        ${benim.some(x => !x.sendika) ? `<button class="btn ikinci" style="margin-top:10px" onclick="toSendikaKur()">İşveren sendikası kur (50.000 ₺)</button>` : ""}</section>
      <section class="kart"><details><summary><b>Üye şirketler (${o.uye})</b></summary>${(d.uyeler || []).map(u => `<div class="to-satir">${e(u.ad)} <span class="kucuk">${u.il ? e(u.il) + " · " : ""}${e(u.yonetici || "")}${u.sendika ? " · " + e(u.sendika) : ""}${u.borclu ? " · aidat borçlu" : ""}</span></div>`).join("") || bos("Üye yok.")}</details></section>
    </div>`, { geri: D.yigin.length > 0 });
    window._toPanel = d;
    if (bolum) setTimeout(() => window.toAtla(bolum), 80);
    if (d.benim.baskan) window.toIcraatAlan();
    if (d.secim) {                                    // geri sayım ve durum geçişi için hafif tazeleme
      const taz = async () => { if (!document.getElementById("toKok") || document.hidden || $("#modal")) return; const ta = $("#toVaat"); if (ta && ta.value.trim()) return; try { await window.ticaretOdasiEkrani(d.il); } catch (_) {} };
      D.canli = setInterval(taz, 60000);
    }
  };

  window.toAtla = function (bolum) {
    const ids = { oda:"toBolumOda", sirket:"toBolumSirket", secim:"toBolumSecim", masa:"toBolumMasa", sendika:"toBolumSendika" };
    const el = document.getElementById(ids[bolum] || ids.oda) || document.getElementById("toKok");
    if (el) el.scrollIntoView({ behavior:"smooth", block:"start" });
  };
  window.toIlDegis = v => { eylem(); return window.ticaretOdasiEkrani(Number(v)); };
  const calis = async (fn, basari, il) => { try { const r = await fn(); ozetOn.t = 0; if (basari) toast(typeof basari === "function" ? basari(r) : basari); await window.ticaretOdasiEkrani(il); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.toAdayOl = il => { const v = ($("#toVaat") || {}).value || "", s = ($("#toSen") || {}).value; return calis(() => rpc("oda_aday_ol", { p_il: il, p_vaat: v.trim(), p_sendika: s ? Number(s) : null }), "Adaylığın açıklandı.", il); };
  window.toAdayCekil = async il => { if (!await onayla("Adaylıktan çekil", "Adaylığın ve sana verilen oylar silinir.", "Çekil", true)) return; return calis(() => rpc("oda_aday_cekil", { p_il: il }), "Adaylıktan çekildin.", il); };
  window.toOyVer = (il, kad) => calis(() => rpc("oda_oy_ver", { p_il: il, p_aday: kad, p_sirket: null }), r => `${r.oy_sayisi} şirketinin oyu kullanıldı.${r.borclu_atlanan ? " " + r.borclu_atlanan + " şirket aidat borcu nedeniyle oy kullanamadı." : ""}`, il);
  window.toAidatOde = id => calis(() => rpc("oda_aidat_ode", { p_sirket: id }), r => `${tl(r.odenen)} ödendi.${r.kalan > 0 ? " Kalan borç " + tl(r.kalan) + "." : ""}`, D._toIl);
  window.toImza = il => calis(() => rpc("oda_erken_secim_imza", { p_il: il, p_sirket: null }), r => r.secim_acildi ? "Çoğunluk sağlandı; seçim açıldı." : `${r.imzalanan} şirketinle imza attın.`, il);
  window.toIcraatYap = async il => {
    const t = $("#toTur").value, tutar = Number(($("#toTutar") || {}).value) || null, metin = (($("#toMetin") || {}).value || "").trim(), hedef = Number(($("#toHedef") || {}).value) || null;
    if (t !== "rapor" && !(tutar > 0)) return toast("Tutar gir.", true);
    if (t !== "rapor" && !await onayla(ICRAAT_AD[t] || "İcraat", t === "aidat" ? `Haftalık aidat ${tl(tutar)} olacak.` : `${tl(tutar)} oda kasasından harcanacak.`, "Uygula")) return;
    return calis(() => rpc("oda_icraat", { p_il: il, p_tur: t, p_tutar: t === "rapor" ? null : tutar, p_metin: t === "rapor" ? metin : null, p_hedef: t === "il_destek" ? hedef : null }), "İcraat uygulandı.", il);
  };
  window.toSendikaKur = function () {
    const sir = ((window._toPanel || {}).benim || {}).sirketler || [], uygun = sir.filter(x => !x.sendika);
    if (!uygun.length) return toast("Sendikasız bir şirketin yok.", true);
    const m = modal(`<h3 style="font-size:19px;font-weight:800">İşveren sendikası kur</h3>
      <p class="alt" style="margin-top:6px">Kuruluş harcı 50.000 ₺ seçtiğin şirketin kasasından ödenir; şirket ilk üye, sen başkan olursun.</p>
      <div class="alan"><label for="skSir">Kurucu şirket</label><select id="skSir">${uygun.map(x => `<option value="${x.id}">${e(x.ad)}</option>`).join("")}</select></div>
      <div class="alan"><label for="skAd">Sendika adı</label><input id="skAd" maxlength="60" placeholder="ör. Anadolu İşverenler Sendikası"></div>
      <div class="alan"><label for="skAmac">Amaç (isteğe bağlı)</label><textarea id="skAmac" maxlength="300" rows="2"></textarea></div>
      <button class="btn altin" id="skKur">Sendikayı kur</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    $("#skKur", m).onclick = async () => {
      try { const r = await rpc("sendika_kur", { p_sirket: Number($("#skSir", m).value), p_ad: $("#skAd", m).value.trim(), p_amac: $("#skAmac", m).value.trim() });
        modalKapat(); toast("Sendika kuruldu."); ekranAc(() => window.sendikaEkrani(r.id)); }
      catch (err) { toast(hataCevir(err.message), true); }
    };
  };

  /* ------------------------------------------------------------ sendika ekranı */
  window.sendikaEkrani = async function (id) {
    stil();
    if (!document.getElementById("sdKok")) yukleniyor("İşveren sendikası");
    let d, od; try { d = await rpc("sendika_panel", { p_sendika: id }); } catch (err) { return hataEkran("İşveren sendikası", err); }
    try { od = window._toPanel || await rpc("oda_panel", { p_il: 0 }); } catch (_) { od = { iller: [] }; }
    const sir = d.sirketlerim || [], katilabilir = sir.filter(x => !x.sendika_id), buradaki = sir.filter(x => x.sendika_id === d.id);
    const odalar = [{ il_id: 0, ad: "Türkiye Odalar Birliği" }].concat((od.iller || []).filter(x => x.il_id !== 0));
    iskelet("İşveren sendikası", `<div id="sdKok">
      <section class="kart"><h2>${e(d.ad)} ${d.kapali ? rozet("Kapandı", "var(--mut)") : konumRozet(d.konum)}</h2>
        ${d.amac ? `<p class="alt">${e(d.amac)}</p>` : ""}
        ${kv("Başkan", kisi(d.baskan))}${kv("Üye şirket", (d.uyeler || []).length)}${kv("Haftalık sendika aidatı", d.aidat > 0 ? tl(d.aidat) : "Yok")}
        ${d.kasa != null ? kv("Sendika kasası", "<b>" + tl(d.kasa) + "</b>") : ""}
        ${(d.odalar || []).length ? kv("Başkanlığını kazandığı odalar", d.odalar.map(e).join(", ")) : ""}
        <p class="kucuk" style="margin-top:6px">${d.konum === "yonetim" ? "Bu sendikanın adayı Türkiye Odalar Birliği başkanı." : "Birlik yönetiminde değil: bildiri ve kampanyayla muhalefet yapar, erken seçim için imza toplar."}</p></section>
      ${!d.kapali && (katilabilir.length || buradaki.length) ? `<section class="kart"><h2>Şirketlerim</h2>
        ${buradaki.map(x => `<div class="to-satir"><b>${e(x.ad)}</b> <span class="kucuk">üye</span><button class="btn ikinci" onclick="sdAyril(${x.id},${d.id})">Sendikadan ayrıl</button></div>`).join("")}
        ${katilabilir.map(x => `<div class="to-satir"><b>${e(x.ad)}</b> <span class="kucuk">sendikasız</span><button class="btn altin" onclick="sdKatil(${d.id},${x.id})">Bu şirketi üye yap</button></div>`).join("")}</section>` : ""}
      ${d.baskanim ? `<section class="kart" style="border:2px solid var(--gold)"><h2>Başkanlık</h2>
        <div class="alan"><label for="sdTur">İşlem</label><select id="sdTur" onchange="sdAlan()">
          <option value="bildiri">Bildiri yayımla (ücretsiz, günde 1)</option><option value="kampanya">Kampanya yap (oda üyelerine bildirim, en az 25.000 ₺)</option>
          <option value="aidat">Haftalık sendika aidatını belirle</option><option value="devret">Başkanlığı devret</option></select></div>
        <div id="sdYazi"><div class="alan"><label for="sdOda">Hangi odaya yönelik?</label><select id="sdOda">${odalar.map(x => `<option value="${x.il_id}">${e(x.ad)}</option>`).join("")}</select></div>
          <div class="alan"><label for="sdBaslik">Başlık</label><input id="sdBaslik" maxlength="90"></div>
          <div class="alan"><label for="sdMetin">Metin</label><textarea id="sdMetin" maxlength="1500" rows="4"></textarea></div></div>
        <div class="alan" id="sdTutarK" hidden><label for="sdTutar" id="sdTutarL">Tutar (₺)</label><input id="sdTutar" type="number" inputmode="numeric" min="0" step="500"></div>
        <div class="alan" id="sdKadK" hidden><label for="sdKad">Yeni başkanın kullanıcı adı (üye şirket yöneticisi)</label><input id="sdKad" autocapitalize="off"></div>
        <button class="btn altin" onclick="sdIslem(${d.id})">Uygula</button></section>` : ""}
      <section class="kart"><h2>Üye şirketler</h2>${(d.uyeler || []).map(u => `<div class="to-satir">${e(u.ad)} <span class="kucuk">${e(u.il || "")} · ${e(u.yonetici || "")}</span></div>`).join("") || bos("Üye yok.")}</section>
      <section class="kart"><h2>Bildiriler ve kampanyalar</h2>${(d.bildiriler || []).map(b => `<div class="to-satir"><b>${e(b.baslik)}</b>
        <div class="kucuk">${e(b.oda)} · ${tarihSaat(b.zaman)}${b.tur === "kampanya" ? " · kampanya " + tl(b.tutar) : ""}</div>
        <p style="margin:4px 0 0;font-size:14.5px;line-height:1.45;overflow-wrap:anywhere">${e(b.metin)}</p></div>`).join("") || bos("Henüz bildiri yok.")}</section>
      ${(d.hareketler || []).length ? `<section class="kart"><details><summary><b>Kasa hareketleri</b></summary>${d.hareketler.map(h => kv(e(h.aciklama || "") + " · " + tarihSaat(h.zaman), tl(h.tutar))).join("")}</details></section>` : ""}
    </div>`, { geri: true });
    if (d.baskanim) window.sdAlan();
  };
  window.sdAlan = function () {
    const t = ($("#sdTur") || {}).value, g = (id, v) => { const el = document.getElementById(id); if (el) el.hidden = !v; };
    g("sdYazi", t === "bildiri" || t === "kampanya"); g("sdTutarK", t === "kampanya" || t === "aidat"); g("sdKadK", t === "devret");
    const l = $("#sdTutarL"); if (l) l.textContent = t === "aidat" ? "Haftalık aidat (₺, 0–10.000; 0 = aidat yok)" : "Kampanya bütçesi (₺)";
  };
  const sdCalis = async (fn, basari, id) => { try { await fn(); toast(basari); window._toPanel = null; await window.sendikaEkrani(id); } catch (err) { toast(hataCevir(err.message), true); } };
  window.sdKatil = (sid, sirket) => sdCalis(() => rpc("sendika_katil", { p_sendika: sid, p_sirket: sirket }), "Şirketin sendikaya üye oldu.", sid);
  window.sdAyril = async (sirket, sid) => { if (!await onayla("Sendikadan ayrıl", "Şirketin bu sendikadan ayrılacak.", "Ayrıl", true)) return; return sdCalis(() => rpc("sendika_ayril", { p_sirket: sirket }), "Şirketin sendikadan ayrıldı.", sid); };
  window.sdIslem = function (id) {
    const t = $("#sdTur").value; let veri = {};
    if (t === "bildiri" || t === "kampanya") veri = { il: Number($("#sdOda").value), baslik: $("#sdBaslik").value.trim(), metin: $("#sdMetin").value.trim(), tutar: Number(($("#sdTutar") || {}).value) || 0 };
    else if (t === "aidat") veri = { aidat: Number($("#sdTutar").value) || 0 };
    else veri = { kad: $("#sdKad").value.trim() };
    return sdCalis(() => rpc("sendika_islem", { p_sendika: id, p_islem: t, p_veri: veri }), "İşlem tamamlandı.", id);
  };
})();
