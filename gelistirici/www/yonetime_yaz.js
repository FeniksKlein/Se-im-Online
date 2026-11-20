/* 20.11.2026 · Yönetime Yaz — oyuncunun olayı kendi cümleleriyle yazdığı talep (ticket) ekranı.
   Talep konusuna göre ilgili masaya düşer; görevli görev koduyla yanıtlar; oyuncu karşılık yazabilir. */
(function () {
  const esc = (x) => (typeof e === "function" ? e(String(x == null ? "" : x)) : String(x == null ? "" : x).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])));
  const hc = (m) => (typeof hataCevir === "function" ? hataCevir(m) : m);
  const hata = (err) => toast(hc((err && err.message) || String(err)), true);
  const zaman = (t) => { try { return new Date(t).toLocaleString("tr-TR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (_) { return ""; } };
  const DURUM = { yeni: ["Yanıt bekliyor", "#e0a43a"], yanitlandi: ["Yanıtlandı", "#34c98a"], kapali: ["Kapandı", "#98a4c4"] };
  const YY = { veri: null, acik: null };

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
      .yy-mesaj{padding:10px 12px;border-radius:12px;margin:8px 0;font-size:15px;line-height:1.45;white-space:pre-wrap;overflow-wrap:anywhere;background:rgba(255,255,255,.05)}
      .yy-mesaj.g{background:rgba(52,201,138,.12);border-left:3px solid #34c98a}
      .yy-mesaj small{display:block;font-size:13px;opacity:.7;margin-bottom:3px}
      .yy-ust{display:flex;gap:8px;align-items:center;justify-content:space-between;flex-wrap:wrap}
      .yy-nokta{display:inline-block;width:9px;height:9px;border-radius:50%;background:#e5574f;margin-right:6px;vertical-align:middle}`;
    document.head.appendChild(s);
  }

  async function yonetimeYazEkrani(on) {
    css();
    yukleniyor("Yönetime yaz");
    try { YY.veri = await API.rpc("yonetime_yaz_bilgi"); }
    catch (err) { iskelet("Yönetime yaz", `<div class="bos">${esc(hc(err.message))}</div>`, { geri: true }); return; }
    ciz(on && on.konu ? on : null);
    if (YY.veri.okunmamis) API.rpc("yonetime_yaz_okundu").catch(() => {});
  }

  function talepKart(t) {
    const d = DURUM[t.durum] || DURUM.yeni, acik = YY.acik === t.id;
    const yeniYanit = t.durum === "yanitlandi" && !t.okundu;
    return `<div class="kart" data-talep="${t.id}">
      <div class="yy-ust" data-ac="${t.id}" style="cursor:pointer"><b style="font-size:16px">${yeniYanit ? `<span class="yy-nokta"></span>` : ""}#${t.id} · ${esc(t.konu_ad)}</b><span class="yy-etiket" style="--c:${d[1]}">${d[0]}</span></div>
      <div class="kucuk" data-ac="${t.id}" style="cursor:pointer">${zaman(t.zaman)}${t.hedef ? " · hakkında: " + esc(t.hedef) : ""}${acik ? "" : " · görmek için dokun"}</div>
      ${acik ? `${(t.mesajlar || []).map(m => `<div class="yy-mesaj ${m.gorevli ? "g" : ""}"><small>${m.gorevli ? esc(m.yazan) : "Sen"} · ${zaman(m.zaman)}</small>${esc(m.metin)}</div>`).join("")}
        ${t.durum !== "kapali" ? `<label class="yy-alan" for="yyY${t.id}">Karşılık yaz</label><textarea class="yy-girdi" id="yyY${t.id}" maxlength="1000" style="min-height:80px" placeholder="Ek bilgi ya da yanıtın"></textarea>
          <button class="btn" data-yanit="${t.id}" style="margin-top:8px">Gönder</button>` : `<p class="kucuk">Bu talep kapatıldı. Yeni bir durum varsa yeni talep açabilirsin.</p>`}` : ""}
    </div>`;
  }

  function ciz(on) {
    const v = YY.veri, konular = v.konular || [];
    let konu = on && on.konu ? on.konu : null;
    iskelet("Yönetime yaz", `
      <div class="kart"><h2>Yeni talep</h2>
        <p class="kucuk">Şikâyetini, ihbarını, itirazını ya da sorununu kendi cümlelerinle yaz. Talebin ilgili görevliye ulaşır; yanıt gelince bildirim alırsın. Yazdıkların gizlidir.</p>
        <div class="yy-alan">Konu</div>
        <div id="yyKonular">${konular.map(k => `<button type="button" class="yy-konu ${k.kod === konu ? "on" : ""}" data-k="${esc(k.kod)}"><b>${esc(k.ad)}</b><small>${esc(k.aciklama)}</small></button>`).join("")}</div>
        <label class="yy-alan" for="yyHedef">İlgili oyuncu (varsa)</label>
        <input class="yy-girdi" id="yyHedef" maxlength="40" autocapitalize="off" autocomplete="off" placeholder="Kullanıcı adı" value="${esc(on && on.hedef || "")}">
        <label class="yy-alan" for="yyMetin">Ne oldu?</label>
        <textarea class="yy-girdi" id="yyMetin" maxlength="2000" placeholder="Ne oldu, nerede (sohbet, Kürsü, özel mesaj, pano, banka…), ne zaman? Ne kadar ayrıntı verirsen o kadar hızlı çözülür.">${esc(on && on.metin || "")}</textarea>
        <button class="btn altin" id="yyGonder" style="margin-top:10px">Talebi gönder</button>
        <p class="kucuk" style="margin-top:8px">Tek bir mesajı ya da paylaşımı bildirmek için içeriğin üzerindeki <b>Şikâyet et</b> düğmesi daha hızlıdır. Asılsız ihbar yaptırım sebebidir.</p>
      </div>
      <div class="kart"><h2>Taleplerim (${(v.talepler || []).length})</h2>
        <p class="kucuk">Yanıt bekleyen en fazla 3 talebin olabilir.</p></div>
      ${(v.talepler || []).map(talepKart).join("") || `<div class="bos">Henüz talebin yok.</div>`}`, { geri: true });
    const ic = document.getElementById("icerik") || document;
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
        toast(`Talebin alındı (#${r.id}). Yanıt gelince bildirim alacaksın.`);
        YY.acik = r.id; yonetimeYazEkrani();
      } catch (err) { g.disabled = false; hata(err); }
    };
    ic.querySelectorAll("[data-ac]").forEach(b => b.onclick = () => { const id = +b.dataset.ac; YY.acik = YY.acik === id ? null : id; const y = window.scrollY; ciz(); window.scrollTo(0, y); });
    ic.querySelectorAll("[data-yanit]").forEach(b => b.onclick = async () => {
      const id = +b.dataset.yanit, m = ic.querySelector("#yyY" + id).value.trim();
      if (m.length < 2) { toast("Yanıtını yaz.", true); return; }
      b.disabled = true;
      try { YY.veri = await API.rpc("yonetime_yaz_yanit", { p_id: id, p_metin: m }); toast("Gönderildi."); ciz(); }
      catch (err) { b.disabled = false; hata(err); }
    });
  }

  window.yonetimeYazEkrani = yonetimeYazEkrani;
  // Şikâyet penceresinden "olayı anlat" kısayolu
  window.yonetimeYazAc = (hedef) => { if (typeof modalKapat === "function") modalKapat(); ekranAc(() => yonetimeYazEkrani({ konu: "sikayet", hedef: hedef || "" })); };
})();
