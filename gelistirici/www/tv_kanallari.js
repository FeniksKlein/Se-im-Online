/* 11.11.2026 · TV Kanalları — sunucu modülü 198.
   Kanal kurma, maaşlı sunucu, zamanlı canlı program (siyasi düello / söyleşi / haber), konuk daveti, canlı yazışma,
   izleyici sayısı ve listesi, alkış / yuh, düello oylaması, izleyici başına ücretli reklam. Mevcut ekranlara dokunmaz.
   12.11.2026 · Yayın Merkezi tasarımı: yayın monitörü, saatli yayın akışı, kanal logoları, düello köşeleri, ekran içi sekmeler.
   RPC'ler, parametreler ve form alanı kimlikleri aynen korunur. */
(function () {
  "use strict";
  if (window.SO_TV_KANALLARI_V1) return;
  window.SO_TV_KANALLARI_V1 = true;

  const rpc = (fn, a) => API.rpc(fn, a);
  const KX = () => window.SO_KX;
  const tl = x => (Number(x) || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺";
  const n = x => (Number(x) || 0).toLocaleString("tr-TR");
  const kv = (a, b) => `<div class="kv"><span class="k">${a}</span><span class="v">${b}</span></div>`;
  const bos = m => `<div class="tvx-bos">${m}</div>`;
  const kisi = k => k ? `<b>${e(k.kad)}</b>${k.unvan ? ` <span class="kucuk" style="color:var(--gold2)">${e(k.unvan)}</span>` : ""}` : "—";
  const hataEkran = (b, err) => iskelet(b, `<div class="bos">${e(hataCevir(err.message))}</div><button class="btn ikinci" onclick="yenidenCiz()">Tekrar dene</button>`, { geri: true });
  const benimKad = () => { try { return D.durum.profil.kad; } catch (_) { return ""; } };
  // kesintisiz_ekran.js, kullanıcı eylemi olmadan gelen çizimleri erteleyebilir; seçim kutusu gibi düğme dışı eylemleri bildirir
  const eylem = () => { try { if (window.SO_KESINTISIZ) window.SO_KESINTISIZ.eylem = Date.now(); } catch (_) {} };
  const ROL = { sunucu: "Sunucu", konuk: "Konuk", reklam: "Reklam" };
  const SURELER = [[10, "10 dakika"], [15, "15 dakika"], [20, "20 dakika"], [30, "30 dakika"], [45, "45 dakika"], [60, "1 saat"], [90, "1,5 saat"], [120, "2 saat"], [180, "3 saat"]];
  const TUR = { duello: ["Siyasi düello", "İki ya da daha çok konuk tartışır, izleyiciler en ikna ediciyi oylar."], soylesi: ["Söyleşi", "Sunucu konuklarına soru sorar; oylama yok."], haber: ["Haber programı", "Sunucu gündemi aktarır, konuk çağırabilir."] };
  // düello köşe renkleri: 1. konuk mavi, 2. konuk kırmızı, sonrakiler sırayla
  const KOSE = ["#4C8DFF", "#F0454B", "#2FBF8F", "#F2B33D", "#B07CFF", "#3FC5E0"];
  const ton = s => (KX() ? KX().ton(s) : 250);
  const harf = s => (KX() ? KX().harfler(s, 2) : "TV");
  const logo = (ad, cls) => `<span class="tvx-logo ${cls || ""}" style="--h:${ton(ad)}" aria-hidden="true">${e(harf(ad))}</span>`;

  function stil() {
    if (KX()) KX().stil();
    if (document.getElementById("tvStil")) return;
    const s = document.createElement("style"); s.id = "tvStil";
    s.textContent = `
      .tv-canli{display:inline-flex;align-items:center;gap:5px;background:#F0454B;color:#fff;font-size:11px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;padding:2px 8px 2px 7px;border-radius:999px;margin-right:6px;vertical-align:middle;line-height:1.5}
      .tv-canli::before{content:"";width:6px;height:6px;border-radius:50%;background:#fff;animation:tvNabiz 1.4s ease-in-out infinite}
      @keyframes tvNabiz{50%{opacity:.25}}
      @media (prefers-reduced-motion:reduce){.tv-canli::before{animation:none}}
      .tvx{--kx:#E23A40}
      .tvx .tvx-bos{padding:14px 2px;font-size:14px;line-height:1.45;color:var(--mut)}
      /* kanal logosu: kanal adından üretilen istasyon amblemi */
      .tvx-logo{flex:none;display:inline-grid;place-items:center;width:34px;height:34px;border-radius:10px;font-family:var(--disp);font-weight:700;font-size:15px;letter-spacing:.02em;color:#fff;
        background:linear-gradient(150deg,hsl(var(--h) 70% 52%),hsl(calc(var(--h) + 40) 62% 30%));box-shadow:inset 0 1px 0 rgba(255,255,255,.28),0 4px 12px -6px hsl(var(--h) 70% 40%)}
      .tvx-logo.b{width:58px;height:58px;border-radius:16px;font-size:24px}
      .tvx-logo.k{width:26px;height:26px;border-radius:8px;font-size:12px}
      /* yayın monitörü */
      .tvx-ekran{position:relative;display:block;width:100%;text-align:left;margin:0 0 12px;padding:14px 14px 13px;border-radius:20px;overflow:hidden;color:#F4F6FF;
        background:radial-gradient(120% 90% at 85% 0%,hsl(var(--h,350) 60% 30% / .55),transparent 60%),linear-gradient(180deg,#0A0F24,#060917);
        box-shadow:inset 0 0 0 1px rgba(255,255,255,.08),inset 0 0 40px rgba(0,0,0,.5),0 18px 34px -26px #000}
      .tvx-ekran::after{content:"";position:absolute;inset:0;pointer-events:none;background:repeating-linear-gradient(0deg,rgba(255,255,255,.025) 0 1px,transparent 1px 3px);border-radius:inherit}
      .tvx-ekran.canli{box-shadow:inset 0 0 0 1.5px rgba(240,69,75,.75),inset 0 0 40px rgba(0,0,0,.5),0 18px 34px -22px rgba(240,69,75,.6)}
      .tvx-e-ust{display:flex;align-items:center;gap:9px;position:relative;z-index:1}
      .tvx-e-ust .tvx-e-kanal{flex:1;min-width:0;font-weight:800;font-size:14px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
      .tvx-e-ust .tvx-e-saat{font-variant-numeric:tabular-nums;font-size:12.5px;color:#C9D1E6}
      .tvx-e-orta{position:relative;z-index:1;margin:22px 0 14px}
      .tvx-e-orta small{display:block;font-size:12.5px;color:#FF9A9E;font-weight:750;margin-bottom:4px}
      .tvx-ekran:not(.canli) .tvx-e-orta small{color:#B5C3FF}
      .tvx-e-orta h2{font-family:var(--disp);font-size:25px;line-height:1.12;margin:0;color:#fff;text-wrap:balance;overflow-wrap:anywhere}
      .tvx-e-orta p{margin:7px 0 0;font-size:13px;line-height:1.4;color:#C9D1E6;overflow-wrap:anywhere}
      .tvx-e-alt{position:relative;z-index:1;display:flex;align-items:center;gap:12px}
      .tvx-e-alt .tvx-izl{flex:1;min-width:0;font-size:12.5px;color:#C9D1E6;line-height:1.3}
      .tvx-e-alt .tvx-izl b{display:block;font-family:var(--disp);font-size:24px;line-height:1;color:#fff;font-variant-numeric:tabular-nums}
      .tvx-e-alt .btn{width:auto;flex:none;margin:0;padding:11px 18px;min-height:44px}
      .tvx-cubuk{display:flex;height:5px;border-radius:3px;overflow:hidden;margin:0 0 14px;position:relative;z-index:1}
      .tvx-cubuk i{flex:1}
      .tvx-sayac{font-family:var(--disp);font-size:30px;line-height:1;color:#fff;font-variant-numeric:tabular-nums;letter-spacing:.01em}
      /* gelen teklif / davet */
      .tvx-gelen{padding:13px 14px;border-radius:16px;margin:0 0 10px;background:linear-gradient(135deg,rgba(242,179,61,.13),rgba(242,179,61,.03));box-shadow:inset 0 0 0 1px rgba(242,179,61,.4)}
      .tvx-gelen h2{font-size:16px;margin:0 0 4px}
      .tvx-gelen p{font-size:14px;line-height:1.45;color:var(--txt2);margin:0 0 10px}
      .tv-iki{display:flex;gap:8px;flex-wrap:wrap}
      .tv-iki .btn{flex:1;min-width:120px;margin:0}
      /* yayın akışı: saat sütunlu liste */
      .tvx-gun{font-size:13px;font-weight:800;color:var(--txt2);margin:14px 2px 6px}
      .tvx-gun:first-child{margin-top:0}
      .tvx-akis{display:flex;gap:12px;width:100%;text-align:left;padding:12px;border-radius:14px;background:var(--panel);box-shadow:inset 0 0 0 1px var(--line);margin-bottom:8px;color:var(--txt)}
      .tvx-akis .tvx-saat{flex:none;width:52px;font-family:var(--disp);font-size:20px;line-height:1.1;font-variant-numeric:tabular-nums;color:#fff}
      .tvx-akis .tvx-saat small{display:block;font-family:inherit;font-size:11.5px;font-weight:600;color:var(--mut);margin-top:3px}
      .tvx-akis .tvx-a-g{flex:1;min-width:0}
      .tvx-akis .tvx-a-g b{display:block;font-size:15px;line-height:1.3;overflow-wrap:anywhere}
      .tvx-akis .tvx-a-g span{display:flex;align-items:center;gap:6px;margin-top:5px;font-size:12.5px;color:var(--mut);overflow-wrap:anywhere}
      .tvx-akis .tvx-a-g em{display:block;font-style:normal;font-size:12.5px;color:var(--txt2);margin-top:4px;overflow-wrap:anywhere}
      .tvx-akis.canli{box-shadow:inset 0 0 0 1.5px rgba(240,69,75,.6);background:linear-gradient(90deg,rgba(240,69,75,.10),transparent 60%),var(--panel)}
      .tvx-akis.canli .tvx-saat{color:#FF8A8E}
      .tvx-akis .tvx-ok{flex:none;align-self:center;color:var(--faint);font-size:20px}
      /* kanal ızgarası */
      .tvx-izgara{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}
      .tvx-kanal{position:relative;display:flex;flex-direction:column;align-items:flex-start;gap:9px;padding:13px 12px 12px;min-width:0;border-radius:16px;text-align:left;color:var(--txt);background:var(--panel);box-shadow:inset 0 0 0 1px var(--line)}
      .tvx-kanal b{font-size:15px;line-height:1.25;overflow-wrap:anywhere}
      .tvx-kanal small{font-size:12px;line-height:1.35;color:var(--mut);overflow-wrap:anywhere}
      .tvx-kanal .tv-canli{position:absolute;top:12px;right:10px;margin:0}
      .tvx-kanal.ben{box-shadow:inset 0 0 0 1.5px rgba(242,179,61,.6)}
      /* kanal kurma: canlı amblem önizlemesi */
      .tvx-kur{display:flex;align-items:center;gap:12px;margin-bottom:12px}
      .tvx-kur b{display:block;font-size:17px}
      .tvx-kur small{font-size:12.5px;color:var(--mut)}
      /* kanal künyesi */
      .tvx-kunye{display:flex;gap:13px;align-items:center}
      .tvx-kunye h2{font-family:var(--disp);font-size:24px;line-height:1.1;margin:0;overflow-wrap:anywhere}
      .tvx-kunye p{margin:4px 0 0;font-size:13.5px;color:var(--txt2);line-height:1.4;overflow-wrap:anywhere}
      .tv-satir{padding:11px 0;border-bottom:1px solid var(--line2);overflow-wrap:anywhere}
      .tv-satir:last-child{border-bottom:0}
      .tv-satir .btn{margin-top:8px}
      .tvx-kasa{font-family:var(--disp);font-size:32px;line-height:1.05;color:#fff;font-variant-numeric:tabular-nums;margin:2px 0 4px}
      /* stüdyo */
      .tvx-kose{display:grid;grid-template-columns:repeat(var(--n,2),minmax(0,1fr));gap:8px;margin:0 0 12px}
      .tvx-kose .btn{position:relative;display:flex;flex-direction:column;align-items:flex-start;justify-content:flex-start;gap:2px;margin:0;padding:11px 11px 12px;min-height:76px;text-align:left;border-radius:14px;color:var(--txt);
        background:linear-gradient(160deg,color-mix(in srgb,var(--k) 22%,transparent),transparent 70%),var(--panel);box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--k) 45%,transparent)}
      .tvx-kose .btn.altin{box-shadow:inset 0 0 0 2px var(--k),0 8px 18px -12px var(--k)}
      .tvx-kose .btn b{font-size:15px;line-height:1.2;overflow-wrap:anywhere}
      .tvx-kose .btn small{font-size:12px;color:var(--txt2)}
      .tvx-kose .btn .tvx-pay{font-family:var(--disp);font-size:22px;line-height:1.1;color:#fff;font-variant-numeric:tabular-nums;margin-top:4px}
      .tvx-kose .btn .tvx-bar{position:absolute;left:11px;right:11px;bottom:7px;height:3px;border-radius:2px;background:rgba(255,255,255,.1);overflow:hidden}
      .tvx-kose .btn .tvx-bar i{display:block;height:100%;background:var(--k)}
      .tvx-kose .btn .tvx-sec{position:absolute;top:9px;right:9px;font-size:10.5px;font-weight:800;padding:1px 7px;border-radius:999px;background:var(--k);color:#fff}
      .tvx-oyb{margin:0 0 4px}
      .tvx-oyb h2{font-size:16px;margin:0 0 3px}
      .tvx-oyb p{font-size:12.5px;color:var(--mut);margin:0 0 10px;line-height:1.4}
      .tv-oda{max-height:56vh;min-height:170px;overflow-y:auto;overscroll-behavior:contain;padding:2px 2px 4px}
      .tv-mesaj{max-width:88%;margin:0 0 10px;padding:9px 12px 10px;border-radius:16px;overflow-wrap:anywhere;background:var(--panel2);box-shadow:inset 3px 0 0 var(--k,var(--ink2))}
      .tv-mesaj p{margin:4px 0 0;font-size:15px;line-height:1.45;white-space:pre-wrap;color:var(--txt)}
      .tv-mesaj .tvx-m-bas{display:flex;align-items:baseline;gap:7px;flex-wrap:wrap;font-size:13px}
      .tv-mesaj .tvx-m-bas b{color:var(--k,var(--txt))}
      .tv-mesaj .tvx-m-bas .kucuk{color:var(--faint)}
      .tv-mesaj.sunucu{max-width:100%;background:rgba(255,255,255,.04);box-shadow:inset 0 0 0 1px var(--line2);--k:#E8EBF6}
      .tv-mesaj.konuk.sag{margin-left:auto;box-shadow:inset -3px 0 0 var(--k)}
      .tv-mesaj.konuk.sag .tvx-m-bas{justify-content:flex-end}
      .tv-mesaj.reklam{max-width:100%;display:flex;gap:10px;align-items:center;background:repeating-linear-gradient(135deg,rgba(242,179,61,.10) 0 10px,rgba(242,179,61,.05) 10px 20px);box-shadow:inset 0 0 0 1px rgba(242,179,61,.3)}
      .tv-mesaj.reklam p{margin:0;font-size:14px}
      .tv-rol{display:inline-block;flex:none;font-size:10.5px;font-weight:800;text-transform:uppercase;letter-spacing:.05em;padding:1px 7px;border-radius:999px;border:1px solid currentColor;color:var(--mut)}
      .tv-mesaj.reklam .tv-rol{color:#F2B33D}
      .tvx-yaz{display:flex;gap:8px;align-items:flex-end}
      .tvx-yaz textarea{flex:1;min-width:0;min-height:48px;max-height:140px;resize:vertical;font-size:16px}
      .tvx-yaz .btn{width:auto;flex:none;margin:0;min-height:48px;padding:0 18px}
      .tvx-tepki{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:0 0 12px}
      .tvx-tepki .btn{margin:0;min-height:52px;font-size:15px}
      .tvx-tepki .btn i{font-style:normal;font-variant-numeric:tabular-nums;opacity:.75;font-weight:700;margin-left:2px}
      .tv-izl{margin:8px 0 0;font-size:14px;line-height:1.6;overflow-wrap:anywhere}
      .tv-sponsor{font-size:12.5px;color:#C9D1E6;margin-top:10px;position:relative;z-index:1;overflow-wrap:anywhere}
      .tv-yaz{width:100%;min-height:64px;resize:vertical}
      .tvx-tur{display:grid;gap:8px;margin:0 0 4px}
      .tvx-tur label{display:flex;gap:10px;align-items:flex-start;padding:11px 12px;border-radius:12px;background:var(--panel2);box-shadow:inset 0 0 0 1px var(--line2);cursor:pointer}
      .tvx-tur label:has(input:checked){box-shadow:inset 0 0 0 2px var(--kx)}
      .tvx-tur input{margin-top:3px;accent-color:#E23A40;width:18px;height:18px;flex:none}
      .tvx-tur b{display:block;font-size:14.5px}.tvx-tur small{display:block;font-size:12.5px;color:var(--mut);line-height:1.35;margin-top:2px}
      .tvx-ozet{font-size:13px;color:var(--txt2);margin:4px 0 0}
      @media (max-width:350px){.tvx-e-orta h2{font-size:21px}.tvx-kose{grid-template-columns:1fr 1fr}.tvx-akis .tvx-saat{width:46px;font-size:18px}}`;
    document.head.appendChild(s);
  }

  /* ------------------------------------------------------------------ ortak parçalar */
  function progZaman(p) {
    if (p.durum === "canli") return p.acik_uclu ? "Sunucu bitirene kadar" : "Bitiş " + saatYaz(p.bit);
    if (p.durum === "planli") return tarihSaat(p.bas) + (p.acik_uclu ? " · sunucu bitirene kadar" : " – " + saatYaz(p.bit));
    if (p.durum === "iptal") return "İptal edildi";
    return "Bitti · " + tarihSaat(p.bit);
  }
  const konukYazi = p => (p.konuklar || []).length ? "Konuklar: " + p.konuklar.map(e).join(", ") : "";
  // yayın akışı satırı: solda saat, sağda program
  function akisSatir(p, kanalGoster) {
    const canli = p.durum === "canli", bitti = p.durum === "bitti" || p.durum === "iptal";
    const saat = canli ? `<span class="tvx-saat">${saatYaz(p.bas)}<small>şimdi</small></span>`
      : bitti ? `<span class="tvx-saat">${saatYaz(p.bas)}<small>${tarih(p.bas)}</small></span>`
      : `<span class="tvx-saat">${saatYaz(p.bas)}<small>${p.acik_uclu ? "açık uçlu" : saatYaz(p.bit) + "’e dek"}</small></span>`;
    return `<button type="button" class="tvx-akis${canli ? " canli" : ""}" onclick="tvStudyoAc(${Number(p.id)})">${saat}
      <span class="tvx-a-g">${canli ? '<span class="tv-canli" style="margin:0 0 4px">Canlı</span>' : ""}<b>${e(p.baslik)}</b>
        <span>${kanalGoster ? logo(p.kanal, "k") + e(p.kanal) + " · " : ""}${e(p.tur_ad)} · sunucu ${e(p.sunucu || "—")}</span>
        ${konukYazi(p) ? `<em>${konukYazi(p)}</em>` : ""}
        <em>${canli ? `${n(p.izleyici)} izleyici · ${progZaman(p)}` : bitti ? `${p.durum === "iptal" ? "İptal edildi" : n(p.izleyici) + " izleyici"}` : ""}${p.reklam ? ` · ${p.reklam} reklam` : ""}</em>
      </span><span class="tvx-ok" aria-hidden="true">›</span></button>`;
  }
  // akışı güne göre gruplar (aynı gün başlığı tekrar etmez)
  function gunluAkis(liste, kanalGoster) {
    let son = "", h = "";
    const bugun = tarih(simdi()), yarin = tarih(simdi() + 864e5);
    liste.forEach(p => { const g = tarih(p.bas); if (g !== son) { son = g; h += `<div class="tvx-gun">${g === bugun ? "Bugün" : g === yarin ? "Yarın" : g}</div>`; } h += akisSatir(p, kanalGoster); });
    return h;
  }
  // yayın monitörü: canlı program ya da sıradaki yayın
  function monitor(p, canliSayi) {
    if (!p) return `<div class="tvx-ekran"><div class="tvx-cubuk">${["#e8e8e8", "#e3d84a", "#4ad6d9", "#4ad65a", "#d64ad0", "#d9473f", "#3f4fd9"].map(c => `<i style="background:${c};opacity:.55"></i>`).join("")}</div>
      <div class="tvx-e-orta" style="margin-top:6px"><small>Yayın yok</small><h2>Şu an canlı yayın yok</h2><p>Kanalların planladığı programlar Akış sekmesinde. Kendi kanalını kurup ilk yayını sen açabilirsin.</p></div></div>`;
    const canli = p.durum === "canli";
    if (!canli) {
      const ms = new Date(p.bas).getTime() - simdi();
      return `<button type="button" class="tvx-ekran" style="--h:${ton(p.kanal)}" onclick="tvStudyoAc(${Number(p.id)})">
        <div class="tvx-e-ust">${logo(p.kanal)}<span class="tvx-e-kanal">${e(p.kanal)}</span><span class="tvx-e-saat">${tarihSaat(p.bas)}</span></div>
        <div class="tvx-e-orta"><small>Sıradaki yayın · ${e(p.tur_ad)}</small><h2>${e(p.baslik)}</h2><p>Sunucu ${e(p.sunucu || "—")}${konukYazi(p) ? " · " + konukYazi(p) : ""}</p></div>
        <div class="tvx-e-alt"><span class="tvx-izl">Başlamasına<span class="tvx-sayac" style="display:block;margin-top:3px">${kalan(ms)}</span></span><span class="btn ikinci">Programa git</span></div></button>`;
    }
    return `<button type="button" class="tvx-ekran canli" style="--h:${ton(p.kanal)}" onclick="tvStudyoAc(${Number(p.id)})">
      <div class="tvx-e-ust">${logo(p.kanal)}<span class="tvx-e-kanal">${e(p.kanal)}</span><span class="tv-canli" style="margin:0">Canlı</span></div>
      <div class="tvx-e-orta"><small>${e(p.tur_ad)}</small><h2>${e(p.baslik)}</h2><p>Sunucu ${e(p.sunucu || "—")}${konukYazi(p) ? " · " + konukYazi(p) : ""}</p></div>
      <div class="tvx-e-alt"><span class="tvx-izl"><b>${n(p.izleyici)}</b>izleyici · ${progZaman(p)}${canliSayi > 1 ? `<br>${canliSayi - 1} canlı yayın daha` : ""}</span><span class="btn canli">Yayını izle</span></div></button>`;
  }
  // eski çağrılar için (başka modüller progKart beklemez ama ad korunur)
  const progKart = (p, kanalGoster) => akisSatir(p, kanalGoster);
  window.tvStudyoAc = id => ekranAc(() => window.tvStudyoEkrani(id));
  window.tvKanalAc = id => ekranAc(() => window.tvKanalEkrani(id));
  const yaziyor = kok => { const k = document.getElementById(kok); return !!k && Array.prototype.some.call(k.querySelectorAll("input,textarea"), x => x.type !== "checkbox" && x.type !== "radio" && x.type !== "hidden" && (x.value || "").trim() !== ""); };

  /* ------------------------------------------------------------------ Gündem: öne çıkan TV kartı + canlı rozeti (45 sn önbellek) */
  let rozetOn = { t: 0, d: null };
  const ozetSifirla = () => { rozetOn.t = 0; };
  function gundemKartVeri(d) {
    const o = { id: "tvGundemKart", ikon: "tv", renk: "229,72,77", acik: "#ffb1b5", etiket: "TV Kanalları", git: "Aç", onclick: "ekranAc(tvKanallariEkrani)", canli: false };
    d = d || {};
    if (d.ilk) {
      o.canli = true; o.etiket = d.ilk.kanal + " · " + d.ilk.tur_ad; o.baslik = d.ilk.baslik;
      o.alt = `${d.ilk.izleyici} kişi izliyor · sunucu ${d.ilk.sunucu || ""}${Number(d.canli) > 1 ? " · " + (d.canli - 1) + " canlı yayın daha" : ""}`;
      o.git = "İzle"; o.onclick = "tvStudyoAc(" + Number(d.ilk.id) + ")";
    } else if (Number(d.davet) > 0) {
      o.baslik = d.davet + " program davetin var"; o.alt = "Bir TV programına konuk olarak çağrıldın; yanıtını bekliyorlar."; o.git = "Yanıtla";
    } else if (Number(d.teklif) > 0) {
      o.baslik = "Sunuculuk teklifin var"; o.alt = "Bir TV kanalı sana günlük ücretle sunuculuk teklif etti."; o.git = "Yanıtla";
    } else if (d.siradaki) {
      o.etiket = "TV Kanalları · yayın akışı"; o.baslik = tarihSaat(d.siradaki.bas) + " · " + d.siradaki.baslik;
      o.alt = `${d.siradaki.kanal} · ${d.siradaki.tur_ad}${Number(d.yakinda) > 1 ? " · " + d.yakinda + " program planlandı" : ""}`; o.git = "Akış";
    } else {
      o.baslik = "Canlı yayınlar ve siyasi düellolar";
      o.alt = Number(d.kanal) > 0 ? `${d.kanal} kanal var; şu an yayın yok. Yayın akışına bak ya da kendi kanalını kur.` : "Henüz kanal yok. İlk TV kanalını sen kur; program yap, reklam al.";
    }
    return o;
  }
  const gundemde = () => { try { const h = document.querySelector("header.ust h1"); return D.sekme === "gundem" && !(D.yigin || []).length && !!h && h.textContent.trim() === "Gündem"; } catch (_) { return false; } };
  function gundemKartKoy(d) {
    if (!window.SO_ONE_CIKAN || !gundemde()) return;
    window.SO_ONE_CIKAN.koy(gundemKartVeri(d), ic => {
      const hz = ic.querySelector('.pa-hizli[data-pa-hizli="gundem"]'); if (hz) return { el: hz, yer: "afterend" };
      const ks = ic.querySelector(".so-gundem-kisa"); if (ks) return { el: ks, yer: "beforebegin" };
      return { el: ic, yer: "afterbegin" };
    });
  }
  window.tvGundemRozet = async function () {
    const yaz = d => { if (!d) return; const h = Number(d.canli) > 0 || d.ilk ? '<span class="tv-canli" style="margin:0 0 0 4px">Canlı</span>' : "";
      document.querySelectorAll(".tv-gundem-rozet").forEach(el => { if (el.innerHTML !== h) el.innerHTML = h; }); };
    try {
      stil();
      if (window.SO_ONE_CIKAN) window.SO_ONE_CIKAN.tekrarla(() => gundemKartKoy(rozetOn.d));
      yaz(rozetOn.d);
      if (rozetOn.d && Date.now() - rozetOn.t < 45000) return;
      rozetOn = { t: Date.now(), d: rozetOn.d };
      const d = await rpc("tv_canli_ozet"); rozetOn = { t: Date.now(), d }; yaz(d); gundemKartKoy(d);
    } catch (_) {}
  };

  /* ------------------------------------------------------------------ ana ekran: Yayın Merkezi */
  window.tvKanallariEkrani = async function () {
    stil();
    if (!document.getElementById("tvKok")) yukleniyor("TV Kanalları");
    let d; try { d = await rpc("tv_liste"); } catch (err) { return hataEkran("TV Kanalları", err); }
    const teklif = d.sunucu_teklif || [], davet = d.davetlerim || [], canli = d.canli || [], yakinda = d.yakinda || [], biten = d.biten || [], kanallar = d.kanallar || [], sun = d.sunuculuk || [];
    const enCok = canli.slice().sort((a, b) => (b.izleyici || 0) - (a.izleyici || 0))[0];
    const SEK = [["yayin", "Yayında", canli.length ? String(canli.length) : ""], ["akis", "Akış", yakinda.length ? String(yakinda.length) : ""], ["kanallar", "Kanallar", String(kanallar.length)],
      ["kanalim", d.kanalim ? "Kanalım" : sun.length ? "Kanallarım" : "Kanal kur"], ["arsiv", "Arşiv"]];
    const akt = KX() ? KX().secili("tv", SEK, "yayin") : "yayin";
    const pano = (k, h) => KX() ? KX().pano("tv", k, akt, h) : h;
    const gelen = teklif.map(x => `<section class="tvx-gelen"><h2>Sunuculuk teklifi</h2>
        <p><b>${e(x.kanal)}</b> (sahibi ${e(x.sahip)}) sana günlük <b>${tl(x.gunluk_ucret)}</b> ücretle sunuculuk teklif ediyor. Ücret her gün kanal kasasından cüzdanına ödenir; dilediğinde ayrılabilirsin.</p>
        <div class="tv-iki"><button class="btn altin" onclick="tvSunucuYanit(${x.kanal_id},true)">Kabul et</button><button class="btn ikinci" onclick="tvSunucuYanit(${x.kanal_id},false)">Reddet</button></div></section>`).join("")
      + (davet.length ? `<section class="tvx-gelen"><h2>Program davetlerin</h2>${davet.map(p => `<div class="tv-satir"><b>${e(p.baslik)}</b>
        <div class="kucuk">${e(p.kanal)} · ${e(p.tur_ad)} · sunucu ${e(p.sunucu || "")} · ${progZaman(p)}</div>
        <div class="tv-iki" style="margin-top:8px"><button class="btn altin" onclick="tvKonukYanit(${p.id},true,true)">Katılıyorum</button><button class="btn ikinci" onclick="tvKonukYanit(${p.id},false,true)">Katılamam</button></div></div>`).join("")}</section>` : "");
    const kanalimHtml = (d.kanalim ? `<section class="kart"><div class="tvx-kunye">${logo(d.kanalim.ad, "b")}<div><h2>${e(d.kanalim.ad)}</h2><p>Kanalının sahibisin. Program aç, sunucu al, reklamları onayla.</p></div></div>
          <button class="btn altin" style="margin-top:12px" onclick="tvKanalAc(${d.kanalim.id})">Kanalımı yönet</button></section>`
        : `<section class="kart"><h2>TV kanalı kur</h2>
          <div class="tvx-kur">${logo("Yeni Kanal", "b").replace('aria-hidden="true"', 'id="tvKurLogo" aria-hidden="true"')}<div><b id="tvKurAd">Kanalının adı</b><small>Kanal amblemi adından oluşur.</small></div></div>
          <p class="alt">Canlı programlar ve siyasi düellolar düzenle, maaşlı sunucu çalıştır, yayınlarına reklam alıp para kazan. Yayın lisansı <b>${tl(d.kur_ucret)}</b>, cüzdanından ödenir.</p>
          <div class="alan"><label for="tvKAd">Kanal adı</label><input id="tvKAd" maxlength="40" placeholder="Örn. Başkent TV" oninput="tvKurOnizle(this.value)"></div>
          <div class="alan"><label for="tvKSlogan">Slogan (isteğe bağlı)</label><input id="tvKSlogan" maxlength="120"></div>
          <button class="btn altin" onclick="tvKanalKur()">Kanalı kur</button></section>`)
      + (sun.length ? `<section class="kart"><h2>Sunuculuk yaptığım kanallar</h2>${sun.map(x => `<div class="tv-satir" style="display:flex;gap:10px;align-items:center;flex-wrap:wrap">${logo(x.kanal)}<span style="flex:1;min-width:0"><b>${e(x.kanal)}</b><br><span class="kucuk">günlük ${tl(x.gunluk_ucret)}</span></span>
          <button class="btn ikinci" style="margin:0" onclick="tvKanalAc(${x.kanal_id})">Kanala git, program aç</button></div>`).join("")}</section>` : "");
    iskelet("TV Kanalları", `<div id="tvKok" class="tvx">
      ${monitor(enCok || yakinda[0], canli.length)}
      ${gelen}
      ${KX() ? KX().sekmeler("tv", SEK, akt, "#E23A40") : ""}
      ${pano("yayin", `
        ${enCok ? (KX() ? KX().bas("Şu an yayında", canli.length + " yayın") : "<h2>Şu an yayında</h2>") + canli.map(p => akisSatir(p, true)).join("")
          : (KX() ? KX().bas("Şu an yayında") : "") + bos("Şu an canlı yayın yok.") + (yakinda.length ? `<button class="btn ikinci" onclick="SO_KX.gec('tv','akis')">Yayın akışına bak</button>` : "")}`)}
      ${pano("akis", (KX() ? KX().bas("Yayın akışı", "saati gelince kendiliğinden başlar") : "<h2>Yayın akışı</h2>") + (yakinda.length ? gunluAkis(yakinda, true) : bos("Planlanmış program yok."))) }
      ${pano("kanallar", (KX() ? KX().bas("Kanallar", kanallar.length + " kanal") : "<h2>Kanallar</h2>") + (kanallar.length ? `<div class="tvx-izgara">${kanallar.map(k => `<button type="button" class="tvx-kanal${d.kanalim && d.kanalim.id === k.id ? " ben" : ""}" onclick="tvKanalAc(${k.id})">${k.canli ? '<span class="tv-canli">Canlı</span>' : ""}${logo(k.ad)}
          <span><b>${e(k.ad)}</b></span><small>${k.slogan ? e(k.slogan) + "<br>" : ""}Sahibi ${e(k.sahip)}<br>${n(k.program)} program · ${n(k.toplam_izleyici)} izlenme</small></button>`).join("")}</div>` : bos("Henüz kurulmuş kanal yok. İlk kanalı sen kur.")))}
      ${pano("kanalim", kanalimHtml)}
      ${pano("arsiv", (KX() ? KX().bas("Biten programlar") : "<h2>Biten programlar</h2>") + (biten.map(p => akisSatir(p, true)).join("") || bos("Henüz biten program yok.")))}
    </div>`, { geri: D.yigin.length > 0 });
    const taz = async () => { if (!document.getElementById("tvKok") || document.hidden || $("#modal") || yaziyor("tvKok")) return; window.tvKanallariEkrani(); };
    if (window.CANLI && CANLI.izle) CANLI.izle({ anahtarlar: [], tazele: taz, hizliMs: 30000, yedekMs: 30000, yayilim: 3000 });
  };
  window.tvKurOnizle = v => {
    const ad = (v || "").trim(), l = document.getElementById("tvKurLogo"), b = document.getElementById("tvKurAd");
    if (l) { l.style.setProperty("--h", ton(ad || "Yeni Kanal")); l.textContent = harf(ad || "Yeni Kanal"); }
    if (b) b.textContent = ad || "Kanalının adı";
  };

  const anaCalis = async (fn, basari, sonra) => { try { const r = await fn(); ozetSifirla(); if (basari) toast(typeof basari === "function" ? basari(r) : basari); if (sonra) await sonra(r); else await yenidenCiz(); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvKanalKur = async () => {
    const ad = ($("#tvKAd").value || "").trim(), sl = ($("#tvKSlogan").value || "").trim();
    if (ad.length < 3) return toast("Kanal adı en az 3 karakter olmalı.", true);
    if (!await onayla("TV kanalı kur", `"${e(ad)}" kanalı kurulacak. Yayın lisansı ${tl(250000)} cüzdanından alınır ve iade edilmez.`, "Kanalı kur")) return;
    return anaCalis(() => rpc("tv_kanal_kur", { p_ad: ad, p_slogan: sl || null }), "Kanalın kuruldu.", r => { $("#tvKAd").value = ""; $("#tvKSlogan").value = ""; window.tvKanalAc(r.id); });
  };
  window.tvSunucuYanit = (kanal, kabul) => anaCalis(() => rpc("tv_sunucu_yanit", { p_kanal: kanal, p_kabul: kabul }), kabul ? "Sunuculuk sözleşmen başladı." : "Teklif reddedildi.");
  window.tvKonukYanit = (prog, kabul, listeden) => anaCalis(() => rpc("tv_konuk_yanit", { p_program: prog, p_kabul: kabul }), kabul ? "Programa konuk oldun." : "Davet reddedildi.",
    listeden && kabul ? () => window.tvStudyoAc(prog) : null);

  /* ------------------------------------------------------------------ kanal ekranı */
  window.tvKanalEkrani = async function (id) {
    stil();
    if (!document.getElementById("tvKanalKok")) yukleniyor("TV kanalı");
    let d; try { d = await rpc("tv_kanal_detay", { p_kanal: id }); } catch (err) { return hataEkran("TV kanalı", err); }
    const sunucular = d.sunucular || [], aktifSun = sunucular.filter(s => s.durum === "aktif"), ben = benimKad();
    const benSunucu = !d.benim && aktifSun.some(s => s.kad === ben);
    const programlar = d.programlar || [], gecmis = d.gecmis || [], bekleyen = d.bekleyen_reklam || [];
    const canliP = programlar.find(p => p.durum === "canli");
    const SEK = [["akis", "Yayın akışı", programlar.length ? String(programlar.length) : ""]]
      .concat(d.yayinciyim ? [["program", "Program aç"]] : [])
      .concat(d.benim ? [["kasa", "Kasa ve reklam", bekleyen.length ? String(bekleyen.length) : "", bekleyen.length > 0], ["sunucu", "Sunucular", String(aktifSun.length)]] : [])
      .concat([["arsiv", "Geçmiş"]]);
    const varsay = d.benim && bekleyen.length ? "kasa" : "akis";
    const akt = KX() ? KX().secili("tvk" + id, SEK, varsay) : varsay;
    const pano = (k, h) => KX() ? KX().pano("tvk" + id, k, akt, h) : h;
    const kasaHtml = d.benim ? `
      <section class="kart"><h2>Kanal kasası</h2>
        <div class="tvx-kasa">${tl(d.kasa)}</div>
        <p class="alt">Reklam gelirleri kasaya girer, sunucu ücretleri kasadan ödenir. Kasadaki parayı cüzdanına çekebilirsin.</p>
        <div class="alan" style="margin-top:8px"><label for="tvKasaT">Tutar (₺)</label><input id="tvKasaT" type="number" inputmode="numeric" min="100" step="100"></div>
        <div class="tv-iki"><button class="btn ikinci" onclick="tvKasa(${d.id},'yatir')">Kasaya yatır</button><button class="btn altin" onclick="tvKasa(${d.id},'cek')">Cüzdanıma çek</button></div>
        ${(d.hareketler || []).length ? `<details style="margin-top:12px"><summary class="kucuk" style="cursor:pointer">Kasa hareketleri (${d.hareketler.length})</summary>${d.hareketler.map(h => kv(e(h.aciklama || "") + " · " + tarihSaat(h.zaman), `<span style="color:${Number(h.tutar) < 0 ? "var(--al2)" : "var(--good)"}">${tl(h.tutar)}</span>`)).join("")}</details>` : ""}</section>
      <section class="kart"><h2>Onay bekleyen reklam talepleri</h2>
        ${bekleyen.map(r => `<div class="tv-satir"><b>${e(r.marka)}</b> <span class="kucuk">${e(r.sirket || r.veren)} · bütçe ${tl(r.butce)} · izleyici başına ${tl(r.birim)}</span>
          <div class="kucuk">"${e(r.metin)}" · program: ${e(r.program)} (${tarihSaat(r.program_bas)})</div>
          <div class="kucuk" style="color:var(--good)">En çok ${n(Math.floor(r.butce / Math.max(1, r.birim)))} izleyiciye kadar gelir getirir.</div>
          <div class="tv-iki" style="margin-top:8px"><button class="btn altin" onclick="tvReklamKarar(${r.id},true,${d.id})">Onayla</button><button class="btn ikinci" onclick="tvReklamKarar(${r.id},false,${d.id})">Reddet</button></div></div>`).join("") || bos("Bekleyen reklam talebi yok.")}</section>
      <section class="kart"><h2>Reklam ayarları</h2>
        <p class="alt">Reklamverenler programlarına bütçeli reklam verir; sen onaylarsın. Program bitince izleyici sayısı × birim ücret kadar (en çok bütçe) kazanırsın; %${d.reklam_vergisi} reklam vergisi kesilir.</p>
        <div class="alan"><label for="tvUcret">İzleyici başına reklam ücreti (₺, 50 – 2.000)</label><input id="tvUcret" type="number" inputmode="numeric" min="50" max="2000" step="10" data-ilk="${Number(d.izleyici_ucret)}" placeholder="${Number(d.izleyici_ucret)}"></div>
        <div class="alan"><label for="tvSlogan">Slogan</label><input id="tvSlogan" maxlength="120" placeholder="${e(d.slogan || "Slogan yaz")}"></div>
        <button class="btn ikinci" onclick="tvAyar(${d.id})">Kaydet</button></section>` : "";
    const sunucuHtml = d.benim ? `<section class="kart"><h2>Sunucular</h2>
        <p class="alt">Bir oyuncuya günlük ücretle sunuculuk teklif et. Kabul ederse ücreti her gün kanal kasasından ödenir; kasa yetmezse sözleşme sona erer.</p>
        ${sunucular.map(s => `<div class="tv-satir">${kisi(s)} <span class="kucuk">${s.durum === "aktif" ? "sunucu · " + tarih(s.bas) + " tarihinden beri" : "teklif bekliyor"} · günlük ${tl(s.gunluk_ucret)}${s.durum === "aktif" ? " · toplam " + tl(s.toplam) : ""}</span>
          <button class="btn ikinci" onclick="tvSunucuCikar(${d.id},'${e(s.kad)}',${s.durum === "aktif"})">${s.durum === "aktif" ? "Sözleşmeyi bitir" : "Teklifi geri çek"}</button></div>`).join("") || bos("Henüz sunucu yok; programları kendin sunabilirsin.")}
        ${aktifSun.length ? `<p class="kucuk" style="margin-top:6px">Günlük toplam sunucu gideri ${tl(aktifSun.reduce((t, s) => t + (Number(s.gunluk_ucret) || 0), 0))}; kasa bunu ${Math.floor((Number(d.kasa) || 0) / Math.max(1, aktifSun.reduce((t, s) => t + (Number(s.gunluk_ucret) || 0), 0)))} gün karşılar.</p>` : ""}
        <h3 style="margin-top:14px;font-size:15px">Yeni sunucu</h3>
        <div class="alan" style="margin-top:8px"><label for="tvSunKad">Kullanıcı adı</label><input id="tvSunKad" autocapitalize="off" maxlength="40"></div>
        <div class="alan"><label for="tvSunUcret">Günlük ücret (₺, 500 – 100.000)</label><input id="tvSunUcret" type="number" inputmode="numeric" min="500" max="100000" step="100"></div>
        <button class="btn ikinci" onclick="tvSunucuTeklif(${d.id})">Sunuculuk teklif et</button></section>` : "";
    const programAc = d.yayinciyim ? `
      <section class="kart"><h2>Program aç</h2>
        <p class="alt">Başlangıcı boş bırakırsan yayın hemen başlar. Tarih ve saat seçersen program yayın akışına girer ve saati gelince kendiliğinden başlar. Konukları programı açtıktan sonra çağırırsın.</p>
        <input type="hidden" id="tvTur" value="duello">
        <div class="tvx-tur" role="radiogroup" aria-label="Program türü">${Object.keys(TUR).map(k => `<label><input type="radio" name="tvTurSec" value="${k}"${k === "duello" ? " checked" : ""} onchange="document.getElementById('tvTur').value=this.value"><span><b>${TUR[k][0]}</b><small>${TUR[k][1]}</small></span></label>`).join("")}</div>
        <div class="alan"><label for="tvBaslik">Başlık</label><input id="tvBaslik" maxlength="90" placeholder="Örn. Ekonomi düellosu"></div>
        <div class="alan"><label for="tvAcik">Kısa açıklama (isteğe bağlı)</label><input id="tvAcik" maxlength="300"></div>
        <div class="alan"><label for="tvBas">Başlangıç (cihazının saatine göre; boş = hemen)</label><input id="tvBas" type="datetime-local"></div>
        <div class="alan"><label for="tvSure">Süre</label><select id="tvSure">${SURELER.map(s => `<option value="${s[0]}"${s[0] === 30 ? " selected" : ""}>${s[1]}</option>`).join("")}<option value="">Sunucu bitirene kadar (en çok 3 saat)</option></select></div>
        ${d.benim && aktifSun.length ? `<div class="alan"><label for="tvSun">Sunucu</label><select id="tvSun"><option value="">Ben sunacağım</option>${aktifSun.map(s => `<option value="${e(s.kad)}">${e(s.kad)}</option>`).join("")}</select></div>` : ""}
        <p class="kucuk">Bir kanal günde en çok 4 program açabilir.</p>
        <button class="btn altin" onclick="tvProgramAc(${d.id})">Programı aç</button></section>` : "";
    iskelet(d.ad, `<div id="tvKanalKok" class="tvx">
      <section class="kart" style="margin-bottom:12px"><div class="tvx-kunye">${logo(d.ad, "b")}<div style="min-width:0"><h2>${e(d.ad)}</h2>${d.slogan ? `<p>${e(d.slogan)}</p>` : ""}</div></div>
        ${KX() ? KX().sayilar([[n(programlar.length), "planlı / süren"], [n(gecmis.length), "geçmiş program"], [tl(d.izleyici_ucret).replace(" ₺", "₺"), "izleyici başı reklam"]]) : ""}
        <div style="margin-top:10px">${kv("Sahibi", kisi(d.sahip))}${kv("Kuruluş", tarih(d.kurulus))}${kv("Sunucular", aktifSun.map(s => e(s.kad)).join(", ") || "—")}${kv("İzleyici başına reklam ücreti", tl(d.izleyici_ucret))}</div>
        ${canliP ? `<button class="btn canli" style="margin-top:10px" onclick="tvStudyoAc(${canliP.id})">Şu an yayında: ${e(canliP.baslik)}</button>` : ""}
        ${benSunucu ? `<button class="btn ikinci" style="margin-top:8px" onclick="tvSunucuAyril(${d.id})">Sunuculuktan ayrıl</button>` : ""}</section>
      ${KX() ? KX().sekmeler("tvk" + id, SEK, akt, "#E23A40") : ""}
      ${pano("akis", (programlar.length ? gunluAkis(programlar, false) : bos("Planlanmış ya da süren program yok.")) + (d.yayinciyim ? `<button class="btn ikinci" onclick="SO_KX.gec('tvk${id}','program')">Yeni program aç</button>` : ""))}
      ${d.yayinciyim ? pano("program", programAc) : ""}
      ${d.benim ? pano("kasa", kasaHtml) + pano("sunucu", sunucuHtml) : ""}
      ${pano("arsiv", (KX() ? KX().bas("Geçmiş programlar") : "<h2>Geçmiş programlar</h2>") + (gecmis.map(p => akisSatir(p, false)).join("") || bos("Henüz biten program yok.")))}
    </div>`, { geri: true });
  };
  const kanalCalis = async (id, fn, basari) => { try { const r = await fn(); ozetSifirla(); if (basari) toast(basari); await window.tvKanalEkrani(id); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvKasa = async (id, yon) => {
    const el = $("#tvKasaT"), t = Math.round(Number(el.value) || 0); if (t < 100) return toast("En az 100 ₺ gir.", true);
    el.value = "";
    return kanalCalis(id, () => rpc("tv_kasa", { p_kanal: id, p_yon: yon, p_tutar: t }), yon === "yatir" ? tl(t) + " kasaya yatırıldı." : tl(t) + " cüzdanına geçti.");
  };
  window.tvAyar = id => {
    const u = $("#tvUcret"), s = $("#tvSlogan"), uv = (u.value || "").trim(), sv = (s.value || "").trim();
    if (!uv && !sv) return toast("Değiştirmek istediğin alanı doldur.", true);
    u.value = ""; s.value = "";
    return kanalCalis(id, () => rpc("tv_kanal_ayar", { p_kanal: id, p_slogan: sv || null, p_izleyici_ucret: uv ? Number(uv) : null }), "Kaydedildi.");
  };
  window.tvReklamKarar = (rid, onay, kanal) => kanalCalis(kanal, () => rpc("tv_reklam_karar", { p_reklam: rid, p_onay: onay }), onay ? "Reklam onaylandı." : "Reklam reddedildi, bütçe iade edildi.");
  window.tvSunucuTeklif = id => {
    const k = $("#tvSunKad"), u = $("#tvSunUcret"), kad = (k.value || "").trim(), uc = Math.round(Number(u.value) || 0);
    if (!kad || uc < 500) return toast("Kullanıcı adı ve en az 500 ₺ günlük ücret gir.", true);
    k.value = ""; u.value = "";
    return kanalCalis(id, () => rpc("tv_sunucu_teklif", { p_kanal: id, p_kad: kad, p_gunluk: uc }), "Teklif gönderildi.");
  };
  window.tvSunucuCikar = async (id, kad, aktif) => {
    if (aktif && !await onayla("Sözleşmeyi bitir", `${e(kad)} ile sunuculuk sözleşmesi sona erecek.`, "Bitir", true)) return;
    return kanalCalis(id, () => rpc("tv_sunucu_bitir", { p_kanal: id, p_kad: kad }), aktif ? "Sözleşme sona erdi." : "Teklif geri çekildi.");
  };
  window.tvSunucuAyril = async id => { if (!await onayla("Sunuculuktan ayrıl", "Bu kanaldaki sunuculuk sözleşmen sona erecek.", "Ayrıl", true)) return; return kanalCalis(id, () => rpc("tv_sunucu_bitir", { p_kanal: id, p_kad: null }), "Kanaldan ayrıldın."); };
  window.tvProgramAc = async id => {
    const baslik = ($("#tvBaslik").value || "").trim(), bas = $("#tvBas").value, sure = $("#tvSure").value, sun = $("#tvSun") ? $("#tvSun").value : "";
    if (baslik.length < 4) return toast("Program başlığı en az 4 karakter olmalı.", true);
    let basIso = null;
    if (bas) { const t = new Date(bas); if (isNaN(t.getTime())) return toast("Başlangıç tarihi geçersiz.", true); basIso = t.toISOString(); }
    try {
      const r = await rpc("tv_program_ac", { p_kanal: id, p_tur: $("#tvTur").value, p_baslik: baslik, p_aciklama: ($("#tvAcik").value || "").trim() || null,
        p_bas: basIso, p_dakika: sure ? Number(sure) : null, p_sunucu: sun || null });
      $("#tvBaslik").value = ""; $("#tvAcik").value = ""; $("#tvBas").value = ""; ozetSifirla();
      toast(r.durum === "canli" ? "Yayın başladı." : "Program yayın akışına eklendi.");
      window.tvStudyoAc(r.id);
    } catch (err) { toast(hataCevir(err.message), true); }
  };

  /* ------------------------------------------------------------------ stüdyo (yayın) ekranı */
  // konuğun köşe rengi ve yönü (düelloda karşılıklı)
  function koseler(d) {
    const m = {}; (d.konuk_liste || []).forEach((k, i) => { m[k.kad] = { renk: KOSE[i % KOSE.length], sag: i % 2 === 1 }; }); return m;
  }
  function mesajHtml(m, ks) {
    if (m.rol === "reklam") return `<div class="tv-mesaj reklam"><span class="tv-rol">Reklam</span><p>${e(m.metin)}</p></div>`;
    const k = ks && m.kisi && ks[m.kisi.kad];
    const sinif = m.rol === "konuk" ? "konuk" + (k && k.sag ? " sag" : "") : "sunucu";
    return `<div class="tv-mesaj ${sinif}"${k && m.rol === "konuk" ? ` style="--k:${k.renk}"` : ""}><div class="tvx-m-bas"><span class="tv-rol">${ROL[m.rol] || ""}</span>${kisi(m.kisi)} <span class="kucuk">${saatYaz(m.zaman)}</span></div><p>${e(m.metin)}</p></div>`;
  }
  const odaHtml = d => { const ks = koseler(d); return (d.mesajlar || []).map(m => mesajHtml(m, ks)).join("") || bos(d.durum === "planli" ? "Yayın henüz başlamadı. Saati gelince sunucu ve konuklar burada konuşur." : d.durum === "iptal" ? "Program iptal edildi." : "Henüz söz alınmadı."); };
  function sayacHtml(d) {
    const z = d.izleyiciler || {};
    return `${d.durum === "canli" ? `<b>${z.anlik || 0}</b> kişi izliyor · toplam ${z.toplam || 0} izleyici` : `${z.toplam || 0} izleyici`} · ${d.alkis} alkış · ${d.yuh} yuh`;
  }
  function izleyiciHtml(d) {
    const z = d.izleyiciler || {}, l = z.liste || [], sayi = d.durum === "canli" ? (z.anlik || 0) : (z.toplam || 0);
    return `<details ${window._tvIzlAcik ? "open" : ""} ontoggle="window._tvIzlAcik=this.open"><summary style="cursor:pointer"><b>${d.durum === "canli" ? "Şu an izleyenler" : "İzleyenler"} (${sayi})</b></summary>
      <p class="tv-izl">${l.map(e).join(" · ") || "Henüz izleyici yok."}${sayi > l.length ? ` · ve ${sayi - l.length} kişi daha` : ""}</p></details>`;
  }
  const konusmaci = d => d.rolum === "sunucu" || d.rolum === "konuk";
  function tepkiHtml(d) {
    const acik = !konusmaci(d) && (d.durum === "canli" || (d.durum === "bitti" && d.oy_penceresi));
    if (!acik) return "";
    return `<div class="tvx-tepki"><button class="btn ${d.tepkim === "alkis" ? "altin" : "ikinci"}" onclick="tvTepki(${d.id},'alkis')">Alkışla <i>${n(d.alkis)}</i></button><button class="btn ${d.tepkim === "yuh" ? "tehlike" : "ikinci"}" onclick="tvTepki(${d.id},'yuh')">Yuhala <i>${n(d.yuh)}</i></button></div>`;
  }
  function oyHtml(d) {
    const ks = koseler(d), kabul = (d.konuk_liste || []).filter(k => k.durum === "kabul");
    if (d.tur !== "duello" || !kabul.length) return "";
    const top = kabul.reduce((t, k) => t + (Number(k.oy) || 0), 0) || 1;
    const kose = (k, dugme) => { const r = (ks[k.kad] || {}).renk || KOSE[0], pay = Math.round(100 * (Number(k.oy) || 0) / top);
      return `<${dugme ? `button type="button" class="btn ${d.oyum === k.kad ? "altin" : "ikinci"}" onclick="tvOyla(${d.id},'${e(k.kad)}')"` : 'div class="btn ikinci"'} style="--k:${r}">${d.oyum === k.kad ? '<span class="tvx-sec">Oyun</span>' : ""}
        <b>${e(k.kad)}</b><small>${k.unvan ? e(k.unvan) : "Konuk"}</small><span class="tvx-pay">%${pay}</span><small>${n(k.oy)} oy</small><span class="tvx-bar"><i style="width:${pay}%"></i></span></${dugme ? "button" : "div"}>`; };
    if (d.oy_acik && !konusmaci(d)) return `<section class="tvx-oyb"><h2>En ikna edici kim?</h2><p>Oylama, düello bittikten 15 dakika sonra kapanır. Oyunu değiştirebilirsin.</p>
      <div class="tvx-kose" style="--n:${Math.min(3, kabul.length)}">${kabul.map(k => kose(k, true)).join("")}</div></section>`;
    return `<section class="tvx-oyb"><h2>İzleyici oylaması</h2><p>${d.oy_acik ? "Oylama sürüyor; sunucu ve konuklar oy kullanamaz." : d.durum === "bitti" ? "Oylama kapandı." : "Oylama yayın başlayınca açılır."}</p>
      <div class="tvx-kose" style="--n:${Math.min(3, kabul.length)}">${kabul.slice().sort((a, b) => b.oy - a.oy).map(k => kose(k, false)).join("")}</div></section>`;
  }
  const imza = d => [d.durum, d.rolum, (d.konuk_liste || []).map(k => k.kad + ":" + k.durum).join(","), (d.reklamlarim || []).map(r => r.id + ":" + r.durum).join(","), (d.reklamlar || []).length, d.oy_acik ? 1 : 0].join("|");
  const hazirla = d => { d.oy_penceresi = d.durum === "bitti" && simdi() < new Date(d.bit).getTime() + 15 * 60e3; return d; };

  function kismiGuncelle(d) {
    const oda = document.getElementById("tvOda");
    if (oda && Number(oda.dataset.n) !== (d.mesajlar || []).length) {
      const dipte = oda.scrollHeight - oda.scrollTop - oda.clientHeight < 60;
      oda.innerHTML = odaHtml(d); oda.dataset.n = (d.mesajlar || []).length;
      if (dipte) oda.scrollTop = oda.scrollHeight;
    }
    const yaz = (id, html) => { const el = document.getElementById(id); if (el && el.innerHTML !== html) el.innerHTML = html; };
    yaz("tvSayac", sayacHtml(d)); yaz("tvIzl", izleyiciHtml(d)); yaz("tvTepkiK", tepkiHtml(d)); yaz("tvOyK", oyHtml(d));
  }

  window.tvStudyoEkrani = async function (id, hazir) {
    stil();
    if (window._tvStudyoId !== id || !document.getElementById("tvStudyo")) yukleniyor("TV yayını");
    let d = hazir; if (!d) { try { d = await rpc("tv_detay", { p_program: id }); } catch (err) { return hataEkran("TV yayını", err); } }
    hazirla(d);
    window._tvStudyoId = id;
    const canli = d.durum === "canli", planli = d.durum === "planli", acik = canli || planli;
    const yetkili = d.rolum === "sunucu" || d.kanal_sahibi;
    const konuklar = d.konuk_liste || [], reklamlar = d.reklamlar || [], benimRek = d.reklamlarim || [];
    const aktifRek = benimRek.some(r => r.durum === "bekliyor" || r.durum === "onay");
    const ks = koseler(d);
    const REK_DURUM = { bekliyor: "Onay bekliyor", onay: "Onaylandı", ret: "Reddedildi, bütçe iade edildi", iptal: "İptal edildi, bütçe iade edildi", yayinlandi: "Yayınlandı", iade: "Bütçe iade edildi" };
    const rolYazi = { sunucu: "Bu yayının sunucususun", konuk: "Bu yayında konuksun", davetli: "Bu programa davetlisin" }[d.rolum] || "";
    iskelet(d.kanal || "TV yayını", `<div id="tvStudyo" class="tvx" data-imza="${e(imza(d))}">
      <section class="tvx-ekran${canli ? " canli" : ""}" style="--h:${ton(d.kanal)}">
        <div class="tvx-e-ust">${logo(d.kanal)}<button type="button" class="tvx-e-kanal" style="text-align:left;color:#fff" onclick="tvKanalAc(${d.kanal_id})">${e(d.kanal)}</button>${canli ? '<span class="tv-canli" style="margin:0">Canlı</span>' : `<span class="tvx-e-saat">${planli ? "Planlı" : d.durum === "iptal" ? "İptal" : "Bitti"}</span>`}</div>
        <div class="tvx-e-orta" style="margin:16px 0 10px"><small>${e(d.tur_ad)}${rolYazi ? " · " + rolYazi : ""}</small><h2>${e(d.baslik)}</h2>
          <p>Sunucu ${kisi(d.sunucu_kisi)}${konuklar.length ? " · Konuklar: " + konuklar.map(k => `<span style="color:${(ks[k.kad] || {}).renk || "inherit"};font-weight:700">${e(k.kad)}</span>${k.durum === "kabul" ? "" : k.durum === "davet" ? " (davetli)" : " (katılmıyor)"}`).join(", ") : ""}</p>
          ${d.aciklama ? `<p>${e(d.aciklama)}</p>` : ""}</div>
        ${planli ? `<div class="tvx-e-alt"><span class="tvx-izl">Başlamasına<span class="tvx-sayac" style="display:block;margin-top:3px">${kalan(new Date(d.bas).getTime() - simdi())}</span></span></div>
          <p class="kucuk" style="position:relative;z-index:1;color:#C9D1E6;margin-top:8px">Başlangıç ${tarihSaat(d.bas)}${d.acik_uclu ? " · sunucu bitirene kadar" : " · bitiş " + saatYaz(d.bit)}</p>` : `<p class="kucuk" style="position:relative;z-index:1;color:#C9D1E6">${progZaman(d)}</p>`}
        <p class="kucuk" id="tvSayac" style="position:relative;z-index:1;color:#E8EBF6;margin-top:4px">${sayacHtml(d)}</p>
        ${reklamlar.length ? `<div class="tv-sponsor">Bu yayının reklamverenleri: ${reklamlar.map(r => e(r.marka)).join(" · ")}</div>` : ""}</section>
      ${d.rolum === "davetli" && acik ? `<section class="tvx-gelen"><h2>Bu programa konuk olarak davetlisin.</h2><p>Katılırsan yayın sırasında söz alabilirsin; izleyiciler seni oylayabilir.</p>
        <div class="tv-iki"><button class="btn altin" onclick="tvKonukYanit(${d.id},true)">Katılıyorum</button><button class="btn ikinci" onclick="tvKonukYanit(${d.id},false)">Katılamam</button></div></section>` : ""}
      <div id="tvOyK">${oyHtml(d)}</div>
      <section class="kart"><div class="tv-oda" id="tvOda" data-n="${(d.mesajlar || []).length}" aria-live="polite">${odaHtml(d)}</div>
      ${canli && konusmaci(d) ? `<div class="tvx-yaz" style="margin-top:10px"><textarea class="tv-yaz" id="tvYaz" maxlength="600" rows="2" placeholder="${d.rolum === "sunucu" ? "Yayını yönet, soru sor…" : "Söz al…"}" aria-label="Yayına yaz"></textarea>
        <button class="btn altin" id="tvYazB" onclick="tvYaz(${d.id})">Gönder</button></div>` : ""}</section>
      <div id="tvTepkiK">${tepkiHtml(d)}</div>
      <section class="kart" id="tvIzl">${izleyiciHtml(d)}</section>
      ${yetkili && acik ? `<section class="kart"><h2>Yayın yönetimi</h2>
        <div class="alan"><label for="tvKonukKad">Konuk çağır (kullanıcı adı, en çok 6 konuk)</label><input id="tvKonukKad" autocapitalize="off" maxlength="40"></div>
        <div class="tv-iki"><button class="btn ikinci" onclick="tvKonukDavet(${d.id})">Davet gönder</button>
          <button class="btn tehlike" onclick="tvBitir(${d.id},${planli})">${planli ? "Programı iptal et" : "Yayını bitir"}</button></div></section>` : ""}
      ${benimRek.length ? `<section class="kart"><h2>Reklamım</h2>${benimRek.map(r => `<div class="tv-satir"><b>${e(r.marka)}</b> <span class="kucuk">${e(r.sirket || "cüzdanımdan")} · bütçe ${tl(r.butce)} · ${REK_DURUM[r.durum] || r.durum}${r.durum === "yayinlandi" ? " · ödenen " + tl(r.odenen) + ", iade " + tl(r.iade) : ""}</span>
          ${r.durum === "bekliyor" || (r.durum === "onay" && planli) ? `<button class="btn ikinci" onclick="tvReklamIptal(${r.id},${d.id})">Reklamı iptal et, bütçeyi geri al</button>` : ""}</div>`).join("")}</section>` : ""}
      ${acik && !d.kanal_sahibi && !aktifRek ? `<section class="kart"><details id="tvRekD" ontoggle="if(this.open)tvReklamKaynak(${d.id})"><summary style="cursor:pointer"><b>Bu programa reklam ver</b> <span class="kucuk">izleyici başına ${tl(d.izleyici_ucret)}</span></summary>
        <p class="alt" style="margin-top:8px">Bütçe peşin ayrılır; program bitince izleyici sayısı kadarı kanala ödenir, kalanı sana iade edilir. Kanal sahibi onaylayınca reklamın yayında görünür; onaylanmazsa bütçenin tamamı geri döner.</p>
        <div class="alan"><label for="tvRMarka">Marka ya da ad</label><input id="tvRMarka" maxlength="40"></div>
        <div class="alan"><label for="tvRMetin">Reklam metni</label><input id="tvRMetin" maxlength="200"></div>
        <div class="alan"><label for="tvRButce">Bütçe (₺, 5.000 – 5.000.000)</label><input id="tvRButce" type="number" inputmode="numeric" min="5000" max="5000000" step="1000" oninput="tvReklamOzet(${Number(d.izleyici_ucret)})"></div>
        <div class="alan"><label for="tvRKaynak">Ödeme kaynağı</label><select id="tvRKaynak"><option value="">Cüzdanım</option></select></div>
        <div class="tvx-ozet" id="tvROzet"></div>
        <button class="btn altin" style="margin-top:8px" onclick="tvReklamVer(${d.id})">Reklam talebi gönder</button></details></section>` : ""}
    </div>`, { geri: true });
    const kok = document.getElementById("tvStudyo");
    if (!kok || kok.dataset.imza !== imza(d)) return;      // çizim ertelendi (oyuncu meşgul); zamanlayıcı yeniden dener
    const oda = $("#tvOda"); if (oda) oda.scrollTop = oda.scrollHeight;
    const ta = $("#tvYaz");
    if (ta) ta.onkeydown = ev => { if (ev.key === "Enter" && !ev.shiftKey && window.matchMedia && matchMedia("(pointer:fine)").matches) { ev.preventDefault(); window.tvYaz(id); } };
    if (acik || d.oy_penceresi) {
      const taz = async () => {
        if (window._tvStudyoId !== id || !document.getElementById("tvStudyo") || document.hidden) return;
        let y; try { y = hazirla(await rpc("tv_detay", { p_program: id })); } catch (_) { return; }
        if (window._tvStudyoId !== id || !document.getElementById("tvStudyo")) return;
        const k = document.getElementById("tvStudyo");
        if (imza(y) !== k.dataset.imza && !$("#modal") && (y.durum !== d.durum || !yaziyor("tvStudyo"))) {
          if (y.durum !== d.durum) eylem();                 // yayın başladı / bitti: ekran her durumda yenilenir
          return window.tvStudyoEkrani(id, y);
        }
        kismiGuncelle(y);
      };
      window._tvTaz = taz;
      const basaKalan = planli ? new Date(d.bas).getTime() - simdi() : null;
      if (window.CANLI && CANLI.izle) CANLI.izle({ anahtarlar: ["yayin:tv" + id], tazele: taz, hizliMs: canli ? 5000 : 15000, yedekMs: 20000, yayilim: 1500, pencereMs: 1200,
        sonraMs: basaKalan != null && basaKalan > 0 ? basaKalan + 900 : null });
      else D.canli = setInterval(taz, 6000);
    }
  };
  const studyoCalis = async (id, fn, basari) => { try { const r = await fn(); ozetSifirla(); if (basari) toast(basari); await window.tvStudyoEkrani(id, r && r.rolum ? r : null); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvYaz = async id => {
    const ta = $("#tvYaz"), b = $("#tvYazB"); if (!ta) return;
    const v = (ta.value || "").trim(); if (!v) return;
    if (b) b.disabled = true;
    try { await rpc("tv_yaz", { p_program: id, p_metin: v }); ta.value = ""; if (window._tvTaz) await window._tvTaz(); const oda = $("#tvOda"); if (oda) oda.scrollTop = oda.scrollHeight; }
    catch (err) { toast(hataCevir(err.message), true); }
    const b2 = $("#tvYazB"); if (b2) b2.disabled = false;
    const t2 = $("#tvYaz"); if (t2) t2.focus();
  };
  window.tvTepki = async (id, tur) => { try { kismiGuncelle(hazirla(await rpc("tv_tepki", { p_program: id, p_tur: tur }))); } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvOyla = async (id, kad) => { try { kismiGuncelle(hazirla(await rpc("tv_oyla", { p_program: id, p_kad: kad }))); toast("Oyun kaydedildi."); } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvKonukDavet = id => { const el = $("#tvKonukKad"), k = (el.value || "").trim(); if (!k) return toast("Kullanıcı adı gir.", true); el.value = ""; return studyoCalis(id, () => rpc("tv_konuk_davet", { p_program: id, p_kad: k }), "Davet gönderildi."); };
  window.tvBitir = async (id, planli) => {
    if (!await onayla(planli ? "Programı iptal et" : "Yayını bitir", planli ? "Program iptal edilecek; verilen reklam bütçeleri iade edilir." : "Yayın şimdi sona erecek ve reklam gelirleri hesaplanacak.", planli ? "İptal et" : "Bitir", true)) return;
    return studyoCalis(id, () => rpc("tv_bitir", { p_program: id }), planli ? "Program iptal edildi." : "Yayın sona erdi.");
  };
  window.tvReklamKaynak = async id => {
    const sec = $("#tvRKaynak"); if (!sec || sec.dataset.dolu) return;
    try {
      const k = await rpc("tv_reklam_kaynak", { p_program: id });
      sec.dataset.dolu = "1";
      sec.innerHTML = `<option value="">Cüzdanım (${tl(k.cuzdan)})</option>` + (k.sirketler || []).map(s => `<option value="${s.id}">${e(s.ad)} kasası (${tl(s.kasa)})</option>`).join("");
    } catch (_) {}
  };
  window.tvReklamOzet = birim => {
    const b = Math.round(Number(($("#tvRButce") || {}).value) || 0), o = $("#tvROzet"); if (!o) return;
    o.textContent = b >= 5000 && birim > 0 ? `Bu bütçe en çok ${Math.floor(b / birim).toLocaleString("tr-TR")} izleyiciyi karşılar; daha az izleyici olursa fark iade edilir.` : "";
  };
  window.tvReklamVer = async id => {
    const marka = ($("#tvRMarka").value || "").trim(), metin = ($("#tvRMetin").value || "").trim(), butce = Math.round(Number($("#tvRButce").value) || 0), kaynak = $("#tvRKaynak").value;
    if (marka.length < 2 || metin.length < 5) return toast("Marka en az 2, reklam metni en az 5 karakter olmalı.", true);
    if (butce < 5000) return toast("Reklam bütçesi en az 5.000 ₺ olmalı.", true);
    if (!await onayla("Reklam ver", `${tl(butce)} bütçe ${kaynak ? "şirket kasasından" : "cüzdanından"} ayrılacak. Kullanılmayan kısım program bitince iade edilir.`, "Talebi gönder")) return;
    try {
      const r = await rpc("tv_reklam_ver", { p_program: id, p_marka: marka, p_metin: metin, p_butce: butce, p_sirket: kaynak ? Number(kaynak) : null });
      ["tvRMarka", "tvRMetin", "tvRButce"].forEach(x => { const el = document.getElementById(x); if (el) el.value = ""; });
      toast("Reklam talebin kanal sahibine iletildi."); await window.tvStudyoEkrani(id, r);
    } catch (err) { toast(hataCevir(err.message), true); }
  };
  window.tvReklamIptal = async (rid, id) => { if (!await onayla("Reklamı iptal et", "Reklam talebin geri çekilecek ve bütçenin tamamı iade edilecek.", "İptal et", true)) return; return studyoCalis(id, () => rpc("tv_reklam_iptal", { p_reklam: rid }), "Reklam iptal edildi, bütçe iade edildi."); };
  void progKart;
})();
