/* =====================================================================
   SİVİL TOPLUM — dernekler, üyelik, bağış, şubeler, açıklamalar, protestolar
   Sunucu: gelistirici/sql/55_dernekler.sql
   ===================================================================== */
const STK_ALAN = [["genel", "Genel"], ["emek", "Emek ve Sendika"], ["cevre", "Çevre"], ["hak", "İnsan Hakları"], ["genclik", "Gençlik"], ["kadin", "Kadın"],
  ["egitim", "Eğitim"], ["esnaf", "Esnaf ve Meslek"], ["hayvan", "Hayvan Hakları"], ["kultur", "Kültür ve Sanat"], ["yerel", "Kent ve Yerel"]];
const STK_TUR = { basin: "Basın açıklaması", bildiri: "Bildiri", destek: "Destek açıklaması", protesto: "Protesto" };
const STK_HEDEF = { genel: "Genel konu", kanun: "Bir kanun", parti: "Bir parti", dernek: "Başka bir dernek", oyuncu: "Bir oyuncu / aday" };

// Partiler sekmesindeki giriş kartı
function stkGirisHtml() {
  return `<div class="kart"><h2>Sivil toplum</h2><p class="alt">Dernek kur ya da üye ol; protesto düzenle, basın açıklaması yap, bildiri yayımla, partilere ve adaylara destek açıkla.</p>
    <button class="btn altin" onclick="sekmeAc('dernek')">Dernekler ve sivil toplum kuruluşları</button></div>`;
}

function stkEylemHtml(x, opt) {
  opt = opt || {};
  const p = x.bas ? trParca(x.bas) : null;
  const zaman = x.tur === "protesto" ? (x.canli ? `<span class="rozet kirmizi">Canlı</span>` : x.bitti ? `<span class="rozet">Bitti · ${x.katilim} kişi</span>`
    : `<span class="rozet altin">${p.g} ${AYLAR[p.a - 1].slice(0, 3)} ${p.s}:${p.d}</span>`) : `<span class="kucuk">${tarihSaat(x.zaman)}</span>`;
  const katil = x.tur === "protesto" && x.canli && x.benim_ilim && !x.katildim ? `<button class="btn canli" onclick="stkProtestoKatil(${x.id})">Protestoya katıl</button>`
    : x.tur === "protesto" && x.canli && x.katildim ? `<div class="kucuk" style="margin-top:6px;color:var(--good)">Protestodasın · ${x.katilim} kişi</div>`
    : x.tur === "protesto" && x.canli ? `<div class="kucuk" style="margin-top:6px">Yalnız ${e(x.il)}'de yaşayanlar katılabilir · ${x.katilim} kişi</div>` : "";
  return `<div class="kart" style="margin:${opt.ic ? "10px 0 0" : "0 0 10px"};${opt.ic ? "background:var(--panel2)" : ""}">
    <div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><span class="rozet">${e(STK_TUR[x.tur])}${x.il ? " · " + e(x.il) : ""}</span>${zaman}</div>
    <b style="display:block;margin-top:6px">${e(x.baslik)}</b>
    ${opt.dernekAdi !== false ? `<div class="kucuk"><a class="bag" href="#" onclick="ekranAc(()=>stkDetay(${x.dernek.id}));return false">${e(x.dernek.ad)}</a>${x.hedef_ad ? " · " + e(x.hedef_ad) : ""}</div>` : x.hedef_ad ? `<div class="kucuk">Konu: ${e(x.hedef_ad)}</div>` : ""}
    <p style="white-space:pre-wrap;margin-top:6px;font-size:14.5px">${e(x.metin)}</p>${katil}</div>`;
}

// Bildirimden doğrudan açıklamanın kendisine açılan detay sayfası.
async function stkYayinGoster(id) {
  yukleniyor("Yayın");
  let x;
  try { x = await API.rpc("dernek_eylem_oku", { p_eylem: id }); }
  catch (err) {
    iskelet("Yayın", '<div class="bos">' + e(hataCevir(err.message)) + '</div>', { geri: true });
    return;
  }
  if (!x || !x.id) {
    iskelet("Yayın", '<div class="bos">Bu yayın kaldırılmış veya artık erişilemiyor.</div>', { geri: true });
    return;
  }
  const dId = Number(x.dernek && x.dernek.id);
  const kId = x.hedef_tur === "kanun" && /^[0-9]+$/.test(String(x.hedef_id)) ? Number(x.hedef_id) : null;
  iskelet(STK_TUR[x.tur] || "Yayın", stkEylemHtml(x) +
    (Number.isSafeInteger(dId) && dId > 0 ? '<button class="btn ikinci" onclick="ekranAc(()=>stkDetay(' + dId + '))">Derneğin sayfasına git</button>' : '') +
    (Number.isSafeInteger(kId) && kId > 0 ? '<button class="btn ikinci" onclick="ekranAc(()=>kanunEkrani(' + kId + '))">İlgili kanun teklifine git</button>' : ''),
    { geri: true });
}

async function stkEkrani() {
  const kok = D.sekme === "dernek" && !D.yigin.length;   // alt menüden açıldı
  yukleniyor(kok ? "Dernekler" : "Sivil toplum");
  let l, a; try { [l, a] = await Promise.all([API.rpc("dernekler"), API.rpc("dernek_akis", { p_limit: 15 })]); }
  catch (err) { iskelet(kok ? "Dernekler" : "Sivil toplum", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: !kok }); return; }
  const benim = l.filter(x => x.uyesiyim);
  iskelet(kok ? "Dernekler" : "Sivil toplum", `
    ${kok ? `<p class="alt" style="margin:0 0 12px">Dernek kur ya da üye ol; protesto düzenle, basın açıklaması yap, bildiri yayımla, partilere ve adaylara destek açıkla.</p>` : ""}
    ${benim.length ? `<div class="bolum-bas"><h2>Üyesi olduğun dernekler</h2></div><div class="kart">${benim.map(stkSatir).join("")}</div>` : ""}
    ${(a.protestolar || []).length ? `<div class="bolum-bas"><h2>Protestolar</h2><span class="kucuk">Sokaklar</span></div>${a.protestolar.map(x => stkEylemHtml(x)).join("")}` : ""}
    <div class="bolum-bas"><h2>Tüm dernekler</h2><span class="kucuk">${l.length} dernek</span></div>
    <div class="kart">${l.length ? l.map(stkSatir).join("") : `<div class="bos">Henüz dernek yok. İlk sivil toplum kuruluşunu sen kur.</div>`}</div>
    <button class="btn altin" style="margin:0 0 12px" onclick="stkKurModal()">Dernek kur</button>
    ${(a.aciklamalar || []).length ? `<div class="bolum-bas"><h2>Son açıklamalar</h2></div>${a.aciklamalar.map(x => stkEylemHtml(x)).join("")}` : ""}`, { geri: !kok });
}
function stkSatir(d) {
  return `<div class="liste-satir" onclick="ekranAc(()=>stkDetay(${d.id}))" style="cursor:pointer"><div class="orta"><b>${e(d.ad)}</b>${d.uyesiyim ? ` <span class="rozet">Üyesin</span>` : ""}
    <div class="kucuk">${e(d.alan_ad)} · ${e(d.merkez || "")} · ${d.uye} üye · ${d.sube} şube${d.baskan ? " · Başkan " + e(d.baskan) : ""}</div></div><span>›</span></div>`;
}

async function stkKurModal() {
  let harc = null; try { const l = await API.rpc("dernekler"); if (l[0]) harc = (await API.rpc("dernek_detay", { p_dernek: l[0].id })).harc; } catch (_) {}
  const m = modal(`<h3>Dernek kur</h3><p class="alt">Kurucusu olarak başkan olursun; kayıtlı olduğun il merkez şube olur. Bir oyuncu yalnız bir derneğin başkanı olabilir.${harc ? ` Kuruluş harcı: <b>${tlYaz(harc)}</b>.` : ""}</p>
    <div class="alan"><label for="dkAd">Derneğin adı</label><input id="dkAd" maxlength="50" placeholder="Örnek: Ege Doğa Derneği"></div>
    <div class="alan"><label for="dkAlan">Çalışma alanı</label><select id="dkAlan">${STK_ALAN.map(([k, v]) => `<option value="${k}">${e(v)}</option>`).join("")}</select></div>
    <div class="alan"><label for="dkAmac">Amacı (isteğe bağlı)</label><textarea id="dkAmac" class="alanmetin" maxlength="600" placeholder="Derneğin neyi savunduğu, neler yapacağı…"></textarea></div>
    <div class="hata-metin" id="dkHata"></div><button class="btn altin" id="dkTamam">Derneği kur</button>`);
  $("#dkTamam", m).onclick = async () => {
    const b = $("#dkTamam", m); b.disabled = true;
    try { const d = await API.rpc("dernek_kur", { p_ad: $("#dkAd", m).value, p_alan: $("#dkAlan", m).value, p_amac: $("#dkAmac", m).value });
      modalKapat(); toast("Dernek kuruldu."); ekranAc(() => stkDetay(d.id)); }
    catch (err) { b.disabled = false; $("#dkHata", m).textContent = hataCevir(err.message); }
  };
}

async function stkDetay(id) {
  yukleniyor("Dernek");
  let d; try { d = await API.rpc("dernek_detay", { p_dernek: id }); }
  catch (err) { iskelet("Dernek", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
  D._stk = d;
  const rolAd = { baskan: "Başkan", yonetim: "Yönetim kurulu", uye: "Üye" };
  iskelet(e(d.ad), `
    <div class="kart" style="text-align:center"><h3 style="font-size:21px">${e(d.ad)}</h3>
      <div class="alt">${e(d.alan_ad)} · Merkez ${e(d.merkez || "")} · ${tarih(d.kurulus)} tarihinde ${e(d.kurucu || "")} kurdu</div>
      ${d.kapali ? `<div class="rozet kirmizi" style="margin-top:8px">Kapandı</div>` : ""}
      <div style="display:flex;justify-content:center;gap:16px;margin-top:12px">
        <div><b style="font-size:20px">${d.uyeler.length}</b><div class="kucuk">üye</div></div><div><b style="font-size:20px">${d.subeler.length}</b><div class="kucuk">şube</div></div><div><b style="font-size:20px">${tlYaz(d.kasa)}</b><div class="kucuk">kasa</div></div></div>
      ${d.amac ? `<p style="white-space:pre-wrap;margin-top:10px;text-align:left">${e(d.amac)}</p>` : ""}</div>
    ${d.kapali ? "" : `<div class="satir" style="margin-bottom:12px">${d.rolum ? `<button class="btn yarim tehlike" onclick="stkAyril(${d.id})">Dernekten ayrıl</button>` : `<button class="btn yarim" onclick="stkKatil(${d.id})">Üye ol</button>`}
      <button class="btn yarim altin" onclick="stkBagisModal(${d.id})">Bağış yap</button></div>`}
    ${d.yetkili && !d.kapali ? `<div class="kart"><h2>Eylem ve açıklama</h2><p class="alt">Başkan ve yönetim kurulu dernek adına konuşur. Günde en fazla 3 açıklama ve 1 protesto.</p>
      <div class="vit-dugme"><button class="btn canli" onclick="stkEylemModal(${d.id},'protesto')">Protesto düzenle</button><button class="btn ikinci" onclick="stkEylemModal(${d.id},'basin')">Basın açıklaması</button></div>
      <div class="vit-dugme"><button class="btn ikinci" onclick="stkEylemModal(${d.id},'bildiri')">Bildiri yayımla</button><button class="btn ikinci" onclick="stkEylemModal(${d.id},'destek')">Destek açıkla</button></div></div>` : ""}
    <div class="kart"><h2>Şubeler</h2><div style="margin-top:6px">${d.subeler.map(s => `<span class="cip notr">${e(s.il)}${s.merkez ? " · merkez" : ""}</span>`).join("")}</div>
      ${d.yetkili && !d.kapali ? `<p class="kucuk" style="margin-top:8px">Protesto yalnız şubesi olan illerde yapılır. Şube bedeli kasadan: küçük il ${tlYaz(d.sube_ucretleri["1"])}, orta il ${tlYaz(d.sube_ucretleri["2"])}, büyük il ${tlYaz(d.sube_ucretleri["3"])}.</p>
        <button class="btn ikinci" onclick="stkSubeModal(${d.id})">Şube aç</button>` : ""}</div>
    <div class="bolum-bas"><h2>Eylemler</h2><span class="kucuk">${d.eylemler.length}</span></div>
    ${d.eylemler.length ? d.eylemler.map(x => stkEylemHtml(x, { dernekAdi: false })).join("") : `<div class="kart"><p class="alt">Henüz açıklama ya da protesto yok.</p></div>`}
    <div class="kart"><h2>Üyeler</h2>${d.uyeler.map(u => `<div class="liste-satir"><div class="orta" onclick="oyuncuKart('${e(u.kad)}')" style="cursor:pointer"><b>${e(u.kad)}</b> ${u.rol !== "uye" ? `<span class="rozet ${u.rol === "baskan" ? "altin" : ""}">${rolAd[u.rol]}</span>` : ""}<div class="kucuk">${e(u.il)}</div></div>
      ${d.rolum === "baskan" && u.rol !== "baskan" && !d.kapali ? `<button class="btn ikinci mt-kucuk" style="width:auto;margin:0" onclick="stkUyeIslem(${d.id},'${e(u.kad)}','${u.rol}')">Yönet</button>` : ""}</div>`).join("")}</div>
    ${d.hareketler && d.hareketler.length ? `<div class="kart"><h2>Kasa hareketleri</h2>${d.hareketler.map(h => `<div class="kv"><span class="k">${e(h.aciklama)}<div class="kucuk">${tarihSaat(h.zaman)}</div></span><span class="v" style="color:${h.tutar >= 0 ? "var(--good)" : "var(--al2)"}">${h.tutar >= 0 ? "+" : ""}${tlYaz(h.tutar)}</span></div>`).join("")}</div>` : ""}`, { geri: true });
}

async function stkKatil(id) { try { await API.rpc("dernek_katil", { p_dernek: id }); toast("Derneğe üye oldun."); stkDetay(id); } catch (err) { toast(hataCevir(err.message), true); } }
async function stkAyril(id) {
  if (!await onayla("Dernekten ayrıl", "Üyeliğin sona erecek. Başkansan önce başkanlığı devretmelisin; son üye ayrılırsa dernek kapanır.", "Ayrıl", true)) return;
  try { await API.rpc("dernek_ayril", { p_dernek: id }); toast("Dernekten ayrıldın."); stkDetay(id); } catch (err) { toast(hataCevir(err.message), true); }
}
function stkBagisModal(id) {
  const m = modal(`<h3>Derneğe bağış</h3><p class="alt">Bağış dernek kasasına girer; kasa şube açmak için kullanılır. En az 100 ₺.</p>
    <div class="alan"><label for="dbTutar">Tutar (₺)</label><input id="dbTutar" type="number" min="100" step="100" value="1000" inputmode="numeric"></div>
    <div class="hata-metin" id="dbHata"></div><button class="btn altin" id="dbTamam">Bağış yap</button>`);
  $("#dbTamam", m).onclick = async () => {
    const b = $("#dbTamam", m); b.disabled = true;
    try { await API.rpc("dernek_bagis", { p_dernek: id, p_tutar: +$("#dbTutar", m).value }); modalKapat(); toast("Bağışın için teşekkürler."); stkDetay(id); }
    catch (err) { b.disabled = false; $("#dbHata", m).textContent = hataCevir(err.message); }
  };
}
function stkSubeModal(id) {
  const d = D._stk, var_ = new Set(d.subeler.map(s => s.il_id));
  const iller = [...VERI.iller].sort((a, b) => a.ad.localeCompare(b.ad, "tr")).filter(i => !var_.has(i.id));
  const m = modal(`<h3>Şube aç</h3><p class="alt">Bedel dernek kasasından ödenir (kasada ${tlYaz(d.kasa)}).</p>
    <div class="alan"><label for="dsIl">İl</label><select id="dsIl">${iller.map(i => `<option value="${i.id}">${e(i.ad)}</option>`).join("")}</select></div>
    <div class="hata-metin" id="dsHata"></div><button class="btn altin" id="dsTamam">Şubeyi aç</button>`);
  $("#dsTamam", m).onclick = async () => {
    const b = $("#dsTamam", m); b.disabled = true;
    try { await API.rpc("dernek_sube_ac", { p_dernek: id, p_il: +$("#dsIl", m).value }); modalKapat(); toast("Şube açıldı."); stkDetay(id); }
    catch (err) { b.disabled = false; $("#dsHata", m).textContent = hataCevir(err.message); }
  };
}
async function stkUyeIslem(id, kad, rol) {
  const m = modal(`<h3>${e(kad)}</h3><p class="alt">Yönetim kurulu (en fazla 4 kişi) dernek adına açıklama yapar, protesto düzenler ve şube açar.</p>
    ${rol === "yonetim" ? `<button class="btn ikinci" id="duY">Yönetim kurulundan çıkar</button>` : `<button class="btn" id="duY">Yönetim kuruluna al</button>`}
    <button class="btn altin" id="duB">Başkanlığı devret</button>`);
  $("#duY", m).onclick = async () => { try { await API.rpc("dernek_yonetim_ata", { p_dernek: id, p_kad: kad, p_yonetim: rol !== "yonetim" }); modalKapat(); toast("Yönetim kurulu güncellendi."); stkDetay(id); } catch (err) { toast(hataCevir(err.message), true); } };
  $("#duB", m).onclick = async () => {
    if (!await onayla("Başkanlığı devret", `${kad} derneğin başkanı olacak; sen yönetim kurulunda kalacaksın.`, "Devret")) return;
    try { await API.rpc("dernek_baskan_devret", { p_dernek: id, p_kad: kad }); toast("Başkanlık devredildi."); stkDetay(id); } catch (err) { toast(hataCevir(err.message), true); }
  };
}

async function stkEylemModal(id, tur) {
  const d = D._stk;
  let partiler = [], dernekler = [], kanunlar = [];
  try { [partiler, dernekler, kanunlar] = await Promise.all([API.rpc("partiler"), API.rpc("dernekler"), API.rpc("kanunlar", { p_limit: 40 }).catch(() => [])]); } catch (_) {}
  dernekler = dernekler.filter(x => x.id !== id);
  const hedefTurler = tur === "destek" ? ["parti", "oyuncu"] : ["genel", "kanun", "parti", "dernek", "oyuncu"];
  const t = new Date(simdi() + 2 * 3600e3); t.setMinutes(0, 0, 0);
  const pz = trParca(t), iki = (n) => String(n).padStart(2, "0");
  const m = modal(`<h3>${e(STK_TUR[tur])}</h3>
    <p class="alt">${tur === "protesto" ? "Bir saatlik protesto. Başlayınca o ildeki herkese ve derneğin üyelerine haber gider; o ilde yaşayanlar katılır. Bitince katılım Gündem'e haber olur."
      : tur === "destek" ? "Bir partiye ya da bir oyuncuya (adaya) destek açıklarsın. Gündem'e haber olur, desteklenen tarafa bildirim gider."
      : "Açıklama Gündem'e haber olur. Konu bir parti, oyuncu, dernek ya da kanunsa ilgilisine bildirim gider."}</p>
    <div class="alan"><label for="deKonu">Konu</label><select id="deKonu">${hedefTurler.map(k => `<option value="${k}">${e(STK_HEDEF[k])}</option>`).join("")}</select></div>
    <div class="alan" id="deHedefAlan"></div>
    ${tur === "protesto" ? `<div class="alan"><label for="deIl">İl (şubesi olan iller)</label><select id="deIl">${d.subeler.map(s => `<option value="${s.il_id}">${e(s.il)}</option>`).join("")}</select></div>
      <div class="alan"><label for="deZaman">Başlangıç (Türkiye saati)</label><input id="deZaman" type="datetime-local" value="${pz.y}-${iki(pz.a)}-${iki(pz.g)}T${pz.s}:00"></div>` : ""}
    <div class="alan"><label for="deBaslik">Başlık</label><input id="deBaslik" maxlength="100" placeholder="${tur === "protesto" ? "Örnek: Kordon'da büyük buluşma" : "Kısa ve net bir başlık"}"></div>
    <div class="alan"><label for="deMetin">Metin</label><textarea id="deMetin" class="alanmetin" maxlength="2000" placeholder="Derneğin görüşü, talepleri, çağrısı…"></textarea></div>
    <div class="hata-metin" id="deHata"></div><button class="btn ${tur === "protesto" ? "canli" : "altin"}" id="deTamam">${tur === "protesto" ? "Protestoyu duyur" : "Yayımla"}</button>`);
  const hedefCiz = () => {
    const k = $("#deKonu", m).value, al = $("#deHedefAlan", m);
    al.innerHTML = k === "genel" ? `<label for="deHedef">Konu başlığı (isteğe bağlı)</label><input id="deHedef" maxlength="80" placeholder="Örnek: Asgari ücret, kıyı imarı…">`
      : k === "oyuncu" ? `<label for="deHedef">Oyuncunun kullanıcı adı</label><input id="deHedef" maxlength="20">`
      : `<label for="deHedef">Seç</label><select id="deHedef">${(k === "parti" ? partiler.map(x => [x.id, `${x.ad} (${x.kisa})`]) : k === "dernek" ? dernekler.map(x => [x.id, x.ad])
          : kanunlar.map(x => [x.id, x.baslik])).map(([v, a]) => `<option value="${v}">${e(a)}</option>`).join("") || `<option value="">— Seçenek yok —</option>`}</select>`;
  };
  $("#deKonu", m).onchange = hedefCiz; hedefCiz();
  $("#deTamam", m).onclick = async () => {
    const b = $("#deTamam", m); b.disabled = true;
    try {
      await API.rpc("dernek_eylem", { p_dernek: id, p_tur: tur, p_baslik: $("#deBaslik", m).value, p_metin: $("#deMetin", m).value,
        p_hedef_tur: $("#deKonu", m).value, p_hedef: ($("#deHedef", m) || {}).value || null,
        p_il: tur === "protesto" ? +$("#deIl", m).value : null, p_bas: tur === "protesto" ? $("#deZaman", m).value + ":00+03:00" : null });
      modalKapat(); toast(tur === "protesto" ? "Protesto duyuruldu." : "Yayımlandı."); stkDetay(id);
    } catch (err) { b.disabled = false; $("#deHata", m).textContent = hataCevir(err.message); }
  };
}
async function stkProtestoKatil(eid) {
  try { const r = await API.rpc("dernek_protesto_katil", { p_eylem: eid }); toast(`Protestodasın: ${r.katilim} kişi.`); yenidenCiz(); }
  catch (err) { toast(hataCevir(err.message), true); }
}

// Gündem: ilindeki canlı protesto "Bugün" listesine, yaklaşan/canlı protestolar ayrı bölüme
function stkGundemHtml(a) {
  const l = (a && a.protestolar) || [];
  if (!l.length) return "";
  return `<div class="bolum-bas"><h2>Sokaklar</h2><span class="kucuk">Protestolar</span></div>${l.slice(0, 5).map(x => stkEylemHtml(x)).join("")}
    <button class="btn ikinci" style="margin:0 0 12px" onclick="sekmeAc('dernek')">Dernekler</button>`;
}
