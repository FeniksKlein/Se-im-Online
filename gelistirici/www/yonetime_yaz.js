/* 20.11.2026 · Yönetime Yaz — oyuncunun olayı kendi cümleleriyle yazdığı talep (ticket) ekranı.
   26.11.2026 · Yardım ve destek sohbeti: her talep oyuncuya özel bir sohbettir. Sunucu talebi çevrimiçi bir görevliye
   otomatik atar (yanıt gelmezse 30 dakikada başka görevliye geçer); bütün görevliler görür, görevli işi bitince kapatır.
   Talep listesi + sohbet ekranı (balonlar, 15 sn'de bir yenileme, "Görevli: Oyun Yöneticisi G-07").
   Eski sunucu (gorevli_ad alanı yok) ile de çalışır; o durumda görevli satırı gösterilmez. */
(function () {
  const esc = (x) => (typeof e === "function" ? e(String(x == null ? "" : x)) : String(x == null ? "" : x).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])));
  const hc = (m) => (typeof hataCevir === "function" ? hataCevir(m) : m);
  const hata = (err) => toast(hc((err && err.message) || String(err)), true);
  const zaman = (t) => { try { return new Date(t).toLocaleString("tr-TR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (_) { return ""; } };
  const DURUM = { yeni: ["Yanıt bekliyor", "#e0a43a"], yanitlandi: ["Yanıtlandı", "#34c98a"], kapali: ["Kapandı", "#98a4c4"] };
  const YY = { veri: null, form: false, sohbet: null, zaman: null };

  function css() {
    if (document.getElementById("yyCss")) return;
    const s = document.createElement("style"); s.id = "yyCss";
    s.textContent = `
      .yy-alan{display:block;font-size:15px;font-weight:700;margin:12px 0 6px}
      .yy-girdi{display:block;width:100%;min-width:0;box-sizing:border-box;font-size:16px;line-height:1.45;padding:12px;border-radius:12px;border:1px solid rgba(255,255,255,.16);background:rgba(255,255,255,.06);color:inherit;color-scheme:dark}
      textarea.yy-girdi{min-height:120px;resize:vertical}
      .yy-girdi::placeholder{color:rgba(255,255,255,.5)}
      .yy-konu{display:block;width:100%;box-sizing:border-box;text-align:left;min-height:48px;padding:10px 12px;margin:6px 0;border-radius:12px;border:1px solid rgba(255,255,255,.14);background:rgba(255,255,255,.04);color:inherit;font-size:15px;cursor:pointer}
      .yy-konu b{display:block;font-size:16px}.yy-konu small{display:block;font-size:14px;opacity:.75;line-height:1.35;margin-top:2px}
      .yy-konu.on{border-color:#9a7bff;background:rgba(154,123,255,.16)}
      .yy-etiket{display:inline-block;font-size:13px;font-weight:700;padding:3px 9px;border-radius:999px;background:color-mix(in srgb,var(--c) 22%,transparent);color:var(--c);white-space:nowrap}
      .yy-ust{display:flex;gap:8px;align-items:center;justify-content:space-between;flex-wrap:wrap}
      .yy-nokta{display:inline-block;width:9px;height:9px;border-radius:50%;background:#e5574f;margin-right:6px;vertical-align:middle}
      .yy-satir{display:block;width:100%;box-sizing:border-box;text-align:left;min-height:64px;padding:12px 14px;margin:0 0 10px;border-radius:14px;border:1px solid rgba(255,255,255,.1);background:rgba(255,255,255,.04);color:inherit;cursor:pointer}
      .yy-satir .yy-onizleme{display:block;font-size:14px;opacity:.75;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .yy-satir .yy-gorevli{display:block;font-size:13px;color:#34c98a;margin-top:4px}
      .yy-baslik{position:sticky;top:0;z-index:2}
      .yy-gorevli-kutu{display:flex;gap:10px;align-items:center;margin-top:8px;padding:10px 12px;border-radius:12px;background:rgba(52,201,138,.1);font-size:14px;line-height:1.4}
      .yy-gorevli-kutu.bekle{background:rgba(224,164,58,.1)}
      .yy-kalkan{flex:0 0 32px;height:32px;border-radius:50%;display:grid;place-items:center;background:rgba(52,201,138,.2);color:#34c98a;font-weight:800}
      .yy-gorevli-kutu.bekle .yy-kalkan{background:rgba(224,164,58,.2);color:#e0a43a}
      .yy-akis{display:flex;flex-direction:column;gap:8px;padding:4px 0 8px}
      .yy-balon{max-width:84%;padding:9px 12px;border-radius:16px;font-size:15px;line-height:1.45;white-space:pre-wrap;overflow-wrap:anywhere}
      .yy-balon small{display:block;font-size:12px;opacity:.7;margin-top:4px}
      .yy-balon.ben{align-self:flex-end;background:#6a4fd8;color:#fff;border-bottom-right-radius:4px}
      .yy-balon.ben small{text-align:right}
      .yy-balon.g{align-self:flex-start;background:rgba(52,201,138,.13);border:1px solid rgba(52,201,138,.35);border-bottom-left-radius:4px}
      .yy-balon.g b{display:block;font-size:13px;color:#34c98a;margin-bottom:2px}
      .yy-sistem{align-self:center;font-size:13px;opacity:.7;text-align:center;padding:4px 10px}
      .yy-yaz{position:sticky;bottom:0;padding:10px 0 4px;background:linear-gradient(transparent,var(--zemin,#0b1022) 30%)}
      .yy-yaz textarea{min-height:56px;max-height:160px}`;
    document.head.appendChild(s);
  }

  async function veriAl() { YY.veri = await API.rpc("yonetime_yaz_bilgi"); return YY.veri; }

  async function yonetimeYazEkrani(on) {
    css();
    yukleniyor("Yönetime yaz");
    try { await veriAl(); }
    catch (err) { iskelet("Yönetime yaz", `<div class="bos">${esc(hc(err.message))}</div>`, { geri: true }); return; }
    if (on && on.konu) YY.form = true;
    ciz(on && on.konu ? on : null);
  }

  function sonMesaj(t) { const l = t.mesajlar || []; return l.length ? l[l.length - 1] : null; }

  function talepSatir(t) {
    const d = DURUM[t.durum] || DURUM.yeni, son = sonMesaj(t);
    const yeniYanit = t.durum === "yanitlandi" && !t.okundu;
    const gorevli = t.durum !== "kapali" ? (t.gorevli_ad ? `<span class="yy-gorevli">Görevli: ${esc(t.gorevli_ad)}</span>` : (t.durum === "yeni" && "gorevli_ad" in t ? `<span class="yy-gorevli" style="color:#e0a43a">Görevli atanıyor…</span>` : "")) : "";
    return `<button type="button" class="yy-satir" data-ac="${t.id}">
      <span class="yy-ust"><b style="font-size:16px">${yeniYanit ? `<span class="yy-nokta"></span>` : ""}#${t.id} · ${esc(t.konu_ad)}</b><span class="yy-etiket" style="--c:${d[1]}">${d[0]}</span></span>
      <span class="yy-onizleme">${son ? (son.gorevli ? "Görevli: " : "Sen: ") + esc(son.metin) : esc(t.metin || "")}</span>
      ${gorevli}<span class="kucuk" style="display:block;margin-top:4px">${zaman(t.son_hareket || t.zaman)}${t.hedef ? " · hakkında: " + esc(t.hedef) : ""}</span></button>`;
  }

  function ciz(on) {
    const v = YY.veri, konular = v.konular || [], talepler = v.talepler || [];
    const acikSayi = talepler.filter(t => t.durum !== "kapali").length;
    let konu = on && on.konu ? on.konu : null;
    iskelet("Yönetime yaz", `
      <div class="kart"><h2>Yardım ve destek</h2>
        <p class="kucuk">Sorununu, şikâyetini ya da itirazını yaz. Talebin sana özel bir sohbet olarak açılır ve çevrimiçi bir oyun yöneticisine atanır; yanıt gelince bildirim alırsın. Yazdıklarını yalnız oyun yönetimi görür.</p>
        ${YY.form ? `
        <div class="yy-alan">Konu</div>
        <div id="yyKonular">${konular.map(k => `<button type="button" class="yy-konu ${k.kod === konu ? "on" : ""}" data-k="${esc(k.kod)}"><b>${esc(k.ad)}</b><small>${esc(k.aciklama)}</small></button>`).join("")}</div>
        <label class="yy-alan" for="yyHedef">İlgili oyuncu (varsa)</label>
        <input class="yy-girdi" id="yyHedef" maxlength="40" autocapitalize="off" autocomplete="off" placeholder="Kullanıcı adı" value="${esc(on && on.hedef || "")}">
        <label class="yy-alan" for="yyMetin">Ne oldu?</label>
        <textarea class="yy-girdi" id="yyMetin" maxlength="2000" placeholder="Ne oldu, nerede (sohbet, Kürsü, özel mesaj, pano, banka…), ne zaman? Ne kadar ayrıntı verirsen o kadar hızlı çözülür.">${esc(on && on.metin || "")}</textarea>
        <button class="btn altin" id="yyGonder" style="margin-top:10px">Talebi gönder</button>
        <button class="btn ikinci" id="yyVazgec" style="margin-top:8px">Vazgeç</button>
        <p class="kucuk" style="margin-top:8px">Tek bir mesajı ya da paylaşımı bildirmek için içeriğin üzerindeki <b>Şikâyet et</b> düğmesi daha hızlıdır. Asılsız ihbar yaptırım sebebidir.</p>`
        : `<button class="btn altin" id="yyYeni" style="margin-top:6px">Yardım iste · yeni talep aç</button>`}
      </div>
      <div class="kart" style="padding-bottom:6px"><div class="yy-ust"><h2 style="margin:0">Taleplerim</h2><span class="kucuk">${acikSayi} açık · ${talepler.length} toplam</span></div>
        <p class="kucuk">Bir talebe dokunarak sohbeti aç. Yanıt bekleyen en fazla 3 talebin olabilir.</p></div>
      ${talepler.map(talepSatir).join("") || `<div class="bos">Henüz talebin yok.</div>`}`, { geri: true });
    const ic = document.getElementById("icerik") || document;
    const yb = ic.querySelector("#yyYeni"); if (yb) yb.onclick = () => { YY.form = true; ciz(); };
    const vz = ic.querySelector("#yyVazgec"); if (vz) vz.onclick = () => { YY.form = false; ciz(); };
    ic.querySelectorAll("#yyKonular [data-k]").forEach(b => b.onclick = () => { konu = b.dataset.k; ic.querySelectorAll("#yyKonular [data-k]").forEach(x => x.classList.toggle("on", x === b)); });
    const g = ic.querySelector("#yyGonder");
    if (g) g.onclick = async () => {
      if (!konu) { toast("Önce bir konu seç.", true); return; }
      const metin = ic.querySelector("#yyMetin").value.trim(), hedef = ic.querySelector("#yyHedef").value.trim();
      if (metin.length < 20) { toast("Olayı biraz daha ayrıntılı yaz (en az 20 karakter).", true); return; }
      g.disabled = true;
      try {
        const platform = (window.Capacitor && window.Capacitor.getPlatform && window.Capacitor.getPlatform()) || "web";
        const r = await API.rpc("yonetime_yaz", { p_konu: konu, p_metin: metin, p_hedef: hedef || null, p_surum: window.UYGULAMA_SURUM || null, p_platform: platform });
        toast(`Talebin alındı (#${r.id}). Bir görevli seninle ilgilenecek.`);
        YY.form = false;
        await veriAl();
        ekranAc(() => talepSohbeti(r.id));
      } catch (err) { g.disabled = false; hata(err); }
    };
    ic.querySelectorAll("[data-ac]").forEach(b => b.onclick = () => { const id = +b.dataset.ac; ekranAc(() => talepSohbeti(id)); });
  }

  /* ---------------- Talep sohbeti ---------------- */
  function gorevliKutu(t) {
    if (t.durum === "kapali") return `<div class="yy-gorevli-kutu bekle"><span class="yy-kalkan">✓</span><div>Bu talep kapatıldı. Yeni bir sorunun varsa yeni talep açabilirsin.</div></div>`;
    if (t.gorevli_ad) return `<div class="yy-gorevli-kutu"><span class="yy-kalkan">⛨</span><div><b>${esc(t.gorevli_ad)}</b><br><span class="kucuk">Talebinle bu görevli ilgileniyor.</span></div></div>`;
    if ("gorevli_ad" in t) return `<div class="yy-gorevli-kutu bekle"><span class="yy-kalkan">…</span><div><b>Görevli atanıyor</b><br><span class="kucuk">Çevrimiçi bir oyun yöneticisi talebini üstlenecek. Yanıt gelince bildirim alırsın.</span></div></div>`;
    return "";
  }

  function akisHtml(t) {
    const l = t.mesajlar || [];
    return `<div class="yy-sistem">Talep #${t.id} · ${esc(t.konu_ad)} · ${zaman(t.zaman)}${t.hedef ? " · hakkında: " + esc(t.hedef) : ""}</div>` +
      l.map(m => m.gorevli
        ? `<div class="yy-balon g"><b>${esc(m.yazan)}</b>${esc(m.metin)}<small>${zaman(m.zaman)}</small></div>`
        : `<div class="yy-balon ben">${esc(m.metin)}<small>${zaman(m.zaman)}</small></div>`).join("") +
      (t.durum === "kapali" ? `<div class="yy-sistem">Talep kapatıldı</div>` : "");
  }

  function imza(t) { return t ? [t.durum, t.gorevli_ad || "", (t.mesajlar || []).length].join("|") : ""; }

  async function talepSohbeti(id) {
    css();
    let t = YY.veri && (YY.veri.talepler || []).find(x => x.id === id);
    if (!t) {
      yukleniyor("Talep");
      try { await veriAl(); } catch (err) { iskelet("Talep", `<div class="bos">${esc(hc(err.message))}</div>`, { geri: true }); return; }
      t = (YY.veri.talepler || []).find(x => x.id === id);
      if (!t) { iskelet("Talep", `<div class="bos">Talep bulunamadı.</div>`, { geri: true }); return; }
    }
    YY.sohbet = id;
    const d = DURUM[t.durum] || DURUM.yeni;
    iskelet(`Talep #${t.id}`, `<div id="yySohbet" data-id="${t.id}">
      <div class="kart yy-baslik"><div class="yy-ust"><b style="font-size:16px">${esc(t.konu_ad)}</b><span class="yy-etiket" id="yyDurum" style="--c:${d[1]}">${d[0]}</span></div>
        <div id="yyGorevli">${gorevliKutu(t)}</div></div>
      <div class="yy-akis" id="yyAkis">${akisHtml(t)}</div>
      <div class="yy-yaz" id="yyYazAlan">${t.durum !== "kapali" ? `<label class="yy-alan" for="yyY" style="margin-top:0">Mesajın</label>
        <textarea class="yy-girdi" id="yyY" maxlength="1000" placeholder="Görevliye yaz…"></textarea>
        <button class="btn" id="yyYGonder" style="margin-top:8px">Gönder</button>` : ""}</div></div>`, { geri: true });
    const ic = document.getElementById("icerik") || document;
    const kaydir = () => { const a = ic.querySelector("#yyAkis"); if (a && a.lastElementChild) a.lastElementChild.scrollIntoView({ block: "end" }); };
    kaydir();
    if (t.durum === "yanitlandi" && !t.okundu) API.rpc("yonetime_yaz_okundu").catch(() => {});
    let son = imza(t);
    const guncelle = (yeni) => {
      if (!yeni || !document.getElementById("yySohbet")) return;
      const s2 = imza(yeni); if (s2 === son) return;
      const kapandi = yeni.durum === "kapali" && t.durum !== "kapali";
      son = s2; t = yeni;
      const dd = DURUM[t.durum] || DURUM.yeni, de = ic.querySelector("#yyDurum");
      if (de) { de.textContent = dd[0]; de.style.setProperty("--c", dd[1]); }
      const gk = ic.querySelector("#yyGorevli"); if (gk) gk.innerHTML = gorevliKutu(t);
      const a = ic.querySelector("#yyAkis"); if (a) a.innerHTML = akisHtml(t);
      if (kapandi) { const ya = ic.querySelector("#yyYazAlan"); if (ya) ya.innerHTML = ""; }
      if (t.durum === "yanitlandi" && !t.okundu) API.rpc("yonetime_yaz_okundu").catch(() => {});
      kaydir();
    };
    const b = ic.querySelector("#yyYGonder");
    if (b) b.onclick = async () => {
      const ta = ic.querySelector("#yyY"), m = ta.value.trim();
      if (m.length < 2) { toast("Mesajını yaz.", true); return; }
      b.disabled = true;
      try {
        YY.veri = await API.rpc("yonetime_yaz_yanit", { p_id: id, p_metin: m });
        ta.value = ""; b.disabled = false;
        guncelle((YY.veri.talepler || []).find(x => x.id === id));
      } catch (err) { b.disabled = false; hata(err); }
    };
    // Sohbet açıkken 15 sn'de bir yenile (yalnız bu ekran açık ve uygulama ön plandayken).
    clearTimeout(YY.zaman);
    const dongu = () => {
      YY.zaman = setTimeout(async () => {
        const el = document.getElementById("yySohbet");
        if (!el || +el.dataset.id !== id || YY.sohbet !== id) return;
        if (document.visibilityState === "visible" && t.durum !== "kapali") {
          try { await veriAl(); guncelle((YY.veri.talepler || []).find(x => x.id === id)); } catch (_) {}
        }
        dongu();
      }, 15000);
    };
    dongu();
  }

  window.yonetimeYazEkrani = yonetimeYazEkrani;
  window.yonetimeYazTalep = (id) => ekranAc(() => talepSohbeti(+id));
  // Şikâyet penceresinden "olayı anlat" kısayolu
  window.yonetimeYazAc = (hedef) => { if (typeof modalKapat === "function") modalKapat(); ekranAc(() => yonetimeYazEkrani({ konu: "sikayet", hedef: hedef || "" })); };
})();
