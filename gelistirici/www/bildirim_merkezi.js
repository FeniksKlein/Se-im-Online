/* =====================================================================
   BİLDİRİM MERKEZİ (2026-10-23) — sürüm 2026.10.23-1
   Sorun: kişisel bildirimler, Meclis duyuruları, grup kararları ve
   propaganda yayınları aynı listeye alt alta düşüyordu. Oyuncu başına
   haftada ~60 bildirim geldiği için süreli işler (kriz masası, savunma,
   jüri, istinaf, kredi gecikmesi, görev ihmali uyarısı, davetler)
   kalabalığın içinde kayboluyordu.

   · Bildirimler ekranı: "Dikkat isteyen" kartı en üstte sabit kalır
     (son 3 gün; oyuncu "Gördüm" diyene kadar), filtre çipleri
     (Tümü · Sana özel · Meclis ve parti · Duyurular · Yayınlar),
     gün başlıkları ve kategoriye göre görsel ağırlık.
   · Oyun açıkken yeni süreli bildirim gelirse üstte kalıcı bant çıkar.
   · Toast: bir öncekini silmek yerine en fazla 3'lü yığın; hata 5 sn,
     başarı mesajı hatayı itip silemez.

   Sunucu: public.bildirim_yeniler(p_limit) — okunmamış kişisel
   bildirimleri okundu İŞARETLEMEDEN döndürür (129_bildirim_merkezi.sql).
   Sunucuda yoksa yalnızca bant devre dışı kalır; ekran yine çalışır.
   Mevcut bildirimEkrani'ni yeniden yazmaz: orijinal ekranı çizdirir,
   sonra aynı öğeleri (dokunma işleyicileriyle birlikte) gruplara taşır.
   Oyun verisine, kurala ya da RPC'ye yazma yapmaz.
   ===================================================================== */
(function () {
  if (window.__bildirimMerkezi) return; window.__bildirimMerkezi = true;

  /* ---------------- Sınıflandırma ---------------- */
  // Sunucu metinlerinin bir kısmı Türkçe harfsiz yazılıyor; ikisini de yakalamak için katlanır.
  const katla = (s) => String(s == null ? "" : s).toLocaleLowerCase("tr-TR")
    .replace(/ı/g, "i").replace(/ş/g, "s").replace(/ğ/g, "g").replace(/ü/g, "u")
    .replace(/ö/g, "o").replace(/ç/g, "c").replace(/[âà]/g, "a").replace(/î/g, "i").replace(/û/g, "u");

  // Sıra önemlidir: önce herkese giden duyurular, sonra kaçırılmış işler, sonra süreli işler.
  const DUYURU_ONCE = /^(cumhurbaskanligi karari|haftanin ozeti|haftalik anket|sponsorlu|yuksek mahkeme)/;
  const KACTI = /karar vermedin|kacirdin|suresi doldu|suresi gecti/;
  // Başkasının mitingi / basın toplantısı: isteğe bağlı davet, süreli iş sayılmaz.
  const GENEL_DAVET = /meydaninda|mitinge katilip|mitingi basladi|basin toplantisi|canli izle/;
  // Hissedar oylamaları süreli ama sık; "Sana özel"de kalır, Dikkat kartını doldurmaz.
  const HISSEDAR = /genel kuruluna onerge geldi/;
  const ACIL = /saat icinde|gun icinde|karar ver|savunma|jurisine|istinafa basv|davada hakkinizda|davalidir|odenemedi|gecikmede|gecikme|yasal takip|haciz|icra takib|icra satis|girmezsen|gorevden alinacak|davet etti|davet ediyor|teklif etti|yanitla(?!nd)|yanitini .{0,40}ver|ruhsat merkezi|onayini bekliyor|onay bekliyor|yanitini bekliyor|iflas edebilir|zarar ediyor|mitingin basladi|teslim etmeniz/;
  const SEN = /(^|[\s"'(])(sen|seni|sana|senin|sizi|size|sizin|hakkinizda|partiniz|partinizin|partin|goreviniz|cezanizi|cezaniz|yetkiniz|sirketiniz|ittifakiniza|adayligin|kredin|kredini|hesabina|hesabin|cuzdan\w*|maasin|statun|payina|uyeligin|makamin|sirketin|paran|gorevin|teklifin|talebin|basvurun|basvurunu)(?=[\s.,;:!?)"'»]|$)|[a-z](din|dun|tin|tun|digin|dugun|tigin|tugun)(?=[\s.,;:!?)"'»]|$)/;
  const OZEL = /genel kurul|temettu|halka arz|bilanco|ihale|karari kesinlesti|mahkeme kararini|basarim|kredi|miting yetkisi|tahsil edildi|yeni siparis|paylasimina yanit verdi|cimer|spk|rekabet kurumu|affetti|cekilmen|kurucu davetine|genel baskansiz|kadrosunda .{0,20}bos|atayabilirsin|satis tamamlandi|ilan meydani/;
  const MECLIS = /grup karari|kanun teklifi|vergi kanunu|anayasa degisikligi|oylama|meclis|tbmm|veto|yasama|grup konusmasi|grup gunu|grup toplantisi|tuzuk|partimize katildi|partimizden ayrildi|birlesti|kurultay|on secim|grup baskanvekil|partisinin adi|genel baskani yeni|teskilatli/;

  function rotaBul(t) {
    if (/^muzayede:/.test(t)) return "muzayede";
    if (/ilan meydani|ilanina .{0,40}teklif|ilani icin karsi teklif|ilani baska bir aliciya|ilani yayindan kalkti|ilaninin 30 gunluk|ilanin oyun yonetimi|^satis tamamlandi: |artik senin \(/.test(t)) return "ilan";
    if (/kriz masasi|yonetim ›|yonetim >|ruhsat merkezi/.test(t)) return "yonetim";
    if (/adliye|dava|juri|istinaf|savunma|mahkeme/.test(t)) return "adliye";
    if (/kredi|taksit|vadesiz|banka/.test(t)) return "banka";
    if (/devlet > hukumet|devlet › hukumet/.test(t)) return "devlet";
    if (/meclis|tbmm|kanun teklifi|oylama gunu|anayasa degisikligi|grup karari/.test(t)) return "meclis";
    if (/kurucular kurulu|kurucu davet|genel baskan yardimcisi|parti sozcusu|parti sayfas|ittifak kartindan/.test(t)) return "parti";
    if (/mitingin basladi|gundem'den mitingine/.test(t)) return "gundem";
    return null;
  }
  function kategori(metin) {
    const t = katla(metin);
    let kat;
    if (DUYURU_ONCE.test(t)) kat = "duyuru";
    else if (KACTI.test(t)) kat = "ozel";
    else if (GENEL_DAVET.test(t)) kat = "duyuru";
    else if (HISSEDAR.test(t)) kat = "ozel";
    else if (ACIL.test(t)) kat = "acil";
    else if (SEN.test(t) || OZEL.test(t)) kat = "ozel";
    else if (MECLIS.test(t)) kat = "meclis";
    else kat = "duyuru";
    return { kat, rota: rotaBul(t) };
  }
  window.bmKategori = kategori;

  const ROTA = {
    yonetim: { ad: "Yönetime git", ac: () => sekmeAc("yonetim"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.yonetim === "function" },
    adliye:  { ad: "Adliye'ye git", ac: () => sekmeAc("adliye"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.adliye === "function" },
    banka:   { ad: "Bankaya git", ac: () => ekranAc(bankaEkrani), var: () => typeof bankaEkrani === "function" },
    muzayede:{ ad: "Müzayede’ye git", ac: () => ekranAc(muzayedeEkrani), var: () => typeof muzayedeEkrani === "function" },
    ilan:    { ad: "İlan Meydanı’na git", ac: () => ekranAc(ilanMeydaniEkrani), var: () => typeof ilanMeydaniEkrani === "function" },
    meclis:  { ad: "Meclis'e git", ac: () => sekmeAc("meclis"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.meclis === "function" },
    parti:   { ad: "Partilere git", ac: () => sekmeAc("parti"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.parti === "function" },
    devlet:  { ad: "Devlet'e git", ac: () => sekmeAc("devlet"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.devlet === "function" },
    gundem:  { ad: "Gündem'e git", ac: () => sekmeAc("gundem"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.gundem === "function" }
  };
  function rotaGit(r) { try { if (ROTA[r] && ROTA[r].var()) { bantKapat(); ROTA[r].ac(); } } catch (_) {} }
  window.bmRotaGit = rotaGit;

  /* ---------------- Yerel kayıtlar (yalnız bu cihaz) ---------------- */
  const yerel = {
    oku(k, v) { try { const x = JSON.parse(localStorage.getItem(k)); return x == null ? v : x; } catch (_) { return v; } },
    yaz(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (_) {} }
  };
  const GORDUM = "bm_gordum_v1", UYARILDI = "bm_uyarildi_v1", FILTRE = "bm_filtre_v1";
  function kumeEkle(anahtar, idler, ust) {
    const l = yerel.oku(anahtar, []);
    const s = new Set(l.map(String));
    for (const id of idler) if (!s.has(String(id))) { l.push(String(id)); s.add(String(id)); }
    yerel.yaz(anahtar, l.slice(-(ust || 400)));
  }
  const kumede = (anahtar, id) => yerel.oku(anahtar, []).map(String).includes(String(id));

  /* ---------------- Stil ---------------- */
  const CSS = `
.bm-dikkat{border:1px solid rgba(240,69,75,.38);background:linear-gradient(180deg,var(--albg),var(--panel) 72%)}
.bm-dikkat h2{display:flex;align-items:center;gap:8px}
.bm-dikkat .bm-d-oge{padding:11px 0 2px;border-top:1px solid var(--line)}
.bm-dikkat .bm-d-oge:first-of-type{border-top:0;padding-top:4px}
.bm-dikkat .bm-d-metin{font-size:14.5px;color:var(--txt);line-height:1.45;user-select:text;-webkit-user-select:text}
.bm-d-alt{display:flex;align-items:center;gap:8px;margin-top:7px;flex-wrap:wrap}
.bm-d-alt .kucuk{flex:1;min-width:60px}
@media (max-width:360px){.bm-d-alt .kucuk{flex-basis:100%}.bm-dugme{padding:4px 10px}}
.bm-dugme{background:var(--inkbg);color:var(--ink2);border:1px solid var(--ink);border-radius:8px;min-height:32px;padding:4px 12px;font-size:12.5px;font-weight:750;white-space:nowrap}
.bm-dugme:active{background:var(--ink);color:#fff}
.bm-dugme.sade{background:transparent;border-color:var(--line2);color:var(--mut)}
.bm-cipler{display:flex;gap:6px;overflow-x:auto;padding:2px 0 4px;margin-bottom:4px;scrollbar-width:none;-webkit-overflow-scrolling:touch}
.bm-cipler::-webkit-scrollbar{display:none}
.bm-cip{flex:none;display:inline-flex;align-items:center;gap:6px;padding:7px 12px;border-radius:999px;background:var(--panel);border:1px solid var(--line2);color:var(--txt2);font-size:13px;font-weight:700}
.bm-cip i{font-style:normal;color:var(--faint);font-weight:650}
.bm-cip.secili{background:var(--ink);border-color:var(--ink);color:#fff}
.bm-cip.secili i{color:rgba(255,255,255,.78)}
.bm-cip .bm-nokta{width:7px;height:7px;border-radius:50%;background:var(--al);flex:none}
.bm-gun{font-family:var(--disp);font-size:15px;font-weight:700;color:var(--mut);margin:14px 2px 8px}
.bm-liste > .bm-gun:first-child{margin-top:6px}
.kisisel.bm-k-acil{box-shadow:inset 3px 0 0 var(--al);background:linear-gradient(90deg,var(--albg),var(--panel) 58%)}
.kisisel.bm-k-acil > div{color:var(--txt)}
.kisisel.bm-k-acil .bm-ik{color:var(--al2)!important}
.kisisel.bm-k-ozel .bm-ik{color:var(--ink2)!important}
.kisisel.bm-k-meclis,.kisisel.bm-k-duyuru{background:transparent;border:1px solid var(--line);font-size:13.5px;color:var(--txt2);padding:9px 11px}
.kisisel.bm-k-meclis .bm-ik,.kisisel.bm-k-duyuru .bm-ik{color:var(--faint)!important}
.kisisel.bm-k-meclis.yeni,.kisisel.bm-k-duyuru.yeni{box-shadow:inset 3px 0 0 var(--ink)}
.bm-etiket{display:inline-block;font-size:11.5px;font-weight:750;color:var(--al2);margin-bottom:2px}
.bm-git{margin-left:auto}
.bm-bos{color:var(--mut);text-align:center;padding:22px 8px;font-size:14px}
#bmTostYigin{position:fixed;left:16px;right:16px;bottom:calc(var(--safeB) + 90px);z-index:40;display:flex;flex-direction:column;gap:8px;pointer-events:none;max-width:560px;margin:0 auto}
#bmTostYigin .toast{position:relative;left:auto;right:auto;bottom:auto;top:auto;margin:0;pointer-events:auto;cursor:pointer;transition:opacity .18s,transform .18s}
#bmTostYigin .toast.bm-cik{opacity:0;transform:translateY(6px)}
#bmBant{position:fixed;left:12px;right:12px;top:calc(var(--safeT) + 62px);z-index:45;max-width:540px;margin:0 auto;background:rgba(29,40,80,.97);-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);border:1px solid rgba(240,69,75,.45);border-left:4px solid var(--al);border-radius:14px;padding:12px 44px 12px 14px;box-shadow:0 18px 40px -14px rgba(0,0,0,.8);animation:bmBantGel .25s ease-out}
#bmBant .bm-b-ust{font-size:12.5px;font-weight:750;color:var(--al2);display:flex;align-items:center;gap:7px}
#bmBant .bm-b-ust::before{content:"";width:7px;height:7px;border-radius:50%;background:var(--al);animation:nabiz 1.6s ease-in-out infinite}
#bmBant p{margin-top:5px;font-size:14.5px;line-height:1.42;color:var(--txt);display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
#bmBant .bm-b-alt{display:flex;gap:8px;align-items:center;margin-top:10px;flex-wrap:wrap}
#bmBant .bm-b-alt .kucuk{flex-basis:100%}
#bmBant .bm-b-kapat{position:absolute;top:6px;right:6px;width:34px;height:34px;border-radius:9px;color:var(--mut);font-size:22px;line-height:1}
@keyframes bmBantGel{from{opacity:0;transform:translateY(-10px)}to{opacity:1;transform:none}}
@media (prefers-reduced-motion:reduce){#bmBant,#bmBant .bm-b-ust::before{animation:none}#bmTostYigin .toast{transition:none}}
`;
  function stilEkle() {
    if (document.getElementById("bmStil")) return;
    const s = document.createElement("style"); s.id = "bmStil"; s.textContent = CSS;
    (document.head || document.documentElement).appendChild(s);
  }
  stilEkle();

  const kac = (s) => typeof e === "function" ? e(s) : String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const zamanYaz = (z) => { try { return typeof zamanKisa === "function" ? zamanKisa(z) : ""; } catch (_) { return ""; } };
  const UYARI_SVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4l9 16H3zM12 10v4M12 17v.01"/></svg>';

  function gunEtiketi(z) {
    try {
      const p = trParca(z), b = trParca(simdi());
      const gun = (x) => Date.UTC(x.y, x.a - 1, x.g) / 864e5;
      const fark = gun(b) - gun(p);
      if (fark === 0) return "Bugün";
      if (fark === 1) return "Dün";
      return `${p.g} ${AYLAR[p.a - 1]}${p.y !== b.y ? " " + p.y : ""}`;
    } catch (_) { return ""; }
  }

  /* ---------------- Toast yığını ---------------- */
  const eskiToast = window.toast;
  function tostKaldir(t) {
    if (!t || t.dataset.cik) return;
    t.dataset.cik = "1"; clearTimeout(t._bmZ);
    t.classList.add("bm-cik");
    setTimeout(() => t.remove(), 190);
  }
  function tostSure(t) {
    clearTimeout(t._bmZ);
    t._bmZ = setTimeout(() => tostKaldir(t), t.classList.contains("hata") ? 5000 : 2600);
  }
  window.toast = function (m, hata) {
    try {
      let y = document.getElementById("bmTostYigin");
      if (!y) { y = document.createElement("div"); y.id = "bmTostYigin"; y.setAttribute("aria-live", "polite"); document.body.appendChild(y); }
      const metin = String(m == null ? "" : m);
      const canli = [...y.children].filter(x => !x.dataset.cik);
      const ayni = canli.find(x => x.dataset.m === metin);
      if (ayni) { tostSure(ayni); return; }
      // En fazla 3: önce en eski başarı mesajı çıkar, hata mesajları yerinde kalır.
      if (canli.length >= 3) tostKaldir(canli.find(x => !x.classList.contains("hata")) || canli[0]);
      const t = document.createElement("div");
      t.className = "toast" + (hata ? " hata" : ""); t.textContent = metin; t.dataset.m = metin;
      t.setAttribute("role", hata ? "alert" : "status");
      t.onclick = () => tostKaldir(t);
      y.appendChild(t); tostSure(t);
    } catch (_) { if (typeof eskiToast === "function") eskiToast(m, hata); }
  };

  /* ---------------- Bildirimler ekranı ---------------- */
  const eskiEkran = window.bildirimEkrani;
  let filtre = yerel.oku(FILTRE, "tumu");
  const FILTRELER = [["tumu", "Tümü"], ["ozel", "Sana özel"], ["meclis", "Meclis ve parti"], ["duyuru", "Duyurular"], ["yayin", "Yayınlar"]];

  function ekranBizimMi() {
    const h = document.querySelector(".ust h1");
    return !!(h && h.textContent.trim() === "Bildirimler");
  }

  function duzenle(liste) {
    const ic = document.getElementById("icerik");
    if (!ic || !Array.isArray(liste) || !liste.length) return;
    const dugumler = [...ic.querySelectorAll(":scope > .yayin, :scope > .kisisel")];
    if (dugumler.length !== liste.length) return; // beklenmeyen düzen: orijinal ekran olduğu gibi kalır
    const ogeler = liste.map((x, i) => {
      const n = dugumler[i];
      if (x.tur === "yayin") return { x, n, kat: "yayin", ust: "yayin" };
      const k = kategori(x.metin);
      n.classList.add("bm-k-" + k.kat);
      const ik = n.querySelector(":scope > span");
      if (ik) { ik.classList.add("bm-ik"); if (k.kat === "acil") ik.innerHTML = UYARI_SVG; }
      const govde = n.querySelector(":scope > div");
      if (govde && k.kat === "acil" && !govde.querySelector(".bm-etiket")) govde.insertAdjacentHTML("afterbegin", `<span class="bm-etiket">Dikkat isteyen</span><br>`);
      if (govde && k.rota && (k.kat === "acil" || k.kat === "ozel") && ROTA[k.rota] && ROTA[k.rota].var()) {
        const alt = govde.querySelector(".bildirim-alt");
        if (alt && !alt.querySelector(".bm-git")) alt.insertAdjacentHTML("beforeend", `<button type="button" class="bildirim-goster bm-git" onclick="event.stopPropagation();bmRotaGit('${k.rota}')">${kac(ROTA[k.rota].ad)} ›</button>`);
      }
      return { x, n, kat: k.kat, ust: k.kat === "acil" ? "ozel" : k.kat, rota: k.rota };
    });

    // Dikkat isteyenler: son 3 gün, oyuncu "Gördüm" demediyse en üstte kalır.
    const sinir = (typeof simdi === "function" ? simdi() : Date.now()) - 3 * 864e5;
    const dikkat = ogeler.filter(o => o.kat === "acil" && new Date(o.x.zaman).getTime() >= sinir && !kumede(GORDUM, o.x.id));

    const kap = document.createElement("div");
    kap.className = "bm-kap";
    kap.innerHTML = `${dikkat.length ? `<div class="kart bm-dikkat" id="bmDikkat"><h2>Dikkat isteyen <span class="rozet kirmizi">${dikkat.length}</span></h2>
        <p class="alt" style="margin-bottom:6px">Süreli işler ve yanıt bekleyen davetler. "Gördüm" deyince karttan kalkar.</p>
        ${dikkat.map(o => `<div class="bm-d-oge" data-id="${kac(o.x.id)}"><div class="bm-d-metin">${kac(o.x.metin)}</div>
          <div class="bm-d-alt"><span class="kucuk">${zamanYaz(o.x.zaman)}</span>
          ${o.rota && ROTA[o.rota] && ROTA[o.rota].var() ? `<button type="button" class="bm-dugme" onclick="bmRotaGit('${o.rota}')">${kac(ROTA[o.rota].ad)} ›</button>` : ""}
          <button type="button" class="bm-dugme sade" data-gordum="${kac(o.x.id)}">Gördüm</button></div></div>`).join("")}</div>` : ""}
      <div class="bm-cipler" role="tablist" aria-label="Bildirim türü"></div>
      <div class="bm-liste"></div>`;
    ic.insertBefore(kap, dugumler[0]);
    const liEl = kap.querySelector(".bm-liste"), cipEl = kap.querySelector(".bm-cipler");

    kap.querySelectorAll("[data-gordum]").forEach(b => b.onclick = () => {
      kumeEkle(GORDUM, [b.dataset.gordum], 500);
      const oge = b.closest(".bm-d-oge"); if (oge) oge.remove();
      const kart = document.getElementById("bmDikkat");
      if (kart) {
        const kalan = kart.querySelectorAll(".bm-d-oge").length;
        if (!kalan) kart.remove(); else { const r = kart.querySelector("h2 .rozet"); if (r) r.textContent = kalan; }
      }
    });

    function ciz() {
      if (!FILTRELER.some(f => f[0] === filtre)) filtre = "tumu";
      const sec = ogeler.filter(o => filtre === "tumu" || o.ust === filtre);
      cipEl.innerHTML = FILTRELER.map(([k, ad]) => {
        const grup = ogeler.filter(o => k === "tumu" || o.ust === k);
        if (k !== "tumu" && !grup.length) return "";
        const yeni = grup.some(o => o.x.yeni);
        return `<button type="button" role="tab" aria-selected="${filtre === k}" class="bm-cip${filtre === k ? " secili" : ""}" data-f="${k}">${yeni && filtre !== k ? '<span class="bm-nokta" aria-label="yeni"></span>' : ""}${ad} <i>${grup.length}</i></button>`;
      }).join("");
      cipEl.querySelectorAll("[data-f]").forEach(b => b.onclick = () => { filtre = b.dataset.f; yerel.yaz(FILTRE, filtre); ciz(); });
      liEl.textContent = "";
      let sonGun = null;
      for (const o of sec) {
        const g = gunEtiketi(o.x.zaman);
        if (g && g !== sonGun) { const h = document.createElement("div"); h.className = "bm-gun"; h.textContent = g; liEl.appendChild(h); sonGun = g; }
        liEl.appendChild(o.n);
      }
      if (!sec.length) liEl.innerHTML = `<div class="bm-bos">Bu türde bildirim yok.</div>`;
      // Seçilen filtre görünürde kalsın
      const s = cipEl.querySelector(".secili");
      if (s && (s.offsetLeft < cipEl.scrollLeft || s.offsetLeft + s.offsetWidth > cipEl.scrollLeft + cipEl.clientWidth)) cipEl.scrollLeft = Math.max(0, s.offsetLeft - 12);
    }
    // Hiç ilgili öğe yoksa kayıtlı filtre boş liste göstermesin
    if (filtre !== "tumu" && !ogeler.some(o => o.ust === filtre)) filtre = "tumu";
    ciz();
  }

  if (typeof eskiEkran === "function") {
    window.bildirimEkrani = async function () {
      let yakalanan = null, eskiRpc = null, apiRef = null;
      try {
        apiRef = typeof API !== "undefined" ? API : null;
        if (apiRef && typeof apiRef.rpc === "function") {
          eskiRpc = apiRef.rpc;
          apiRef.rpc = function (ad, arg) {
            const s = eskiRpc.apply(this, arguments);
            if (ad === "bildirim_kutusu" && s && typeof s.then === "function") s.then(r => { yakalanan = r; }, () => {});
            return s;
          };
        }
      } catch (_) { eskiRpc = null; }
      try { await eskiEkran.apply(this, arguments); }
      finally { if (apiRef && eskiRpc) apiRef.rpc = eskiRpc; }
      try { if (ekranBizimMi()) duzenle(yakalanan); } catch (_) { /* orijinal ekran olduğu gibi kalır */ }
      bantKapat();
    };
  }

  /* ---------------- Yeni süreli bildirim bandı ---------------- */
  let sonSayi = -1, kontrolSuruyor = false, bantKapali = false;
  function bantKapat() { const b = document.getElementById("bmBant"); if (b) b.remove(); }
  function bantGoster(ogeler) {
    if (!ogeler.length || ekranBizimMi()) return;
    bantKapat();
    const o = ogeler[0], ek = ogeler.length - 1;
    const b = document.createElement("div");
    b.id = "bmBant"; b.setAttribute("role", "alert");
    b.innerHTML = `<div class="bm-b-ust">Dikkat isteyen bildirim</div><p>${kac(o.metin)}</p>
      <div class="bm-b-alt"><span class="kucuk">${ek > 0 ? `+${ek} süreli bildirim daha` : zamanYaz(o.zaman)}</span>
      ${o.rota && ROTA[o.rota] && ROTA[o.rota].var() ? `<button type="button" class="bm-dugme" data-git="${o.rota}">${kac(ROTA[o.rota].ad)}</button>` : ""}
      <button type="button" class="bm-dugme" data-ac="1">Bildirimleri aç</button></div>
      <button type="button" class="bm-b-kapat" aria-label="Kapat">×</button>`;
    b.querySelector(".bm-b-kapat").onclick = bantKapat;
    b.querySelector("[data-ac]").onclick = () => { bantKapat(); try { if (typeof modalKapat === "function") modalKapat(); ekranAc(window.bildirimEkrani); } catch (_) {} };
    const g = b.querySelector("[data-git]"); if (g) g.onclick = () => rotaGit(g.dataset.git);
    document.body.appendChild(b);
  }
  async function yeniKontrol(sayi) {
    if (bantKapali || kontrolSuruyor) return;
    if (typeof API === "undefined" || !API || typeof API.rpc !== "function") return;
    kontrolSuruyor = true;
    try {
      const l = await API.rpc("bildirim_yeniler", { p_limit: 10 });
      if (!Array.isArray(l)) return;
      const uyarilacak = [], taze = (typeof simdi === "function" ? simdi() : Date.now()) - 2 * 864e5;
      for (const x of l) {
        if (kumede(UYARILDI, x.id) || kumede(GORDUM, x.id)) continue;
        if (new Date(x.zaman).getTime() < taze) continue; // eski, süresi büyük olasılıkla geçmiş
        const k = kategori(x.metin);
        if (k.kat === "acil") uyarilacak.push({ id: x.id, metin: x.metin, zaman: x.zaman, rota: k.rota });
      }
      kumeEkle(UYARILDI, l.map(x => x.id), 400);
      if (uyarilacak.length) bantGoster(uyarilacak);
    } catch (err) {
      // Sunucuda fonksiyon yoksa (eski kurulum) bandı sessizce kapat.
      if (/bildirim_yeniler|does not exist|could not find|404|PGRST202/i.test(String(err && (err.message || err.code) || ""))) bantKapali = true;
    } finally { kontrolSuruyor = false; }
  }
  function sayiGeldi(ok) {
    const n = ok && ok.bildirim != null ? Number(ok.bildirim) : NaN;
    if (!Number.isFinite(n)) return;
    const artti = n > Math.max(0, sonSayi);
    sonSayi = n;
    if (artti) yeniKontrol(n);
  }
  const eskiRozet = window.rozetGuncelle;
  if (typeof eskiRozet === "function") {
    window.rozetGuncelle = function (ok) {
      const r = eskiRozet.apply(this, arguments);
      try { sayiGeldi(ok || (typeof D === "object" && D ? D.okunmamis : null)); } catch (_) {}
      return r;
    };
  }
  // Açılışta: oyuncu yokken gelen süreli bildirimler için bir kez bakılır.
  let acilisDenemesi = 0;
  const acilis = setInterval(() => {
    acilisDenemesi++;
    try {
      if (typeof D === "object" && D && D.durum && D.durum.profil) { clearInterval(acilis); if (sonSayi < 0) sayiGeldi(D.okunmamis); }
    } catch (_) {}
    if (acilisDenemesi > 60) clearInterval(acilis);
  }, 2000);
})();
