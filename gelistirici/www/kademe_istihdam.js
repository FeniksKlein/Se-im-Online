/* =====================================================================
   KADEMELİ GETİRİ + İSTİHDAM (26.11.2026 · sunucu: sql/zz_20261126_kademeli_getiri_istihdam.sql)
   - Şirket › Özet: "Kademeli Getiri" kartı (dilimler, günlük hedef, kuruluş verimi, Hızlı Açılış Belgesi kullan)
     ve "👥 Personel" düğmesi. Şirket › Personel: iş ilanı ver/kapat, başvurular (kabul/ret), çalışanlar
     (maaş değiştir, sözleşmeyi bitir), son 7 günün mesai özeti.
   - Ek İşler'in üstünde "İş Hayatı" kartı: işin varsa "Mesaiye git", yoksa "İş ilanlarına bak".
   - İş Hayatı ekranı (istihdamEkrani): işim, başvurularım, açık iş ilanları, yönettiğim şirketler.
   - Mağaza: "Oyun parası" listesinin altında "Bu parayı şirketine koyarsan" tahmini getiri kartı, Patron Kartı durumu.
   Yetki ve bütün kurallar sunucuda doğrulanır; bu dosya yalnız gösterir. Eski sunucuda (RPC yoksa) hiçbir şey eklenmez.
   ===================================================================== */
(function () {
  "use strict";
  if (window.KADEME_ISTIHDAM_YUKLENDI) return;
  window.KADEME_ISTIHDAM_YUKLENDI = true;

  const esc = (s) => String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const tl = (n) => Math.round(Number(n) || 0).toLocaleString("tr-TR") + " ₺";
  const yuzde = (n) => "%" + String(Number(n) || 0).replace(".", ",");
  const rpc = (ad, arg) => API.rpc(ad, arg || {});
  const hataYaz = (err) => (typeof hataCevir === "function" ? hataCevir((err && err.message) || String(err)) : ((err && err.message) || String(err)));
  const uyar = (err) => { if (typeof toast === "function") toast(hataYaz(err), true); };
  const tarih = (x) => x ? new Date(x).toLocaleDateString("tr-TR", { day: "2-digit", month: "2-digit" }) : "—";

  const stil = document.createElement("style");
  stil.textContent = `
  .ki-kart h2{display:flex;align-items:center;gap:8px}
  .ki-dilim{display:grid;grid-template-columns:1fr auto;gap:4px 10px;margin:10px 0;font-size:14px;line-height:1.4}
  .ki-dilim span{min-width:0;overflow-wrap:anywhere}
  .ki-dilim b{text-align:right;white-space:nowrap}
  .ki-dilim .ki-ben{color:var(--gold2,#F2C94C);font-weight:800}
  .ki-buyuk{font-size:24px;font-weight:800;letter-spacing:-.3px;margin:4px 0 2px}
  .ki-not{font-size:14px;line-height:1.5;opacity:.85;margin:8px 0 0}
  .ki-cubuk{height:8px;border-radius:99px;background:rgba(255,255,255,.1);overflow:hidden;margin:6px 0 2px}
  .ki-cubuk i{display:block;height:100%;background:linear-gradient(90deg,#3FB27F,#F2C94C);border-radius:99px}
  .ki-satir{display:flex;align-items:center;gap:10px;padding:12px 0;border-top:1px solid rgba(255,255,255,.08)}
  .ki-satir:first-of-type{border-top:0}
  .ki-satir .ki-orta{flex:1;min-width:0}
  .ki-satir .ki-orta b{display:block;overflow-wrap:anywhere}
  .ki-satir .ki-orta span{display:block;font-size:14px;opacity:.8;line-height:1.45;overflow-wrap:anywhere}
  .ki-satir .btn{width:auto;min-height:44px;padding:8px 14px;flex:0 0 auto;margin:0}
  .ki-form label{display:block;font-size:15px;margin:10px 0 4px}
  .ki-form input,.ki-form textarea{width:100%;min-width:0;box-sizing:border-box;font-size:16px;color-scheme:dark}
  .ki-form textarea{min-height:72px;resize:vertical}
  .ki-etiket{display:inline-block;font-size:12px;font-weight:800;padding:2px 8px;border-radius:99px;background:rgba(63,178,127,.18);color:#6FD3A4;margin-left:4px;vertical-align:1px}
  .ki-etiket.sari{background:rgba(242,201,76,.18);color:#F2C94C}
  .ki-etiket.kirmizi{background:rgba(235,87,87,.18);color:#FF8A8A}
  .ki-dugmeler{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}
  .ki-dugmeler .btn{flex:1 1 140px;min-height:48px;margin:0}
  `;
  document.head.appendChild(stil);

  /* ---------------- KADEMELİ GETİRİ KARTI ---------------- */
  function kademeKart(o, sirketId) {
    if (!o || !o.aktif) return "";
    const d = o.dilimler || [];
    const T = Number(o.sermaye) || 0;
    const buDilim = (x) => T > 0 ? (T > Number(x.alt) && (x.ust == null || T <= Number(x.ust))) : Number(x.alt) === 0;
    const satir = (x, i) => {
      const etiket = i === 0 ? `İlk ${tl(x.ust)}` : x.ust == null ? `${tl(x.alt)} üstü` : `${tl(x.alt)} – ${tl(x.ust)}`;
      return `<span class="${buDilim(x) ? "ki-ben" : ""}">${esc(etiket)}${buDilim(x) ? " ← sen" : ""}</span><b>günde ${yuzde(x.oran)}</b>`;
    };
    const s = (o.sirketler || []).find(x => Number(x.id) === Number(sirketId));
    const olg = s ? Number(s.olgunluk) : 100;
    const hizli = Number(o.hizli_jeton) || 0;
    return `<section class="kart ki-kart" id="kiKademe"><h2>📈 Kademeli Getiri</h2>
      <p class="alt">Şirket kazancın kişi başına kademeli: şirket payının ilk diliminde en yüksek getiri. Şirketi bölmek getiriyi değiştirmez.</p>
      <div class="ki-dilim">${d.map(satir).join("")}</div>
      <div class="kv"><span class="k">Şirketlerdeki toplam payın</span><span class="v">${tl(T)}</span></div>
      <div class="kv"><span class="k">Hedef günlük net getirin</span><span class="v">${tl(o.gunluk_hedef)}</span></div>
      ${Number(o.ilk_dilim_kalan) > 0 ? `<p class="ki-not">İlk dilimde <b>${tl(o.ilk_dilim_kalan)}</b> daha yerin var: bu kadar ek sermaye günde ${yuzde(d[0] ? d[0].oran : 2.5)} hedefler.</p>` : ""}
      ${o.patron && o.patron.aktif ? `<p class="ki-not"><span class="ki-etiket sari">Patron Kartı</span> ilk dilimin ${tl(o.patron.ek)} genişledi · bitiş ${tarih(o.patron.bitis)}</p>` : ""}
      ${s ? `<div class="kv" style="margin-top:8px"><span class="k">Bu şirketin kuruluş verimi</span><span class="v">%${olg}</span></div><div class="ki-cubuk"><i style="width:${Math.max(2, Math.min(100, olg))}%"></i></div>` : ""}
      ${s && olg < 100 && hizli > 0 ? `<button type="button" class="btn altin" id="kiHizli" style="margin-top:10px">⚡ Hızlı Açılış Belgesi kullan (${hizli} adet · ${o.hizli_gun} gün kısaltır)</button>` : ""}
      <p class="ki-not">Hedef, iyi yönetilen (doğru fiyat, kalite, rakip durumu) ve kuruluş dönemini bitirmiş şirket içindir; zarar eden şirketin kârı büyütülmez.</p>
    </section>`;
  }

  async function hizliKullan(id) {
    if (typeof onayla === "function" && !(await onayla("Hızlı Açılış Belgesi", "Bu şirketin kuruluş dönemi kısalır ve kazancı hemen yükselir. Belge geri alınamaz.", "Kullan"))) return;
    try {
      const r = await rpc("hizli_acilis_kullan", { p_sirket: Number(id) });
      toast(`Kuruluş verimi %${r.once} → %${r.sonra}`);
      await window.sirketTekSirketEkrani(Number(id), "genel");
    } catch (err) { uyar(err); }
  }

  /* ---------------- ŞİRKET EKRANINA BAĞLAMA ---------------- */
  async function sirketGenelEkle(id) {
    const ic = document.getElementById("icerik"); if (!ic || ic.querySelector("#kiKademe")) return;
    let o = null; try { o = await rpc("kademe_ozet"); } catch (_) { return; }
    const ic2 = document.getElementById("icerik"); if (!ic2 || ic2.querySelector("#kiKademe")) return;
    const ilk = ic2.querySelector(".sm-tabs");
    const html = kademeKart(o, id) + `<div class="kart" id="kiPersonelGiris"><button type="button" class="btn altin" id="kiPersonelBtn">👥 Personel ve iş ilanı</button>
      <p class="ki-not" style="margin-top:6px">Gerçek oyuncuları işe al: her mesai şirket kasana maaşından fazlasını kazandırır.</p></div>`;
    if (ilk) ilk.insertAdjacentHTML("afterend", html); else ic2.insertAdjacentHTML("beforeend", html);
    const b = document.getElementById("kiHizli"); if (b) b.onclick = () => hizliKullan(id);
    const p = document.getElementById("kiPersonelBtn"); if (p) p.onclick = () => ekranAc(() => window.personelEkrani(id));
  }
  function sirketBagla() {
    const f = window.sirketTekSirketEkrani;
    if (typeof f !== "function") return false;
    if (f._ki) return true;
    const yeni = async function (id, tab) {
      if (tab === "personel") return window.personelEkrani(id);
      const r = await f.apply(this, arguments);
      if (!tab || tab === "genel") { try { await sirketGenelEkle(id); } catch (_) {} }
      return r;
    };
    yeni._ki = true;
    window.sirketTekSirketEkrani = yeni;
    return true;
  }

  /* ---------------- PERSONEL (şirket yönetimi) ---------------- */
  window.personelEkrani = async function personelEkrani(id) {
    id = Number(id);
    if (typeof yukleniyor === "function") yukleniyor("Personel");
    let d;
    try { d = await rpc("istihdam_sirket", { p_sirket: id }); }
    catch (err) { iskelet("Personel", `<div class="kart"><p class="alt">${esc(hataYaz(err))}</p></div>`, { geri: true }); return; }
    personelCiz(d);
  };
  function personelCiz(d) {
    const id = Number(d.sirket_id), il = d.ilan;
    const katmaOrnek = Math.round(Math.min(2500, d.piyasa_ucret) * d.katma_kat);
    let h = `<section class="kart ki-kart"><h2>👥 ${esc(d.ad)} · Personel</h2>
      <div class="kv"><span class="k">Şirket kasası</span><span class="v">${tl(d.kasa)}</span></div>
      <div class="kv"><span class="k">Çalışan / kontenjan</span><span class="v">${(d.calisanlar || []).length} / ${d.kontenjan}</span></div>
      <p class="ki-not">Kontenjan: 1 + her ${tl(d.kontenjan_birim)} sermaye için 1 kişi (en çok ${d.kontenjan_max}). Çalışan günde bir kez mesai yapar; maaşı kasadan ödenir, kasaya <b>en çok ${tl(d.piyasa_ucret)} × ${String(d.katma_kat).replace(".", ",")}</b> katma değer girer (örnek: ${tl(d.piyasa_ucret)} maaşlı çalışan → ${tl(katmaOrnek)}). Piyasa ücretinin üstündeki maaş şirkete ek kazanç getirmez.</p>
      ${d.son7 && Number(d.son7.mesai) > 0 ? `<div class="kv"><span class="k">Son 7 gün</span><span class="v">${d.son7.mesai} mesai · net ${tl((d.son7.katma || 0) - (d.son7.maas || 0) - (d.son7.vergi || 0))}</span></div>` : ""}
    </section>`;
    h += `<section class="kart ki-form"><h2>İş ilanı ${il && il.acik ? '<span class="ki-etiket">Yayında</span>' : il ? '<span class="ki-etiket sari">Kapalı</span>' : ""}</h2>
      <label for="kiMaas">Günlük maaş (₺)</label><input id="kiMaas" type="number" inputmode="numeric" min="${d.maas_taban}" max="${d.maas_tavan}" step="100" value="${il ? Number(il.maas) : d.piyasa_ucret}">
      <label for="kiKont">Kaç kişi alınacak</label><input id="kiKont" type="number" inputmode="numeric" min="1" max="${d.kontenjan}" step="1" value="${il ? Math.min(Number(il.kontenjan), d.kontenjan) : 1}">
      <label for="kiAcik">Kısa açıklama (isteğe bağlı)</label><textarea id="kiAcik" maxlength="300" placeholder="Örneğin: Fabrikamıza düzenli çalışacak arkadaş arıyoruz.">${esc(il ? il.aciklama : "")}</textarea>
      <div class="ki-dugmeler"><button type="button" class="btn altin" id="kiIlanVer">${il && il.acik ? "İlanı güncelle" : "İlanı yayınla"}</button>
      ${il && il.acik ? `<button type="button" class="btn ikinci" id="kiIlanKapat">İlanı kapat</button>` : ""}</div>
      <p class="ki-not">Maaş ${tl(d.maas_taban)} – ${tl(d.maas_tavan)} arası. Kasada en az 7 günlük maaş varsa ilanında "ödeme güvenli" görünür.</p></section>`;
    const bas = d.basvurular || [];
    h += `<section class="kart"><h2>Başvurular <span class="kucuk">${bas.length}</span></h2>${bas.length ? bas.map(b => `<div class="ki-satir"><div class="ki-orta"><b>${esc(b.ad)}</b><span>Kıdem ${esc(b.kidem)} · ${tarih(b.zaman)}${b.mesaj ? " · “" + esc(b.mesaj) + "”" : ""}</span></div>
        <button type="button" class="btn altin" data-kabul="${Number(b.id)}">Kabul</button><button type="button" class="btn ikinci" data-ret="${Number(b.id)}">Ret</button></div>`).join("")
      : '<p class="alt">Bekleyen başvuru yok. Başvurular 72 saat içinde yanıtlanmazsa kapanır.</p>'}</section>`;
    const cal = d.calisanlar || [];
    h += `<section class="kart"><h2>Çalışanlar <span class="kucuk">${cal.length}</span></h2>${cal.length ? cal.map(c => `<div class="ki-satir"><div class="ki-orta"><b>${esc(c.ad)} ${c.bugun ? '<span class="ki-etiket">Bugün mesaide</span>' : ""}</b>
        <span>Günlük ${tl(c.maas)} · ${c.mesai_sayi} mesai · şirkete katma değer ${tl(c.toplam_katma)} · son mesai ${tarih(c.son_mesai)}</span></div>
        <button type="button" class="btn ikinci" data-maas="${Number(c.id)}" data-eski="${Number(c.maas)}">Maaş</button><button type="button" class="btn ikinci" data-cikar="${Number(c.id)}">Bitir</button></div>`).join("")
      : '<p class="alt">Henüz çalışanın yok. İlan ver; başvuru gelince bildirim alırsın.</p>'}
      <p class="ki-not">7 gün üst üste mesai yapmayan çalışanın sözleşmesi kendiliğinden biter.</p></section>`;
    iskelet("Personel", h, { geri: true });
    const yenile = (r) => { if (r && r.uyari) toast(r.uyari, true); if (r && r.sirket_id) personelCiz(r); else window.personelEkrani(id); };
    const kilit = (b) => { if (b) b.disabled = true; };
    const ver = document.getElementById("kiIlanVer");
    if (ver) ver.onclick = async () => {
      kilit(ver);
      try {
        const r = await rpc("istihdam_ilan_ver", { p_sirket: id, p_maas: Number(document.getElementById("kiMaas").value), p_kontenjan: Number(document.getElementById("kiKont").value), p_aciklama: document.getElementById("kiAcik").value });
        toast("İlan yayında."); yenile(r);
      } catch (err) { uyar(err); ver.disabled = false; }
    };
    const kap = document.getElementById("kiIlanKapat");
    if (kap) kap.onclick = async () => { kilit(kap); try { yenile(await rpc("istihdam_ilan_kapat", { p_sirket: id })); toast("İlan kapatıldı."); } catch (err) { uyar(err); kap.disabled = false; } };
    document.querySelectorAll("[data-kabul],[data-ret]").forEach(b => b.onclick = async () => {
      const kabul = b.hasAttribute("data-kabul"), bid = Number(b.dataset.kabul || b.dataset.ret);
      kilit(b);
      try { const r = await rpc("istihdam_basvuru_karar", { p_basvuru: bid, p_kabul: kabul }); if (!(r && r.uyari)) toast(kabul ? "İşe alındı." : "Başvuru reddedildi."); yenile(r); }
      catch (err) { uyar(err); b.disabled = false; }
    });
    document.querySelectorAll("[data-cikar]").forEach(b => b.onclick = async () => {
      if (typeof onayla === "function" && !(await onayla("Sözleşmeyi bitir", "Bu çalışanın sözleşmesi hemen sona erer ve kendisine bildirim gider.", "Bitir", true))) return;
      kilit(b);
      try { yenile(await rpc("istihdam_cikar", { p_istihdam: Number(b.dataset.cikar) })); toast("Sözleşme sona erdi."); } catch (err) { uyar(err); b.disabled = false; }
    });
    document.querySelectorAll("[data-maas]").forEach(b => b.onclick = () => {
      const m = modal(`<h3>Günlük maaşı değiştir</h3><div class="ki-form"><label for="kiYeniMaas">Yeni günlük maaş (₺)</label>
        <input id="kiYeniMaas" type="number" inputmode="numeric" min="${d.maas_taban}" max="${d.maas_tavan}" step="100" value="${Number(b.dataset.eski)}"></div>
        <p class="ki-not">Çalışana bildirim gider. Yeni maaş bir sonraki mesaiden geçerlidir.</p>
        <button type="button" class="btn altin" id="kiMaasOnay" style="min-height:48px">Kaydet</button>`);
      const o = m.querySelector("#kiMaasOnay");
      o.onclick = async () => {
        o.disabled = true;
        try { const r = await rpc("istihdam_maas", { p_istihdam: Number(b.dataset.maas), p_maas: Number(m.querySelector("#kiYeniMaas").value) }); modalKapat(); toast("Maaş güncellendi."); yenile(r); }
        catch (err) { uyar(err); o.disabled = false; }
      };
    });
  }

  /* ---------------- İŞ HAYATI (oyuncu) ---------------- */
  window.istihdamEkrani = async function istihdamEkrani() {
    if (typeof yukleniyor === "function") yukleniyor("İş Hayatı");
    let d;
    try { d = await rpc("istihdam_panel"); }
    catch (err) { iskelet("İş Hayatı", `<div class="kart"><p class="alt">${esc(hataYaz(err))}</p></div>`, { geri: true }); return; }
    isCiz(d);
  };
  function isKartHtml(d, kisa) {
    const is = d.is;
    if (!is) return `<section class="kart ki-kart" id="kiIsKart"><h2>🏢 İş Hayatı</h2>
      <p class="alt">Bir şirkette işe gir, her gün tek dokunuşla mesai yap, maaşını al. Mesai günlük ek iş haklarından birini kullanır.</p>
      ${kisa ? `<button type="button" class="btn altin" id="kiIlanlaraGit">İş ilanlarına bak</button>` : ""}</section>`;
    const kapali = is.bugun_yapildi || Number(d.ek_is_kalan) <= 0;
    return `<section class="kart ki-kart" id="kiIsKart"><h2>🏢 ${esc(is.sirket)} ${is.bugun_yapildi ? '<span class="ki-etiket">Bugün mesaide</span>' : ""}</h2>
      <div class="ki-buyuk">${tl(is.maas)} <span class="kucuk">/ gün</span></div>
      <div class="kv"><span class="k">Toplam mesai</span><span class="v">${is.mesai_sayi} gün · ${tl(is.toplam_maas)}</span></div>
      ${is.kasa_yeter === false ? `<p class="ki-not"><span class="ki-etiket kirmizi">Uyarı</span> Şirket kasası bugünkü maaşını karşılamıyor.</p>` : ""}
      <div class="ki-dugmeler"><button type="button" class="btn altin" id="kiMesai" ${kapali ? "disabled" : ""}>${is.bugun_yapildi ? "Bugünkü mesai tamam" : Number(d.ek_is_kalan) <= 0 ? "Ek iş hakların doldu" : "Mesaiye git · " + tl(is.maas)}</button>
      ${kisa ? `<button type="button" class="btn ikinci" id="kiIlanlaraGit">İş Hayatı</button>` : `<button type="button" class="btn ikinci" id="kiAyril">İşten ayrıl</button>`}</div>
      <p class="ki-not">Mesai 1 ek iş hakkı kullanır (kalan: ${Number(d.ek_is_kalan)}). ${d.pasif_gun} gün üst üste mesai yapılmazsa sözleşme biter.</p></section>`;
  }
  function isCiz(d) {
    let h = "";
    if (d.acik === false) h += `<div class="kart"><p class="alt">İstihdam şu an kapalı.</p></div>`;
    h += isKartHtml(d, false);
    const bas = (d.basvurularim || []);
    if (bas.length) h += `<section class="kart"><h2>Başvurularım</h2>${bas.map(b => `<div class="ki-satir"><div class="ki-orta"><b>${esc(b.sirket)}</b><span>${({ bekliyor: "Şirketin kararı bekleniyor", kabul: "Kabul edildi", ret: "Kabul edilmedi", geri: "Geri çektin", kapandi: "Kapandı" })[b.durum] || esc(b.durum)} · ${tarih(b.zaman)}</span></div>
      ${b.durum === "bekliyor" ? `<button type="button" class="btn ikinci" data-geri="${Number(b.id)}">Geri çek</button>` : ""}</div>`).join("")}</section>`;
    const il = d.ilanlar || [];
    h += `<section class="kart"><h2>İş ilanları <span class="kucuk">${il.length}</span></h2>${il.length ? il.map(x => `<div class="ki-satir"><div class="ki-orta"><b>${esc(x.sirket)} ${x.odeme_guvenli ? '<span class="ki-etiket">Ödeme güvenli</span>' : ""}</b>
        <span>${esc(x.sektor)}${x.il ? " · " + esc(x.il) : ""} · ${x.dolu}/${x.kontenjan} kişi</span>${x.aciklama ? `<span>${esc(x.aciklama)}</span>` : ""}</div>
        <div style="text-align:right"><b style="display:block;white-space:nowrap">${tl(x.maas)}</b><button type="button" class="btn altin" data-basvur="${Number(x.id)}" ${d.is ? "disabled" : ""}>Başvur</button></div></div>`).join("")
      : '<p class="alt">Şu an açık iş ilanı yok. Şirketler ilan verdikçe burada görünür.</p>'}
      <p class="ki-not">Başvuru için hesabın en az ${d.min_hesap_gun} günlük olmalı; aynı anda en çok 3 başvurun olabilir. Ortağı olduğun ya da sahipleriyle aynı cihazı kullandığın şirkette çalışamazsın.</p></section>`;
    const sk = d.sirketlerim || [];
    if (sk.length) h += `<section class="kart"><h2>Şirketlerimin personeli</h2>${sk.map(s => `<div class="ki-satir"><div class="ki-orta"><b>${esc(s.ad)}</b><span>${s.calisan}/${s.kontenjan} çalışan${Number(s.bekleyen) ? ` · <b style="display:inline">${s.bekleyen} başvuru bekliyor</b>` : ""} · ilan ${s.ilan_acik ? "yayında" : "yok"}</span></div>
      <button type="button" class="btn ikinci" data-personel="${Number(s.id)}">Yönet</button></div>`).join("")}</section>`;
    iskelet("İş Hayatı", h, { geri: true });
    isDugmeler(d, () => window.istihdamEkrani());
    document.querySelectorAll("[data-geri]").forEach(b => b.onclick = async () => { b.disabled = true; try { isCiz(await rpc("istihdam_basvuru_geri", { p_basvuru: Number(b.dataset.geri) })); } catch (err) { uyar(err); b.disabled = false; } });
    document.querySelectorAll("[data-personel]").forEach(b => b.onclick = () => { const sid = Number(b.dataset.personel); ekranAc(() => window.personelEkrani(sid)); });
    document.querySelectorAll("[data-basvur]").forEach(b => b.onclick = () => {
      const ilan = il.find(x => Number(x.id) === Number(b.dataset.basvur)); if (!ilan) return;
      const m = modal(`<h3>${esc(ilan.sirket)} · ${tl(ilan.maas)}/gün</h3><div class="ki-form"><label for="kiNot">Kısa not (isteğe bağlı)</label>
        <textarea id="kiNot" maxlength="200" placeholder="Kendini kısaca tanıt"></textarea></div>
        <p class="ki-not">Şirket kabul ederse bildirim alırsın. Kabul edilince bekleyen diğer başvuruların kapanır.</p>
        <button type="button" class="btn altin" id="kiBasvurOnay" style="min-height:48px">Başvur</button>`);
      const o = m.querySelector("#kiBasvurOnay");
      o.onclick = async () => { o.disabled = true; try { const r = await rpc("istihdam_basvur", { p_ilan: Number(ilan.id), p_mesaj: m.querySelector("#kiNot").value }); modalKapat(); toast("Başvurun gönderildi."); isCiz(r); } catch (err) { uyar(err); o.disabled = false; } };
    });
  }
  function isDugmeler(d, tazele) {
    const ms = document.getElementById("kiMesai");
    if (ms) ms.onclick = async () => {
      ms.disabled = true;
      try {
        const r = await rpc("istihdam_mesai");
        if (r && r.uyari) toast(r.uyari, true); else toast(`Mesai tamam: +${tl(r.odenen)}`);
        if (typeof durumYenile === "function") { try { await durumYenile(); } catch (_) {} }
        tazele(r);
      } catch (err) { uyar(err); ms.disabled = false; }
    };
    const ay = document.getElementById("kiAyril");
    if (ay) ay.onclick = async () => {
      if (typeof onayla === "function" && !(await onayla("İşten ayrıl", "Sözleşmen hemen sona erer. Yeniden çalışmak için yeni bir ilana başvurman gerekir.", "Ayrıl", true))) return;
      ay.disabled = true;
      try { isCiz(await rpc("istihdam_ayril")); toast("İşinden ayrıldın."); } catch (err) { uyar(err); ay.disabled = false; }
    };
    const git = document.getElementById("kiIlanlaraGit");
    if (git) git.onclick = () => ekranAc(window.istihdamEkrani);
  }

  /* ---------------- EK İŞLER'E KART ---------------- */
  let ekIsMesgul = false, ekIsHataZaman = 0;
  async function ekIsKartEkle() {
    const ust = document.querySelector(".ei-ust"); if (!ust || document.getElementById("kiIsKart")) return;
    if (ekIsMesgul || Date.now() - ekIsHataZaman < 60000) return;
    ekIsMesgul = true;
    let d; try { d = await rpc("istihdam_panel"); } catch (_) { ekIsHataZaman = Date.now(); return; } finally { ekIsMesgul = false; }
    const ust2 = document.querySelector(".ei-ust"); if (!ust2 || document.getElementById("kiIsKart") || d.acik === false) return;
    ust2.insertAdjacentHTML("afterend", isKartHtml(d, true));
    isDugmeler(d, () => { if (typeof window.ekIslerEkrani === "function") window.ekIslerEkrani(true); });
  }
  /* ---------------- MAĞAZA: tahmini getiri ---------------- */
  function magazaEkle() {
    const M = window.MGZ, d = M && M.durum; if (!d || !d.getiri) return;
    const ekran = document.getElementById("mgEkran"); if (!ekran || document.getElementById("kiMagaza")) return;
    const paralar = (d.paketler || []).filter(p => p.tur === "para" && Number(d.getiri[p.urun_id]) > 0);
    if (!paralar.length) return;
    const bas = Array.prototype.slice.call(document.querySelectorAll(".bolum-bas")).find(x => /Oyun parası/.test(x.textContent));
    const kart = bas && bas.nextElementSibling;
    const k = d.kademe || {};
    const html = `<section class="kart ki-kart" id="kiMagaza"><h2>📈 Bu parayı şirketine koyarsan</h2>
      <div class="ki-dilim">${paralar.map(p => `<span>${tl(p.miktar)}</span><b>günde ≈ ${tl(d.getiri[p.urun_id])} ek getiri</b>`).join("")}</div>
      <p class="ki-not">Kademeli getiri: şirket payının ilk ${tl(k.ilk_dilim || 500000)}'si günde ${yuzde(k.ilk_oran || 2.5)} net hedefler. Tahmin iyi yönetilen, kuruluş dönemini bitirmiş şirket içindir; senin şu anki payına (${tl(k.sermaye)}) göre hesaplandı.</p>
      ${d.patron && d.patron.aktif ? `<p class="ki-not"><span class="ki-etiket sari">Patron Kartı aktif</span> bitiş ${tarih(d.patron.bitis)}</p>` : ""}</section>`;
    if (kart && kart.classList.contains("kart")) kart.insertAdjacentHTML("afterend", html); else ekran.insertAdjacentHTML("afterend", html);
  }
  /* Ek İşler ve Mağaza ekranları kendi içlerinden yeniden çizildiği için (yerel çağrılar) ekleme bir gözlemciyle yapılır. */
  let bekle = null;
  function tara() {
    bekle = null;
    try { if (document.querySelector(".ei-ust") && !document.getElementById("kiIsKart")) ekIsKartEkle(); } catch (_) {}
    try { if (document.getElementById("mgEkran") && !document.getElementById("kiMagaza")) magazaEkle(); } catch (_) {}
  }
  try {
    new MutationObserver(() => { if (!bekle) bekle = setTimeout(tara, 120); }).observe(document.body, { childList: true, subtree: true });
  } catch (_) {}
  if (!sirketBagla()) { setTimeout(sirketBagla, 1500); setTimeout(sirketBagla, 4000); }
})();
