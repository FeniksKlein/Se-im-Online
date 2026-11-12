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

  const KX = () => window.SO_KX;
  const n = x => (Number(x) || 0).toLocaleString("tr-TR");
  const virgul = x => String(Math.round((Number(x) || 0) * 1000) / 1000).replace(".", ",");
  const ton = s => (KX() ? KX().ton(s) : 170);
  const harf = s => (KX() ? KX().harfler(s, 2) : "?");
  const plaka = il => Number(il) === 0 ? "TR" : String(Number(il) || 0).padStart(2, "0");
  let muhurNo = 0;
  // oda mührü: il plaka kodu ortada, oda adı çevresinde
  function muhur(il, ad, boy) {
    const id = "toM" + (++muhurNo), yazi = String(ad || "Ticaret Odası").toLocaleUpperCase("tr-TR");
    const tekrar = yazi.length < 26 ? yazi + "  •  " + yazi + "  •  " : yazi + "  •  ";
    return `<svg class="tox-muhur" viewBox="0 0 100 100" width="${boy || 74}" height="${boy || 74}" aria-hidden="true"><defs><path id="${id}" d="M50,50 m-37,0 a37,37 0 1,1 74,0 a37,37 0 1,1 -74,0"/></defs>
      <circle cx="50" cy="50" r="48" fill="rgba(217,178,106,.10)" stroke="currentColor" stroke-width="2"/><circle cx="50" cy="50" r="28" fill="none" stroke="currentColor" stroke-width="1.2" stroke-dasharray="1.5 2.5"/>
      <text font-size="7.4" font-weight="700" fill="currentColor"><textPath href="#${id}" textLength="228" lengthAdjust="spacing">${e(tekrar)}</textPath></text>
      <text x="50" y="${Number(il) === 0 ? 58 : 59}" text-anchor="middle" font-size="${Number(il) === 0 ? 22 : 25}" font-weight="700" fill="currentColor" style="font-family:var(--disp)">${plaka(il)}</text></svg>`;
  }
  const harfRozet = (ad, renkAd) => `<span class="tox-harf" style="--h:${ton(renkAd || ad)}" aria-hidden="true">${e(harf(ad))}</span>`;

  function stil() {
    if (KX()) KX().stil();
    if (document.getElementById("toStil")) return;
    const s = document.createElement("style"); s.id = "toStil";
    s.textContent = `
      .to-rozet{display:inline-block;padding:2px 8px;border-radius:999px;font-size:11.5px;font-weight:800;color:var(--r);border:1px solid var(--r);vertical-align:middle;white-space:nowrap}
      .tox{--kx:#2F9E8F;--pirinc:#D9B26A}
      .tox .bos{padding:12px 2px;color:var(--mut)}
      .tox-muhur{flex:none;color:var(--pirinc,#D9B26A);filter:drop-shadow(0 6px 14px rgba(0,0,0,.35))}
      .tox-kapak{position:relative;padding:16px 15px 15px;border-radius:20px;margin:0 0 12px;overflow:hidden;color:#F3FBF8;
        background:radial-gradient(130% 100% at 0% 0%,rgba(47,158,143,.40),transparent 55%),linear-gradient(160deg,#123A3D,#14213F 75%);box-shadow:inset 0 0 0 1px rgba(217,178,106,.35),0 16px 30px -24px #000}
      .tox-kapak::after{content:"";position:absolute;inset:auto -30px -40px auto;width:160px;height:160px;border-radius:50%;border:1px dashed rgba(217,178,106,.22);pointer-events:none}
      .tox-k-ust{display:flex;gap:13px;align-items:center}
      .tox-k-ust h2{font-family:var(--disp);font-size:25px;line-height:1.08;margin:0;color:#fff;text-wrap:balance;overflow-wrap:anywhere}
      .tox-k-ust p{margin:5px 0 0;font-size:13px;line-height:1.4;color:#CFE3E0;overflow-wrap:anywhere}
      .tox-k-ust p b{color:#fff}
      .tox-gec{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:12px;padding:4px;border-radius:14px;background:rgba(0,0,0,.22)}
      .tox-gec button{min-height:40px;border-radius:10px;font-size:13.5px;font-weight:750;color:#CFE3E0;padding:4px 6px;line-height:1.2}
      .tox-gec button[aria-pressed=true]{background:#D9B26A;color:#1A1405}
      .tox-kapak .alan{margin:10px 0 0}.tox-kapak .alan label{color:#CFE3E0}
      .tox-kart{background:var(--panel);border-radius:16px;padding:14px 14px 13px;margin:0 0 10px;box-shadow:inset 0 0 0 1px var(--line)}
      .tox-kart h2{font-size:17px;line-height:1.25;margin:0 0 6px}
      .tox-kart>.alt{margin:0 0 8px}
      .tox-sure{display:flex;align-items:baseline;gap:10px;margin:6px 0 10px}
      .tox-sure b{font-family:var(--disp);font-size:30px;line-height:1;font-variant-numeric:tabular-nums;color:#fff}
      .tox-sure span{font-size:13px;color:var(--txt2);line-height:1.35}
      .to-bar{height:8px;border-radius:6px;background:var(--panel2);overflow:hidden;margin:6px 0 4px}
      .to-bar i{display:block;height:100%;background:linear-gradient(90deg,#2F9E8F,#D9B26A)}
      .tox-aday{display:flex;gap:12px;padding:13px 0;border-bottom:1px solid var(--line2)}
      .tox-aday:last-child{border-bottom:0}
      .tox-aday .tox-a-g{flex:1;min-width:0}
      .tox-aday blockquote{margin:7px 0 10px;padding:8px 11px;border-radius:0 10px 10px 0;background:rgba(255,255,255,.04);box-shadow:inset 3px 0 0 var(--pirinc);font-size:14.5px;line-height:1.45;color:var(--txt);overflow-wrap:anywhere}
      .tox-aday .btn{margin:0}
      .tox-harf{flex:none;width:42px;height:42px;border-radius:50%;display:grid;place-items:center;font-weight:800;font-size:15px;color:#fff;background:linear-gradient(150deg,hsl(var(--h) 55% 48%),hsl(calc(var(--h) + 35) 50% 28%));box-shadow:inset 0 1px 0 rgba(255,255,255,.25)}
      .tox-sonuc{margin:8px 0 0}
      .tox-sonuc div{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:2px 10px;margin:0 0 9px;font-size:13.5px}
      .tox-sonuc div i{grid-column:1/-1;height:6px;border-radius:4px;background:var(--panel2);overflow:hidden}
      .tox-sonuc div i b{display:block;height:100%;background:var(--pirinc)}
      .tox-sonuc div:first-child i b{background:#2F9E8F}
      .tox-cip{display:inline-flex;align-items:center;gap:6px;padding:5px 10px;border-radius:999px;font-size:12.5px;line-height:1.25;background:var(--panel2);margin:0 6px 6px 0;max-width:100%;overflow-wrap:anywhere}
      .tox-cip.iyi{background:rgba(52,201,138,.13);color:#9FEACB}.tox-cip.kotu{background:rgba(240,69,75,.14);color:#FFB0B3}.tox-cip.bekle{background:rgba(242,179,61,.13);color:#FFD98C}
      .tox-sirket{padding:13px 0;border-bottom:1px solid var(--line2)}
      .tox-sirket:last-child{border-bottom:0}
      .tox-sirket>b{display:block;font-size:15px;line-height:1.3;overflow-wrap:anywhere}
      .tox-sirket>.kucuk{display:block;margin:3px 0 8px}
      .tox-sirket .btn{margin-top:4px}
      .tox-kasa{font-family:var(--disp);font-size:34px;line-height:1;color:#fff;font-variant-numeric:tabular-nums;margin:4px 0 12px}
      .tox-icr{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:0 0 12px}
      .tox-icr button{display:flex;flex-direction:column;align-items:flex-start;gap:3px;min-height:72px;padding:11px;border-radius:13px;text-align:left;background:var(--panel2);box-shadow:inset 0 0 0 1px var(--line2);color:var(--txt)}
      .tox-icr button b{font-size:14px;line-height:1.25}
      .tox-icr button small{font-size:12px;line-height:1.3;color:var(--mut)}
      .tox-icr button[aria-pressed=true]{box-shadow:inset 0 0 0 2px var(--pirinc);background:linear-gradient(160deg,rgba(217,178,106,.16),transparent 70%),var(--panel2)}
      .tox-icr button:disabled{opacity:.5}
      .tox-hizli{display:flex;gap:6px;flex-wrap:wrap;margin:-2px 0 10px}
      .tox-hizli button{min-height:36px;padding:0 12px;border-radius:999px;font-size:13px;font-weight:700;background:var(--panel2);box-shadow:inset 0 0 0 1px var(--line2)}
      .tox-etki{padding:11px 12px;border-radius:12px;background:rgba(47,158,143,.10);box-shadow:inset 0 0 0 1px rgba(47,158,143,.35);font-size:13.5px;line-height:1.5;color:var(--txt2);margin:0 0 10px}
      .tox-etki b{color:#fff}.tox-etki .uyari{color:#FFB0B3}
      .tox-olay{display:flex;gap:11px;padding:12px 0;border-bottom:1px solid var(--line2)}
      .tox-olay:last-child{border-bottom:0}
      .tox-olay .tox-o-n{flex:none;width:9px;height:9px;border-radius:50%;margin-top:6px;background:var(--pirinc);box-shadow:0 0 0 4px rgba(217,178,106,.14)}
      .tox-olay.sendika .tox-o-n{background:#A895FF;box-shadow:0 0 0 4px rgba(168,149,255,.14)}
      .tox-olay .tox-o-g{flex:1;min-width:0}
      .tox-olay b{display:block;font-size:14.5px;line-height:1.3;overflow-wrap:anywhere}
      .tox-olay .kucuk{display:block;margin-top:2px}
      .tox-olay p{margin:5px 0 0;font-size:14px;line-height:1.45;overflow-wrap:anywhere;color:var(--txt2)}
      .tox-sendika{display:flex;gap:11px;align-items:center;width:100%;padding:12px 0;border-bottom:1px solid var(--line2);text-align:left;color:var(--txt)}
      .tox-sendika:last-of-type{border-bottom:0}
      .tox-sendika .tox-s-g{flex:1;min-width:0}
      .tox-sendika b{display:block;font-size:15px;line-height:1.3;overflow-wrap:anywhere}
      .tox-sendika small{display:block;font-size:12.5px;color:var(--mut);margin-top:3px;overflow-wrap:anywhere}
      .tox-sendika .ok{color:var(--faint);font-size:20px}
      .to-satir{padding:9px 0;border-bottom:1px solid var(--line2);overflow-wrap:anywhere}
      .to-satir:last-child{border-bottom:0}
      .to-iki{display:flex;gap:8px;flex-wrap:wrap}
      .to-iki .btn{flex:1;min-width:130px;margin:0}
      /* Ekonomi sekmesindeki oda özeti */
      .to-hub{padding-bottom:18px}
      .to-hub .tox-kutu{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}
      .to-hub .tox-kutu button{display:flex;flex-direction:column;align-items:flex-start;gap:4px;min-height:84px;padding:12px;border-radius:15px;text-align:left;color:var(--txt);background:var(--panel);box-shadow:inset 0 0 0 1px var(--line)}
      .to-hub .tox-kutu button b{font-size:14.5px;line-height:1.25}
      .to-hub .tox-kutu button small{font-size:12.5px;line-height:1.35;color:var(--mut)}
      @media (max-width:350px){.tox-k-ust h2{font-size:21px}.tox-icr{grid-template-columns:1fr}.tox-muhur{width:60px;height:60px}}`;
    document.head.appendChild(s);
  }

  /* ------------------------------------------------------------ oda ekranı */
  function secimHtml(d) {
    const s = d.secim, il = d.il, benimSirket = (d.benim.sirketler || []).filter(x => x.bu_oda);
    const ss = d.son_secim;
    const sonucHtml = ss => { const l = ss.sonuc || []; if (!l.length) return `<p class="kucuk">Son seçimde (${tarihSaat(ss.bitis)}) aday çıkmadı.</p>`;
      const top = l.reduce((t, x) => t + (Number(x.oy) || 0), 0) || 1;
      return `<div class="tox-sonuc">${l.map(x => `<div><span><b>${e(x.aday)}</b>${x.sendika ? ` <span class="kucuk">${e(x.sendika)}</span>` : ""}</span><span>${n(x.oy)} oy · %${Math.round(100 * x.oy / top)}</span><i><b style="width:${Math.round(100 * x.oy / top)}%"></b></i></div>`).join("")}</div>
        <p class="kucuk">Son seçim ${tarihSaat(ss.bitis)} tarihinde bitti${ss.katilim != null ? `; ${n(ss.katilim)} şirket oy kullandı` : ""}.</p>`; };
    const adim = no => KX() ? KX().adimlar(["Adaylık (48 sa)", "Oylama (24 sa)", "Sonuç"], no) : "";
    if (!s) {
      let h = `<section class="tox-kart" id="toBolumSecim"><h2>Başkanlık seçimi</h2>${adim(3)}`;
      if (d.oda.baskan) h += `<p class="alt">Görev süresi 21 gündür. Sonraki seçim <b>${tarihSaat(d.oda.donem_bitis)}</b> dolayında kendiliğinden açılır.</p>
        <div class="tox-sure"><b>${kalan(new Date(d.oda.donem_bitis).getTime() - simdi()).replace(/:\d\d$/, "")}</b><span>sonraki seçime</span></div>`;
      else h += `<p class="alt">${d.oda.uye > 0 ? "Seçim birkaç dakika içinde kendiliğinden açılır" + (d.oda.sonraki_secim ? " (en erken " + tarihSaat(d.oda.sonraki_secim) + ")" : "") + "." : "Bu odanın henüz üyesi yok; ilk şirket kurulunca seçim açılır."}</p>`;
      if (ss) h += `<h3 style="font-size:15px;margin:14px 0 4px">Son seçim sonucu</h3>` + sonucHtml(ss);
      return h + `</section>`;
    }
    const adaylik = s.durum === "aday";
    const hedef = adaylik ? s.oy_bas : s.oy_son;
    let h = `<section class="tox-kart" id="toBolumSecim"><h2>Başkanlık seçimi · ${adaylik ? "adaylık dönemi" : "oylama"}</h2>${adim(adaylik ? 0 : 1)}
      <div class="tox-sure"><b>${kalan(new Date(hedef).getTime() - simdi()).replace(/:\d\d$/, "")}</b><span>${adaylik ? "oylamanın başlamasına" : "oylamanın bitmesine"}<br>${tarihSaat(hedef)}</span></div>
      <p class="alt">Her şirketin 1 oyu vardır; oyu şirketin yöneticisi kullanır. En çok oyu alan kazanır.${s.neden ? " <i>" + e(s.neden) + "</i>" : ""}</p>`;
    if (!adaylik) h += `<div class="to-bar"><i style="width:${Math.min(100, Math.round(100 * s.kullanilan / Math.max(1, s.oy_hakki)))}%"></i></div><div class="kucuk">${s.kullanilan} / ${s.oy_hakki} şirket oy kullandı · sonuçlar oylama bitince açıklanır</div>`;
    if (!adaylik && benimSirket.length) {
      h += `<div style="margin:12px 0 2px"><div class="kucuk" style="margin-bottom:6px"><b>Şirketlerimin oyu</b></div>${benimSirket.map(x => `<span class="tox-cip ${x.oy ? "iyi" : x.aidat_borc > 0 ? "kotu" : "bekle"}">${e(x.ad)} → ${x.oy ? e(x.oy) : (x.aidat_borc > 0 ? "aidat borcu var, oy kullanamaz" : "kullanılmadı")}</span>`).join("")}</div>`;
    }
    h += `<h3 style="font-size:15px;margin:14px 0 0">Adaylar <span class="kucuk">${(s.adaylar || []).length}</span></h3>`;
    h += (s.adaylar || []).map(a => `<div class="tox-aday">${harfRozet(a.kad, a.sendika || a.kad)}<div class="tox-a-g">${kisi(a)}${a.sendika ? "<br>" + rozet(a.sendika, "var(--ink2,#a995ff)") : ""}
      ${a.vaat ? `<blockquote>${e(a.vaat)}</blockquote>` : '<div style="height:8px"></div>'}
      ${!adaylik && benimSirket.length ? `<button class="btn ${benimSirket.some(x => x.oy === a.kad) ? "altin" : "ikinci"}" onclick="toOyVer(${il},'${e(a.kad)}')">Şirketlerimin oyunu ${e(a.kad)} için kullan</button>` : ""}</div></div>`).join("") || bos("Henüz aday yok.");
    if (s.adayim) h += `<button class="btn tehlike" style="margin-top:10px" onclick="toAdayCekil(${il})">Adaylıktan çekil</button>`;
    else if (adaylik && d.benim.temsilci) {
      const sen = []; (d.benim.sirketler || []).forEach(x => { if (x.sendika && !sen.some(y => y.id === x.sendika.id)) sen.push(x.sendika); });
      h += `<h3 style="font-size:15px;margin:16px 0 4px">Aday ol</h3><div class="alan"><label for="toVaat">Seçim vaadin</label><textarea id="toVaat" maxlength="600" rows="3" placeholder="Üyelere ne vaat ediyorsun?"></textarea></div>
        ${sen.length ? `<div class="alan"><label for="toSen">Hangi sendikanın adayısın?</label><select id="toSen"><option value="">Bağımsız aday</option>${sen.map(x => `<option value="${x.id}">${e(x.ad)}</option>`).join("")}</select></div>` : ""}
        <button class="btn altin" onclick="toAdayOl(${il})">Başkanlığa aday ol</button>`;
    } else if (adaylik) h += `<p class="kucuk" style="margin-top:8px">Aday olmak için ${d.ulusal ? "bir ticaret odasına" : "bu odaya"} üye faal bir şirketin yöneticisi olmalısın.</p>`;
    if (ss) h += `<details style="margin-top:12px"><summary class="kucuk" style="cursor:pointer">Önceki seçimin sonucu</summary>${sonucHtml(ss)}</details>`;
    return h + `</section>`;
  }

  // başkanlık masası: icraat türü kutucuklardan seçilir, etki ve maliyet yazarken hesaplanır
  const ICRAAT_ACIK = { destek: "Kasadan üye şirketlere eşit pay", fuar: "İl gelişimi artar", egitim: "Halk memnuniyeti artar", aidat: "Haftalık aidatı değiştir", rapor: "Gündem'de yayımlanır", il_destek: "Birlikten il odasına" };
  function masaHtml(d) {
    if (!d.benim.baskan) return "";
    const turler = d.ulusal ? ["destek", "fuar", "il_destek", "rapor"] : ["destek", "fuar", "egitim", "aidat", "rapor"];
    const son48 = t => (d.icraatlar || []).find(x => x.tur === t && new Date(x.zaman).getTime() > simdi() - 48 * 36e5);
    const bekle = t => { const x = son48(t); return x ? new Date(x.zaman).getTime() + 48 * 36e5 : 0; };
    window._toMasa = { ulusal: d.ulusal, kasa: Number(d.oda.kasa) || 0, uye: Number(d.oda.uye) || 0, borclu: Number(d.oda.borclu) || 0, aidat: Number(d.oda.aidat) || 0,
      yedi: (d.icraatlar || []).filter(x => (x.tur === "fuar" || x.tur === "egitim") && new Date(x.zaman).getTime() > simdi() - 7 * 864e5).length, bekle: { fuar: bekle("fuar"), egitim: bekle("egitim") } };
    return `<section class="tox-kart" id="toBolumMasa" style="box-shadow:inset 0 0 0 1.5px rgba(217,178,106,.55)"><h2>Başkanlık masası</h2>
      <div class="kucuk">Oda kasası</div><div class="tox-kasa">${tl(d.oda.kasa)}</div>
      <input type="hidden" id="toTur" value="${turler[0]}">
      <div class="tox-icr" role="group" aria-label="İcraat türü">${turler.map((k, i) => { const b = bekle(k); return `<button type="button" data-to-tur="${k}" aria-pressed="${i === 0}" onclick="toTurSec('${k}')"><b>${e(ICRAAT_AD[k])}</b><small>${b ? "Yeniden " + tarihSaat(b) : e(ICRAAT_ACIK[k])}</small></button>`; }).join("")}</div>
      <div class="alan" id="toTutarK"><label for="toTutar">Tutar (₺)</label><input id="toTutar" type="number" inputmode="numeric" min="0" step="1000" oninput="toEtkiYaz()"></div>
      <div class="tox-hizli" id="toHizli"></div>
      <div class="alan" id="toHedefK" hidden><label for="toHedef">İl odası</label><select id="toHedef">${(d.iller || []).filter(x => x.il_id !== 0).map(x => `<option value="${x.il_id}">${e(x.ad)} (${x.uye} üye)</option>`).join("")}</select></div>
      <div class="alan" id="toMetinK" hidden><label for="toMetin">Açıklama metni</label><textarea id="toMetin" maxlength="1500" rows="4"></textarea></div>
      <div class="tox-etki" id="toEtki" hidden></div>
      <p class="kucuk" id="toIpucu"></p>
      <p class="kucuk">Fuar ve eğitim 48 saatte bir yapılır; harcamanın %20'si KDV olarak Hazine'ye gider. Oda kasasından kişilere ödeme yapılamaz.</p>
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
  const HIZLI = { destek: [10000, 50000, 100000], fuar: [100000, 250000, 500000], egitim: [100000, 200000, 400000], aidat: [1000, 3000, 5000], il_destek: [10000, 50000, 250000] };
  const HIZLI_U = { fuar: [500000, 1000000, 2000000] };
  window.toTurSec = function (t) {
    const g = $("#toTur"); if (g) g.value = t;
    document.querySelectorAll("[data-to-tur]").forEach(b => b.setAttribute("aria-pressed", String(b.dataset.toTur === t)));
    window.toIcraatAlan();
  };
  window.toIcraatAlan = function () {
    const t = ($("#toTur") || {}).value, m = window._toMasa || {};
    const g = (id, goster) => { const el = document.getElementById(id); if (el) el.hidden = !goster; };
    g("toTutarK", t !== "rapor"); g("toMetinK", t === "rapor"); g("toHedefK", t === "il_destek"); g("toHizli", t !== "rapor");
    const lb = document.querySelector('label[for="toTutar"]'); if (lb) lb.textContent = t === "aidat" ? "Yeni haftalık aidat (şirket başına, ₺)" : "Tutar (₺)";
    const hz = $("#toHizli"); if (hz) hz.innerHTML = ((m.ulusal && HIZLI_U[t]) || HIZLI[t] || []).map(v => `<button type="button" onclick="toTutarKoy(${v})">${tl(v)}</button>`).join("");
    const ip = $("#toIpucu"); if (ip) ip.textContent = IPUCU[t] || "";
    window.toEtkiYaz();
  };
  window.toTutarKoy = v => { const el = $("#toTutar"); if (el) { el.value = v; window.toEtkiYaz(); } };
  // sunucudaki formüllerle aynı yaklaşık hesap (196_ticaret_odasi.sql · oda_icraat)
  window.toEtkiYaz = function () {
    const el = $("#toEtki"); if (!el) return;
    const t = ($("#toTur") || {}).value, m = Number(($("#toTutar") || {}).value) || 0, o = window._toMasa || {};
    if (t === "rapor" || !(m > 0)) { el.hidden = true; return; }
    let h = "";
    if (t === "destek") { const k = o.ulusal ? o.uye : Math.max(0, o.uye - o.borclu); h = k ? `Aidat borcu olmayan <b>${n(k)}</b> şirketin her birine yaklaşık <b>${tl(Math.floor(m / k))}</b>.` : "Pay alacak (aidat borcu olmayan) üye şirket yok."; }
    else if (t === "fuar" || t === "egitim") {
      const azalma = 1 + 0.5 * (o.yedi || 0);
      if (o.ulusal) h = `Üyesi olan her ilde gelişim <b>+${virgul(Math.min(0.30, m / 2000000 * 0.15))}</b>.`;
      else { let gel, mem; if (t === "fuar") { gel = Math.min(0.60, m / 500000 * 0.30); mem = gel / 3; } else { mem = Math.min(0.60, m / 400000 * 0.30); gel = mem / 3; }
        h = `İl gelişimi <b>+${virgul(gel / azalma)}</b>, memnuniyet <b>+${virgul(mem / azalma)}</b>.${o.yedi ? ` Bu hafta ${o.yedi} organizasyon yapıldı; etki azalır.` : ""}`; }
      h += ` Bunun <b>${tl(Math.round(m * 0.20))}</b> kadarı KDV olarak Hazine'ye gider.`;
      if (o.bekle && o.bekle[t] > simdi()) h += `<br><span class="uyari">Bu tür organizasyon ${tarihSaat(o.bekle[t])} tarihine kadar yapılamaz.</span>`;
    }
    else if (t === "aidat") { const net = Math.max(0, o.uye - o.borclu); h = `Aidat borcu olmayan ${n(net)} şirketten haftada yaklaşık <b>${tl(m * net)}</b> tahsil edilir; <b>${tl(Math.round(m * net * 0.75))}</b> odaya, kalanı Birliğe. Şu anki aidat ${tl(o.aidat)}.`; }
    else if (t === "il_destek") h = `Seçtiğin il odasının kasasına <b>${tl(m)}</b> aktarılır.`;
    if (t !== "aidat" && m > o.kasa) h += `<br><span class="uyari">Oda kasasında ${tl(o.kasa)} var; bu tutar karşılanamaz.</span>`;
    el.innerHTML = h; el.hidden = !h;
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
    try { d = await rpc("oda_ozet"); }
    catch (err) {
      return `<section class="kart"><h2>Ticaret Odası</h2><p class="alt">${e(hataCevir(err.message))}</p>
        <button type="button" class="btn ikinci" onclick="ekranAc(function(){return ticaretOdasiEkrani()})">Ayrıntılı odayı aç</button></section>`;
    }
    d = d || {};
    const il = Number(d.il) || Number((D.durum || {}).profil?.il_id) || 6;
    const ad = d.ad || "İl Ticaret Odası", s = d.secim, birlik = d.birlik, borc = Number(d.aidat_borc) || 0;
    const odaAc = bolum => `ekranAc(function(){return ticaretOdasiEkrani(${il},'${bolum}')})`;
    const birlikAc = `ekranAc(function(){return ticaretOdasiEkrani(0)})`;
    let dk = "";
    if (KX()) {
      if (borc) dk += KX().dikkat("Aidat borcun var: " + tl(borc), "Borçlu şirket oy kullanamaz; şirket kasasından öde.", "Öde", odaAc("sirket"));
      if (s && s.durum === "oy" && Number(d.oy_bekleyen) > 0) dk += KX().dikkat(`Oylama sürüyor: ${d.oy_bekleyen} oyun bekliyor`, `${n(s.aday)} aday · ${tarihSaat(s.oy_son)} tarihinde biter.`, "Oy ver", odaAc("secim"));
      else if (s && s.durum === "aday" && Number(d.sirketim) && !s.adayim) dk += KX().dikkat("Başkanlık adaylığı açık", `${n(s.aday)} aday · oylama ${tarihSaat(s.oy_bas)} tarihinde başlar.`, "Aday ol", odaAc("secim"));
      if (d.baskanim) dk += KX().dikkat("Oda başkanısın", "Destek fonu, fuar, eğitim ve aidat kararlarını masandan yönet.", "Masam", odaAc("masa"));
    }
    const secimAlt = !s ? "Adaylık, oylama ve geçmiş sonuçlar." : s.durum === "aday" ? `${n(s.aday)} aday · oylama ${tarihSaat(s.oy_bas)}` : `${n(s.aday)} aday · ${tarihSaat(s.oy_son)} tarihinde biter`;
    return `<div class="to-hub tox">
      <section class="tox-kapak"><div class="tox-k-ust">${muhur(il, ad, 72)}<div style="min-width:0"><h2>${e(ad)}</h2><p>Başkan <b>${e(d.baskan || "henüz seçilmedi")}</b></p></div></div>
        ${KX() ? KX().sayilar([[n(d.uye), "üye şirket"], [n(d.sirketim), "şirketim"], [n(d.oy_hakki), "oy hakkım"]]) : ""}
        <div class="tox-gec"><button type="button" aria-pressed="true" onclick="${odaAc("oda")}">İl odamı aç</button><button type="button" aria-pressed="false" onclick="${birlikAc}">Odalar Birliği</button></div></section>
      ${dk}
      <div class="tox-kutu">
        <button type="button" onclick="${odaAc("secim")}"><b>${!s ? "Seçimler" : s.durum === "aday" ? "Başkanlık adaylığı açık" : "Başkanlık oylaması sürüyor"}</b><small>${e(secimAlt)}</small></button>
        <button type="button" onclick="${odaAc("sirket")}"><b>Şirketlerim ve aidat</b><small>${borc ? tl(borc) + " borç" : Number(d.sirketim) ? n(d.sirketim) + " şirket kayıtlı · haftalık " + tl(d.aidat) : "Şirket kurunca otomatik üye olursun"}</small></button>
        <button type="button" onclick="${odaAc("sendika")}"><b>İşveren sendikaları</b><small>Kur, katıl, bildiri yayımla, aday göster</small></button>
        <button type="button" onclick="${birlikAc}"><b>${e(d.birlik_baskan || "Türkiye Odalar Birliği")}</b><small>${birlik ? `Birlik seçimi: ${n(birlik.aday)} aday · ${birlik.durum === "aday" ? "adaylık" : "oylama"}` : "Ulusal fuar ve il odalarına kaynak"}</small></button>
      </div></div>`;
  };

  window.ticaretOdasiEkrani = async function (il, bolum) {
    stil();
    if (il === undefined && D._toIl !== undefined) il = D._toIl;
    if (il === undefined) il = null;
    if (!document.getElementById("toKok")) yukleniyor("Ticaret Odası");
    let d; try { d = await rpc("oda_panel", { p_il: il }); } catch (err) { return hataEkran("Ticaret Odası", err); }
    D._toIl = d.il;
    const o = d.oda, benim = d.benim.sirketler || [], evIl = (benim[0] || {}).il_id || (D.durum && D.durum.profil && D.durum.profil.il_id) || 6;
    const borclu = benim.filter(x => x.aidat_borc > 0), buOda = benim.filter(x => x.bu_oda);
    const s = d.secim, oyBekleyen = s && s.durum === "oy" ? buOda.filter(x => !x.oy && !(x.aidat_borc > 0)).length : 0;
    const SEK = [["oda", "Oda"], ["secim", s ? (s.durum === "aday" ? "Seçim · adaylık" : "Seçim · oylama") : "Seçim", oyBekleyen ? String(oyBekleyen) : "", oyBekleyen > 0],
      ["sirket", "Şirketlerim", borclu.length ? String(borclu.length) : benim.length ? String(benim.length) : "", borclu.length > 0]]
      .concat(d.benim.baskan ? [["masa", "Başkanlık masası"]] : []).concat([["sendika", "Sendikalar", String((d.sendikalar || []).length)]]);
    if (bolum && KX()) KX().SEC.to = bolum === "masa" && !d.benim.baskan ? "oda" : bolum;
    const varsay = oyBekleyen ? "secim" : "oda";
    const akt = KX() ? KX().secili("to", SEK, varsay) : varsay;
    const pano = (k, h) => KX() ? KX().pano("to", k, akt, h) : h;
    let dk = "";
    if (KX()) {
      if (borclu.length) dk += KX().dikkat(`${borclu.length} şirketinin aidat borcu var`, "Borçlu şirket oy kullanamaz. Toplam " + tl(borclu.reduce((t, x) => t + (Number(x.aidat_borc) || 0), 0)) + ".", "Öde", "SO_KX.gec('to','sirket')");
      if (oyBekleyen) dk += KX().dikkat(`${oyBekleyen} şirketinin oyu kullanılmadı`, "Oylama " + tarihSaat(s.oy_son) + " tarihinde biter.", "Oy ver", "SO_KX.gec('to','secim')");
    }
    // oda gündemi: icraatlar ve sendika bildirileri tek zaman çizelgesinde
    const olaylar = (d.icraatlar || []).map(x => ({ z: x.zaman, h: `<div class="tox-olay"><span class="tox-o-n"></span><div class="tox-o-g"><b>${e(ICRAAT_AD[x.tur] || x.tur)}${x.tutar > 0 ? " · " + tl(x.tutar) : ""}</b>
        <span class="kucuk">${tarihSaat(x.zaman)} · ${e(x.yapan || "")}</span><p>${e(x.baslik)}</p>${x.metin ? `<p style="color:var(--txt)">${e(x.metin)}</p>` : ""}</div></div>` }))
      .concat((d.bildiriler || []).map(b => ({ z: b.zaman, h: `<div class="tox-olay sendika"><span class="tox-o-n"></span><div class="tox-o-g"><b>${e(b.baslik)} ${konumRozet(b.konum)}</b>
        <span class="kucuk">${e(b.sendika)} · ${e(b.yazar || "")} · ${tarihSaat(b.zaman)}${b.tur === "kampanya" ? " · kampanya" : ""}</span><p style="color:var(--txt)">${e(b.metin)}</p></div></div>` })))
      .sort((a, b) => new Date(b.z) - new Date(a.z));
    const odaPano = `
      ${o.baskan && !d.secim ? `<section class="tox-kart"><h2>Erken seçim talebi</h2>
        <p class="alt">Üye şirketlerin yarısından fazlası imzalarsa başkanlık seçimi hemen açılır (başkan en az 5 gündür görevdeyse).</p>
        <div class="to-bar"><i style="width:${Math.min(100, Math.round(100 * d.imza.sayi / Math.max(1, d.imza.gereken)))}%"></i></div>
        <div class="kucuk">${d.imza.sayi} imza · gereken ${d.imza.gereken}</div>
        ${buOda.some(x => !x.imza) ? `<button class="btn ikinci" style="margin-top:10px" onclick="toImza(${d.il})">Şirketlerimle imza at</button>` : ""}</section>` : ""}
      <section class="tox-kart" id="toBolumOda"><h2>Oda gündemi</h2><p class="alt">Başkanlık icraatları ve sendika bildirileri, en yenisi üstte.</p>${olaylar.map(x => x.h).join("") || bos("Henüz icraat ya da bildiri yok.")}</section>
      <section class="tox-kart"><h2>Oda bilgileri</h2>
        ${kv("Başkan", o.baskan ? kisi(o.baskan) + (o.baskan_sendika ? " " + rozet(o.baskan_sendika.ad, "var(--ink2,#a995ff)") : "") : "Seçilmedi")}
        ${o.baskan && o.donem_bitis ? kv("Görev süresi bitişi", tarihSaat(o.donem_bitis)) : ""}
        ${kv("Üye şirket", o.uye + (o.borclu > 0 ? ` <span class="kucuk">(${o.borclu} aidat borçlu)</span>` : ""))}
        ${kv("Oda kasası", "<b>" + tl(o.kasa) + "</b>")}
        ${d.ulusal ? "" : kv("Haftalık aidat (şirket başına)", tl(o.aidat))}
        ${kv("Bugüne kadar toplanan / harcanan", tl(o.toplam_aidat) + " / " + tl(o.toplam_harcama))}
        <details style="margin-top:10px"><summary><b>Üye şirketler (${o.uye})</b></summary>${(d.uyeler || []).map(u => `<div class="to-satir">${e(u.ad)} <span class="kucuk">${u.il ? e(u.il) + " · " : ""}${e(u.yonetici || "")}${u.sendika ? " · " + e(u.sendika) : ""}${u.borclu ? " · aidat borçlu" : ""}</span></div>`).join("") || bos("Üye yok.")}</details></section>`;
    const sirketPano = benim.length ? `<section class="tox-kart" id="toBolumSirket"><h2>Şirketlerim</h2>
        <p class="alt">${borclu.length ? "Borçlu şirketler oda seçimlerinde oy kullanamaz; borç en çok 8 haftalık aidat kadar birikir." : `Aidat borcun yok; bu odada ${buOda.length} oy hakkın var.`}</p>
        ${benim.map(x => `<div class="tox-sirket"><b>${e(x.ad)}</b><span class="kucuk">${e(x.il || "")} Ticaret Odası${x.sendika ? " · " + e(x.sendika.ad) : " · sendikasız"}</span>
          ${x.aidat_borc > 0 ? `<span class="tox-cip kotu">Aidat borcu ${tl(x.aidat_borc)} · oy kullanamaz</span>` : '<span class="tox-cip iyi">Aidat ödendi</span>'}
          ${s && s.durum === "oy" && x.bu_oda ? `<span class="tox-cip ${x.oy ? "iyi" : "bekle"}">${x.oy ? "Oyu: " + e(x.oy) : "Oy kullanmadı"}</span>` : ""}
          ${x.aidat_borc > 0 ? `<button class="btn ikinci" onclick="toAidatOde(${x.id})">Aidat borcunu şirket kasasından öde</button>` : ""}</div>`).join("")}</section>`
      : `<section class="tox-kart" id="toBolumSirket"><h2>Şirketlerim</h2><p class="alt">Yöneticisi olduğun faal bir şirket yok. Şirket kurduğunda merkez ilinin odasına kendiliğinden kaydolur; şirket başına 1 oy hakkın olur.</p></section>`;
    const sendikaPano = `<section class="tox-kart" id="toBolumSendika"><h2>İşveren sendikaları</h2>
        <p class="alt">Şirketler serbestçe sendikalaşır (şirket başına tek sendika). Sendikalar oda seçimlerinde aday çıkarır; Birlik başkanlığını alamayanlar muhalefette kalır.</p>
        ${(d.sendikalar || []).map(sd => `<button type="button" class="tox-sendika" onclick="ekranAc(()=>sendikaEkrani(${sd.id}))">${harfRozet(sd.ad)}<span class="tox-s-g"><b>${e(sd.ad)} ${konumRozet(sd.konum)}</b><small>${sd.uye} üye şirket · başkan ${e(sd.baskan || "—")}${sd.aidat > 0 ? " · aidat " + tl(sd.aidat) + "/hafta" : ""}</small>${sd.amac ? `<small>${e(sd.amac)}</small>` : ""}</span><span class="ok" aria-hidden="true">›</span></button>`).join("") || bos("Henüz sendika kurulmadı.")}
        ${benim.some(x => !x.sendika) ? `<button class="btn ikinci" style="margin-top:12px" onclick="toSendikaKur()">İşveren sendikası kur (50.000 ₺)</button>` : ""}</section>`;
    iskelet(d.ulusal ? "Odalar Birliği" : "Ticaret Odası", `<div id="toKok" class="tox">
      <section class="tox-kapak"><div class="tox-k-ust">${muhur(d.il, d.ad, 76)}<div style="min-width:0"><h2>${e(d.ad)}</h2>
          <p>${o.baskan ? `Başkan <b>${e(o.baskan.kad)}</b>${o.baskan_sendika ? " · " + e(o.baskan_sendika.ad) : ""}` : "Başkan henüz seçilmedi"}</p></div></div>
        <p style="margin:10px 0 0;font-size:13px;line-height:1.45;color:#CFE3E0">${d.ulusal ? "81 il odasının çatı kuruluşu. Bütün şirketler üyesidir; il odalarına ödenen aidatın %25'i Birlik kasasına gelir." : "Bu ildeki bütün faal şirketler odanın zorunlu üyesidir. Aidat her hafta şirket kasasından alınır."}</p>
        ${KX() ? KX().sayilar([[n(o.uye), "üye şirket"], [tl(o.kasa).replace(" ₺", "₺"), "oda kasası"], [d.ulusal ? n((d.iller || []).filter(x => x.il_id !== 0 && x.uye > 0).length) : tl(o.aidat).replace(" ₺", "₺"), d.ulusal ? "üyeli il odası" : "haftalık aidat"]]) : ""}
        <div class="tox-gec"><button type="button" aria-pressed="${!d.ulusal}" onclick="ticaretOdasiEkrani(${evIl})">İl odam</button><button type="button" aria-pressed="${!!d.ulusal}" onclick="ticaretOdasiEkrani(0)">Türkiye Odalar Birliği</button></div>
        ${(d.iller || []).length > 1 ? `<div class="alan"><label for="toIlSec">Başka bir odaya bak</label><select id="toIlSec" onchange="toIlDegis(this.value)">
          ${d.iller.map(x => `<option value="${x.il_id}" ${x.il_id === d.il ? "selected" : ""}>${e(x.ad)} · ${x.uye} üye${x.baskan ? " · " + e(x.baskan) : ""}</option>`).join("")}</select></div>` : ""}
      </section>
      ${dk}
      ${KX() ? KX().sekmeler("to", SEK, akt, "#2F9E8F") : ""}
      ${pano("oda", odaPano)}
      ${pano("secim", secimHtml(d))}
      ${pano("sirket", sirketPano)}
      ${d.benim.baskan ? pano("masa", masaHtml(d)) : ""}
      ${pano("sendika", sendikaPano)}
    </div>`, { geri: D.yigin.length > 0 });
    window._toPanel = d;
    if (d.benim.baskan) window.toIcraatAlan();
    if (d.secim) {                                    // geri sayım ve durum geçişi için hafif tazeleme
      const taz = async () => { if (!document.getElementById("toKok") || document.hidden || $("#modal")) return; const ta = $("#toVaat"); if (ta && ta.value.trim()) return; const tt = $("#toTutar"); if (tt && tt.value) return; try { await window.ticaretOdasiEkrani(d.il); } catch (_) {} };
      D.canli = setInterval(taz, 60000);
    }
  };

  window.toAtla = function (bolum) {
    if (KX()) return KX().gec("to", bolum || "oda");
    const el = document.getElementById("toKok"); if (el) el.scrollIntoView({ block: "start" });
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
    iskelet("İşveren sendikası", `<div id="sdKok" class="tox">
      <section class="tox-kapak"><div class="tox-k-ust">${harfRozet(d.ad).replace('class="tox-harf"', 'class="tox-harf" style="width:64px;height:64px;font-size:22px;--h:' + ton(d.ad) + '"')}<div style="min-width:0"><h2>${e(d.ad)}</h2>
          <p>${d.kapali ? rozet("Kapandı", "var(--mut)") : konumRozet(d.konum)} · Başkan <b>${e((d.baskan || {}).kad || "—")}</b></p></div></div>
        ${d.amac ? `<p style="margin:10px 0 0;font-size:13.5px;line-height:1.45;color:#CFE3E0">${e(d.amac)}</p>` : ""}
        ${KX() ? KX().sayilar([[n((d.uyeler || []).length), "üye şirket"], [d.aidat > 0 ? tl(d.aidat).replace(" ₺", "₺") : "Yok", "haftalık aidat"], [n((d.odalar || []).length), "kazandığı oda"]]) : ""}
        <p style="margin:10px 0 0;font-size:12.5px;line-height:1.45;color:#CFE3E0">${d.konum === "yonetim" ? "Bu sendikanın adayı Türkiye Odalar Birliği başkanı." : "Birlik yönetiminde değil: bildiri ve kampanyayla muhalefet yapar, erken seçim için imza toplar."}</p></section>
      <section class="tox-kart">${kv("Başkan", kisi(d.baskan))}${kv("Üye şirket", (d.uyeler || []).length)}${kv("Haftalık sendika aidatı", d.aidat > 0 ? tl(d.aidat) : "Yok")}
        ${d.kasa != null ? kv("Sendika kasası", "<b>" + tl(d.kasa) + "</b>") : ""}
        ${(d.odalar || []).length ? kv("Başkanlığını kazandığı odalar", d.odalar.map(e).join(", ")) : ""}</section>
      ${!d.kapali && (katilabilir.length || buradaki.length) ? `<section class="tox-kart"><h2>Şirketlerim</h2>
        ${buradaki.map(x => `<div class="tox-sirket"><b>${e(x.ad)}</b><span class="tox-cip iyi">Üye</span><button class="btn ikinci" onclick="sdAyril(${x.id},${d.id})">Sendikadan ayrıl</button></div>`).join("")}
        ${katilabilir.map(x => `<div class="tox-sirket"><b>${e(x.ad)}</b><span class="tox-cip">Sendikasız</span><button class="btn altin" onclick="sdKatil(${d.id},${x.id})">Bu şirketi üye yap</button></div>`).join("")}</section>` : ""}
      ${d.baskanim ? `<section class="tox-kart" style="box-shadow:inset 0 0 0 1.5px rgba(217,178,106,.55)"><h2>Başkanlık</h2>
        <div class="alan"><label for="sdTur">İşlem</label><select id="sdTur" onchange="sdAlan()">
          <option value="bildiri">Bildiri yayımla (ücretsiz, günde 1)</option><option value="kampanya">Kampanya yap (oda üyelerine bildirim, en az 25.000 ₺)</option>
          <option value="aidat">Haftalık sendika aidatını belirle</option><option value="devret">Başkanlığı devret</option></select></div>
        <div id="sdYazi"><div class="alan"><label for="sdOda">Hangi odaya yönelik?</label><select id="sdOda">${odalar.map(x => `<option value="${x.il_id}">${e(x.ad)}</option>`).join("")}</select></div>
          <div class="alan"><label for="sdBaslik">Başlık</label><input id="sdBaslik" maxlength="90"></div>
          <div class="alan"><label for="sdMetin">Metin</label><textarea id="sdMetin" maxlength="1500" rows="4"></textarea></div></div>
        <div class="alan" id="sdTutarK" hidden><label for="sdTutar" id="sdTutarL">Tutar (₺)</label><input id="sdTutar" type="number" inputmode="numeric" min="0" step="500"></div>
        <div class="alan" id="sdKadK" hidden><label for="sdKad">Yeni başkanın kullanıcı adı (üye şirket yöneticisi)</label><input id="sdKad" autocapitalize="off"></div>
        <button class="btn altin" onclick="sdIslem(${d.id})">Uygula</button></section>` : ""}
      <section class="tox-kart"><h2>Bildiriler ve kampanyalar</h2>${(d.bildiriler || []).map(b => `<div class="tox-olay sendika"><span class="tox-o-n"></span><div class="tox-o-g"><b>${e(b.baslik)}</b>
        <span class="kucuk">${e(b.oda)} · ${tarihSaat(b.zaman)}${b.tur === "kampanya" ? " · kampanya " + tl(b.tutar) : ""}</span>
        <p style="color:var(--txt)">${e(b.metin)}</p></div></div>`).join("") || bos("Henüz bildiri yok.")}</section>
      <section class="tox-kart"><h2>Üye şirketler</h2>${(d.uyeler || []).map(u => `<div class="to-satir">${e(u.ad)} <span class="kucuk">${e(u.il || "")} · ${e(u.yonetici || "")}</span></div>`).join("") || bos("Üye yok.")}</section>
      ${(d.hareketler || []).length ? `<section class="tox-kart"><details><summary><b>Kasa hareketleri</b></summary>${d.hareketler.map(h => kv(e(h.aciklama || "") + " · " + tarihSaat(h.zaman), tl(h.tutar))).join("")}</details></section>` : ""}
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
