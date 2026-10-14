/* =====================================================================
   SİYASİ KURUMLAR (2026-10-14) — sunucu: sql/97_siyasi_kurumlar.sql
   Davet kodu · Ulusal kriz masası · Meclis komisyonları · Parti kapatma davası · Gençlik ve kadın kolları
   Bütün yetki, ödül ve para kararları RPC'de verilir; bu dosya yalnız gösterir ve çağırır.
   ===================================================================== */
(function(){
  const sv = d => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
  const SK_IKON = {
    davet: sv('<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6M22 11h-6"/>'),
    kriz: sv('<path d="M10.3 3.9 2 18a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/>'),
    komisyon: sv('<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9h10M7 13h6M7 17h8"/>'),
    terazi: sv('<path d="M12 3v18M5 21h14M3 7h18M6 7l-3 5h6zM18 7l-3 5h6z"/>'),
    kol: sv('<circle cx="8" cy="8" r="3"/><circle cx="16" cy="8" r="3"/><path d="M2 20c.8-3 3.2-5 6-5s5.2 2 6 5M14.5 15.3c.5-.2 1-.3 1.5-.3 2.8 0 5.2 2 6 5"/>')
  };
  const satirBtn = (ik, bas, alt, cagri) => `<button class="giris-satir" onclick="${cagri}"><span class="yik">${SK_IKON[ik]}</span><span class="orta"><b>${bas}</b><span class="kucuk">${alt}</span></span><span class="ok">›</span></button>`;
  const hata = err => toast(hataCevir(err && err.message ? err.message : String(err)), true);
  const tl = n => (typeof tlYaz === "function" ? tlYaz(n) : fmt(n) + " ₺");
  const ts = x => x ? tarihSaat(x) : "—";
  const kalan = x => { if (!x) return ""; const ms = new Date(x).getTime() - (Date.now() + (typeof saatFarki === "number" ? saatFarki : 0)); if (ms <= 0) return "süre doldu"; const s = Math.floor(ms / 36e5), d = Math.floor((ms % 36e5) / 6e4); return s > 0 ? `${s} sa ${d} dk kaldı` : `${d} dk kaldı`; };
  const isaret = n => (+n > 0 ? "+" : "") + fmt(+n || 0, 0);
  const css = `<style id="skCss">
    .sk-sec{border-top:1px solid var(--line);padding:12px 0}.sk-sec:first-of-type{border-top:0}
    .sk-sec b{display:block}.sk-sec .kucuk{margin-top:3px}
    .sk-etki{display:flex;flex-wrap:wrap;gap:6px;margin:8px 0}
    .sk-uye{display:inline-flex;align-items:center;gap:6px;padding:5px 9px;border-radius:7px;background:var(--panel2);font-size:13px;margin:0 6px 6px 0}
    .sk-uye i{width:8px;height:8px;border-radius:50%;display:inline-block}
    .sk-uye.yedek{opacity:.55}
    .sk-yildiz{display:flex;gap:6px;margin:6px 0 10px}
    .sk-yildiz button{flex:1;padding:9px 0;border-radius:8px;background:var(--panel2);font-weight:700;color:var(--txt2)}
    .sk-yildiz button.secili{background:var(--ink);color:#fff}
    .sk-kod{font-family:var(--disp);font-size:34px;letter-spacing:6px;text-align:center;margin:8px 0;color:var(--ink2)}
    .sk-karne{font-family:var(--disp);font-size:30px;font-weight:700}
    .sk-cizgi{border-left:2px solid var(--line2);padding:0 0 10px 12px;margin-left:4px}
    .sk-serit{border-top:3px solid var(--al)}
  </style>`;
  try { if (!document.getElementById("skCss")) document.head.insertAdjacentHTML("beforeend", css); } catch (_) {}

  /* ============================== 1) DAVET ============================== */
  try {
    const u = new URLSearchParams(location.search).get("davet");
    if (u && /^[A-Za-z0-9]{6}$/.test(u)) localStorage.setItem("skDavet", u.toUpperCase());
  } catch (_) {}
  const davetLink = kod => "https://feniksklein.github.io/Se-im-Online/?davet=" + encodeURIComponent(kod);

  async function davetEkrani(){
    yukleniyor("Davet et");
    let d; try { d = await API.rpc("davet_bilgim"); } catch (err) { iskelet("Davet et", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
    const a = d.ayar || {}, s = d.sayilar || {};
    let h = `<div class="kart"><h2>Arkadaşını davet et</h2>
      <p class="alt">Davet kodunla katılan oyuncu oy hakkı kazandığında sana ${tl(a.odul_eden)}, ona ${tl(a.odul_edilen)} hoş geldin ödülü yatar. Haftada en fazla ${fmt(a.haftalik_tavan)} davet ödüllendirilir. Aynı cihazdan açılan hesaplar sayılmaz.</p>
      <div class="sk-kod">${e(d.kod)}</div>
      <div class="satir"><button class="btn altin yarim" onclick="skDavetPaylas('${e(d.kod)}')">Paylaş</button><button class="btn ikinci yarim" onclick="skKopyala('${e(davetLink(d.kod))}')">Bağlantıyı kopyala</button></div>
      ${a.aktif ? "" : `<p class="kucuk" style="margin-top:8px">Davet ödülleri şu an kapalı.</p>`}</div>
      <div class="kart"><div class="kv"><span class="k">Ödül alan davetlerin</span><span class="v">${fmt(s.odendi)}</span></div>
      <div class="kv"><span class="k">Oy hakkı bekleyen</span><span class="v">${fmt(s.bekliyor)}</span></div>
      <div class="kv"><span class="k">Geçersiz sayılan</span><span class="v">${fmt(s.gecersiz)}</span></div>
      <div class="kv"><span class="k">Toplam kazancın</span><span class="v">${tl(s.kazanc)}</span></div></div>`;
    if (d.kod_girebilir) h += `<div class="kart"><h3>Seni biri mi davet etti?</h3><p class="alt">Davet kodunu ${ts(d.kod_son)} tarihine kadar girebilirsin.</p>
      <div class="alan"><label>Davet kodu</label><input id="skDavetKod" maxlength="8" autocapitalize="characters" placeholder="ÖRN. K7M2PA"></div><button class="btn" onclick="skDavetGir()">Kodu kullan</button></div>`;
    if (d.beni_davet_eden) { const b = d.beni_davet_eden; h += `<div class="kart"><h3>Seni davet eden: ${e(b.kad)}</h3><p class="alt">${b.durum === "odendi" ? "Hoş geldin ödülün yattı." : b.durum === "gecersiz" ? e(b.neden || "Davet geçersiz sayıldı.") : "Oy hakkı kazandığında ödülün yatacak." + (b.eksik ? " Eksik: " + e(b.eksik) : "")}</p></div>`; }
    h += `<div class="bolum-bas"><h2>Davetlerin</h2></div><div class="kart">` + ((d.davetlerim || []).map(x => `<div class="liste-satir"><div class="orta"><b>${e(x.kad)}</b><span class="kucuk">${ts(x.zaman)}${x.eksik ? " · " + e(x.eksik) : ""}${x.neden ? " · " + e(x.neden) : ""}</span></div><span class="rozet ${x.durum === "odendi" ? "yesil" : x.durum === "gecersiz" ? "kirmizi" : "sari"}">${x.durum === "odendi" ? "Ödül alındı" : x.durum === "gecersiz" ? "Geçersiz" : "Bekliyor"}</span></div>`).join("") || `<p class="alt">Henüz davet ettiğin oyuncu yok.</p>`) + `</div>`;
    if ((d.liderler || []).length) h += `<div class="bolum-bas"><h2>Son 30 günün davetçileri</h2></div><div class="kart">` + d.liderler.map((x, i) => `<div class="kv"><span class="k">${i + 1}. ${e(x.kad)}</span><span class="v">${fmt(x.n)} oyuncu</span></div>`).join("") + `</div>`;
    if (d.yonetici) h += `<div class="kart"><h3>Yönetici · Davet ödülleri</h3>
      <label class="kucuk"><input type="checkbox" id="skDvAktif" ${a.aktif ? "checked" : ""}> Davet ödülleri açık</label>
      <div class="alan"><label>Davet edene ödül (₺)</label><input id="skDvEden" type="number" value="${+a.odul_eden}"></div>
      <div class="alan"><label>Davet edilene ödül (₺)</label><input id="skDvEdilen" type="number" value="${+a.odul_edilen}"></div>
      <div class="alan"><label>Haftalık ödül sınırı (kişi başı)</label><input id="skDvTavan" type="number" value="${+a.haftalik_tavan}"></div>
      <button class="btn ikinci" onclick="skDavetAyar()">Kaydet</button></div>`;
    iskelet("Davet et", h, { geri: true });
  }
  window.skDavetPaylas = async function(kod){
    const metin = `Seçim Simülasyonu Online'da parti kur, seçim kazan, Türkiye'yi yönet. Davet kodum: ${kod}`;
    try { if (navigator.share) { await navigator.share({ title: "Seçim Simülasyonu Online", text: metin, url: davetLink(kod) }); return; } } catch (_) { return; }
    skKopyala(metin + " " + davetLink(kod));
  };
  window.skKopyala = async function(m){ try { await navigator.clipboard.writeText(m); toast("Kopyalandı."); } catch (_) { toast("Kopyalanamadı; kodu elle paylaşabilirsin.", true); } };
  window.skDavetGir = async function(){
    const k = ($("#skDavetKod") || {}).value || "";
    try { const r = await API.rpc("davet_kodu_gir", { p_kod: k }); toast(r.durum === "odendi" ? "Ödülün yattı. Hoş geldin!" : `${r.davet_eden} seni davet etti. Oy hakkı kazanınca ödülün yatacak.`); try { localStorage.removeItem("skDavet"); } catch (_) {} davetEkrani(); }
    catch (err) { hata(err); }
  };
  window.skDavetAyar = async function(){
    try { await API.rpc("davet_ayar_kaydet", { p_aktif: $("#skDvAktif").checked, p_odul_eden: +$("#skDvEden").value, p_odul_edilen: +$("#skDvEdilen").value, p_haftalik_tavan: +$("#skDvTavan").value }); toast("Kaydedildi."); davetEkrani(); }
    catch (err) { hata(err); }
  };
  // Kayıt ekranında girilen ya da bağlantıyla gelen kod, profil oluşunca bir kez uygulanır.
  let skDavetDenendi = false;
  async function skBekleyenDavet(){
    if (skDavetDenendi) return;
    let kod = null; try { kod = localStorage.getItem("skDavet"); } catch (_) {}
    if (!kod || !(D.durum && D.durum.profil)) return;
    skDavetDenendi = true;
    try { const r = await API.rpc("davet_kodu_gir", { p_kod: kod }); toast(r.durum === "odendi" ? "Davet ödülün yattı. Hoş geldin!" : `${r.davet_eden} seni davet etti. Oy hakkı kazanınca hoş geldin ödülün yatacak.`); }
    catch (err) { if (!/zaten/i.test(err.message || "")) toast("Davet kodu: " + hataCevir(err.message), true); }
    try { localStorage.removeItem("skDavet"); } catch (_) {}
  }
  if (typeof window.profilOlusturEkrani === "function") {
    const eskiPo = window.profilOlusturEkrani;
    window.profilOlusturEkrani = profilOlusturEkrani = async function(){
      const r = await eskiPo.apply(this, arguments);
      try {
        const btn = $("#tamam");
        if (btn && !$("#skKayitDavet")) {
          let kod = ""; try { kod = localStorage.getItem("skDavet") || ""; } catch (_) {}
          btn.insertAdjacentHTML("beforebegin", `<div class="alan"><label>Davet kodu (isteğe bağlı)</label><input id="skKayitDavet" maxlength="8" autocapitalize="characters" value="${e(kod)}" placeholder="Seni davet eden oyuncunun kodu"></div>`);
          btn.addEventListener("click", () => { const v = ($("#skKayitDavet").value || "").trim(); try { if (v) localStorage.setItem("skDavet", v.toUpperCase()); else localStorage.removeItem("skDavet"); } catch (_) {} }, true);
        }
      } catch (_) {}
      return r;
    };
  }

  /* ============================== 2) ULUSAL KRİZ ============================== */
  let skKrizOnbellek = null, skKrizZaman = 0;
  async function skKrizVeri(zorla){
    if (!zorla && skKrizOnbellek && Date.now() - skKrizZaman < 60000) return skKrizOnbellek;
    try { skKrizOnbellek = await API.rpc("ulusal_kriz"); skKrizZaman = Date.now(); } catch (_) { skKrizOnbellek = null; }
    return skKrizOnbellek;
  }
  function etkiRozet(o, kapsam){
    const r = [];
    if (+o.maliyet > 0) r.push(`<span class="rozet">Hazine −${fmt(o.maliyet, 2)} mlr ₺</span>`);
    if (+o.ulke_mem) r.push(`<span class="rozet ${o.ulke_mem > 0 ? "yesil" : "kirmizi"}">Ülke memnuniyeti ${isaret(o.ulke_mem)}</span>`);
    if (+o.il_mem && kapsam === "il") r.push(`<span class="rozet ${o.il_mem > 0 ? "yesil" : "kirmizi"}">İl memnuniyeti ${isaret(o.il_mem)}</span>`);
    if (+o.afad_tl > 0) r.push(`<span class="rozet altin">İldeki her oyuncuya ${tl(o.afad_tl)}</span>`);
    if (+o.kasa_oran > 0) r.push(`<span class="rozet">Belediye kasasının %${fmt(o.kasa_oran * 100)}'i</span>`);
    return `<div class="sk-etki">${r.join("")}</div>`;
  }
  function asamaHtml(k, ad, x, yetki, asama, son){
    let h = `<div class="kart"><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><h3>${ad}</h3>`;
    if (x.karar) h += `<span class="rozet ${x.karar === "yok" ? "kirmizi" : "yesil"}">${x.karar === "yok" ? "Karar verilmedi" : "Karar verildi"}</span></div>`;
    else h += `<span class="rozet sari">${son ? kalan(son) : "Sırada"}</span></div>`;
    if (x.karar && x.karar !== "yok") h += `<p style="margin-top:6px"><b>${e(x.ad)}</b></p><p class="kucuk">${e(x.veren || "")} · ${ts(x.at)}</p>`;
    if (x.karar === "yok") h += `<p class="alt" style="margin-top:6px">Süresinde karar verilmediği için halkın memnuniyeti düştü.</p>`;
    if (!x.karar && x.secenekler) {
      h += x.secenekler.map(o => `<div class="sk-sec"><b>${e(o.ad)}</b><span class="kucuk">${e(o.aciklama || "")}</span>${etkiRozet(o, k.kapsam)}
        ${yetki ? `<button class="btn altin" onclick="skKrizKarar(${k.id},'${asama}','${e(o.kod)}')">Bu kararı uygula</button>` : ""}</div>`).join("");
      if (!yetki) h += `<p class="kucuk">Bu kararı ${asama === "yerel" ? "il belediye başkanı" : asama === "kalici" ? "yürütmenin başı" : "ilgili bakan ya da yürütmenin başı"} verir.</p>`;
    }
    return h + `</div>`;
  }
  function yildizHtml(id, secili){ return `<div class="sk-yildiz" id="${id}">${[1,2,3,4,5].map(i => `<button class="${secili === i ? "secili" : ""}" onclick="skYildiz('${id}',${i})">${i}</button>`).join("")}</div>`; }
  window.skYildiz = function(id, i){ const k = document.getElementById(id); if (!k) return; k.dataset.deger = i; k.querySelectorAll("button").forEach((b, j) => b.classList.toggle("secili", j + 1 === i)); };
  function karneHtml(k){
    let h = `<div class="kart"><h3>Kriz karnesi</h3><div style="display:flex;gap:16px;margin-top:8px"><div><div class="sk-karne">${k.karne == null ? "—" : fmt(k.karne)}</div><div class="kucuk">Hükümet</div></div>`;
    if (k.kapsam === "il") h += `<div><div class="sk-karne">${k.bel_karne == null ? "—" : fmt(k.bel_karne)}</div><div class="kucuk">Belediye</div></div>`;
    h += `</div><p class="kucuk" style="margin-top:8px">Uzman değerlendirmesi ${k.puan_karar == null ? "—" : fmt(k.puan_karar)}/100${k.puan_halk != null ? " · halk " + fmt(k.puan_halk) + "/100" : " · halk değerlendirmesi yetersiz (en az 3 oy)"}. Karne, kararların uzman puanının %60'ı ve halkın puanının %40'ıdır.</p></div>`;
    return h;
  }
  async function ulusalKrizEkrani(){
    yukleniyor("Ulusal Kriz Masası");
    const d = await skKrizVeri(true);
    if (!d) { iskelet("Ulusal Kriz Masası", `<div class="bos">Kriz masası şu an açılamadı.</div>`, { geri: true }); return; }
    const k = d.aktif;
    let h = `<div class="kart"><h2>Ulusal Kriz Masası</h2><p class="alt">Deprem, salgın, kur şoku gibi büyük krizlerde önce ilgili bakan ya da yürütmenin başı 6 saat içinde ilk müdahaleyi, ardından yürütmenin başı 24 saat içinde kalıcı çözümü seçer. İl krizlerinde belediye başkanı da yerel müdahale kararı verir. Oy hakkı olan oyuncular kriz yönetimini 1-5 arası puanlar; sonunda herkesin göreceği bir karne çıkar.</p><div class="kv"><span class="k">Hazine</span><span class="v">${fmt(d.hazine, 2)} milyar ₺</span></div></div>`;
    if (k) {
      h += `<div class="kart sk-serit"><span class="rozet kirmizi">${e(k.kategori)}${k.il_ad ? " · " + e(k.il_ad) : ""}</span><h2 style="margin-top:8px">${e(k.baslik)}${k.il_ad ? " · " + e(k.il_ad) : ""}</h2><p style="margin-top:6px">${e(k.aciklama)}</p>
        <div class="kv"><span class="k">Sorumlu bakanlık</span><span class="v">${e(k.bakanlik)}</span></div>
        <div class="kv"><span class="k">Yürütme / Bakan${k.kapsam === "il" ? " / Belediye" : ""}</span><span class="v">${e(k.yetkililer.yurutme || "boş")} / ${e(k.yetkililer.bakan || "boş")}${k.kapsam === "il" ? " / " + e(k.yetkililer.belediye || "boş") : ""}</span></div>
        <div class="kv"><span class="k">Şu ana kadarki maliyet</span><span class="v">${fmt(k.maliyet, 2)} mlr ₺</span></div></div>`;
      h += asamaHtml(k, "1. İlk müdahale", k.ilk, k.yetki_ilk, "ilk", k.asama === 1 ? k.a1_son : null);
      if (k.yerel) h += asamaHtml(k, "Belediyenin yerel müdahalesi" + (k.yerel.il_kasa != null ? ` <span class="kucuk">(kasa ${fmt(k.yerel.il_kasa, 3)} mlr ₺)</span>` : ""), k.yerel, k.yetki_yerel, "yerel", k.yerel.karar ? null : k.y_son);
      h += asamaHtml(k, "2. Kalıcı çözüm", k.kalici, k.yetki_kalici, "kalici", k.asama === 2 ? k.a2_son : null);
      h += `<div class="kart"><h3>Halkın değerlendirmesi</h3><p class="kucuk">${fmt(k.halk.n)} oy · hükümet ortalaması ${k.halk.hukumet == null ? "—" : fmt(k.halk.hukumet, 1)}${k.kapsam === "il" ? " · belediye ortalaması " + (k.halk.belediye == null ? "—" : fmt(k.halk.belediye, 1)) : ""}${k.degerlendirme_son ? " · değerlendirme " + kalan(k.degerlendirme_son) : ""}</p>`;
      if (k.degerlendirebilir) {
        h += `<p class="alt" style="margin-top:8px">Hükümet krizi nasıl yönetiyor?</p>${yildizHtml("skPuanH", k.puanim && k.puanim.hukumet)}`;
        if (k.belediye_puanlayabilir) h += `<p class="alt">${e(k.il_ad)} Belediyesi nasıl yönetiyor?</p>${yildizHtml("skPuanB", k.puanim && k.puanim.belediye)}`;
        h += `<button class="btn" onclick="skKrizPuanla(${k.id})">${k.puanim ? "Puanımı güncelle" : "Puanımı ver"}</button>`;
      } else if (k.degerlendirme_engel) h += `<p class="kucuk" style="margin-top:8px">${e(k.degerlendirme_engel)}</p>`;
      h += `</div>`;
      h += `<div class="kart"><h3>Kriz günlüğü</h3>${(k.zaman_cizelgesi || []).map(z => `<div class="sk-cizgi"><span class="kucuk">${ts(z.zaman)}${z.kim ? " · " + e(z.kim) : ""}</span><div>${e(z.aciklama)}</div></div>`).join("")}</div>`;
    } else h += `<div class="kart"><h3>Normal dönem</h3><p class="alt">Şu an süren büyük bir ulusal kriz yok. Krizler en az ${fmt(d.ayar.min_aralik_gun)} gün arayla, çarşamba akşamları çıkabilir.</p></div>`;
    h += `<div class="bolum-bas"><h2>Geçmiş krizler</h2></div>`;
    h += (d.arsiv || []).map(x => `<div class="kart"><div style="display:flex;justify-content:space-between;gap:8px"><b>${e(x.baslik)}${x.il_ad ? " · " + e(x.il_ad) : ""}</b><span class="kucuk">${ts(x.bas)}</span></div>
        <div class="kv"><span class="k">İlk müdahale</span><span class="v">${x.ilk.karar === "yok" ? "Karar yok" : e(x.ilk.ad || "—") + (x.ilk.veren ? " (" + e(x.ilk.veren) + ")" : "")}</span></div>
        <div class="kv"><span class="k">Kalıcı çözüm</span><span class="v">${x.kalici.karar === "yok" ? "Karar yok" : e(x.kalici.ad || "—") + (x.kalici.veren ? " (" + e(x.kalici.veren) + ")" : "")}</span></div>
        ${x.yerel ? `<div class="kv"><span class="k">Belediye</span><span class="v">${x.yerel.karar === "yok" ? "Karar yok" : e(x.yerel.ad || "—") + (x.yerel.veren ? " (" + e(x.yerel.veren) + ")" : "")}</span></div>` : ""}
        <div class="kv"><span class="k">Karne</span><span class="v">Hükümet ${x.karne == null ? "—" : fmt(x.karne)}/100${x.yerel ? " · Belediye " + (x.bel_karne == null ? "—" : fmt(x.bel_karne)) + "/100" : ""}</span></div></div>`).join("") || `<div class="kart"><p class="alt">Henüz yaşanmış büyük kriz yok.</p></div>`;
    if (d.arsiv && d.arsiv[0] && !k) h = h.replace(`<div class="bolum-bas"><h2>Geçmiş krizler</h2></div>`, karneHtml(d.arsiv[0]) + `<div class="bolum-bas"><h2>Geçmiş krizler</h2></div>`);
    if (d.yonetici) {
      h += `<div class="kart"><h3>Yönetici · Kriz başlat</h3><div class="alan"><label>Kriz türü</label><select id="skKrizTur">${(d.katalog || []).map(c => `<option value="${e(c.kod)}">${e(c.baslik)} (${c.kapsam === "il" ? "il" : "ülke"})</option>`).join("")}</select></div>
        <div class="alan"><label>İl (il krizlerinde isteğe bağlı)</label><input id="skKrizIl" placeholder="Boş bırakılırsa uygun illerden seçilir"></div>
        <button class="btn tehlike" onclick="skKrizBaslat()">Krizi şimdi başlat</button>
        <h3 style="margin-top:16px">Otomatik krizler</h3><label class="kucuk"><input type="checkbox" id="skKrizAktif" ${d.ayar.aktif ? "checked" : ""}> Çarşamba çekilişleri açık</label>
        <div class="alan"><label>Haftalık olasılık (%)</label><input id="skKrizOran" type="number" value="${+d.ayar.haftalik_ihtimal}"></div>
        <div class="alan"><label>İki kriz arası en az gün</label><input id="skKrizGun" type="number" value="${+d.ayar.min_aralik_gun}"></div>
        <button class="btn ikinci" onclick="skKrizAyar()">Kaydet</button></div>`;
    }
    iskelet("Ulusal Kriz Masası", h, { geri: true });
  }
  window.skKrizKarar = async function(id, asama, kod){
    if (!await onayla("Kriz kararı", "Bu karar hemen uygulanır ve geri alınamaz. Devam edilsin mi?", "Kararı uygula")) return;
    try { await API.rpc("ulusal_kriz_karar", { p_olay: id, p_asama: asama, p_secenek: kod }); toast("Karar uygulandı."); skKrizOnbellek = null; ulusalKrizEkrani(); } catch (err) { hata(err); }
  };
  window.skKrizPuanla = async function(id){
    const h = +(($("#skPuanH") || {}).dataset || {}).deger || 0, b = $("#skPuanB") ? (+$("#skPuanB").dataset.deger || null) : null;
    if (!h) return toast("Hükümet için 1-5 arası bir puan seç.", true);
    try { await API.rpc("ulusal_kriz_puanla", { p_olay: id, p_hukumet: h, p_belediye: b }); toast("Puanın kaydedildi."); ulusalKrizEkrani(); } catch (err) { hata(err); }
  };
  window.skKrizBaslat = async function(){
    if (!await onayla("Kriz başlat", "Seçilen kriz bütün oyuncular için hemen başlar.", "Başlat", true)) return;
    try { await API.rpc("ulusal_kriz_baslat", { p_kod: $("#skKrizTur").value, p_il: ($("#skKrizIl").value || "").trim() || null }); toast("Kriz başladı."); skKrizOnbellek = null; ulusalKrizEkrani(); } catch (err) { hata(err); }
  };
  window.skKrizAyar = async function(){
    try { await API.rpc("ulusal_kriz_ayar", { p_aktif: $("#skKrizAktif").checked, p_ihtimal: +$("#skKrizOran").value, p_min_gun: +$("#skKrizGun").value }); toast("Kaydedildi."); ulusalKrizEkrani(); } catch (err) { hata(err); }
  };
  function krizGundemKart(d){
    const k = d && d.aktif; if (!k) return "";
    const bende = k.yetki_ilk || k.yetki_kalici || k.yetki_yerel;
    return `<div class="kart sk-serit sk-gundem-kriz"><span class="rozet kirmizi">Ulusal kriz${k.il_ad ? " · " + e(k.il_ad) : ""}</span><h2 style="margin:8px 0 4px">${e(k.baslik)}</h2>
      <p class="alt">${bende ? "Karar senden bekleniyor." : k.asama === 1 ? "İlk müdahale kararı bekleniyor." : k.asama === 2 ? "Kalıcı çözüm kararı bekleniyor." : "Halk değerlendirmesi sürüyor."} ${k.degerlendirebilir ? "Kriz yönetimini puanlayabilirsin." : ""}</p>
      <button class="btn ${bende ? "altin" : "ikinci"}" onclick="ekranAc(ulusalKrizEkrani)">${bende ? "Karar ver" : "Kriz masasını aç"}</button></div>`;
  }

  /* ============================== 3) KOMİSYONLAR ============================== */
  async function komisyonlarEkrani(){
    yukleniyor("Meclis komisyonları");
    let d; try { d = await API.rpc("komisyonlar"); } catch (err) { iskelet("Meclis komisyonları", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
    let h = `<div class="kart"><h2>İhtisas komisyonları</h2><p class="alt">Her kanun teklifi görüşme süresinde konusuna göre bir komisyona gider. Komisyon üyeleri oy verir, başkan rapor yazar. Ret oyları kabulden fazla ve yeterli sayıdaysa teklif Genel Kurul'a gelmez. Her komisyon ${fmt(d.boyut)} üyelidir; kontenjanlar partilerin sandalyeleriyle orantılıdır. Bir vekil en fazla ${d.azami_uyelik} komisyonda görev alır.</p>
      <div class="sk-etki">${(d.kontenjan || []).map(x => `<span class="rozet" style="border-left:3px solid ${e(x.renk || "#888")}">${e(x.parti)}: ${fmt(x.kontenjan)} sandalye</span>`).join("")}</div>
      ${d.vekilim ? `<p class="kucuk">Komisyon üyeliğin: ${fmt(d.uyeliklerim)}/${d.azami_uyelik}</p>` : `<p class="kucuk">Komisyonlarda yalnız milletvekilleri görev alır.</p>`}</div>`;
    (d.komisyonlar || []).forEach(k => {
      h += `<div class="kart"><h3>${e(k.ad)}</h3><p class="kucuk">${e(k.aciklama)}</p>
        <div class="kv"><span class="k">Başkan</span><span class="v">${e(k.baskan || "Seçilmedi")}</span></div>
        <div style="margin-top:8px">${(k.uyeler || []).map(u => `<span class="sk-uye ${u.gecerli ? "" : "yedek"}"><i style="background:${e(u.renk || "#999")}"></i>${e(u.kad)}${u.baskan ? " · başkan" : ""}${u.gecerli ? "" : " · yedek"}${u.cikarabilirim ? ` <a href="#" onclick="skKomCikar('${k.kod}','${e(u.kad)}');return false" class="kucuk">çek</a>` : ""}</span>`).join("") || `<span class="kucuk">Henüz üye yok.</span>`}</div>`;
      if (k.gecerli_uyeyim && (k.uyeler || []).length) h += `<div class="alan"><label>Başkanlık oyun${k.baskan_oyum ? " (şu an: " + e(k.baskan_oyum) + ")" : ""}</label><select onchange="skKomBaskan('${k.kod}',this.value)"><option value="">Aday seç…</option>${k.uyeler.filter(u => u.gecerli).map(u => `<option ${k.baskan_oyum === u.kad ? "selected" : ""}>${e(u.kad)}</option>`).join("")}</select></div>`;
      if ((k.gundem || []).length) h += `<p class="kucuk" style="margin-top:8px"><b>Gündemdeki teklifler</b></p>` + k.gundem.map(g => `<div class="liste-satir" onclick="ekranAc(()=>kanunEkrani(${g.id}))" style="cursor:pointer"><div class="orta"><b>${e(g.baslik)}</b><span class="kucuk">${fmt(g.kabul)} kabul · ${fmt(g.ret)} ret · ${kalan(g.oy_bas)}${g.oyum ? " · oyun: " + e(g.oyum) : ""}</span></div><span class="ok">›</span></div>`).join("");
      if ((k.son_kararlar || []).length) h += `<p class="kucuk" style="margin-top:8px"><b>Son kararlar</b></p>` + k.son_kararlar.slice(0, 4).map(g => `<div class="kv"><span class="k">${e(g.baslik)}</span><span class="v">${g.karar === "ret" ? "Reddedildi" : g.karar === "kabul" ? "Genel Kurul'a gönderildi" : "Raporsuz"}</span></div>`).join("");
      if (d.vekilim && !d.tbmm_baskani) h += k.uyeyim ? `<button class="btn ikinci" onclick="skKomAyril('${k.kod}')">Komisyondan ayrıl</button>` : `<button class="btn" onclick="skKomKatil('${k.kod}')">Komisyona katıl</button>`;
      h += `</div>`;
    });
    iskelet("Meclis komisyonları", h, { geri: true });
  }
  const komIslem = async (fn, args, mesaj) => { try { await API.rpc(fn, args); if (mesaj) toast(mesaj); komisyonlarEkrani(); } catch (err) { hata(err); } };
  window.skKomKatil = kod => komIslem("komisyon_katil", { p_kom: kod }, "Komisyona katıldın.");
  window.skKomAyril = async kod => { if (await onayla("Komisyondan ayrıl", "Bu komisyondaki üyeliğin ve başkanlık oyların silinecek.", "Ayrıl")) komIslem("komisyon_ayril", { p_kom: kod }, "Ayrıldın."); };
  window.skKomBaskan = (kod, kad) => { if (kad) komIslem("komisyon_baskan_oy", { p_kom: kod, p_kad: kad }, "Başkanlık oyun kaydedildi."); };
  window.skKomCikar = async (kod, kad) => { if (await onayla("Üyeyi çek", `${kad} komisyondan çekilecek.`, "Çek", true)) komIslem("komisyon_uye_cikar", { p_kom: kod, p_kad: kad }, "Üye çekildi."); };

  function komKanunHtml(id, c){
    if (!c) return "";
    const kabul = (c.oylar || []).filter(o => o.oy === "kabul").length, ret = (c.oylar || []).filter(o => o.oy === "ret").length, cek = (c.oylar || []).filter(o => o.oy === "cekimser").length;
    let h = `<div class="kart sk-kom-kanun"><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><h3>${e(c.kom_ad)}</h3><span class="rozet ${c.karar === "ret" ? "kirmizi" : c.karar ? "yesil" : "sari"}">${c.karar === "ret" ? "Komisyonda reddedildi" : c.karar === "kabul" ? "Genel Kurul'a gönderildi" : c.karar === "raporsuz" ? "Raporsuz gönderildi" : c.acik ? kalan(c.bitis) : "Görüşme bitti"}</span></div>
      <p class="kucuk">Başkan: ${e(c.baskan || "seçilmedi")} · ${fmt(c.uye_sayisi)} asıl üye · reddetmek için en az ${fmt(c.esik)} ret oyu ve kabulden fazla olması gerekir${c.havale_eden ? " · havale: " + e(c.havale_eden) : ""}</p>
      <div class="kv"><span class="k">Oylar</span><span class="v">${kabul} kabul · ${ret} ret · ${cek} çekimser</span></div>`;
    if ((c.oylar || []).length) h += `<div style="margin-top:6px">${c.oylar.map(o => `<span class="sk-uye"><i style="background:${e(o.renk || "#999")}"></i>${e(o.kad)}: ${o.oy === "kabul" ? "kabul" : o.oy === "ret" ? "ret" : "çekimser"}</span>`).join("")}</div>`;
    if (c.rapor) h += `<p style="margin-top:8px;white-space:pre-wrap">${e(c.rapor)}</p><p class="kucuk">Komisyon raporu · ${e(c.rapor_yazan || "")} · ${ts(c.rapor_at)}</p>`;
    if (c.oy_verebilirim) h += `<p class="kucuk" style="margin-top:8px">${c.oyum ? "Oyun: " + e(c.oyum) + ". Değiştirebilirsin." : "Komisyon üyesi olarak oyunu kullan."}</p><div class="satir"><button class="btn yarim" onclick="skKomOy(${id},'kabul')">Kabul</button><button class="btn yarim tehlike" onclick="skKomOy(${id},'ret')">Ret</button><button class="btn yarim ikinci" onclick="skKomOy(${id},'cekimser')">Çekimser</button></div>`;
    if (c.rapor_yazabilirim) h += `<button class="btn ikinci" onclick="skKomRapor(${id})">${c.rapor ? "Raporu güncelle" : "Komisyon raporunu yaz"}</button>`;
    if (c.havale_edebilirim) h += `<div class="alan"><label>Meclis Başkanı · havaleyi değiştir</label><select onchange="skKomHavale(${id},this.value)"><option value="">Komisyon seç…</option>${(c.komisyonlar || []).filter(x => x.kod !== c.kom_kod).map(x => `<option value="${e(x.kod)}">${e(x.ad)}</option>`).join("")}</select></div>`;
    return h + `</div>`;
  }
  async function komKanunEkle(id){
    let c; try { c = await API.rpc("komisyon_kanun", { p_kanun: id }); } catch (_) { return; }
    const ic = $("#icerik"); if (!ic || !c) return;
    const eski = ic.querySelector(".sk-kom-kanun"); if (eski) eski.remove();
    const ilk = ic.querySelector(".kart");
    if (ilk) ilk.insertAdjacentHTML("afterend", komKanunHtml(id, c)); else ic.insertAdjacentHTML("afterbegin", komKanunHtml(id, c));
  }
  window.skKomOy = async (id, oy) => { try { await API.rpc("komisyon_oy", { p_kanun: id, p_oy: oy, p_gerekce: null }); toast("Komisyon oyun kaydedildi."); komKanunEkle(id); } catch (err) { hata(err); } };
  window.skKomRapor = id => {
    const m = modal(`<h3>Komisyon raporu</h3><p class="alt">Rapor teklif sahibine bildirilir ve Genel Kurul'da teklifle birlikte görünür.</p><div class="alan"><label>Rapor (20-3000 karakter)</label><textarea class="alanmetin" id="skRapor" maxlength="3000"></textarea></div><button class="btn altin" id="skRaporOK">Raporu kaydet</button>`);
    $("#skRaporOK", m).onclick = async () => { try { await API.rpc("komisyon_rapor", { p_kanun: id, p_metin: $("#skRapor", m).value }); modalKapat(); toast("Rapor kaydedildi."); komKanunEkle(id); } catch (err) { hata(err); } };
  };
  window.skKomHavale = async (id, kod) => { if (!kod) return; try { await API.rpc("komisyon_havale", { p_kanun: id, p_kom: kod }); toast("Havale değiştirildi."); komKanunEkle(id); } catch (err) { hata(err); } };
  if (typeof window.kanunEkrani === "function") {
    const eskiKanun = window.kanunEkrani;
    window.kanunEkrani = kanunEkrani = async function(id){ const r = await eskiKanun.apply(this, arguments); try { await komKanunEkle(id); } catch (_) {} return r; };
  }

  /* ============================== 4) PARTİ KAPATMA ============================== */
  const DURUM_AD = { imza: "İmza toplanıyor", savunma: "Savunma bekleniyor", yargilama: "Anayasa Mahkemesinde", kapatma: "Parti kapatıldı", yardim: "Hazine yardımından yoksun", ret: "Dava reddedildi", dustu: "Dava düştü" };
  async function kapatmaDavalariEkrani(pid){
    yukleniyor("Kapatma davaları");
    let d; try { d = await API.rpc("parti_kapatma_davalari", { p_parti: pid || null }); } catch (err) { iskelet("Kapatma davaları", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
    let h = `<div class="kart"><h2>Parti kapatma davaları</h2><p class="alt">Adalet Bakanı doğrudan, milletvekilleri ise dolu sandalyelerin beşte biri kadar (en az ${fmt(d.imza_gerek)}) imzayla Anayasa Mahkemesinde dava açabilir. Davalı partinin genel başkanı 24 saat içinde savunma verir. Kapatma için Yüksek Mahkeme üyelerinin üçte ikisi gerekir; salt çoğunluk parti hazine yardımından 30 gün yoksun bırakılabilir. Kapatılan partinin üyeleri bağımsız kalır, makamları sürer, kasası hazineye geçer.</p>
      <div class="kv"><span class="k">Yüksek Mahkeme üyesi</span><span class="v">${fmt(d.heyet)}</span></div>
      ${d.acabilirim ? `<button class="btn tehlike" onclick="skPkdAcModal(${pid || 0})">${d.acan_rol === "adalet_bakani" ? "Kapatma davası aç" : "Kapatma davası için imza başlat"}</button>` : ""}</div>`;
    if ((d.yardim_yasaklari || []).length) h += `<div class="kart">${d.yardim_yasaklari.map(y => `<div class="kv"><span class="k">${e(y.parti)} hazine yardımından yoksun</span><span class="v">${ts(y.bit)}'e kadar</span></div>`).join("")}</div>`;
    h += (d.davalar || []).map(x => {
      const acik = ["imza","savunma","yargilama"].includes(x.durum);
      let s = `<div class="kart ${acik ? "sk-serit" : ""}"><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><b><span style="color:${e(x.renk || "inherit")}">${e(x.kisa)}</span> · ${e(x.parti)}</b><span class="rozet ${x.durum === "kapatma" ? "kirmizi" : x.durum === "ret" || x.durum === "dustu" ? "yesil" : "sari"}">${DURUM_AD[x.durum] || x.durum}</span></div>
        <p class="kucuk" style="margin-top:4px">${x.acan_rol === "adalet_bakani" ? "Adalet Bakanı" : "Milletvekilleri"} · ${e(x.acan)} · ${ts(x.bas)}</p>
        <p style="margin-top:6px"><b>${e(x.gerekce_ad)}</b></p><p style="white-space:pre-wrap;margin-top:4px">${e(x.iddia)}</p>`;
      if (x.durum === "imza") s += `<div class="kv"><span class="k">İmzalar</span><span class="v">${fmt(x.imza)}/${fmt(x.imza_gerek)} · ${kalan(x.imza_son)}</span></div>`;
      if (x.savunma) s += `<p class="kucuk" style="margin-top:8px"><b>Savunma</b> · ${e(x.savunan || "")} · ${ts(x.savunma_at)}</p><p style="white-space:pre-wrap">${e(x.savunma)}</p>`;
      else if (x.durum === "savunma") s += `<div class="kv"><span class="k">Savunma süresi</span><span class="v">${kalan(x.savunma_son)}</span></div>`;
      if (x.durum === "yargilama") s += `<div class="kv"><span class="k">Mahkeme oyları</span><span class="v">${fmt(x.verilen_oy)}/${fmt(x.heyet)} · ${kalan(x.karar_son)}</span></div>${x.oyum ? `<p class="kucuk">Oyun: ${e(x.oyum)}</p>` : ""}`;
      if (["kapatma","yardim","ret"].includes(x.durum)) s += `<div class="kv"><span class="k">Karar</span><span class="v">${fmt(x.oy_kapatma)} kapatma · ${fmt(x.oy_yardim)} yoksunluk · ${fmt(x.oy_ret)} ret</span></div>${x.karar_gerekce ? `<p class="kucuk" style="margin-top:6px">Gerekçe (${e(x.hakim || "")}): ${e(x.karar_gerekce)}</p>` : ""}`;
      if (x.durum === "dustu" && x.karar_gerekce) s += `<p class="kucuk">${e(x.karar_gerekce)}</p>`;
      if (x.imzalayabilirim) s += `<button class="btn altin" onclick="skPkdImza(${x.id},${pid || 0})">İmza ver</button>`;
      if (x.savunabilirim) s += `<button class="btn altin" onclick="skPkdSavunma(${x.id},${pid || 0})">Savunma ver</button>`;
      if (x.oy_verebilirim) s += `<button class="btn altin" onclick="skPkdOy(${x.id},${pid || 0})">${x.oyum ? "Oyumu değiştir" : "Mahkeme oyumu ver"}</button>`;
      return s + `</div>`;
    }).join("") || `<div class="kart"><p class="alt">Henüz kapatma davası açılmadı.</p></div>`;
    iskelet("Kapatma davaları", h, { geri: true });
    D._skPkd = d;
  }
  window.skPkdAcModal = pid => {
    const d = D._skPkd || {};
    const m = modal(`<h3>Kapatma davası</h3><div class="alan"><label>Davalı parti</label><select id="skPkdParti">${(d.partiler || []).map(p => `<option value="${p.id}" ${p.id === pid ? "selected" : ""}>${e(p.kisa)} · ${e(p.ad)}</option>`).join("")}</select></div>
      <div class="alan"><label>Gerekçe</label><select id="skPkdGer">${(d.gerekceler || []).map(g => `<option value="${g.kod}">${e(g.ad)}</option>`).join("")}</select></div>
      <div class="alan"><label>İddianame (50-3000 karakter)</label><textarea class="alanmetin" id="skPkdIddia" maxlength="3000" placeholder="Hangi eylemler, hangi kanıtlar?"></textarea></div>
      <button class="btn tehlike" id="skPkdOK">${d.acan_rol === "adalet_bakani" ? "Davayı aç" : "İmza toplamaya başla"}</button>`);
    $("#skPkdOK", m).onclick = async () => { try { await API.rpc("parti_kapatma_ac", { p_parti: +$("#skPkdParti", m).value, p_gerekce_tur: $("#skPkdGer", m).value, p_iddia: $("#skPkdIddia", m).value }); modalKapat(); toast("Dava başlatıldı."); kapatmaDavalariEkrani(pid || null); } catch (err) { hata(err); } };
  };
  window.skPkdImza = async (id, pid) => { if (!await onayla("İmza ver", "Bu partinin kapatılması için Anayasa Mahkemesine başvuruyu imzalayacaksın.", "İmzala", true)) return; try { await API.rpc("parti_kapatma_imza", { p_dava: id }); toast("İmzan eklendi."); kapatmaDavalariEkrani(pid || null); } catch (err) { hata(err); } };
  window.skPkdSavunma = (id, pid) => {
    const m = modal(`<h3>Savunma</h3><p class="alt">Savunman verildiğinde dava Anayasa Mahkemesinin oylamasına geçer.</p><div class="alan"><label>Savunma (50-3000 karakter)</label><textarea class="alanmetin" id="skPkdSav" maxlength="3000"></textarea></div><button class="btn altin" id="skPkdSavOK">Savunmayı sun</button>`);
    $("#skPkdSavOK", m).onclick = async () => { try { await API.rpc("parti_kapatma_savunma", { p_dava: id, p_metin: $("#skPkdSav", m).value }); modalKapat(); toast("Savunma dosyaya eklendi."); kapatmaDavalariEkrani(pid || null); } catch (err) { hata(err); } };
  };
  window.skPkdOy = (id, pid) => {
    const m = modal(`<h3>Anayasa Mahkemesi · oy</h3><div class="alan"><label>Kararın</label><select id="skPkdKarar"><option value="ret">Davanın reddi</option><option value="yardim">Hazine yardımından yoksun bırakma</option><option value="kapatma">Partinin kapatılması</option></select></div>
      <div class="alan"><label>Gerekçeli oy (20-2000 karakter)</label><textarea class="alanmetin" id="skPkdGerekce" maxlength="2000"></textarea></div><button class="btn altin" id="skPkdOyOK">Oyumu ver</button>`);
    $("#skPkdOyOK", m).onclick = async () => { try { await API.rpc("parti_kapatma_oy", { p_dava: id, p_karar: $("#skPkdKarar", m).value, p_gerekce: $("#skPkdGerekce", m).value }); modalKapat(); toast("Oyun kaydedildi."); kapatmaDavalariEkrani(pid || null); } catch (err) { hata(err); } };
  };

  /* ============================== 5) KOLLAR ============================== */
  async function partiKollariEkrani(pid){
    yukleniyor("Gençlik ve Kadın Kolları");
    let d; try { d = await API.rpc("parti_kollari", { p_parti: pid }); } catch (err) { iskelet("Gençlik ve Kadın Kolları", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
    D._skKol = d;
    let h = `<div class="kart"><h2>${e(d.parti)} kolları</h2><p class="alt">Kol başkanlarını genel başkan ya da teşkilattan sorumlu genel başkan yardımcısı atar. Kol başkanı parti kasasından aktarılan ya da üyelerin bağışladığı bütçeyle, partinin teşkilatı olan illerde 24 saatlik etkinlikler düzenler. O ilde yaşayan herkes ve kol üyeleri katılabilir; parti dışından gelenler partiye kazandırılabilir. Kol başkanlığı milletvekilliğiyle birlikte yürütülebilir; genel başkanlık, GBY, belediye başkanlığı ve cumhurbaşkanlığıyla yürütülemez.</p>
      ${d.parti_kasa != null ? `<div class="kv"><span class="k">Parti kasası</span><span class="v">${tl(d.parti_kasa)}</span></div>` : ""}</div>`;
    if (d.kapali) h += `<div class="kart"><p class="alt">Bu parti kapatıldı; kolları kapalı.</p></div>`;
    (d.kollar || []).forEach(k => {
      if (!k) return;
      const s = k.istatistik || {};
      h += `<div class="kart"><h2>${e(k.ad)}</h2>
        <div class="kv"><span class="k">Kol başkanı</span><span class="v">${e(k.baskan || "Atanmadı")}</span></div>
        <div class="kv"><span class="k">Üye</span><span class="v">${fmt(k.uye_sayisi)}</span></div>
        ${k.kasa != null ? `<div class="kv"><span class="k">Kol kasası</span><span class="v">${tl(k.kasa)}</span></div>` : ""}
        <div class="kv"><span class="k">Etkinlik / katılım / kazanılan üye</span><span class="v">${fmt(s.etkinlik)} / ${fmt(s.katilim)} / ${fmt(s.kazanilan_uye)}</span></div>`;
      if (d.uyeyim && !d.kapali) h += k.uyeyim ? `<button class="btn ikinci" onclick="skKol('kol_ayril','${k.tur}')">Koldan ayrıl</button>` : `<button class="btn" onclick="skKol('kol_katil','${k.tur}')">Kola katıl</button>`;
      if (d.uyeyim && !d.kapali) h += `<button class="btn ikinci" onclick="skKolBagis('${k.tur}')">Kola bağış yap</button>`;
      if (d.atayabilirim) h += `<button class="btn ikinci" onclick="skKolAta('${k.tur}')">${k.baskan ? "Kol başkanını değiştir" : "Kol başkanı ata"}</button>`;
      if (k.baskan && (d.atayabilirim || k.baskanim)) h += `<button class="btn ikinci" onclick="skKolGorevden('${k.tur}',${k.baskanim ? 1 : 0})">${k.baskanim ? "Kol başkanlığından çekil" : "Kol başkanını görevden al"}</button>`;
      if (d.butce_verebilirim) h += `<button class="btn ikinci" onclick="skKolButce('${k.tur}')">Parti kasasından bütçe aktar</button>`;
      if (k.baskanim) h += `<div class="satir"><button class="btn altin yarim" onclick="skKolEtkinlik('${k.tur}')">Etkinlik düzenle</button><button class="btn yarim" onclick="skKolDuyuru('${k.tur}')">Duyuru yap</button></div>`;
      if ((k.etkinlikler || []).length) h += `<p class="kucuk" style="margin-top:10px"><b>Etkinlikler</b></p>` + k.etkinlikler.map(x => `<div class="liste-satir"><div class="orta"><b>${e(x.baslik)}</b><span class="kucuk">${e(x.tip_ad)} · ${e(x.il)} · ${fmt(x.katilimci)} katılımcı · ${x.aktif ? kalan(x.bit) : e(x.sonuc || "bitti")}</span><span class="kucuk">${e(x.aciklama)}</span></div>${x.katilabilirim ? `<button class="btn yarim altin" style="flex:none" onclick="skKolKatil(${x.id})">Katıl</button>` : x.katildim ? `<span class="rozet yesil">Katıldın</span>` : ""}</div>`).join("");
      if ((k.duyurular || []).length) h += `<p class="kucuk" style="margin-top:10px"><b>Duyurular</b></p>` + k.duyurular.slice(0, 5).map(x => `<div class="sk-cizgi"><b>${e(x.baslik)}</b><span class="kucuk"> · ${e(x.yazan)} · ${ts(x.zaman)}</span><div style="white-space:pre-wrap">${e(x.metin)}</div></div>`).join("");
      if ((k.hareketler || []).length) h += `<p class="kucuk" style="margin-top:10px"><b>Kasa hareketleri</b></p>` + k.hareketler.slice(0, 8).map(x => `<div class="kv"><span class="k">${e(x.aciklama)}${x.kim ? " · " + e(x.kim) : ""}</span><span class="v">${+x.tutar > 0 ? "+" : ""}${tl(x.tutar)}</span></div>`).join("");
      h += `</div>`;
    });
    iskelet("Gençlik ve Kadın Kolları", h, { geri: true });
  }
  const kolPid = () => (D._skKol || {}).parti_id;
  const kolYenile = mesaj => { if (mesaj) toast(mesaj); partiKollariEkrani(kolPid()); };
  window.skKol = async (fn, tur) => { try { await API.rpc(fn, { p_parti: kolPid(), p_tur: tur }); kolYenile(fn === "kol_katil" ? "Kola katıldın." : "Koldan ayrıldın."); } catch (err) { hata(err); } };
  window.skKolKatil = async id => { try { await API.rpc("kol_etkinlik_katil", { p_etkinlik: id }); kolYenile("Etkinliğe katıldın."); } catch (err) { hata(err); } };
  window.skKolGorevden = async (tur, kendim) => { if (!await onayla(kendim ? "Görevden çekil" : "Görevden al", "Kol başkanlığı sona erecek.", "Onayla", true)) return; try { await API.rpc("kol_baskan_gorevden_al", { p_parti: kolPid(), p_tur: tur }); kolYenile("Kol başkanlığı sona erdi."); } catch (err) { hata(err); } };
  window.skKolAta = tur => {
    const m = modal(`<h3>Kol başkanı ata</h3><div class="alan"><label>Partinin üyesinin kullanıcı adı</label><input id="skKolKad" maxlength="40"></div><button class="btn altin" id="skKolAtaOK">Ata</button>`);
    $("#skKolAtaOK", m).onclick = async () => { try { await API.rpc("kol_baskan_ata", { p_parti: kolPid(), p_tur: tur, p_kad: $("#skKolKad", m).value }); modalKapat(); kolYenile("Kol başkanı atandı."); } catch (err) { hata(err); } };
  };
  const tutarModal = (baslik, aciklama, fn, tur, mesaj) => {
    const m = modal(`<h3>${baslik}</h3><p class="alt">${aciklama}</p><div class="alan"><label>Tutar (₺)</label><input id="skKolTutar" type="number" min="100" step="100"></div><button class="btn altin" id="skKolTutarOK">Onayla</button>`);
    $("#skKolTutarOK", m).onclick = async () => { try { await API.rpc(fn, { p_parti: kolPid(), p_tur: tur, p_tutar: +$("#skKolTutar", m).value }); modalKapat(); kolYenile(mesaj); } catch (err) { hata(err); } };
  };
  window.skKolButce = tur => tutarModal("Kol bütçesi", "Parti kasasından kol kasasına aktarılır (1.000 ₺ - 10 Mn ₺).", "kol_butce_aktar", tur, "Bütçe aktarıldı.");
  window.skKolBagis = tur => tutarModal("Kola bağış", "Cüzdanından kol kasasına bağış yaparsın (100 ₺ - 1 Mn ₺).", "kol_bagis", tur, "Bağışın için teşekkürler.");
  window.skKolEtkinlik = tur => {
    const d = D._skKol || {};
    if (!(d.teskilat_illeri || []).length) return toast("Partinin henüz il teşkilatı yok; etkinlik için önce teşkilat açılmalı.", true);
    const m = modal(`<h3>Etkinlik düzenle</h3><p class="alt">Etkinlik 24 saat sürer; ücret kol kasasından düşer. Aynı anda bir etkinlik düzenlenebilir.</p>
      <div class="alan"><label>Tür</label><select id="skEtTip">${(d.tipler || []).map(t => `<option value="${t.kod}">${e(t.ad)} · ${tl(t.ucret)}</option>`).join("")}</select></div>
      <div class="alan"><label>İl (teşkilatı olan iller)</label><select id="skEtIl">${d.teskilat_illeri.map(i => `<option value="${i.id}">${e(i.ad)}</option>`).join("")}</select></div>
      <div class="alan"><label>Başlık</label><input id="skEtBaslik" maxlength="80"></div>
      <div class="alan"><label>Açıklama</label><textarea class="alanmetin" id="skEtAciklama" maxlength="600"></textarea></div>
      <button class="btn altin" id="skEtOK">Etkinliği başlat</button>`);
    $("#skEtOK", m).onclick = async () => { try { await API.rpc("kol_etkinlik_duzenle", { p_parti: kolPid(), p_tur: tur, p_tip: $("#skEtTip", m).value, p_il: +$("#skEtIl", m).value, p_baslik: $("#skEtBaslik", m).value, p_aciklama: $("#skEtAciklama", m).value }); modalKapat(); kolYenile("Etkinlik başladı; üyelere duyuruldu."); } catch (err) { hata(err); } };
  };
  window.skKolDuyuru = tur => {
    const m = modal(`<h3>Kol duyurusu</h3><p class="alt">Bütün kol üyelerine bildirim gider. 6 saatte bir duyuru yapılabilir.</p><div class="alan"><label>Başlık</label><input id="skDyBaslik" maxlength="80"></div><div class="alan"><label>Metin</label><textarea class="alanmetin" id="skDyMetin" maxlength="1500"></textarea></div><button class="btn altin" id="skDyOK">Duyur</button>`);
    $("#skDyOK", m).onclick = async () => { try { await API.rpc("kol_duyuru_yap", { p_parti: kolPid(), p_tur: tur, p_baslik: $("#skDyBaslik", m).value, p_metin: $("#skDyMetin", m).value }); modalKapat(); kolYenile("Duyuru gönderildi."); } catch (err) { hata(err); } };
  };
  if (typeof window.partiDetay === "function") {
    const eskiParti = window.partiDetay;
    window.partiDetay = partiDetay = async function(id){
      const r = await eskiParti.apply(this, arguments);
      try {
        const ic = $("#icerik"); if (!ic || ic.querySelector(".sk-parti-ek")) return r;
        let dava = null; try { const dv = await API.rpc("parti_kapatma_davalari", { p_parti: id }); dava = (dv.davalar || []).find(x => ["imza","savunma","yargilama"].includes(x.durum)); } catch (_) {}
        const ilk = ic.querySelector(".kart");
        const html = `<div class="kart sk-parti-ek">${dava ? `<p class="kucuk" style="color:var(--al2);margin-bottom:6px">Bu partiye karşı süren bir kapatma davası var: ${e(DURUM_AD[dava.durum] || dava.durum)}.</p>` : ""}
          ${satirBtn("kol", "Gençlik ve Kadın Kolları", "Kol başkanları, etkinlikler ve duyurular", `ekranAc(()=>partiKollariEkrani(${+id}))`)}
          ${satirBtn("terazi", "Kapatma davaları", "Anayasa Mahkemesindeki davalar", `ekranAc(()=>kapatmaDavalariEkrani(${+id}))`)}</div>`;
        if (ilk) ilk.insertAdjacentHTML("afterend", html); else ic.insertAdjacentHTML("afterbegin", html);
      } catch (_) {}
      return r;
    };
  }

  /* ============================== Giriş noktaları ============================== */
  // Ekranın üstündeki sekme düğmelerinin (segment) hemen altına ekler
  function ustEkle(ic, html){
    let el = ic.firstElementChild, son = null;
    while (el && el.classList && el.classList.contains("segment")) { son = el; el = el.nextElementSibling; }
    if (son) son.insertAdjacentHTML("afterend", html); else ic.insertAdjacentHTML("afterbegin", html);
  }
  if (typeof iskelet === "function") {
    const eski = iskelet;
    window.iskelet = iskelet = function(baslik){
      const r = eski.apply(this, arguments);
      try {
        const ic = $("#icerik");
        if (ic) {
          if (baslik === "Meclis" && !ic.querySelector(".sk-meclis")) {
            ustEkle(ic, `<div class="kart sk-meclis">${satirBtn("komisyon", "İhtisas komisyonları", "Kanun teklifleri önce komisyonda görüşülür", "ekranAc(komisyonlarEkrani)")}${satirBtn("terazi", "Parti kapatma davaları", "Anayasa Mahkemesine taşınan davalar", "ekranAc(()=>kapatmaDavalariEkrani(null))")}</div>`);
          }
          if (baslik === "Adliye" && !ic.querySelector(".sk-adliye")) {
            ustEkle(ic, `<div class="kart sk-adliye">${satirBtn("terazi", "Parti kapatma davaları", "Anayasa Mahkemesi: kapatma ve hazine yardımından yoksunluk", "ekranAc(()=>kapatmaDavalariEkrani(null))")}</div>`);
          }
          if (baslik === "Devlet" && !ic.querySelector(".sk-devlet")) {
            ustEkle(ic, `<div class="kart sk-devlet">${satirBtn("kriz", "Ulusal Kriz Masası", "Deprem, salgın, kur şoku: kararlar ve kriz karneleri", "ekranAc(ulusalKrizEkrani)")}</div>`);
          }
          if (baslik === "Ülke Kriz Merkezi" && !ic.querySelector(".sk-devlet")) {
            ustEkle(ic, `<div class="kart sk-devlet">${satirBtn("kriz", "Ulusal Kriz Masası", "Büyük krizler ayrı masada yönetilir", "ekranAc(ulusalKrizEkrani)")}</div>`);
          }
          if (baslik === "Profilim" && !ic.querySelector(".sk-profil")) {
            ustEkle(ic, `<div class="kart sk-profil">${satirBtn("davet", "Arkadaşını davet et", "Davet kodunla gelen oy hakkı kazanınca ikiniz de ödül alırsınız", "ekranAc(davetEkrani)")}</div>`);
          }
          if (baslik === "Gündem" && !ic.querySelector(".sk-gundem-kriz")) {
            const anahtar = D._sonAnahtar;
            skKrizVeri(false).then(d => { const ic2 = $("#icerik"); if (!ic2 || D._sonAnahtar !== anahtar || ic2.querySelector(".sk-gundem-kriz")) return; const h = krizGundemKart(d); if (h) ustEkle(ic2, h); });
          }
        }
        skBekleyenDavet();
      } catch (_) {}
      return r;
    };
  }
  window.davetEkrani = davetEkrani;
  window.ulusalKrizEkrani = ulusalKrizEkrani;
  window.komisyonlarEkrani = komisyonlarEkrani;
  window.kapatmaDavalariEkrani = kapatmaDavalariEkrani;
  window.partiKollariEkrani = partiKollariEkrani;
})();
