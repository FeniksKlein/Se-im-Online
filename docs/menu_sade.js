/* =====================================================================
   MENÜ SADELEŞTİRME (2026-10-13)
   1) Ekonomi: Hayat'taki dağınık kartlar (İş Dünyası, Ekonomi merkezi, Şirketler,
      Rekabetçi şirketler, Halka arzlar, bankalar, ihaleler, ajanslar, emlak…)
      tek bir alt menü sekmesinde toplanır: "Ekonomi".
   2) Yönetim + Devlet: alt menüdeki ayrı "Yönetim" sekmesi kalktı. Makamı olan
      oyuncu Devlet sekmesinin ilk bölümünde ("Makamım") aynı işlemleri görür.
   Bu dosya en son yüklenmeli (diğer modüllerin iskelet sarmalayıcılarının dışında kalır).
   ===================================================================== */
(function(){
  const sv = d => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
  const MS_IKON = {
    ekonomi: sv('<path d="M3 3v18h18"/><path d="m7 15 4-4 3 3 6-7"/><path d="M16 7h4v4"/>'),
    sirket: sv('<rect x="4" y="3" width="10" height="18" rx="1"/><path d="M14 9h6v12h-6M7 7h4M7 11h4M7 15h4"/>'),
    ruhsat: sv('<path d="M3 21h18M5 21V7l7-4 7 4v14M9 21v-7h6v7M9 10h6"/>'),
    dunya: sv('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>'),
    yaris: sv('<path d="M6 20V10M12 20V4M18 20v-7"/>'),
    rehber: sv('<path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2z"/><path d="M4 19V5M9 7h6"/>'),
    ihale: sv('<path d="m14 13-7.5 7.5a2.1 2.1 0 0 1-3-3L11 10"/><path d="m16 16 6-6M8 8l6-6M9 7l8 8M21 11l-8-8"/>'),
    ajans: sv('<path d="M3 11v2a1 1 0 0 0 1 1h3l5 4V6L7 10H4a1 1 0 0 0-1 1z"/><path d="M16 9a3 3 0 0 1 0 6M19 6a7 7 0 0 1 0 12"/>'),
    rapor: sv('<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 16v-3M12 16V8M16 16v-6"/>'),
    borsa: sv('<path d="M3 17l6-6 4 4 8-8"/><path d="M14 7h7v7"/>'),
    arz: sv('<circle cx="12" cy="12" r="9"/><path d="M12 7v10M8.5 10.5 12 7l3.5 3.5"/>'),
    altin: sv('<path d="M5 17h14l-2-6H7z"/><path d="M8.5 11 10 7h4l1.5 4"/>'),
    tahvil: sv('<path d="M6 3h9l4 4v14H6z"/><path d="M14 3v5h5M9 13h7M9 17h5"/>'),
    banka: sv('<path d="M3 21h18M5 21V10M9.5 21V10M14.5 21V10M19 21V10M2.5 10 12 3l9.5 7z"/>'),
    oyb: sv('<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M7 15h4"/>'),
    gonder: sv('<path d="M22 2 11 13"/><path d="m22 2-7 20-4-9-9-4z"/>'),
    gecmis: sv('<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/>'),
    emlak: sv('<path d="M3 11 12 4l9 7"/><path d="M5 10v10h14V10M10 20v-6h4v6"/>'),
    mb: sv('<circle cx="12" cy="12" r="9"/><path d="M15 9.5c-.5-1-1.6-1.5-3-1.5-1.7 0-3 .9-3 2s1.3 1.7 3 2 3 .9 3 2-1.3 2-3 2c-1.4 0-2.5-.5-3-1.5M12 6v2M12 16v2"/>'),
    spk: sv('<circle cx="11" cy="11" r="7"/><path d="m21 21-5-5"/>'),
    terazi: sv('<path d="M12 3v18M5 21h14M3 7h18M6 7l-3 5h6zM18 7l-3 5h6z"/>'),
    konk: sv('<path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2 18a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/>'),
    bagis: sv('<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8z"/>')
  };
  if (typeof IKON === "object" && IKON && !IKON.ekonomi) IKON.ekonomi = MS_IKON.ekonomi;

  const var_ = ad => typeof window[ad] === "function";
  // [ikon, başlık, açıklama, çağrı, gereken fonksiyon]
  const satir = (ik, bas, alt, cagri, fn) => (fn && !var_(fn)) ? "" :
    `<button class="giris-satir" onclick="${cagri}"><span class="yik ms-yik">${MS_IKON[ik]}</span><span class="orta"><b>${bas}</b><span class="kucuk">${alt}</span></span><span class="ok">›</span></button>`;
  const grup = (baslik, alt, satirlar) => {
    const ic = satirlar.join("");
    return ic ? `<div class="bolum-bas"><h2>${baslik}</h2>${alt ? `<span class="kucuk">${alt}</span>` : ""}</div><div class="kart ms-grup">${ic}</div>` : "";
  };

  function msCss(){
    return `<style id="menuSadeCss">
      .ms-yik svg{width:22px;height:22px;color:var(--ink2,#a995ff)}
      .ms-grup{padding-top:4px;padding-bottom:4px}
    </style>`;
  }

  try { if (!document.getElementById("menuSadeCss")) document.head.insertAdjacentHTML("beforeend", msCss()); } catch (_) {}

  /* Ruhsat modülü bazı sürümlerde menüden yüklenmiyordu; gerektiğinde aç. */
  let msRuhsatYukleniyor = false;
  function msRuhsatMerkeziAc(){
    const ac = () => ekranAc(window.belRuhsatMerkeziEkrani);
    if (typeof window.belRuhsatMerkeziEkrani === "function") return ac();
    if (msRuhsatYukleniyor) return;
    msRuhsatYukleniyor = true;
    const script = document.createElement("script");
    script.src = "belediye_ruhsatlar.js?v=20261013-2";
    script.onload = () => {
      msRuhsatYukleniyor = false;
      if (typeof window.belRuhsatMerkeziEkrani === "function") ac();
      else toast("Ruhsat merkezi açılamadı. Sayfayı yenileyip tekrar dene.", true);
    };
    script.onerror = () => {
      msRuhsatYukleniyor = false;
      script.remove();
      toast("Ruhsat merkezi yüklenemedi. Sayfayı yenileyip tekrar dene.", true);
    };
    document.body.appendChild(script);
  }
  window.msRuhsatMerkeziAc = msRuhsatMerkeziAc;


  /* UC ekonomi merkezi: Github Pages'de ayri JS, mobil pakette gomulu. */
  let ucLoaderPromise=null;
  window.ucYeniAc=function(which){
    if(typeof window.ucEkonomiEkrani==="function")return window.ucEkonomiEkrani(which);
    if(!ucLoaderPromise){
      ucLoaderPromise=new Promise((resolve,reject)=>{
        const script=document.createElement("script");
        script.src="uc_ekonomi_yeni.js?v=20261015-medya-1";
        script.onload=resolve;
        script.onerror=()=>reject(new Error("Yeni ekonomi ekranları yüklenemedi"));
        document.body.appendChild(script);
      });
    }
    return ucLoaderPromise.then(()=>window.ucEkonomiEkrani(which)).catch(err=>{ucLoaderPromise=null;toast(err.message,true);});
  };

  /* ---------------- Ekonomi sekmesi ---------------- */
  function ekonomiEkrani(){
    const cz = D.durum && D.durum.profil && D.durum.profil.cuzdan;
    const h = `
      <section class="sahne" style="margin-bottom:12px">
        <div class="ne">Cüzdanın</div>
        <div class="para" style="font-size:34px;margin-top:2px">${cz ? tlYaz(cz.para) : "—"}</div>
        <div class="kucuk" style="margin-top:6px">Şirketler, yatırımlar, bankalar ve emlak tek yerde.</div>
      </section>
      ${grup("Şirket ve iş", "Kur, yönet, yarış", [
        satir("sirket", "Şirketlerim ve şirket kur", "Ortak olduğun şirketleri yönet, yeni şirket kur", "ekranAc(sirketYonetimEkrani)", "sirketYonetimEkrani"),
        satir("dunya", "🌾 Tarım ve hayvancılık", "Tarla, mevsim, hasat, süt, et ve market tedariki", "ucYeniAc('tarim')", "ucYeniAc"),
        satir("rehber", "📚 Kitap ve yayınevi", "Kitap yaz, yayımla, telif al, yeni baskı yap", "ucYeniAc('kitap')", "ucYeniAc"),
        satir("ajans", "📺 Medya ve yayınevleri", "Millet TV, yayınlanan kitaplar ve bağışlar", "ucYeniAc('medya')", "ucYeniAc"),
        satir("ajans", "🎟️ Biletli organizasyonlar", "Konferans, konser, fuar, sponsor ve bilet satışı", "ucYeniAc('etkinlik')", "ucYeniAc"),
        satir("ruhsat", "Yatırım Ruhsat Merkezi", "Şirket, fabrika, mağaza, inşaat ruhsatlarına başvur; belediye onaylarını takip et", "msRuhsatMerkeziAc()", "msRuhsatMerkeziAc"),
        satir("dunya", "İş dünyası", "Üretim, mağaza, inşaat, sigorta, franchise, birleşme", "ekranAc(isDunyasiEkrani)", "isDunyasiEkrani"),
        satir("yaris", "Rekabetçi şirketler", "Okul, hastane, market, ulaşım, enerji; fiyat ve kalite", "ekranAc(pazarMerkezEkrani)", "pazarMerkezEkrani"),
        satir("ihale", "Kamu ihaleleri", "Belediye ve bakanlık ihalelerine teklif ver", "ekranAc(ihaleEkrani)", "ihaleEkrani"),
        satir("ajans", "Reklam ve anket ajansları", "Kampanya reklamı, kamuoyu araştırması", "ekranAc(ajansMerkezEkrani)", "ajansMerkezEkrani"),
        satir("rehber", "Şirket rehberi", "Oyundaki tüm şirketler, sahipleri, kâr sıralaması", "ekranAc(sirketVitrinEkrani)", "sirketVitrinEkrani"),
        satir("gecmis", "Satılık şirketler", "Devren satılan şirketleri incele", "ekranAc(sirketPazarEkrani)", "sirketPazarEkrani")
      ])}
      ${grup("Yatırım", "Hisse, arz, altın, tahvil", [
        satir("rapor", "Piyasa raporu", "Enflasyon, fiyat endeksi, sektör liderleri", "ekranAc(ekonomiMerkeziEkrani)", "ekonomiMerkeziEkrani"),
        satir("borsa", "Borsa", "Şirket hisselerini al, sat", "ekranAc(borsaEkrani)", "borsaEkrani"),
        satir("arz", "Halka arzlar", "Arzlara talep ver, ortak ol", "ekranAc(halkaArzPazarEkrani)", "halkaArzPazarEkrani"),
        satir("altin", "Altın ve döviz", "Emtia ve döviz piyasaları", "ekranAc(piyasaEkrani)", "piyasaEkrani"),
        satir("tahvil", "Belediye tahvilleri", "Belediyelere borç ver, faiz kazan", "ekranAc(belediyeTahvilEkrani)", "belediyeTahvilEkrani")
      ])}
      ${grup("Banka ve para", "", [
        satir("banka", "Devlet bankası", "Vadeli ve vadesiz hesap, kredi", "ekranAc(bankaEkrani)", "bankaEkrani"),
        satir("oyb", "Oyuncu bankaları", "Mevduat ve kredi fırsatları", "ekranAc(bankaRehberiEkrani)", "bankaRehberiEkrani"),
        satir("gonder", "Para gönder", "Başka oyuncuya havale", "paraGonderModal()", "paraGonderModal"),
        satir("gecmis", "Alım-satım geçmişim", "Geçmiş işlemlerin", "ekranAc(ticaretGecmisimEkrani)", "ticaretGecmisimEkrani")
      ])}
      ${grup("Emlak", "", [
        satir("emlak", "Şehir Emlak ve İnşaat", "Müteahhitlerin ürettiği daire ve dükkânları incele, arsa ve tapu işlemlerini yönet", "arsaEkrani()", null)
      ])}
      ${grup("Ekonomi kurumları", "Herkes izleyebilir", [
        satir("mb", "Merkez Bankası", "Politika faizi ve PPK kararları", "ekranAc(merkezBankasiEkrani)", "merkezBankasiEkrani"),
        satir("spk", "Sermaye Piyasası Kurulu", "Borsa gözetimi ve cezalar", "ekranAc(spkEkrani)", "spkEkrani"),
        satir("terazi", "Rekabet Kurumu", "Kartel ve tekel soruşturmaları", "ekranAc(rekabetEkrani)", "rekabetEkrani"),
        satir("konk", "Konkordato ve iflas", "Zor durumdaki şirketler", "ekranAc(konkordatoEkrani)", "konkordatoEkrani"),
        satir("bagis", "Siyasi bağışlar", "Şirketlerin partilere bağışları", "ekranAc(siyasiBagisEkrani)", "siyasiBagisEkrani")
      ])}`;
    iskelet("Ekonomi", h);
  }
  window.ekonomiEkrani = ekonomiEkrani;
  if (typeof EKRAN === "object" && EKRAN) EKRAN.ekonomi = () => ekonomiEkrani();

  /* ---------------- Devlet + Makamım ---------------- */
  const makamVar = () => typeof yonetimVarMi === "function" && yonetimVarMi();
  const DV_SEG = [["yonetim", "Makamım"], ["hukumet", "Hükümet"], ["mevzuat", "Mevzuat"], ["gazete", "Gazete"], ["tarih", "Tarih"]];
  const dvSeg = aktif => `<div class="segment" style="margin-bottom:12px">${DV_SEG.filter(([k]) => k !== "yonetim" || makamVar())
    .map(([k, a]) => `<button class="${aktif === k ? "aktif" : ""}" onclick="D.devletSekme='${k}';devletEkrani()">${a}</button>`).join("")}</div>`;

  if (typeof devletEkrani === "function") {
    const eskiDevlet = devletEkrani;
    window.devletEkrani = devletEkrani = async function(){
      // Makamı olan oyuncu Devlet'i ilk açışında "Makamım" bölümüyle başlar
      if (!D._dvMakamIlk && makamVar() && (!D.devletSekme || D.devletSekme === "hukumet")) D.devletSekme = "yonetim";
      D._dvMakamIlk = true;
      if (D.devletSekme === "yonetim" && !makamVar()) D.devletSekme = "hukumet";
      if (D.devletSekme === "yonetim" && typeof yonetimEkrani === "function") {
        D.sekme = "devlet";
        return yonetimEkrani();
      }
      const r = await eskiDevlet.apply(this, arguments);
      try {
        const h1 = $("header.ust h1");
        if (D.sekme === "devlet" && h1 && h1.textContent === "Devlet" && makamVar()) {
          const seg = $("#icerik .segment");
          if (seg && !seg.querySelector(".ms-makam")) seg.insertAdjacentHTML("afterbegin", `<button class="ms-makam" onclick="D.devletSekme='yonetim';devletEkrani()">Makamım</button>`);
        }
      } catch (_) {}
      return r;
    };
  }
  if (typeof EKRAN === "object" && EKRAN) {
    EKRAN.devlet = () => devletEkrani();
    const makama = () => { D.sekme = "devlet"; D.devletSekme = "yonetim"; return devletEkrani(); };
    EKRAN.yonetim = makama; EKRAN.bakanlik = makama; EKRAN.belediye = makama;
  }


  /* ---------------- Çevrimiçi oyuncular — sohbetten erişilebilir ---------------- */
  try {
    if (!document.getElementById("coStil")) {
      const css = document.createElement("style");
      css.id = "coStil";
      css.textContent =
        '.co-sayi{display:flex;align-items:center;gap:6px;flex-wrap:wrap;text-align:right;color:var(--good);font-size:12.5px;font-weight:700;background:var(--panel2);border:1px solid var(--line2);border-radius:10px;padding:9px 10px}' +
        '.co-sayi span{color:var(--txt2);font-size:11px}' +
        '.co-kisi{display:flex;align-items:center;gap:10px;padding:10px 0;border-bottom:1px solid var(--line)}' +
        '.co-avatar{width:39px;height:39px;border-radius:50%;background:var(--panel3);color:var(--txt);display:grid;place-items:center;font-weight:800;flex:none}' +
        '.co-kim{min-width:0;flex:1}.co-kim b{display:block;overflow-wrap:anywhere}' +
        '.co-islem{display:flex;gap:5px;flex:none}.co-islem button{font-size:12px;font-weight:700;padding:7px 8px;border-radius:8px;background:var(--panel2);color:var(--txt)}' +
        '.co-islem .co-dm{background:var(--ink);color:#fff}';
      document.head.appendChild(css);
    }
  } catch (_) {}
  async function cevrimiciListeAc() {
    const m = modal('<h3 style="font-size:21px">● Çevrimiçi oyuncular</h3>' +
      '<p class="alt" id="coAciklama" style="margin:5px 0 12px">Son 5 dakikada aktif olan oyuncular listeleniyor.</p>' +
      '<div id="coSonuc" style="max-height:55vh;overflow-y:auto"><div class="yukleniyor">Yükleniyor…</div></div>' +
      '<button type="button" class="btn ikinci" id="coYenile">↻ Listeyi yenile</button>');
    const alan = m.querySelector("#coSonuc");
    async function yenile() {
      if (!m.isConnected) return;
      alan.innerHTML = '<div class="yukleniyor">Yükleniyor…</div>';
      try {
        const r = await API.rpc("cevrimici_oyuncular");
        if (!m.isConnected) return;
        const liste = Array.isArray(r && r.oyuncular) ? r.oyuncular : [];
        m.querySelector("#coAciklama").textContent = liste.length + ' oyuncu çevrimiçi · son 5 dakikada aktif';
        alan.innerHTML = liste.length ? liste.map((k, i) => {
          const kad = String(k.kad || "");
          const ilk = kad.slice(0, 1).toLocaleUpperCase("tr-TR");
          const detay = [k.il, k.parti].filter(Boolean).map(x => e(String(x))).join(" · ");
          return '<div class="co-kisi">' +
            '<div class="co-avatar" aria-hidden="true">' + e(ilk) + '</div>' +
            '<div class="co-kim"><b>' + e(kad) + '</b><span class="kucuk">' + (detay || 'Oyuncu') + '</span></div>' +
            '<div class="co-islem"><button type="button" data-co-profil="' + i + '">Profil</button>' +
            '<button type="button" class="co-dm" data-co-mesaj="' + i + '">Mesaj</button></div></div>';
        }).join("") : '<div class="bos">Şu anda çevrimiçi oyuncu yok.</div>';
        alan.querySelectorAll("[data-co-profil]").forEach(b => {
          b.onclick = () => oyuncuKart(liste[Number(b.dataset.coProfil)].kad);
        });
        alan.querySelectorAll("[data-co-mesaj]").forEach(b => {
          b.onclick = () => {
            const kad = liste[Number(b.dataset.coMesaj)].kad;
            modalKapat();
            ekranAc(() => ozelEkrani(kad));
          };
        });
      } catch (err) {
        if (m.isConnected) {
          m.querySelector("#coAciklama").textContent = "Oyuncular yüklenemedi";
          alan.textContent = hataCevir(err.message || String(err));
        }
      }
    }
    m.querySelector("#coYenile").onclick = yenile;
    await yenile();
  }
  window.cevrimiciListeAc = cevrimiciListeAc;

  /* ---------------- Dış sarmalayıcı: başlık ve sekme düzeltmeleri ---------------- */
  if (typeof iskelet === "function") {
    const eski = iskelet;
    window.iskelet = iskelet = function(baslik, govde, opt){
      const args = Array.prototype.slice.call(arguments);
      try {
        // Yönetim ekranı artık Devlet sekmesinin "Makamım" bölümüdür
        if (baslik === "Yönetim" && (D.sekme === "devlet" || D.sekme === "yonetim") && !(opt && opt.geri)) {
          D.sekme = "devlet"; D.devletSekme = "yonetim";
          args[0] = "Devlet";
          args[1] = dvSeg("yonetim") + (govde || "");
        }
      } catch (_) {}
      // Sohbetin üstündeki çevrimiçi sayısına dokununca kullanıcıları göster.
      if (baslik === "Sohbet" && typeof args[1] === "string") {
        args[1] = args[1].replace(/<span class="kucuk" style="color:var\(--good\)">●\s*(\d+) oyuncu çevrimiçi<\/span>/,
          (_tum, n) => '<button type="button" class="co-sayi" onclick="cevrimiciListeAc()" aria-label="' +
          n + ' çevrimiçi oyuncunun listesini aç">● ' + n +
          ' oyuncu çevrimiçi <span>Kişileri gör ›</span></button>');
      }
      return eski.apply(this, args);
    };
  }
})();

/* Belediye arsasi / gayrimenkul modulu (is dunyasi uzerinde yuklenir). */
(function(){
 if(document.getElementById("arsaInsaatModul"))return;
 const s=document.createElement("script");s.id="arsaInsaatModul";s.src="arsa_insaat_magaza.js?v=20261013-2";
 s.async=false;document.body.appendChild(s);
})();

/* Dernek faaliyetlerini GitHub Pages sürümüne ekle. */
(function(){
 if(window.STK_FAALIYET_MODUL||document.getElementById("dernekFaaliyetModul"))return;
 var s=document.createElement("script");s.id="dernekFaaliyetModul";s.src="dernek_faaliyet.js?v=20261013-1";s.async=false;document.body.appendChild(s);
})();


/* ---------------- Tum sohbet odalari + ozel mesaj icin ortak bildirim rozeti ----------------
   'sohbet' sunucuda tum erisilebilir odalar ve ozel mesajlarin toplamidir.
   'ozel' ayrica korunur: DM listesi ve DM okunma durumu degismez.
   Rozet, karsi tarafin kendi mesajlarini saymaz; okunan odalar otomatik duser.
*/
(function () {
  if (window.__tumSohbetRozeti20261013) return;
  window.__tumSohbetRozeti20261013 = true;

  function sohbetSayi() {
    if (typeof D === "undefined" || !D.okunmamis) return 0;
    const ok = D.okunmamis;
    const ham = ok.sohbet != null ? ok.sohbet : ok.ozel;
    const sayi = Number(ham);
    return Number.isFinite(sayi) ? Math.max(0, Math.floor(sayi)) : 0;
  }
  function sohbetRozetiniCiz() {
    const n = sohbetSayi();
    const d = document.getElementById("dmSayi");
    if (d && typeof sayiRozet === "function") d.innerHTML = sayiRozet(n);
    const dugme = document.getElementById("sohbetSekme");
    if (dugme) {
      dugme.classList.toggle("mesaj-var", n > 0);
      dugme.setAttribute("aria-label", "Sohbet, " + n + " okunmamış mesaj");
    }
  }

  if (typeof iskelet === "function") {
    const oncekiIskelet = iskelet;
    window.iskelet = iskelet = function () {
      const sonuc = oncekiIskelet.apply(this, arguments);
      sohbetRozetiniCiz();
      return sonuc;
    };
  }
  if (typeof rozetGuncelle === "function") {
    const oncekiRozet = rozetGuncelle;
    window.rozetGuncelle = rozetGuncelle = function () {
      const sonuc = oncekiRozet.apply(this, arguments);
      sohbetRozetiniCiz();
      return sonuc;
    };
  }
  if (typeof sohbetEkrani === "function") {
    const oncekiSohbet = sohbetEkrani;
    window.sohbetEkrani = sohbetEkrani = async function () {
      const sonuc = await oncekiSohbet.apply(this, arguments);
      // Kanal ilk acildiginda sunucu okunma imlecini ilerletir; rozeti hemen guncelle.
      try {
        if (D.sekme === "sohbet" && API) rozetGuncelle(await API.rpc("rozetler"));
      } catch (_) { /* Sekiz saniyelik genel yoklama tekrar deneyecektir. */ }
      return sonuc;
    };
  }
})();
