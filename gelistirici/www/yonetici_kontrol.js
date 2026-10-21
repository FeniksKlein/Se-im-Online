/* =====================================================================
   YÖNETİCİ KONTROL MERKEZİ (sunucu: sql/113_yonetici_kontrol.sql)
   - Ben › Yönetici paneli › Kontrol Merkezi: pano, oyuncular, görevler, ekonomi, seçimler,
     veri düzenleyici, değişiklik geçmişi (geri al), sistem hataları, uygulama ayarları.
   - Oyuncu kartında yöneticiye "Yönet" düğmesi.
   - Sunucudan uygulama ayarları: destek e-postası, reklam/satış kimlikleri, mağaza bağlantıları,
     bakım modu ve üst duyuru bandı (yeni sürüm çıkarmadan değişir).
   - Engellenen ya da bakım sırasındaki oyuncuya açıklamalı tam ekran.
   - Adaylıklarım kartı: her türlü adaylıktan sandık açılmadan çekilme.
   ===================================================================== */
(function () {
  "use strict";
  if (window.YKM_YUKLENDI) return;
  window.YKM_YUKLENDI = true;

  /* ---------- Stil ---------- */
  const stil = document.createElement("style");
  stil.textContent = `
  .km-izgara{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:10px}
  .km-izgara .btn{margin:0;width:100%;padding:12px 8px;font-size:14px}
  .km-girdi{width:100%;padding:11px 12px;border-radius:10px;background:var(--bg);border:1px solid var(--line2);font-size:16px;color:inherit;outline:none}
  textarea.km-girdi{min-height:84px;font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13px}
  .km-satir{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
  .km-satir>.km-girdi{flex:1;min-width:120px}
  .km-kucukbtn{padding:7px 10px !important;font-size:13px}
  .km-veri-kart{background:var(--panel2);border-radius:12px;padding:10px 12px;margin-top:8px;cursor:pointer;overflow:hidden}
  .km-veri-kart .kv{padding:4px 0;font-size:13px}
  .km-veri-kart .kv .v{max-width:62%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-weight:500}
  .km-fark{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:12px;word-break:break-all;margin-top:4px}
  .km-fark del{color:var(--al2)} .km-fark ins{color:var(--good);text-decoration:none}
  .km-band{background:var(--inkbg);color:var(--ink2);font-weight:700;font-size:13px;padding:9px 12px;border-radius:10px;margin:0 0 10px;line-height:1.35}
  .km-bakim-ust{background:rgba(242,179,61,.14);color:var(--warn);font-weight:700;font-size:13px;padding:9px 12px;border-radius:10px;margin:0 0 10px}
  .km-tablo-ad{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13px}
  .km-uyari{background:var(--albg);color:var(--al2);padding:10px 12px;border-radius:10px;font-size:13px;margin-top:8px}
  `;
  document.head.appendChild(stil);

  /* ---------- Ortak yardımcılar ---------- */
  const YK = window.YKM = window.YKM || { sekme: "pano", oyuncu: { ara: "", filtre: "hepsi", sirala: "son_gorulme", offset: 0 },
    veri: { tablo: null, ara: "", sutun: "", deger: "", sirala: "", azalan: true, offset: 0 }, cache: {} };
  const rpc = (fn, args) => API.rpc(fn, args || {});
  const hata = (err) => toast(hataCevir((err && err.message) || String(err)), true);
  const tl = (n) => fmt(Math.round(Number(n) || 0)) + " ₺";
  const ts = (x) => x ? tarihSaat(x) : "—";
  const yt = () => (typeof yetkim === "function" ? yetkim() : { y: {}, var_: () => false });
  const sahipMi = () => !!yt().y.yonetici;
  const yetkiVar = (k) => yt().var_(k);
  const MAKAM_TUR = [["cb","Cumhurbaşkanı"],["cb_yardimcisi","Cumhurbaşkanı Yardımcısı"],["bakan","Bakan"],["tbmm","TBMM Başkanı"],["bskv","TBMM Başkanvekili"],
    ["grup_bskv","Grup Başkanvekili"],["mv","Milletvekili"],["bel","İl Belediye Başkanı"],["gb","Parti Genel Başkanı"],["gby","Genel Başkan Yardımcısı"]];
  const HEDEF = [["herkes","Tüm oyuncular"],["cevrimici","Şu an çevrimiçi olanlar"],["aktif","Son 7 günde girenler"],["yeni","Son 3 günde katılanlar"],
    ["makamli","Makam sahipleri"],["il","Bir ildekiler"],["parti","Bir partinin üyeleri"],["oyuncu","Tek oyuncu"]];
  const sec = (ad, liste, secili, ek) => `<select class="km-girdi" id="${ad}" ${ek || ""}>${liste.map(([k, a]) => `<option value="${e(k)}" ${String(k) === String(secili) ? "selected" : ""}>${e(a)}</option>`).join("")}</select>`;
  async function katalog(){
    if (YK.cache.katalog && Date.now() - YK.cache.katalogZaman < 60000) return YK.cache.katalog;
    const k = await rpc("yk_makamlar"); YK.cache.katalog = k; YK.cache.katalogZaman = Date.now(); return k;
  }
  function ilListesi(k){ return (k && k.iller) || (window.VERI && VERI.iller ? VERI.iller.map(i => ({ id: i.id, ad: i.ad })) : []); }

  // Moderatör yetki adları ve günlük metinleri
  try {
    Object.assign(MOD_YETKI, { para: "Para ve kıdem", makam: "Görev verme ve alma", ekonomi: "MASAK (ekonomi denetimi)", hesap_kapat: "Engelleme ve hesap kapatma", duyuru: "Duyuru ve bildirim" });
    Object.assign(MOD_ISLEM, { yk_para_ekle: "para yükledi", yk_para_al: "para düştü", yk_kidem: "kıdem değiştirdi", yk_bildirim: "bildirim gönderdi",
      yk_engel_sureli: "süreli engelledi", yk_engel_kalici: "kalıcı engelledi", yk_engel_kaldir: "engeli kaldırdı", yk_sustur: "susturdu",
      yk_adaylik_yasagi: "aday olma yasağını değiştirdi", yk_makam_ver: "göreve atadı", yk_makam_al: "görevden aldı", yk_parti_gorev_al: "parti görevinden aldı",
      yk_parti_degistir: "partisini değiştirdi", yk_il_degistir: "ilini değiştirdi", yk_ad_degistir: "adını değiştirdi", yk_kasa: "kasayı değiştirdi",
      yk_motor: "motoru çalıştırdı", yk_uygulama_ayar: "uygulama ayarını değiştirdi", yk_veri_ekle: "veri ekledi", yk_veri_guncelle: "veri düzenledi",
      yk_veri_sil: "veri sildi", yk_geri_al: "değişikliği geri aldı" });
  } catch (_) {}

  /* =====================================================================
     1) Sunucudan uygulama ayarları + bakım/engel ekranları + duyuru bandı
     ===================================================================== */
  YK.ayar = {};
  const BOS_ANAHTAR = /BURAYA|^\s*$/;
  async function uygulamaAyarYukle(){
    try {
      const a = await rpc("uygulama_ayar");
      YK.ayar = a || {};
      const s = (k) => (a && typeof a[k] === "string" && a[k].trim()) ? a[k].trim() : null;
      if (s("iletisim")) AYAR.ILETISIM = s("iletisim");
      if (s("admob_odullu_ios")) AYAR.ADMOB_ODULLU_IOS = s("admob_odullu_ios");
      if (s("admob_odullu_android")) AYAR.ADMOB_ODULLU_ANDROID = s("admob_odullu_android");
      if (a && typeof a.admob_test === "boolean") AYAR.ADMOB_TEST = a.admob_test;
      if (s("revenuecat_ios")) AYAR.REVENUECAT_IOS = s("revenuecat_ios");
      if (s("revenuecat_android")) AYAR.REVENUECAT_ANDROID = s("revenuecat_android");
      if (s("magaza_ios")) AYAR.APP_STORE = s("magaza_ios");
      if (s("magaza_android")) AYAR.GOOGLE_PLAY = s("magaza_android");
    } catch (_) { /* eski sunucu: uygulamadaki değerlerle devam */ }
    return YK.ayar;
  }
  window.uygulamaAyarYukle = uygulamaAyarYukle;

  // Reklam ve satış: sunucudan kapatılabilir; anahtar yoksa anlaşılır mesaj
  if (typeof REKLAM === "object" && REKLAM && typeof REKLAM.goster === "function") {
    const eskiGoster = REKLAM.goster.bind(REKLAM);
    REKLAM.goster = async function(){
      if (YK.ayar && YK.ayar.reklam_acik === false) throw new Error("Ödüllü reklamlar şu an kapalı.");
      return eskiGoster();
    };
  }
  if (typeof ODEME === "object" && ODEME && typeof ODEME.hazirla === "function") {
    const eskiHazirla = ODEME.hazirla.bind(ODEME);
    ODEME.hazirla = async function(){
      if (YK.ayar && YK.ayar.satis_acik === false) throw new Error("Mağaza şu an kapalı. Kısa süre içinde yeniden açılacak.");
      const ios = window.Capacitor && window.Capacitor.getPlatform && window.Capacitor.getPlatform() === "ios";
      const anahtar = ios ? AYAR.REVENUECAT_IOS : AYAR.REVENUECAT_ANDROID;
      if (!anahtar || BOS_ANAHTAR.test(anahtar)) throw new Error("Mağaza yakında açılacak.");
      return eskiHazirla();
    };
  }

  const ENGEL_RE = /^Hesabın (kural ihlali nedeniyle kapatıldı|.*tarihine kadar oyun yönetimi tarafından engellendi)/;
  const BAKIM_RE = /^Oyun bakımda\./;
  let tamEkranGosteriliyor = false;
  function tamEkran(baslik, metin, bakim, girisYok){
    if (tamEkranGosteriliyor) return; tamEkranGosteriliyor = true;
    try { if (typeof canliDurdur === "function") canliDurdur(); } catch (_) {}
    try { modalKapat(); } catch (_) {}
    try { D.durum = null; D.yigin = []; } catch (_) {}   // otomatik yenilemeler bu ekranı ezmesin
    // Hatayı yakalayan ekran kendi mesajını yazdıktan sonra çiz
    setTimeout(() => {
      const app = $("#app"); if (!app) return;
      app.innerHTML = `<div class="karsila">${typeof LOGO === "string" ? LOGO : ""}<h1>${e(baslik)}</h1><p class="giris">${e(metin)}</p>
        ${bakim ? `<button class="btn" id="kmTekrar">Tekrar dene</button>` : `<a class="btn" style="text-decoration:none;display:block;text-align:center" href="mailto:${e(AYAR.ILETISIM || "")}">Oyun yönetimine yaz</a>`}
        ${girisYok ? `<button class="btn ikinci" id="kmGiris">Yönetici girişi</button>` : `<button class="btn ikinci" id="kmCikis">Çıkış yap</button>`}</div>`;
      const t = $("#kmTekrar"); if (t) t.onclick = () => { tamEkranGosteriliyor = false; basla(); };
      const g = $("#kmGiris"); if (g) g.onclick = () => { tamEkranGosteriliyor = false; if (typeof karsilama === "function") karsilama(); };
      const c = $("#kmCikis"); if (c) c.onclick = () => { tamEkranGosteriliyor = false; if (typeof cikisYap === "function") cikisYap(); else location.reload(); };
    }, 0);
  }
  function hataYakala(msg){
    msg = String(msg || "");
    if (ENGEL_RE.test(msg)) { tamEkran("Hesabın engellendi", msg, false); return true; }
    if (BAKIM_RE.test(msg)) { tamEkran("Bakım çalışması", msg, true); return true; }
    return false;
  }
  // API'yi sar: engel/bakım hatası hangi ekranda gelirse gelsin tam ekran göster
  function apiSar(a){
    if (!a || typeof a.rpc !== "function" || a._kmSarili) return a;
    const eskiRpc = a.rpc;
    a.rpc = async function(fn, args){
      try { return await eskiRpc.call(a, fn, args); }
      catch (err) { if (fn !== "uygulama_ayar" && hataYakala(err && err.message)) { const x = new Error(err.message); x.km = true; throw x; } throw err; }
    };
    a._kmSarili = true;
    return a;
  }
  window.YKM_SAR = apiSar;
  if (typeof gercekApi === "function") {
    const eskiApi = gercekApi;
    window.gercekApi = gercekApi = function(){ return apiSar(eskiApi.apply(this, arguments)); };
  }
  // Açılışta ayarları yükle (giriş ekranından önce)
  if (typeof basla === "function") {
    const eskiBasla = basla;
    window.basla = basla = async function(){
      tamEkranGosteriliyor = false;
      if (API) await uygulamaAyarYukle();
      if (YK.ayar && YK.ayar.bakim === true) {
        // Yönetici girebilsin diye durumu yine de dene: sunucu yöneticiyi geçirir
        try { if (await API.oturum()) { await durumYenile(); } else { return tamEkran("Bakım çalışması", "Oyun bakımda. " + (YK.ayar.bakim_mesaj || "Kısa süre içinde geri döneceğiz; hesabın, makamın ve paran güvende."), true, true); } }
        catch (err) { if (hataYakala(err && err.message)) return; }
      }
      return eskiBasla.apply(this, arguments);
    };
  }
  // Duyuru bandı ve bakım uyarısı (yönetici bakımdayken üstte görür)
  if (typeof iskelet === "function") {
    const eskiIskelet = iskelet;
    window.iskelet = iskelet = function(baslik, govde, opt){
      const r = eskiIskelet.apply(this, arguments);
      try {
        const ic = $("#icerik");
        if (ic && !ic.querySelector(".km-band,.km-bakim-ust")) {
          let ust = "";
          if (YK.ayar && YK.ayar.bakim === true && sahipMi()) ust += `<div class="km-bakim-ust">Bakım modu açık: oyuncular şu an giremiyor. Kapatmak için Kontrol Merkezi › Ayarlar.</div>`;
          const band = YK.ayar && typeof YK.ayar.duyuru_bandi === "string" ? YK.ayar.duyuru_bandi.trim() : "";
          if (band && (!opt || !opt.geri)) ust += `<div class="km-band">${e(band)}</div>`;
          if (ust) ic.insertAdjacentHTML("afterbegin", ust);
        }
        if ((baslik === "Yönetici paneli" || baslik === "Moderatör paneli") && ic && !ic.querySelector(".km-giris") && (sahipMi() || yetkiVar("para") || yetkiVar("makam"))) {
          ic.insertAdjacentHTML("afterbegin", `<div class="kart km-giris"><h2>Kontrol Merkezi</h2>
            <p class="alt">${sahipMi() ? "Oyundaki her şeye anında müdahale et: para yükle, engelle, göreve ata ya da görevden al, kasaları ve seçim takvimini değiştir, her tabloyu düzenle. Her işlem kayda geçer ve geri alınabilir." : "Sana verilen yetkilerle oyunculara para/kıdem ver ya da görev ata."}</p>
            <button class="btn altin" onclick="kontrolMerkezi()">Kontrol Merkezini aç</button></div>`);
        }
      } catch (_) {}
      return r;
    };
  }
  // Oyuncu kartına "Yönet" düğmesi
  if (typeof oyuncuKart === "function") {
    const eskiKart = oyuncuKart;
    window.oyuncuKart = oyuncuKart = async function(kad){
      const r = await eskiKart.apply(this, arguments);
      try {
        if (yetkiVar("oyuncu_ara") && (sahipMi() || yetkiVar("para") || yetkiVar("makam") || yetkiVar("hesap_kapat"))) {
          const m = $("#modal .modal");
          if (m && !m.querySelector(".km-yonet")) m.insertAdjacentHTML("beforeend", `<button class="btn altin km-yonet" style="margin-top:10px">Yönet (Kontrol Merkezi)</button>`);
          const b = m && m.querySelector(".km-yonet"); if (b) b.onclick = () => { modalKapat(); kmOyuncuAc(kad); };
        }
      } catch (_) {}
      return r;
    };
  }

  /* =====================================================================
     2) Kontrol Merkezi ana ekranı
     ===================================================================== */
  function sekmeler(){
    const l = [["pano","Pano"],["oyuncular","Oyuncular"]];
    if (yetkiVar("makam")) l.push(["gorevler","Görevler"]);
    if (sahipMi()) l.push(["ekonomi","Ekonomi"],["secimler","Seçimler"],["veri","Veri"],["gecmis","Geçmiş"],["ayarlar","Ayarlar"]);
    return l;
  }
  function kmIskelet(govde){
    const l = sekmeler(); if (!l.some(x => x[0] === YK.sekme)) YK.sekme = "pano";
    iskelet("Kontrol Merkezi", `<div class="segment" style="margin-bottom:12px;flex-wrap:wrap">${l.map(([k, a]) => `<button class="${YK.sekme === k ? "aktif" : ""}" data-km-sekme="${k}" style="flex:1 0 auto">${a}</button>`).join("")}</div><div id="kmIc">${govde}</div>`, { geri: true });
    document.querySelectorAll("[data-km-sekme]").forEach(b => b.onclick = () => { YK.sekme = b.dataset.kmSekme; kmCiz(); });
  }
  window.kontrolMerkezi = function(sekme){ if (sekme) YK.sekme = sekme; ekranAc(kmCiz); };
  async function kmCiz(){
    kmIskelet(`<div class="yukleniyor">Yükleniyor…</div>`);
    const fn = { pano: panoCiz, oyuncular: oyuncularCiz, gorevler: gorevlerCiz, ekonomi: ekonomiCiz, secimler: secimlerCiz, veri: veriCiz, gecmis: gecmisCiz, ayarlar: ayarlarCiz }[YK.sekme] || panoCiz;
    try { await fn($("#kmIc")); } catch (err) { const ic = $("#kmIc"); if (ic) ic.innerHTML = `<div class="bos">${e(hataCevir(err.message))}</div>`; }
  }

  /* ---------- Pano ---------- */
  async function panoCiz(ic){
    const o = await rpc("yk_ozet");
    ic.innerHTML = `<div class="kart"><h2>Anlık durum</h2><div class="gosterge">
        <div><div class="ad">Oyuncu</div><div class="deger">${fmt(o.oyuncu)}</div><div class="fark">+${fmt(o.yeni24)} bugün</div></div>
        <div><div class="ad">Çevrimiçi (15 dk)</div><div class="deger">${fmt(o.cevrimici)}</div><div class="fark">24 sa: ${fmt(o.aktif24)}</div></div>
        <div><div class="ad">Bekleyen kayıt</div><div class="deger ${o.bekleyen_kayit ? "kotu" : ""}">${fmt(o.bekleyen_kayit)}</div><div class="fark">şikâyet: ${fmt(o.sikayet)}</div></div>
        <div><div class="ad">Engelli</div><div class="deger">${fmt(o.engelli)}</div><div class="fark">susturulmuş: ${fmt(o.susturulmus)}</div></div>
        <div><div class="ad">Oyunculardaki para</div><div class="deger" style="font-size:19px">${paraKisa ? paraKisa(o.toplam_para) : tl(o.toplam_para)}</div><div class="fark">hazine: ${fmt(o.hazine, 1)}</div></div>
        <div><div class="ad">Sistem hatası (24 sa)</div><div class="deger ${(o.motor_hata24 || o.cron_hata24) ? "kotu" : ""}">${fmt((o.motor_hata24 || 0) + (o.cron_hata24 || 0))}</div><div class="fark">açık sandık: ${fmt(o.acik_secim)}</div></div>
      </div>${o.bakim ? `<div class="km-uyari">Bakım modu açık: oyuncular giremiyor.</div>` : ""}</div>
      ${yetkiVar("para") ? `<div class="kart"><h2>Toplu para / kıdem</h2><p class="alt">Eksi tutar yazarsan para düşer (cüzdandaki kadarı). Her oyuncuya bildirim gider; işlem günlüğe yazılır.</p>
        <div class="alan"><label>Kime?</label>${sec("kmHedef", HEDEF, "herkes")}</div><div class="alan" id="kmHedefDeger"></div>
        <div class="alan"><label>Kişi başı tutar (₺)</label><input class="km-girdi" id="kmTutar" type="number" inputmode="decimal" placeholder="Örn. 10000 ya da -5000"></div>
        <div class="alan"><label>Açıklama (oyuncuya görünür)</label><input class="km-girdi" id="kmNeden" maxlength="200" placeholder="Örn. Bayram ikramiyesi"></div>
        <div class="km-izgara"><button class="btn altin" id="kmParaGonder">Para gönder</button><button class="btn ikinci" id="kmKidemGonder">Kıdem olarak ver</button></div></div>` : ""}
      ${yetkiVar("duyuru") ? `<div class="kart"><h2>Bildirim gönder</h2><p class="alt">Seçtiğin gruba zil bildirimi (push açıksa telefona da) gider.</p>
        <div class="alan"><label>Kime?</label>${sec("kmBHedef", HEDEF, "herkes")}</div><div class="alan" id="kmBHedefDeger"></div>
        <textarea class="alanmetin km-girdi" id="kmBMetin" maxlength="500" placeholder="Bildirim metni"></textarea><button class="btn altin" id="kmBGonder">Bildirimi gönder</button></div>` : ""}
      ${sahipMi() ? `<div class="kart"><h2>Hızlı ayarlar</h2>
        <label class="anahtar"><span><b>Bakım modu</b><div class="kucuk">Açıkken yalnız sen girebilirsin; oyun dünyası (seçimler, maaşlar) işlemeye devam eder.</div></span><input type="checkbox" id="kmBakim" ${o.bakim ? "checked" : ""}></label>
        <div class="alan"><label>Üst duyuru bandı (boş bırakırsan görünmez)</label><input class="km-girdi" id="kmBand" maxlength="160" value="${e(o.duyuru_bandi || "")}" placeholder="Örn. Bu akşam 21.00'de büyük miting!"></div>
        <button class="btn ikinci" id="kmHizliKaydet">Kaydet</button></div>` : ""}`;
    hedefAlan("kmHedef", "kmHedefDeger"); hedefAlan("kmBHedef", "kmBHedefDeger");
    const paraBtn = $("#kmParaGonder"), kidemBtn = $("#kmKidemGonder");
    const topluIslem = async (kidem) => {
      const h = $("#kmHedef").value, d = hedefDeger("kmHedefDeger"), tut = Number($("#kmTutar").value), neden = $("#kmNeden").value.trim();
      if (!tut) return toast("Tutar yaz.", true);
      if (h === "oyuncu" && !d) return toast("Oyuncunun kullanıcı adını yaz.", true);
      const kimeAd = (HEDEF.find(x => x[0] === h) || [])[1];
      if (!await onayla(kidem ? "Kıdem ver" : (tut > 0 ? "Para yükle" : "Para düş"), `${e(kimeAd)}${d ? " (" + e(d) + ")" : ""} · kişi başı ${kidem ? fmt(tut) + " kıdem" : tl(tut)}. Onaylıyor musun?`, "Onayla", tut < 0)) return;
      try {
        const r = kidem ? await rpc("yk_kidem", { p_hedef: h, p_deger: d, p_miktar: tut, p_neden: neden || null })
                        : await rpc("yk_para", { p_hedef: h, p_deger: d, p_tutar: tut, p_neden: neden || null, p_bildir: true });
        toast(kidem ? `${fmt(r.kisi)} oyuncuya kıdem verildi.` : `${fmt(r.kisi)} oyuncu · toplam ${tl(r.toplam)}`);
        try { await durumYenile(); } catch (_) {}
      } catch (err) { hata(err); }
    };
    if (paraBtn) paraBtn.onclick = () => topluIslem(false);
    if (kidemBtn) kidemBtn.onclick = () => topluIslem(true);
    if ($("#kmBGonder")) $("#kmBGonder").onclick = async () => {
      const h = $("#kmBHedef").value, d = hedefDeger("kmBHedefDeger"), m = $("#kmBMetin").value.trim();
      if (!m) return toast("Metni yaz.", true);
      try { const r = await rpc("yk_bildirim", { p_hedef: h, p_deger: d, p_metin: m }); toast(`${fmt(r.kisi)} oyuncuya gönderildi.`); $("#kmBMetin").value = ""; } catch (err) { hata(err); }
    };
    if ($("#kmHizliKaydet")) $("#kmHizliKaydet").onclick = async () => {
      const bakim = $("#kmBakim").checked;
      if (bakim && !o.bakim && !await onayla("Bakım modunu aç", "Sen hariç hiçbir oyuncu oyuna giremeyecek; oyundakiler bakım ekranına düşecek.", "Bakıma al", true)) return;
      try { await rpc("yk_uygulama_ayar_kaydet", { p: { bakim, duyuru_bandi: $("#kmBand").value.trim() } }); await uygulamaAyarYukle(); toast("Kaydedildi."); kmCiz(); } catch (err) { hata(err); }
    };
  }
  async function hedefAlan(secId, kutuId){
    const s = $("#" + secId), k = $("#" + kutuId); if (!s || !k) return;
    const ciz = async () => {
      const v = s.value;
      if (v === "oyuncu") k.innerHTML = `<label>Kullanıcı adı</label><input class="km-girdi" data-hd="1" autocapitalize="off" autocomplete="off" spellcheck="false">`;
      else if (v === "il" || v === "parti") {
        k.innerHTML = `<div class="kucuk">Yükleniyor…</div>`;
        try { const kt = await katalog(); const liste = v === "il" ? ilListesi(kt).map(i => [i.id, i.ad]) : (kt.partiler || []).map(p => [p.id, `${p.kisa} · ${p.ad} (${p.uye} üye)`]);
          k.innerHTML = `<label>${v === "il" ? "İl" : "Parti"}</label><select class="km-girdi" data-hd="1">${liste.map(([a, b]) => `<option value="${e(a)}">${e(b)}</option>`).join("")}</select>`;
        } catch (err) { k.innerHTML = `<div class="kucuk">${e(hataCevir(err.message))}</div>`; }
      } else k.innerHTML = "";
    };
    s.onchange = ciz; await ciz();
  }
  function hedefDeger(kutuId){ const x = document.querySelector("#" + kutuId + " [data-hd]"); return x ? (x.value || "").trim() || null : null; }

  /* ---------- Oyuncular ---------- */
  async function oyuncularCiz(ic){
    const s = YK.oyuncu;
    const r = await rpc("yk_oyuncular", { p_ara: s.ara || null, p_filtre: s.filtre, p_sirala: s.sirala, p_limit: 40, p_offset: s.offset });
    const FILTRE = [["hepsi","Hepsi"],["cevrimici","Çevrimiçi"],["makamli","Makamlı"],["engelli","Engelli"],["susturulmus","Susturulmuş"],["yeni","Yeni"],["yonetim","Yönetim"]];
    const SIRA = [["son_gorulme","Son görülme"],["para","Para"],["kidem","Kıdem"],["yeni","Yeni katılan"],["ad","Ada göre"]];
    ic.innerHTML = `<div class="kart"><div class="km-satir"><input class="km-girdi" id="kmOAra" placeholder="Kullanıcı adı ara" value="${e(s.ara)}" autocapitalize="off" autocomplete="off" spellcheck="false"><button class="btn yarim km-kucukbtn" style="width:auto;margin:0" id="kmOBul">Ara</button></div>
      <div class="km-satir" style="margin-top:8px">${sec("kmOFiltre", FILTRE, s.filtre)}${sec("kmOSira", SIRA, s.sirala)}</div>
      <div class="kucuk" style="margin-top:8px">${fmt(r.toplam)} oyuncu</div>
      ${r.liste.map(x => `<div class="liste-satir" data-oy="${e(x.kad)}" style="cursor:pointer">
        <div class="orta"><b>${e(x.kad)} ${x.yonetici ? `<span class="rozet altin">yönetici</span>` : x.moderator ? `<span class="rozet altin">moderatör</span>` : ""} ${x.yasakli ? `<span class="rozet kirmizi">${x.engel_bitis ? "engelli" : "kapalı"}</span>` : ""}${x.susturma_bitis ? ` <span class="rozet sari">susturuldu</span>` : ""}</b>
        <div class="kucuk">${e(x.il || "—")} · ${x.parti ? e(x.parti.kisa) : "bağımsız"} · ${tl(x.para)} · kıdem ${fmt(x.kidem || 0, 1)}${x.makam ? " · " + e(x.makam) + (x.makam_say > 1 ? ` +${x.makam_say - 1}` : "") : ""}</div>
        <div class="kucuk">son görülme ${ts(x.son_gorulme)}</div></div><span style="color:var(--mut)">›</span></div>`).join("") || `<div class="bos">Oyuncu bulunamadı.</div>`}
      ${r.toplam > 40 ? `<div class="km-izgara"><button class="btn ikinci" id="kmOOnce" ${s.offset <= 0 ? "disabled" : ""}>← Önceki</button><button class="btn ikinci" id="kmOSonra" ${s.offset + 40 >= r.toplam ? "disabled" : ""}>Sonraki →</button></div>` : ""}</div>`;
    const yenile = () => { s.ara = $("#kmOAra").value.trim(); s.filtre = $("#kmOFiltre").value; s.sirala = $("#kmOSira").value; kmCiz(); };
    $("#kmOBul").onclick = () => { s.offset = 0; yenile(); };
    $("#kmOAra").onkeydown = (ev) => { if (ev.key === "Enter") { s.offset = 0; yenile(); } };
    $("#kmOFiltre").onchange = () => { s.offset = 0; yenile(); };
    $("#kmOSira").onchange = () => { s.offset = 0; yenile(); };
    if ($("#kmOOnce")) $("#kmOOnce").onclick = () => { s.offset = Math.max(0, s.offset - 40); yenile(); };
    if ($("#kmOSonra")) $("#kmOSonra").onclick = () => { s.offset += 40; yenile(); };
    ic.querySelectorAll("[data-oy]").forEach(el => el.onclick = () => kmOyuncuAc(el.dataset.oy));
  }

  /* ---------- Tek oyuncu yönetimi ---------- */
  window.kmOyuncuAc = function(kad){ YK.secili = kad; ekranAc(kmOyuncuEkrani); };
  async function kmOyuncuEkrani(){
    yukleniyor("Oyuncu yönetimi");
    let o; try { o = await rpc("yk_oyuncu", { p_kad: YK.secili }); } catch (err) { iskelet("Oyuncu yönetimi", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
    kmOyuncuCiz(o);
  }
  function kmOyuncuCiz(o){
    YK.secili = o.kad;
    const durumRozet = `${o.yonetici ? `<span class="rozet altin">yönetici</span> ` : ""}${o.moderator ? `<span class="rozet altin">moderatör</span> ` : ""}${o.yasakli ? `<span class="rozet kirmizi">${o.engel_bitis ? "engelli: " + ts(o.engel_bitis) + "'e kadar" : "hesap kapalı"}</span> ` : ""}${o.susturma_bitis ? `<span class="rozet sari">susturuldu: ${ts(o.susturma_bitis)}</span> ` : ""}${o.adaylik_yasagi_bitis ? `<span class="rozet sari">aday olamaz: ${ts(o.adaylik_yasagi_bitis)}</span>` : ""}`;
    const b = (id, ad, sinif, kosul) => kosul === false ? "" : `<button class="btn ${sinif || "ikinci"}" id="${id}">${ad}</button>`;
    iskelet("Oyuncu yönetimi", `
      <div class="kart"><div style="display:flex;gap:12px;align-items:center">${typeof portre === "function" ? portre(o.kad, o.parti && o.parti.renk, 56) : ""}<div style="min-width:0"><h2 style="margin:0">${e(o.kad)}</h2><div class="kucuk">${e(o.unvan || "")}</div></div></div>
        <div style="margin-top:6px">${durumRozet}</div>
        ${o.engel_neden ? `<div class="kucuk">Engel gerekçesi: ${e(o.engel_neden)}</div>` : ""}
        ${o.eposta ? `<div class="kv"><span class="k">E-posta</span><span class="v">${e(o.eposta)}</span></div>` : ""}
        <div class="kv"><span class="k">İl</span><span class="v">${e(o.il || "—")}</span></div>
        <div class="kv"><span class="k">Parti</span><span class="v">${o.parti ? e(o.parti.ad) + (o.parti.gb ? " · Genel Başkan" : "") + (o.gby ? ` · ${o.gby}. GBY` : "") : "bağımsız"}</span></div>
        <div class="kv"><span class="k">Cüzdan / kıdem</span><span class="v">${tl(o.para)} · ${fmt(o.kidem, 1)}</span></div>
        ${o.banka && o.banka.kredi ? `<div class="kv"><span class="k">Kredi borcu</span><span class="v kotu">${tl(o.banka.kredi)}</span></div>` : ""}
        <div class="kv"><span class="k">Katılım / son görülme</span><span class="v kucuk">${ts(o.olusturma)} / ${ts(o.son_gorulme)}</span></div>
        <div class="kv"><span class="k">Hakkındaki şikâyet</span><span class="v">${fmt(o.sikayet)}</span></div>
        ${o.kayit ? `<div class="kv"><span class="k">Kayıt başvurusu</span><span class="v">${e(o.kayit)}</span></div>` : ""}</div>
      <div class="kart"><h2>Görevleri</h2>
        ${(o.makamlar || []).map(m => `<div class="liste-satir"><div class="orta"><b>${e(m.ad)}</b><div class="kucuk">${ts(m.bas)} · ${e(m.kaynak)}</div></div>${yetkiVar("makam") ? `<button class="rozet kirmizi km-kucukbtn" data-km-al="${m.id}">Görevden al</button>` : ""}</div>`).join("")}
        ${o.parti && o.parti.gb ? `<div class="liste-satir"><div class="orta"><b>${e(o.parti.kisa)} Genel Başkanı</b></div>${yetkiVar("makam") ? `<button class="rozet kirmizi km-kucukbtn" data-km-pg="gb">Görevden al</button>` : ""}</div>` : ""}
        ${o.gby ? `<div class="liste-satir"><div class="orta"><b>${e(o.parti ? o.parti.kisa : "")} ${o.gby}. Genel Başkan Yardımcısı</b></div>${yetkiVar("makam") ? `<button class="rozet kirmizi km-kucukbtn" data-km-pg="gby">Görevden al</button>` : ""}</div>` : ""}
        ${!(o.makamlar || []).length && !(o.parti && o.parti.gb) && !o.gby ? `<div class="bos" style="padding:8px 0">Görevi yok.</div>` : ""}
        ${(o.gecmis_makam || []).length ? `<details style="margin-top:8px"><summary class="kucuk">Geçmiş görevler (${o.gecmis_makam.length})</summary>${o.gecmis_makam.map(g => `<div class="kucuk" style="padding:3px 0">${e(g.ad)} · ${ts(g.bas)} → ${ts(g.bit)}${g.neden ? " · " + e(g.neden) : ""}</div>`).join("")}</details>` : ""}</div>
      <div class="kart"><h2>İşlemler</h2><div class="km-izgara">
        ${b("kmPara", "Para ver / al", "altin", yetkiVar("para"))}
        ${b("kmKidem", "Kıdem ver / al", "ikinci", yetkiVar("para"))}
        ${b("kmGorev", "Göreve ata", "altin", yetkiVar("makam"))}
        ${b("kmParti", "Partisini değiştir", "ikinci", yetkiVar("makam"))}
        ${b("kmIl", "İlini değiştir", "ikinci", yetkiVar("makam"))}
        ${b("kmAdaylik", "Aday olma yasağı", "ikinci", yetkiVar("makam"))}
        ${b("kmBildir", "Bildirim gönder", "ikinci", yetkiVar("duyuru"))}
        ${b("kmSustur", o.susturma_bitis ? "Susturmayı kaldır" : "Sustur", "ikinci", yetkiVar("sustur"))}
        ${b("kmEngel", o.yasakli ? "Engeli kaldır" : "Engelle", o.yasakli ? "altin" : "tehlike", yetkiVar("hesap_kapat"))}
        ${b("kmAd", "Adını değiştir", "ikinci", sahipMi())}
        ${b("kmVeride", "Veride aç", "ikinci", sahipMi())}
      </div></div>
      <div class="kart"><h2>Son para hareketleri</h2>${(o.hareketler || []).map(h => `<div class="kv"><span class="k">${ts(h.zaman)} · ${e(h.aciklama || h.tur)}</span><span class="v ${h.tutar < 0 ? "kotu" : ""}">${h.tutar > 0 ? "+" : ""}${tl(h.tutar)}</span></div>`).join("") || `<div class="bos" style="padding:8px 0">Hareket yok.</div>`}</div>
      <div class="kart"><h2>Son mesajları</h2>${(o.mesajlar || []).map(m => `<div class="kucuk" style="padding:4px 0;${m.gizli ? "text-decoration:line-through" : ""}">${ts(m.zaman)} · ${e(m.kanal)} · ${e(m.metin)}</div>`).join("") || `<div class="bos" style="padding:8px 0">Mesaj yok.</div>`}</div>`, { geri: true });
    const sonra = (yeni) => { if (yeni && yeni.kad) kmOyuncuCiz(yeni); else kmOyuncuEkrani(); try { durumYenile(); } catch (_) {} };
    const tikla = (id, f) => { const x = $("#" + id); if (x) x.onclick = f; };
    document.querySelectorAll("[data-km-al]").forEach(x => x.onclick = async () => {
      const neden = await girdiModal("Görevden al", "Gerekçe (isteğe bağlı; oyuncuya bildirilir)", "", "Görevden al", true);
      if (neden === null) return;
      try { sonra(await rpc("yk_makam_al", { p_makam: +x.dataset.kmAl, p_neden: neden || null })); toast("Görevden alındı."); } catch (err) { hata(err); }
    });
    document.querySelectorAll("[data-km-pg]").forEach(x => x.onclick = async () => {
      if (!await onayla("Parti görevinden al", `${e(o.kad)} ${x.dataset.kmPg === "gb" ? "genel başkanlıktan" : "genel başkan yardımcılığından"} alınacak.`, "Görevden al", true)) return;
      try { sonra(await rpc("yk_parti_gorev_al", { p_kad: o.kad, p_rol: x.dataset.kmPg })); toast("Görevden alındı."); } catch (err) { hata(err); }
    });
    tikla("kmPara", () => tutarModal(o, false, sonra));
    tikla("kmKidem", () => tutarModal(o, true, sonra));
    tikla("kmGorev", () => gorevModal(o.kad, sonra));
    tikla("kmParti", async () => {
      const kt = await katalog().catch(hata); if (!kt) return;
      const m = modal(`<h3 style="font-size:19px;font-weight:800">Partisini değiştir</h3><p class="alt">Mevcut partisinden ayrılır (parti görevleri ve bekleyen adaylıkları düşer), seçtiğin partiye üye olur.</p>
        <div class="alan">${sec("kmPartiSec", [["", "Bağımsız (partisiz)"]].concat((kt.partiler || []).map(p => [p.id, `${p.kisa} · ${p.ad}`])), o.parti ? o.parti.id : "")}</div>
        <button class="btn altin" id="kmPartiK">Kaydet</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
      $("#kmPartiK", m).onclick = async () => { const v = $("#kmPartiSec", m).value; try { const r = await rpc("yk_parti_degistir", { p_kad: o.kad, p_parti: v ? +v : null }); modalKapat(); toast("Kaydedildi."); YK.cache.katalog = null; sonra(r); } catch (err) { hata(err); } };
    });
    tikla("kmIl", async () => {
      const kt = await katalog().catch(() => null);
      const m = modal(`<h3 style="font-size:19px;font-weight:800">İlini değiştir</h3><p class="alt">Taşınma masrafı alınmaz. Görevleri değişmez.</p>
        <div class="alan">${sec("kmIlSec", ilListesi(kt).map(i => [i.id, i.ad]), o.il_id)}</div><button class="btn altin" id="kmIlK">Kaydet</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
      $("#kmIlK", m).onclick = async () => { try { const r = await rpc("yk_il_degistir", { p_kad: o.kad, p_il: +$("#kmIlSec", m).value }); modalKapat(); toast("Kaydedildi."); sonra(r); } catch (err) { hata(err); } };
    });
    tikla("kmAdaylik", async () => {
      const g = await girdiModal("Aday olma yasağı", "Kaç gün? (0 yazarsan yasak kalkar)", o.adaylik_yasagi_bitis ? "0" : "30", "Kaydet", false, "number");
      if (g === null) return;
      try { sonra(await rpc("yk_adaylik_yasagi", { p_kad: o.kad, p_gun: Number(g) || 0, p_neden: null })); toast("Kaydedildi."); } catch (err) { hata(err); }
    });
    tikla("kmBildir", async () => {
      const t = await girdiModal("Bildirim gönder", `${e(o.kad)} adlı oyuncuya`, "", "Gönder", false, "textarea");
      if (!t) return;
      try { await rpc("yk_bildirim", { p_hedef: "oyuncu", p_deger: o.kad, p_metin: t }); toast("Gönderildi."); } catch (err) { hata(err); }
    });
    tikla("kmSustur", async () => {
      if (o.susturma_bitis) { try { sonra(await rpc("yk_sustur", { p_kad: o.kad, p_saat: 0, p_neden: null })); toast("Susturma kaldırıldı."); } catch (err) { hata(err); } return; }
      const m = modal(`<h3 style="font-size:19px;font-weight:800">Sohbette sustur</h3><p class="alt">Süre boyunca sohbete ve özel mesaja yazamaz; oyunun geri kalanını oynar.</p>
        <div class="alan">${sec("kmSSure", [[1,"1 saat"],[6,"6 saat"],[24,"1 gün"],[72,"3 gün"],[168,"7 gün"],[720,"30 gün"]], 24)}</div>
        <div class="alan"><label>Gerekçe (oyuncuya bildirilir)</label><input class="km-girdi" id="kmSNeden" maxlength="200"></div>
        <button class="btn tehlike" id="kmSK">Sustur</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
      $("#kmSK", m).onclick = async () => { try { const r = await rpc("yk_sustur", { p_kad: o.kad, p_saat: +$("#kmSSure", m).value, p_neden: $("#kmSNeden", m).value.trim() || null }); modalKapat(); toast("Susturuldu."); sonra(r); } catch (err) { hata(err); } };
    });
    tikla("kmEngel", async () => {
      if (o.yasakli) {
        if (!await onayla("Engeli kaldır", `${e(o.kad)} yeniden oyuna girebilecek.`, "Engeli kaldır")) return;
        try { sonra(await rpc("yk_engel_kaldir", { p_kad: o.kad })); toast("Engel kaldırıldı."); } catch (err) { hata(err); }
        return;
      }
      const m = modal(`<h3 style="font-size:19px;font-weight:800">${e(o.kad)} · engelle</h3><p class="alt">Engelli oyuncu oyuna giremez; açarsa engel süresini ve gerekçeyi görür. Oyundaysa birkaç saniye içinde dışarı düşer.</p>
        <div class="alan"><label>Süre</label>${sec("kmESure", [[1,"1 gün"],[3,"3 gün"],[7,"7 gün"],[30,"30 gün"],[90,"90 gün"],[0,"Kalıcı"]], 7)}</div>
        <div class="alan"><label>Gerekçe (oyuncu görür)</label><input class="km-girdi" id="kmENeden" maxlength="200" placeholder="Örn. Çoklu hesapla oy"></div>
        <label class="anahtar"><span><b>Hesabı tamamen kapat</b><div class="kucuk">Tüm görevlerinden alınır, partisinden çıkar, mesajları gizlenir. Kapatmazsan görevleri yerinde kalır.</div></span><input type="checkbox" id="kmEKapat"></label>
        <button class="btn tehlike" id="kmEK">Engelle</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
      $("#kmEK", m).onclick = async () => {
        const gun = +$("#kmESure", m).value, kapat = $("#kmEKapat", m).checked;
        try { const r = await rpc("yk_engelle", { p_kad: o.kad, p_gun: gun || null, p_neden: $("#kmENeden", m).value.trim() || null, p_hesabi_kapat: kapat }); modalKapat(); toast("Oyuncu engellendi."); sonra(r); } catch (err) { hata(err); }
      };
    });
    tikla("kmAd", async () => {
      const y = await girdiModal("Adını değiştir", "Yeni kullanıcı adı (3-20 karakter)", o.kad, "Kaydet");
      if (!y || y === o.kad) return;
      try { sonra(await rpc("yk_ad_degistir", { p_kad: o.kad, p_yeni: y })); toast("Ad değiştirildi."); } catch (err) { hata(err); }
    });
    tikla("kmVeride", () => { YK.veri = Object.assign(YK.veri, { tablo: "oyun.profiller", ara: "", sutun: "id", deger: o.id, offset: 0 }); YK.sekme = "veri"; ekranAc(kmCiz); });
  }

  function girdiModal(baslik, etiket, deger, buton, tehlike, tip){
    return new Promise(res => {
      const alan = tip === "textarea" ? `<textarea class="km-girdi" id="kmGirdi" maxlength="500">${e(deger || "")}</textarea>`
        : `<input class="km-girdi" id="kmGirdi" ${tip === "number" ? 'type="number" inputmode="decimal"' : ""} value="${e(deger || "")}" autocapitalize="off" autocomplete="off" spellcheck="false">`;
      const m = modal(`<h3 style="font-size:19px;font-weight:800">${e(baslik)}</h3><div class="alan"><label>${etiket}</label>${alan}</div>
        <button class="btn ${tehlike ? "tehlike" : "altin"}" id="kmGirdiTamam">${e(buton || "Tamam")}</button><button class="btn ikinci" id="kmGirdiVazgec">Vazgeç</button>`);
      const kapan = (v) => { modalKapat(); res(v); };
      $("#kmGirdiTamam", m).onclick = () => kapan($("#kmGirdi", m).value.trim());
      $("#kmGirdiVazgec", m).onclick = () => kapan(null);
      setTimeout(() => { try { $("#kmGirdi", m).focus(); } catch (_) {} }, 50);
    });
  }
  function tutarModal(o, kidem, sonra){
    const m = modal(`<h3 style="font-size:19px;font-weight:800">${e(o.kad)} · ${kidem ? "kıdem" : "para"}</h3>
      <p class="alt">Şu an: ${kidem ? fmt(o.kidem, 1) + " kıdem" : tl(o.para)}. Eksi yazarsan ${kidem ? "kıdem düşer" : "para düşer (cüzdandaki kadarı)"}.</p>
      <div class="km-satir" style="margin-top:6px">${(kidem ? [5, 10, 50, 100] : [1000, 10000, 100000, 1000000]).map(x => `<button class="rozet km-kucukbtn" data-hizli="${x}">+${fmt(x)}</button>`).join("")}</div>
      <div class="alan"><label>${kidem ? "Kıdem" : "Tutar (₺)"}</label><input class="km-girdi" id="kmTM" type="number" inputmode="decimal"></div>
      <div class="alan"><label>Açıklama (oyuncuya görünür)</label><input class="km-girdi" id="kmTN" maxlength="200"></div>
      ${kidem ? "" : `<label class="anahtar"><span><b>Oyuncuya bildirim gitsin</b></span><input type="checkbox" id="kmTB" checked></label>`}
      <button class="btn altin" id="kmTK">Uygula</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    m.querySelectorAll("[data-hizli]").forEach(x => x.onclick = () => { $("#kmTM", m).value = x.dataset.hizli; });
    $("#kmTK", m).onclick = async () => {
      const v = Number($("#kmTM", m).value); if (!v) return toast("Miktar yaz.", true);
      try {
        if (kidem) await rpc("yk_kidem", { p_hedef: "oyuncu", p_deger: o.kad, p_miktar: v, p_neden: $("#kmTN", m).value.trim() || null });
        else await rpc("yk_para", { p_hedef: "oyuncu", p_deger: o.kad, p_tutar: v, p_neden: $("#kmTN", m).value.trim() || null, p_bildir: $("#kmTB", m).checked });
        modalKapat(); toast("Uygulandı."); sonra(await rpc("yk_oyuncu", { p_kad: o.kad }));
      } catch (err) { hata(err); }
    };
  }
  async function gorevModal(kad, sonra, varsayilan){
    const kt = await katalog().catch(hata); if (!kt) return;
    const m = modal(`<h3 style="font-size:19px;font-weight:800">Göreve ata</h3><p class="alt">Tek kişilik koltuktaki (CB, bakanlık, belediye, TBMM Başkanlığı, CB yardımcılığı) mevcut kişi görevden alınır.</p>
      ${kad ? "" : `<div class="alan"><label>Kullanıcı adı</label><input class="km-girdi" id="kmGKad" autocapitalize="off" autocomplete="off" spellcheck="false"></div>`}
      <div class="alan"><label>Görev</label>${sec("kmGTur", MAKAM_TUR, (varsayilan && varsayilan.tur) || "bakan")}</div>
      <div id="kmGEk"></div>
      <label class="anahtar"><span><b>Tek görev kuralını uygula</b><div class="kucuk">Yeni görevle birleşemeyen eski görevleri sona erer (oyunun normal kuralı).</div></span><input type="checkbox" id="kmGTek" checked></label>
      <button class="btn altin" id="kmGK">Ata</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    const ek = () => {
      const t = $("#kmGTur", m).value, k = $("#kmGEk", m);
      if (t === "mv" || t === "bel") k.innerHTML = `<div class="alan"><label>İl</label>${sec("kmGIl", ilListesi(kt).map(i => [i.id, i.ad + (t === "mv" && i.mv != null ? ` (${i.mv_dolu}/${i.mv} vekil)` : "")]), varsayilan && varsayilan.il_id)}</div>`;
      else if (t === "bakan") k.innerHTML = `<div class="alan"><label>Bakanlık</label>${sec("kmGBak", (kt.bakanliklar || []).map(b => [b.kod, b.ad]), varsayilan && varsayilan.bakanlik)}</div>`;
      else if (t === "cb_yardimcisi") k.innerHTML = `<div class="alan"><label>Sıra</label>${sec("kmGSira", [[1, "1. Cumhurbaşkanı Yardımcısı"], [2, "2. Cumhurbaşkanı Yardımcısı"]], 1)}</div>`;
      else if (t === "gby") k.innerHTML = `<div class="alan"><label>Sıra (oyuncunun kendi partisinde)</label>${sec("kmGSira", [1, 2, 3, 4, 5, 6].map(i => [i, i + ". Genel Başkan Yardımcısı"]), 1)}</div>`;
      else if (t === "gb" || t === "grup_bskv") k.innerHTML = `<p class="kucuk">Oyuncunun kendi partisinde uygulanır. Partisi yoksa önce "Partisini değiştir".</p>`;
      else k.innerHTML = "";
    };
    $("#kmGTur", m).onchange = ek; ek();
    $("#kmGK", m).onclick = async () => {
      const k = kad || ($("#kmGKad", m) && $("#kmGKad", m).value.trim()); if (!k) return toast("Kullanıcı adını yaz.", true);
      const t = $("#kmGTur", m).value, x = (id) => { const el = $("#" + id, m); return el ? el.value : null; };
      try {
        const r = await rpc("yk_makam_ver", { p_kad: k, p_tur: t, p_il: x("kmGIl") ? +x("kmGIl") : null, p_bakanlik: x("kmGBak"), p_sira: x("kmGSira") ? +x("kmGSira") : null, p_tek_gorev: $("#kmGTek", m).checked });
        modalKapat(); YK.cache.katalog = null; toast("Göreve atandı."); sonra(r);
      } catch (err) { hata(err); }
    };
  }

  /* ---------- Görevler ---------- */
  async function gorevlerCiz(ic){
    YK.cache.katalog = null;
    const kt = await katalog();
    const grup = {}; (kt.makamlar || []).forEach(m => { (grup[m.tur] = grup[m.tur] || []).push(m); });
    const satir = (m) => `<div class="liste-satir"><div class="orta"><b>${e(m.ad)}</b><div class="kucuk"><a class="bag" href="#" data-km-oy="${e(m.kad)}">${e(m.kad)}</a>${m.parti ? " · " + e(m.parti) : ""} · ${ts(m.bas)}</div></div>
        <button class="rozet km-kucukbtn" data-km-degis='${e(JSON.stringify({ tur: m.tur, il_id: m.il_id, bakanlik: m.bakanlik }))}'>Değiştir</button><button class="rozet kirmizi km-kucukbtn" data-km-al="${m.id}">Al</button></div>`;
    const bosBakanlik = (kt.bakanliklar || []).filter(b => !(grup.bakan || []).some(m => m.bakanlik === b.kod));
    ic.innerHTML = `<div class="kart"><button class="btn altin" id="kmYeniGorev">+ Birini göreve ata</button></div>
      ${MAKAM_TUR.filter(([t]) => !["gb","gby"].includes(t)).map(([t, ad]) => `<div class="kart"><h2>${e(ad)} (${(grup[t] || []).length})</h2>${(grup[t] || []).map(satir).join("") || `<div class="bos" style="padding:6px 0">Boş.</div>`}
        ${t === "bakan" && bosBakanlik.length ? `<div class="kucuk" style="margin-top:6px">Boş bakanlıklar: ${bosBakanlik.map(b => e(b.ad)).join(", ")}</div>` : ""}</div>`).join("")}
      <div class="kart"><h2>Parti genel başkanları ve yardımcıları</h2>${(kt.parti_gorev || []).map(g => `<div class="liste-satir"><div class="orta"><b>${e(g.parti)} · ${g.rol === "gb" ? "Genel Başkan" : g.sira + ". GBY"}</b><div class="kucuk"><a class="bag" href="#" data-km-oy="${e(g.kad)}">${e(g.kad)}</a></div></div>
        <button class="rozet kirmizi km-kucukbtn" data-km-pg='${e(JSON.stringify({ kad: g.kad, rol: g.rol }))}'>Al</button></div>`).join("") || `<div class="bos">Yok.</div>`}</div>`;
    $("#kmYeniGorev").onclick = () => gorevModal(null, () => kmCiz());
    ic.querySelectorAll("[data-km-oy]").forEach(a => a.onclick = (ev) => { ev.preventDefault(); kmOyuncuAc(a.dataset.kmOy); });
    ic.querySelectorAll("[data-km-degis]").forEach(b => b.onclick = () => gorevModal(null, () => kmCiz(), JSON.parse(b.dataset.kmDegis)));
    ic.querySelectorAll("[data-km-al]").forEach(b => b.onclick = async () => {
      if (!await onayla("Görevden al", "Bu kişi görevden alınacak ve kendisine bildirim gidecek.", "Görevden al", true)) return;
      try { await rpc("yk_makam_al", { p_makam: +b.dataset.kmAl, p_neden: null }); toast("Görevden alındı."); kmCiz(); } catch (err) { hata(err); }
    });
    ic.querySelectorAll("[data-km-pg]").forEach(b => b.onclick = async () => {
      const x = JSON.parse(b.dataset.kmPg);
      if (!await onayla("Parti görevinden al", `${e(x.kad)} bu görevden alınacak.`, "Görevden al", true)) return;
      try { await rpc("yk_parti_gorev_al", { p_kad: x.kad, p_rol: x.rol }); toast("Görevden alındı."); kmCiz(); } catch (err) { hata(err); }
    });
  }

  /* ---------- Ekonomi ---------- */
  const ULKE_ALAN = [["hazine","Hazine (oyundaki birimiyle)"],["vergi","Gelir vergisi (%)"],["asgari","Asgari ücret (₺)"],["enflasyon","Enflasyon (%)"],["buyume","Büyüme (%)"],["issizlik","İşsizlik (%)"],
    ["memnuniyet","Halk memnuniyeti"],["kidem_primi","Kıdem primi"],["destek","Yeni vatandaş desteği"],["tasinma_destek","Taşınma desteği"],["belediye_payi","Belediye payı"],["parti_yardim","Parti yardımı"],["endeks","Fiyat endeksi"]];
  const AYAR_ALAN = [["baslangic_para","Yeni oyuncu başlangıç parası (₺)"],["maas_hizi","Vatandaş maaş hızı (çarpan)"],["baraj","Seçim barajı (%)"],["min_hesap_gun","Oy için hesap yaşı (gün)"],
    ["oy_min_kidem","Oy için en az kıdem"],["parti_kur_ucret","Parti kuruluş ücreti (₺)"],["parti_kurucu_sayi","Parti kurucu sayısı"],["havale_sinir","Günlük havale sınırı (asgari ücret katı)"],
    ["banka_tavan","Kişi başı mevduat tavanı (₺)"],["gazete_kur_ucret","Gazete kuruluş ücreti (₺)"],["mentor_odul","Yol arkadaşı ödülü (₺)"],["stant_bedel","Stant bedeli (₺)"]];
  async function ekonomiCiz(ic){
    const [u, a, kt] = await Promise.all([rpc("yk_tablo", { p_tablo: "oyun.ulke", p_limit: 1 }), rpc("yk_tablo", { p_tablo: "oyun.ayarlar", p_limit: 1 }), katalog()]);
    const ul = u.satirlar[0] || {}, ay = a.satirlar[0] || {};
    const alanlar = (liste, satir, on) => liste.filter(([k]) => satir[k] !== undefined).map(([k, ad]) => `<div class="payinput" style="grid-template-columns:1fr 130px"><span>${e(ad)}</span><input data-${on}="${k}" value="${e(satir[k] == null ? "" : satir[k])}" inputmode="decimal"></div>`).join("");
    ic.innerHTML = `<div class="kart"><h2>Kasaya para ekle / çıkar</h2><p class="alt">Eksi yazarsan düşer (sıfırın altına inmez). Her değişiklik Geçmiş sekmesinde geri alınabilir.</p>
        <div class="alan"><label>Kasa</label>${sec("kmKTur", [["hazine","Hazine"],["il","Bir ilin belediye kasası"],["parti","Bir partinin kasası"],["sirket","Şirket kasası (numarayla)"],["dernek","Dernek kasası (numarayla)"]], "hazine")}</div>
        <div class="alan" id="kmKSec"></div>
        <div class="alan"><label>Tutar</label><input class="km-girdi" id="kmKTutar" type="number" inputmode="decimal"></div>
        <div class="alan"><label>Açıklama</label><input class="km-girdi" id="kmKNeden" maxlength="200"></div>
        <button class="btn altin" id="kmKUygula">Uygula</button></div>
      <div class="kart"><h2>Ülke göstergeleri</h2><p class="alt">Doğrudan değer yaz; yalnız değiştirdiklerin kaydedilir.</p>${alanlar(ULKE_ALAN, ul, "ulke")}<button class="btn ikinci" id="kmUlkeK">Göstergeleri kaydet</button></div>
      <div class="kart"><h2>Oyun ayarları</h2>${alanlar(AYAR_ALAN, ay, "ayar")}<button class="btn ikinci" id="kmAyarK">Ayarları kaydet</button>
        <p class="kucuk" style="margin-top:8px">Diğer bütün ayarlar için: Veri sekmesi › oyun.ayarlar, oyun.ulke, oyun.guvenlik_ayar.</p></div>`;
    const kSec = () => {
      const t = $("#kmKTur").value, k = $("#kmKSec");
      if (t === "il") k.innerHTML = `<label>İl</label>${sec("kmKId", ilListesi(kt).map(i => [i.id, i.ad]))}`;
      else if (t === "parti") k.innerHTML = `<label>Parti</label>${sec("kmKId", (kt.partiler || []).map(p => [p.id, p.kisa + " · " + p.ad]))}`;
      else if (t === "sirket" || t === "dernek") k.innerHTML = `<label>${t === "sirket" ? "Şirket" : "Dernek"} numarası (Veri › oyun.${t === "sirket" ? "sirketler" : "dernekler"})</label><input class="km-girdi" id="kmKId" type="number">`;
      else k.innerHTML = "";
    };
    $("#kmKTur").onchange = kSec; kSec();
    $("#kmKUygula").onclick = async () => {
      const t = $("#kmKTur").value, id = $("#kmKId") ? $("#kmKId").value : null, v = Number($("#kmKTutar").value);
      if (!v) return toast("Tutar yaz.", true);
      try { const r = await rpc("yk_kasa", { p_tur: t, p_id: id, p_tutar: v, p_neden: $("#kmKNeden").value.trim() || null }); toast(`${r.ad}: ${fmt(r.once, 1)} → ${fmt(r.yeni, 1)}`); kmCiz(); } catch (err) { hata(err); }
    };
    const kaydet = async (on, tablo, satir) => {
      const deg = {}; document.querySelectorAll(`[data-${on}]`).forEach(i => { const k = i.dataset[on]; if (String(satir[k] == null ? "" : satir[k]) !== i.value) deg[k] = i.value === "" ? null : i.value; });
      if (!Object.keys(deg).length) return toast("Değişiklik yok.");
      try { await rpc("yk_satir_kaydet", { p_tablo: tablo, p_anahtar: { id: satir.id }, p_degerler: deg, p_aciklama: "Kontrol Merkezi › Ekonomi" }); toast("Kaydedildi."); kmCiz(); } catch (err) { hata(err); }
    };
    $("#kmUlkeK").onclick = () => kaydet("ulke", "oyun.ulke", ul);
    $("#kmAyarK").onclick = () => kaydet("ayar", "oyun.ayarlar", ay);
  }

  /* ---------- Seçimler ---------- */
  const SECIM_ALAN = [["basvuru_bas","Başvuru başlangıcı"],["basvuru_bit","Başvuru bitişi"],["oy_bas","Oylama başlangıcı"],["oy_bit","Oylama bitişi"],["sonuc_at","Sonuç açıklama"],["goreve_bas","Göreve başlama"]];
  const yerelSaat = (x) => { if (!x) return ""; const d = new Date(x); const p = new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Istanbul", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(d); return p.replace(" ", "T"); };
  const yerelIso = (v) => v ? v + ":00+03:00" : null;   // Türkiye UTC+3 (yaz saati yok)
  async function secimlerCiz(ic){
    const l = await rpc("yk_secimler");
    const TURAD = (t) => (typeof TUR === "object" && TUR[t] ? TUR[t].kisa : t);
    ic.innerHTML = `<div class="kart"><h2>Oyun motoru</h2><p class="alt">Motor her dakika kendiliğinden çalışır. Bir seçimin saatini değiştirdikten sonra beklemeden işlemesi için çalıştırabilirsin.</p><button class="btn altin" id="kmMotor">Motoru şimdi çalıştır</button></div>
      ${l.map(s => `<div class="kart"><div style="display:flex;justify-content:space-between;gap:8px"><b>${e(TURAD(s.tur))} · ${e(s.donem || "")}${s.il ? " · " + e(s.il) : ""}${s.parti ? " · " + e(s.parti) : ""}</b><span class="rozet ${s.durum === "bekliyor" ? "sari" : ""}">${e(s.durum)}</span></div>
        <div class="kucuk">#${s.id}${s.ara ? " · ara/erken seçim" : ""} · ${fmt(s.aday)} aday</div>
        <details style="margin-top:6px"><summary class="kucuk">Takvimi düzenle (Türkiye saati)</summary>
          ${SECIM_ALAN.map(([k, ad]) => `<div class="alan"><label>${ad}</label><input class="km-girdi" type="datetime-local" data-sid="${s.id}" data-k="${k}" value="${yerelSaat(s[k])}" data-eski="${yerelSaat(s[k])}"></div>`).join("")}
          <button class="btn ikinci" data-km-skaydet="${s.id}">Takvimi kaydet</button></details></div>`).join("") || `<div class="bos">Yaklaşan seçim yok.</div>`}`;
    $("#kmMotor").onclick = async () => { try { const r = await rpc("yk_motor_calistir"); toast(`Motor çalıştı (${r.islenen} seçim adımı).`); kmCiz(); } catch (err) { hata(err); } };
    ic.querySelectorAll("[data-km-skaydet]").forEach(b => b.onclick = async () => {
      const id = +b.dataset.kmSkaydet, deg = {};
      ic.querySelectorAll(`[data-sid="${id}"]`).forEach(i => { if (i.value !== i.dataset.eski) deg[i.dataset.k] = yerelIso(i.value); });
      if (!Object.keys(deg).length) return toast("Değişiklik yok.");
      if (!await onayla("Seçim takvimini değiştir", "Adaylar ve oylar yerinde kalır; yalnız saatler değişir. Geçmişe alınan saatler motorun bir sonraki çalışmasında hemen işlenir.", "Kaydet")) return;
      try { await rpc("yk_satir_kaydet", { p_tablo: "oyun.secimler", p_anahtar: { id }, p_degerler: deg, p_aciklama: "Seçim takvimi" }); toast("Kaydedildi."); kmCiz(); } catch (err) { hata(err); }
    });
  }

  /* ---------- Veri düzenleyici ---------- */
  async function veriCiz(ic){
    const v = YK.veri;
    if (!v.tablo) return tabloListesi(ic);
    const r = await rpc("yk_tablo", { p_tablo: v.tablo, p_ara: v.ara || null, p_sutun: v.sutun || null, p_deger: v.sutun ? v.deger : null, p_sirala: v.sirala || null, p_azalan: v.azalan, p_limit: 30, p_offset: v.offset });
    YK.veriSon = r;
    const kolonlar = r.sutunlar.map(c => [c.ad, c.ad]);
    const goster = (satir) => r.sutunlar.slice(0, 7).map(c => { let x = satir[c.ad]; const ad = typeof x === "string" && r.adlar[x] ? ` (${r.adlar[x]})` : "";
      x = x === null ? "∅" : typeof x === "object" ? JSON.stringify(x) : String(x);
      return `<div class="kv"><span class="k">${e(c.ad)}${c.pk ? " 🔑" : ""}</span><span class="v">${e(x.length > 80 ? x.slice(0, 80) + "…" : x)}${e(ad)}</span></div>`; }).join("");
    ic.innerHTML = `<div class="kart"><div style="display:flex;justify-content:space-between;align-items:center;gap:8px"><b class="km-tablo-ad">${e(r.tablo)}</b><button class="rozet km-kucukbtn" id="kmVGeri">Tablolar</button></div>
        ${r.aciklama ? `<div class="kucuk">${e(r.aciklama)}</div>` : ""}
        ${!r.pk ? `<div class="km-uyari">Bu tablonun birincil anahtarı yok; satırlar yalnız görüntülenir.</div>` : ""}
        <div class="km-satir" style="margin-top:8px"><input class="km-girdi" id="kmVAra" placeholder="Satırlarda ara" value="${e(v.ara)}"></div>
        <div class="km-satir" style="margin-top:8px">${sec("kmVSutun", [["", "Sütun süz: yok"]].concat(kolonlar), v.sutun)}<input class="km-girdi" id="kmVDeger" placeholder="değer (% joker, null)" value="${e(v.deger || "")}"></div>
        <div class="km-satir" style="margin-top:8px">${sec("kmVSira", [["", "Sırala: anahtar"]].concat(kolonlar), v.sirala)}${sec("kmVYon", [["1", "Azalan"], ["0", "Artan"]], v.azalan ? "1" : "0")}</div>
        <div class="km-izgara"><button class="btn ikinci" id="kmVUygula">Süz</button>${r.pk ? `<button class="btn altin" id="kmVYeni">+ Yeni satır</button>` : ""}</div>
        <div class="kucuk" style="margin-top:8px">${fmt(r.toplam)} satır · ${fmt(v.offset + (r.satirlar.length ? 1 : 0))}–${fmt(v.offset + r.satirlar.length)}</div></div>
      ${r.satirlar.map((s, i) => `<div class="km-veri-kart" data-i="${i}">${goster(s)}${r.sutunlar.length > 7 ? `<div class="kucuk">+${r.sutunlar.length - 7} sütun daha</div>` : ""}</div>`).join("") || `<div class="bos">Satır yok.</div>`}
      ${r.toplam > 30 ? `<div class="km-izgara"><button class="btn ikinci" id="kmVOnce" ${v.offset <= 0 ? "disabled" : ""}>← Önceki</button><button class="btn ikinci" id="kmVSonra" ${v.offset + 30 >= r.toplam ? "disabled" : ""}>Sonraki →</button></div>` : ""}`;
    const uygula = () => { v.ara = $("#kmVAra").value.trim(); v.sutun = $("#kmVSutun").value; v.deger = $("#kmVDeger").value.trim(); v.sirala = $("#kmVSira").value; v.azalan = $("#kmVYon").value === "1"; v.offset = 0; kmCiz(); };
    $("#kmVUygula").onclick = uygula; $("#kmVAra").onkeydown = (ev) => { if (ev.key === "Enter") uygula(); };
    $("#kmVGeri").onclick = () => { v.tablo = null; v.offset = 0; kmCiz(); };
    if ($("#kmVOnce")) $("#kmVOnce").onclick = () => { v.offset = Math.max(0, v.offset - 30); kmCiz(); };
    if ($("#kmVSonra")) $("#kmVSonra").onclick = () => { v.offset += 30; kmCiz(); };
    if ($("#kmVYeni")) $("#kmVYeni").onclick = () => satirModal(r, null);
    ic.querySelectorAll(".km-veri-kart").forEach(k => k.onclick = () => satirModal(r, r.satirlar[+k.dataset.i]));
  }
  async function tabloListesi(ic){
    const l = YK.cache.tablolar || (YK.cache.tablolar = await rpc("yk_tablolar"));
    const SIK = ["oyun.profiller","oyun.cuzdan","oyun.makamlar","oyun.partiler","oyun.secimler","oyun.adaylar","oyun.ulke","oyun.ayarlar","oyun.il_durum","oyun.sirketler","oyun.hesap_hareket","oyun.kanunlar","oyun.mesajlar","oyun.bildirimler","oyun.uygulama_ayar"];
    const ciz = (q) => {
      const s = (q || "").toLocaleLowerCase("tr"), f = l.filter(t => !s || t.ad.toLocaleLowerCase("tr").includes(s) || (t.aciklama || "").toLocaleLowerCase("tr").includes(s));
      $("#kmTListe").innerHTML = f.slice(0, 120).map(t => `<div class="liste-satir" data-t="${e(t.ad)}" style="cursor:pointer"><div class="orta"><b class="km-tablo-ad">${e(t.ad)}</b><div class="kucuk">~${fmt(t.satir)} satır${t.aciklama ? " · " + e(t.aciklama) : ""}</div></div><span style="color:var(--mut)">›</span></div>`).join("") || `<div class="bos">Tablo yok.</div>`;
      $("#kmTListe").querySelectorAll("[data-t]").forEach(x => x.onclick = () => ac(x.dataset.t));
    };
    const ac = (t) => { Object.assign(YK.veri, { tablo: t, ara: "", sutun: "", deger: "", sirala: "", azalan: true, offset: 0 }); kmCiz(); };
    ic.innerHTML = `<div class="kart"><h2>Veri düzenleyici</h2><p class="alt">Oyundaki her tabloyu görür ve düzenlersin. Kaydettiğin her değişiklik önce/sonra hâliyle Geçmiş sekmesine yazılır ve tek dokunuşla geri alınabilir. Değişiklik oyunun kendi kurallarını (tetikleyicileri) de çalıştırır.</p>
      <div class="km-satir" style="flex-wrap:wrap;gap:6px">${SIK.filter(t => l.some(x => x.ad === t)).map(t => `<button class="rozet km-kucukbtn" data-sik="${t}">${e(t.replace("oyun.", ""))}</button>`).join("")}</div>
      <input class="km-girdi" id="kmTAra" placeholder="Tablo ara (${fmt(l.length)} tablo)" style="margin-top:10px"></div><div class="kart" id="kmTListe"></div>`;
    ic.querySelectorAll("[data-sik]").forEach(b => b.onclick = () => ac(b.dataset.sik));
    $("#kmTAra").oninput = () => ciz($("#kmTAra").value);
    ciz("");
  }
  function satirModal(r, satir){
    const yeni = !satir;
    const tipJson = (c) => /json|\[\]/.test(c.tip);
    const tipBool = (c) => c.tip === "boolean";
    const alan = (c) => {
      const v = satir ? satir[c.ad] : undefined;
      const kilit = (!yeni && c.pk) || c.uretilmis;
      const yazi = v === undefined || v === null ? "" : (typeof v === "object" ? JSON.stringify(v, null, 1) : String(v));
      const ad = typeof v === "string" && r.adlar[v] ? ` · ${e(r.adlar[v])}` : "";
      const etiket = `<label>${e(c.ad)} <span class="kucuk">${e(c.tip)}${c.pk ? " · anahtar" : ""}${c.bos ? "" : " · zorunlu"}${c.varsayilan && yeni ? " · varsayılan: " + e(c.varsayilan.slice(0, 40)) : ""}${ad}</span></label>`;
      if (tipBool(c)) return `<div class="alan">${etiket}<select class="km-girdi" data-c="${e(c.ad)}" ${kilit ? "disabled" : ""}>${[["", yeni ? "(varsayılan)" : "∅ boş"], ["true", "true"], ["false", "false"]].map(([k, a]) => `<option value="${k}" ${String(v) === k || (v == null && k === "") ? "selected" : ""}>${a}</option>`).join("")}</select></div>`;
      if (tipJson(c) || yazi.length > 60) return `<div class="alan">${etiket}<textarea class="km-girdi" data-c="${e(c.ad)}" ${kilit ? "readonly" : ""}>${e(yazi)}</textarea></div>`;
      return `<div class="alan">${etiket}<input class="km-girdi" data-c="${e(c.ad)}" value="${e(yazi)}" ${kilit ? "readonly" : ""} ${v === null ? 'placeholder="∅ (boş)"' : ""}></div>`;
    };
    const m = modal(`<h3 style="font-size:18px;font-weight:800">${yeni ? "Yeni satır" : "Satırı düzenle"} <span class="km-tablo-ad">${e(r.tablo)}</span></h3>
      <p class="kucuk">Boş bıraktığın alan ∅ (boş) olarak kaydedilir${yeni ? "; yeni satırda boş alanlar varsayılan değeri alır" : ""}. JSON alanlarına geçerli JSON yaz.</p>
      ${r.sutunlar.map(alan).join("")}
      <div class="km-izgara"><button class="btn altin" id="kmSKaydet">${yeni ? "Ekle" : "Kaydet"}</button>${yeni ? "" : `<button class="btn tehlike" id="kmSSil">Sil</button>`}</div>
      ${yeni ? "" : `<button class="btn ikinci" id="kmSKopya">Kopyasını yeni satır olarak aç</button>`}
      <button class="btn ikinci" onclick="modalKapat()">Kapat</button>`);
    const deger = (c, el) => {
      const v = el.value;
      if (tipBool(c)) return v === "" ? null : v === "true";
      if (v === "") return null;
      if (tipJson(c)) { try { return JSON.parse(v); } catch (_) { throw new Error(`${c.ad}: geçerli JSON değil.`); } }
      return v;
    };
    $("#kmSKaydet", m).onclick = async () => {
      const deg = {};
      try {
        r.sutunlar.forEach(c => {
          const el = m.querySelector(`[data-c="${CSS.escape(c.ad)}"]`); if (!el || el.readOnly || el.disabled) return;
          const yv = deger(c, el);
          if (yeni) { if (yv !== null) deg[c.ad] = yv; return; }
          const eski = satir[c.ad];
          const ayni = (eski === null && yv === null) || (typeof eski === "object" && eski !== null ? JSON.stringify(eski) === JSON.stringify(yv) : String(eski) === String(yv));
          if (!ayni) deg[c.ad] = yv;
        });
      } catch (err) { return hata(err); }
      if (!Object.keys(deg).length && !yeni) return toast("Değişiklik yok.");
      const anahtar = yeni ? null : Object.fromEntries((r.pk || []).map(k => [k, satir[k]]));
      try { await rpc("yk_satir_kaydet", { p_tablo: r.tablo, p_anahtar: anahtar, p_degerler: deg, p_aciklama: null }); modalKapat(); toast(yeni ? "Satır eklendi." : "Kaydedildi."); YK.cache.tablolar = null; kmCiz(); } catch (err) { hata(err); }
    };
    if ($("#kmSSil", m)) $("#kmSSil", m).onclick = async () => {
      if (!await onayla("Satırı sil", "Satır silinecek. Geçmiş sekmesinden geri alabilirsin; ancak bağlı kayıtlar da silinebilir (ör. oyuncunun cüzdanı).", "Sil", true)) return;
      try { await rpc("yk_satir_sil", { p_tablo: r.tablo, p_anahtar: Object.fromEntries((r.pk || []).map(k => [k, satir[k]])) }); toast("Silindi."); kmCiz(); } catch (err) { hata(err); }
    };
    if ($("#kmSKopya", m)) $("#kmSKopya", m).onclick = () => { const k = Object.assign({}, satir); (r.pk || []).forEach(p => { if (r.sutunlar.find(c => c.ad === p && (c.varsayilan || c.uretilmis))) delete k[p]; }); modalKapat(); satirModal(r, null); setTimeout(() => { const mm = $("#modal"); if (!mm) return; r.sutunlar.forEach(c => { const el = mm.querySelector(`[data-c="${CSS.escape(c.ad)}"]`); if (el && k[c.ad] != null && !el.readOnly) el.value = typeof k[c.ad] === "object" ? JSON.stringify(k[c.ad]) : String(k[c.ad]); }); }, 30); };
  }

  /* ---------- Geçmiş (değişiklikler + günlük + sistem hataları) ---------- */
  async function gecmisCiz(ic){
    const [d, h] = await Promise.all([rpc("yk_degisiklikler", { p_limit: 80, p_tablo: null }), rpc("yk_sistem_hatalari", { p_limit: 40 })]);
    const fark = (x) => {
      if (x.islem === "guncelle" || x.islem === "geri_al" && x.once && x.sonra) {
        const k = Object.keys(x.sonra || {}).filter(k2 => JSON.stringify((x.once || {})[k2]) !== JSON.stringify((x.sonra || {})[k2]));
        return k.map(k2 => `<div>${e(k2)}: <del>${e(JSON.stringify((x.once || {})[k2]))}</del> → <ins>${e(JSON.stringify(x.sonra[k2]))}</ins></div>`).join("");
      }
      return `<div>${e(JSON.stringify(x.anahtar || {}))}</div>`;
    };
    const ISLEM = { guncelle: "düzenlendi", ekle: "eklendi", sil: "silindi", geri_al: "geri alma" };
    ic.innerHTML = `<div class="kart"><h2>Veri değişiklikleri</h2><p class="alt">Kontrol Merkezinden yapılan her veri değişikliği. "Geri al" önceki hâli geri yükler.</p>
        ${d.map(x => `<div class="liste-satir" style="display:block"><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><b class="km-tablo-ad">${e(x.tablo)} · ${e(ISLEM[x.islem] || x.islem)}</b>
          ${x.geri_alindi ? `<span class="rozet">geri alındı</span>` : x.islem !== "geri_al" ? `<button class="rozet sari km-kucukbtn" data-km-geri="${x.id}">Geri al</button>` : ""}</div>
          <div class="kucuk">#${x.id} · ${ts(x.zaman)} · ${e(x.kad || "")}${x.aciklama ? " · " + e(x.aciklama) : ""}</div><div class="km-fark">${fark(x)}</div></div>`).join("") || `<div class="bos">Henüz değişiklik yok.</div>`}</div>
      <div class="kart"><h2>Sistem hataları</h2><p class="alt">Oyun motorunun bir adımı hata verirse yalnız o adım atlanır, oyun durmaz. Burada görünen hata sürekli tekrarlıyorsa bana bildir.</p>
        ${(h.motor || []).map(x => `<div class="liste-satir" style="display:block"><b>${e(x.adim)}</b> <span class="rozet kirmizi">${fmt(x.sayi)}×</span><div class="kucuk">${ts(x.ilk)} → ${ts(x.son)}</div><div class="km-fark">${e(x.hata || "")}</div></div>`).join("") || `<div class="bos" style="padding:6px 0">Motor hatası yok.</div>`}
        ${(h.zamanlayici || []).length ? `<h2 style="margin-top:12px">Zamanlanmış görevler (48 sa)</h2>${h.zamanlayici.map(x => `<div class="liste-satir" style="display:block"><b>${e(x.is)}</b> <span class="rozet">${fmt(x.sayi)}×</span><div class="kucuk">son ${ts(x.son)}</div><div class="km-fark">${e(x.hata || "")}</div></div>`).join("")}` : ""}</div>
      <div class="kart"><h2>Moderasyon günlüğü</h2><div id="kmGunluk"><div class="kucuk">Yükleniyor…</div></div></div>`;
    ic.querySelectorAll("[data-km-geri]").forEach(b => b.onclick = async () => {
      if (!await onayla("Değişikliği geri al", `#${b.dataset.kmGeri} numaralı değişiklik geri alınacak.`, "Geri al")) return;
      try { await rpc("yk_geri_al", { p_id: +b.dataset.kmGeri }); toast("Geri alındı."); kmCiz(); } catch (err) { hata(err); }
    });
    try {
      const l = await rpc("admin_mod_kayit", { p_limit: 80 });
      $("#kmGunluk").innerHTML = l.map(x => `<div class="liste-satir"><div class="orta"><div style="font-size:14px"><b>${e(x.kad || "?")}</b> ${e(MOD_ISLEM[x.islem] || x.islem)}${x.hedef ? ` → <b>${e(x.hedef)}</b>` : ""}</div>${x.ayrinti ? `<div class="kucuk" style="overflow:hidden;text-overflow:ellipsis">${e(String(x.ayrinti).slice(0, 180))}</div>` : ""}<div class="kucuk">${ts(x.zaman)}</div></div></div>`).join("") || `<div class="bos">Kayıt yok.</div>`;
    } catch (err) { $("#kmGunluk").innerHTML = `<div class="kucuk">${e(hataCevir(err.message))}</div>`; }
  }

  /* ---------- Uygulama ayarları ---------- */
  const AYAR_AD = { iletisim: "Destek e-postası", admob_odullu_ios: "AdMob ödüllü birim · iOS", admob_odullu_android: "AdMob ödüllü birim · Android", admob_test: "Test reklamı göster (true/false)",
    revenuecat_ios: "RevenueCat anahtarı · iOS (appl_...)", revenuecat_android: "RevenueCat anahtarı · Android (goog_...)", reklam_acik: "Ödüllü reklam açık (true/false)",
    satis_acik: "₺ paketi satışı açık (true/false)", magaza_ios: "App Store bağlantısı", magaza_android: "Google Play bağlantısı", bakim: "Bakım modu (true/false)",
    bakim_mesaj: "Bakım ekranı mesajı", duyuru_bandi: "Üst duyuru bandı" };
  async function ayarlarCiz(ic){
    const l = await rpc("yk_uygulama_ayarlari");
    const yaz = (v) => v === null || v === undefined ? "" : typeof v === "string" ? v : JSON.stringify(v);
    ic.innerHTML = `<div class="kart"><h2>Uygulama ayarları</h2><p class="alt">Telefonlardaki uygulama bu ayarları açılışta sunucudan okur; değiştirmek için yeni sürüm gerekmez. Boş bırakılan reklam/satış kimliklerinde uygulamanın içindeki değer kullanılır.</p>
      ${l.map(x => `<div class="alan"><label>${e(AYAR_AD[x.anahtar] || x.anahtar)}<span class="kucuk"> · ${e(x.aciklama || "")}</span></label><input class="km-girdi" data-ua="${e(x.anahtar)}" data-tip="${typeof x.deger === "boolean" ? "b" : typeof x.deger === "number" ? "n" : "s"}" value="${e(yaz(x.deger))}" data-eski="${e(yaz(x.deger))}" autocapitalize="off" autocomplete="off" spellcheck="false"></div>`).join("")}
      <button class="btn altin" id="kmUAKaydet">Kaydet</button></div>`;
    $("#kmUAKaydet").onclick = async () => {
      const p = {};
      ic.querySelectorAll("[data-ua]").forEach(i => {
        if (i.value === i.dataset.eski) return;
        const v = i.value.trim(), k = i.dataset.ua;
        if (v === "") p[k] = null;
        else if (v === "true" || v === "false") p[k] = v === "true";
        else if (i.dataset.tip === "n" && !isNaN(+v)) p[k] = +v;
        else p[k] = v;
      });
      if (!Object.keys(p).length) return toast("Değişiklik yok.");
      if (p.bakim === true && !await onayla("Bakım modu", "Sen hariç hiçbir oyuncu giremeyecek.", "Bakıma al", true)) return;
      try { await rpc("yk_uygulama_ayar_kaydet", { p }); await uygulamaAyarYukle(); toast("Kaydedildi."); kmCiz(); } catch (err) { hata(err); }
    };
  }

  /* =====================================================================
     3) Adaylıklarım: her türlü adaylıktan sandık açılmadan çekilme
     ===================================================================== */
  if (typeof gundemEkAlt === "function") {
    const eskiEk = gundemEkAlt;
    window.gundemEkAlt = gundemEkAlt = function(){
      const mevcut = eskiEk.apply(this, arguments) || "";
      setTimeout(adayliklarimDoldur, 0);
      return `<div id="kmAdayliklarim"></div>` + mevcut.replace(/<div class="bolum-bas"><h2>Adaylıklarım<\/h2><\/div>\s*<div class="kart"><p class="alt"[^>]*>Milletvekilliği ve cumhurbaşkanlığı adaylığından[\s\S]*?<\/div>(?=<|$)/, "");
    };
  }
  let adaylikIstek = 0;
  async function adayliklarimDoldur(){
    const kutu = $("#kmAdayliklarim"); if (!kutu || !API || !D.durum || !D.durum.profil) return;
    const no = ++adaylikIstek;
    let l; try { l = await rpc("adayliklarim"); } catch (_) { return; }
    if (no !== adaylikIstek || !document.body.contains(kutu)) return;
    if (!l || !l.length) { kutu.innerHTML = ""; return; }
    // Eski (yalnız MV/CB) kartı varsa kaldır: bu kart hepsini kapsar
    document.querySelectorAll("#icerik .bolum-bas").forEach(bb => { if (bb.textContent.trim() === "Adaylıklarım" && !kutu.contains(bb)) { const k = bb.nextElementSibling; if (k && k.classList.contains("kart")) k.remove(); bb.remove(); } });
    kutu.innerHTML = `<div class="bolum-bas"><h2>Adaylıklarım</h2></div><div class="kart"><p class="alt" style="margin-bottom:8px">Sandık açılmadan önce adaylığından kendi isteğinle çekilebilirsin. Başvuru harcı iade edilmez.</p>
      ${l.map((x, i) => `<div class="liste-satir" style="flex-wrap:wrap"><div class="orta"><b>${e(x.baslik)}</b><div class="kucuk">${e(x.aciklama || "")}${x.son_tarih ? " · son: " + ts(x.son_tarih) : ""}</div></div><button class="btn ikinci" style="width:auto;margin:0" data-km-cekil="${i}">Çekil</button></div>`).join("")}</div>`;
    kutu.querySelectorAll("[data-km-cekil]").forEach(b => b.onclick = async () => {
      const x = l[+b.dataset.kmCekil];
      if (!await onayla("Adaylıktan çekil", `${e(x.baslik)} adaylığından çekileceksin ve pusuladan çıkarılacaksın. Başvuru ücreti iade edilmez. Onaylıyor musun?`, "Adaylıktan çekil", true)) return;
      try { await rpc("adaylik_vazgec", { p_kaynak: x.kaynak, p_secim: x.id, p_gorev: x.gorev }); toast("Adaylıktan çekildin."); try { await durumYenile(); } catch (_) {} if (D.sekme === "gundem" && typeof gundemEkrani === "function") gundemEkrani(); else adayliklarimDoldur(); }
      catch (err) { hata(err); }
    });
  }
})();
