/* =====================================================================
   SİYASET MERKEZİ (2026-10-16 · sunucu modülü 102)
   Haftalık siyasi takvim, "Şu an seçim olsa" Meclis tablosu, haftanın özeti,
   canlı basın toplantısı ve tartışma programı, transferler ve rozet töreni,
   balkon konuşması ve tebrik, müşahitler, resmî günler, saha çalışması
   (stant + kapı kapı), yol arkadaşı. Mevcut ekranlara dokunmadan eklenir.
   ===================================================================== */
(function () {
  "use strict";
  const sv = d => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
  const SI = {
    takvim: sv('<rect x="3" y="4" width="18" height="17" rx="3"/><path d="M8 2v4M16 2v4M3 10h18"/>'),
    mikrofon: sv('<rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10a7 7 0 0 0 14 0M12 17v5M8 22h8"/>'),
    tv: sv('<rect x="3" y="6" width="18" height="13" rx="2"/><path d="m8 2 4 4 4-4"/>'),
    meclis: sv('<path d="M2.5 19a9.5 9.5 0 0 1 19 0"/><path d="M6.5 19a5.5 5.5 0 0 1 11 0"/><path d="M2 19h20"/>'),
    gazete: sv('<path d="M4 4h13v16H6a2 2 0 0 1-2-2z"/><path d="M17 8h3v10a2 2 0 0 1-2 2M8 8h5M8 12h5M8 16h3"/>'),
    rozet: sv('<circle cx="12" cy="9" r="6"/><path d="m8.5 14-1.5 8 5-3 5 3-1.5-8"/>'),
    balkon: sv('<path d="M3 21h18M5 21v-6h14v6M8 15v6M12 15v6M16 15v6"/><path d="M7 15V9a5 5 0 0 1 10 0v6"/>'),
    sandik: sv('<path d="M4 11h16v9H4zM8 11V4h8v7M10 7h4"/>'),
    bayrak: sv('<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>'),
    stant: sv('<path d="M4 10h16l-1.5-5h-13z"/><path d="M5 10v10M19 10v10M9 20v-6h6v6"/>'),
    kapi: sv('<path d="M6 21V4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v17M3 21h18M14 12h.01"/>'),
    el: sv('<path d="M7 11V7a2 2 0 0 1 4 0v4M11 10V5a2 2 0 0 1 4 0v6M15 10V7a2 2 0 0 1 4 0v6a7 7 0 0 1-7 7h-1a7 7 0 0 1-6-3.5l-2-3.4a1.8 1.8 0 0 1 3-1.9L7 13"/>'),
    ozet: sv('<path d="M4 5a2 2 0 0 1 2-2h12v18H6a2 2 0 0 1-2-2z"/><path d="M8 7h6M8 11h8M8 15h5"/>'),
    canli: sv('<circle cx="12" cy="12" r="3"/><path d="M6.3 6.3a8 8 0 0 0 0 11.4M17.7 6.3a8 8 0 0 1 0 11.4"/>')
  };
  const GUN_KISA = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
  const TUR_AD = { mv: "Genel seçim", cb: "Cumhurbaşkanlığı seçimi", cb2: "Cumhurbaşkanlığı 2. tur", bel: "Belediye seçimi" };
  const rpc = (fn, args) => API.rpc(fn, args);
  const kisi = k => k ? `<b>${e(k.kad)}</b>${k.unvan ? ` <span class="kucuk" style="color:var(--gold2)">${e(k.unvan)}</span>` : ""}` : "";
  const satir = (ik, bas, alt, git, cls) => `<button class="giris-satir sm-satir ${cls || ""}" onclick="${git}"><span class="yik sm-yik">${SI[ik] || SI.takvim}</span><span class="orta"><b>${bas}</b>${alt ? `<span class="kucuk">${alt}</span>` : ""}</span><span class="ok">›</span></button>`;
  const ac = fn => `ekranAc(()=>window.${fn})`;
  const partiK = p => typeof partiRozet === "function" ? partiRozet(p, true) : e(p ? p.kisa : "Bağımsız");
  const bos = m => `<div class="bos" style="padding:10px 0">${m}</div>`;
  const hata = (baslik, err) => iskelet(baslik, `<div class="bos">${e(hataCevir(err.message))}</div><button class="btn ikinci" onclick="yenidenCiz()">Tekrar dene</button>`, { geri: true });

  function stil() {
    if (document.getElementById("smStil")) return;
    const s = document.createElement("style"); s.id = "smStil";
    s.textContent = `
      .sm-yik svg{width:22px;height:22px;color:var(--ink2,#a995ff)}
      .sm-gunler{display:grid;grid-template-columns:repeat(7,1fr);gap:4px;margin:4px 0 10px}
      .sm-gun{border:1px solid var(--line2);border-radius:10px;padding:6px 0;text-align:center;font-size:12px;color:var(--mut);background:var(--panel2)}
      .sm-gun b{display:block;font-size:13px;color:var(--txt)}
      .sm-gun.bugun{border-color:var(--gold);background:color-mix(in srgb,var(--gold) 16%,var(--panel2));color:var(--txt)}
      .sm-tema{font-weight:800;font-size:15px}
      .sm-canli{display:inline-flex;align-items:center;gap:5px;color:var(--al,#e5484d);font-weight:800;font-size:12px}
      .sm-canli::before{content:"";width:8px;height:8px;border-radius:50%;background:currentColor;animation:smNabiz 1.4s infinite}
      @keyframes smNabiz{50%{opacity:.25}}
      .sm-bar{display:flex;height:22px;border-radius:8px;overflow:hidden;margin:8px 0 4px;background:var(--panel2)}
      .sm-bar i{display:block;height:100%}
      .sm-mesaj{padding:9px 0;border-bottom:1px solid var(--line2)}
      .sm-mesaj:last-child{border-bottom:0}
      .sm-mesaj .sm-rol{font-size:11px;font-weight:800;color:var(--mut);margin-right:6px}
      .sm-mesaj.soru{padding-left:10px;border-left:3px solid var(--gold)}
      .sm-mesaj.yanit{padding-left:22px}
      .sm-mesaj p{margin:4px 0 0;font-size:15px;line-height:1.45;overflow-wrap:anywhere}
      .sm-oda{max-height:52vh;overflow-y:auto}
      .sm-dugmeler{display:flex;gap:8px;flex-wrap:wrap}
      .sm-dugmeler .btn{flex:1;min-width:120px;margin:0}
      .sm-alinti{border-left:3px solid var(--gold);padding:6px 10px;margin:8px 0;font-size:15px;line-height:1.5;white-space:pre-wrap;overflow-wrap:anywhere}
      .sm-il-izgara{display:grid;grid-template-columns:repeat(auto-fill,minmax(104px,1fr));gap:6px}
      .sm-il{border-radius:8px;padding:6px 8px;font-size:13px;background:var(--panel2);border-left:4px solid var(--line2);min-width:0}
      .sm-il b{display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .sm-il span{display:block;font-size:11.5px;color:var(--mut);line-height:1.35;overflow-wrap:anywhere}
      textarea.sm-metin{width:100%;min-height:84px;resize:vertical;font:inherit;padding:10px;border-radius:10px;border:1px solid var(--line2);background:var(--panel2);color:var(--txt)}
    `;
    document.head.appendChild(s);
  }

  function metinModal(baslik, aciklama, enfazla, buton, gonder, varsayilan) {
    const m = modal(`<h3 style="font-size:19px;font-weight:800">${baslik}</h3>${aciklama ? `<p class="alt" style="margin-top:6px">${aciklama}</p>` : ""}
      <textarea class="sm-metin" id="smMetin" maxlength="${enfazla}">${e(varsayilan || "")}</textarea>
      <div class="kucuk" id="smSayac" style="text-align:right">0 / ${enfazla}</div>
      <div class="hata-metin" id="smHata"></div>
      <button class="btn altin" id="smGonder">${buton}</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    const ta = $("#smMetin", m), sayac = $("#smSayac", m);
    const say = () => { sayac.textContent = `${ta.value.length} / ${enfazla}`; };
    ta.addEventListener("input", say); say(); setTimeout(() => ta.focus(), 50);
    $("#smGonder", m).onclick = async () => {
      const b = $("#smGonder", m); b.disabled = true;
      try { await gonder(ta.value.trim()); modalKapat(); }
      catch (err) { $("#smHata", m).textContent = hataCevir(err.message); b.disabled = false; }
    };
  }

  /* ------------------------------------------------------------------ Gündem kartı */
  function gundemKarti(o, h) {
    const bg = h ? h.gun_no : 0;
    const sat = [];
    if (o.resmi_gun) sat.push(satir("bayrak", `Bugün ${e(o.resmi_gun.ad)}`, `${o.resmi_gun.mesaj} lider mesajı${o.resmi_gun.yazabilirim ? " · senin mesajın bekleniyor" : ""}`, ac("smResmiEkrani()"), o.resmi_gun.yazabilirim ? "eylem-mor" : ""));
    if (o.balkon_bekleyen) sat.push(satir("balkon", "Kazandın: balkon konuşmanı yap", "Seçim gecesinin son sözü senin", ac("smSecimEkrani()"), "acil"));
    (o.canli || []).forEach(c => sat.push(satir(c.tur === "basin" ? "mikrofon" : "tv", `<span class="sm-canli">Canlı</span> ${e(c.baslik)}`, `${c.tur === "basin" ? "Basın toplantısı" : "Tartışma programı"} · ${e(c.kad)}`, `ekranAc(()=>window.smYayinEkrani(${c.id}))`)));
    if (o.davet) sat.push(satir("tv", `${o.davet} program daveti`, "Tartışma programına konuk olarak çağrıldın", ac("smYayinlarEkrani()"), "eylem-mor"));
    if (o.yaklasan) sat.push(satir("tv", e(o.yaklasan.baslik), `${e(o.yaklasan.gazete || "")} · ${tarihSaat(o.yaklasan.bas)}`, `ekranAc(()=>window.smYayinEkrani(${o.yaklasan.id}))`));
    if (o.balkon) sat.push(satir("balkon", `Balkon konuşması: ${e(o.balkon.kad)}`, `"${e(o.balkon.metin)}"`, ac("smSecimEkrani()")));
    if (o.musahit && (o.musahit.sandik_acik || o.musahit.tutanak_acik)) sat.push(satir("sandik", o.musahit.sandik_acik ? "Sandık başına geç" : "Müşahit tutanağını yaz", `${e(o.musahit.il)} müşahitliği`, ac("smSecimEkrani()"), "acil"));
    (o.transfer || []).slice(0, 2).forEach(t => sat.push(satir("rozet", `Transfer: ${e(t.kad)}`, `${e(t.eski ? t.eski.kisa : "Bağımsız")} → ${e(t.yeni ? t.yeni.kisa : "Bağımsız")}`, ac("smTransferEkrani()"))));
    if (o.stant) sat.push(satir("stant", `İlinde ${o.stant} seçim standı açık`, "Uğra, soru sor", ac("smSahaEkrani()")));
    if (o.mentor_oneri) sat.push(satir("el", "Bir yol arkadaşı seç", "Deneyimli bir oyuncu sana eşlik etsin; ilk oyunda ikiniz de ödül alırsınız", ac("smMentorEkrani()"), "eylem-mor"));
    if (o.ozet_hazir) sat.push(satir("ozet", "Haftanın özeti yayımlandı", "Kanunlar, transferler, mitingler ve anket", `ekranAc(()=>window.smOzetEkrani('${e(o.ozet_hazir)}'))`));
    return `<div class="kart sm-gundem"><div class="gece-bas" style="display:flex;justify-content:space-between;align-items:center"><h2 style="margin:0">Siyasi hafta</h2>
        <button class="kucuk" style="color:var(--ink2);font-weight:700;background:none;border:0" onclick="${ac("smEkrani()")}">Siyaset Merkezi ›</button></div>
      ${h ? `<div class="sm-gunler">${GUN_KISA.map((g, i) => `<div class="sm-gun ${i + 1 === bg ? "bugun" : ""}"><b>${g}</b>${new Date(h.gunler[i].tarih + "T12:00:00").getDate()}</div>`).join("")}</div>` : ""}
      <div class="sm-tema">${e(o.tema.ad)}</div><div class="kucuk" style="margin-bottom:6px">${e(o.tema.alt)}</div>
      ${sat.join("")}</div>`;
  }

  async function gundemEkle() {
    try {
      const [o, h] = await Promise.all([rpc("siyaset_merkezi_ozet"), rpc("siyasi_hafta").catch(() => null)]);
      const ic = $("#icerik");
      if (!ic || D.sekme !== "gundem" || D.yigin.length || ic.querySelector(".sm-gundem")) return;
      stil();
      const hedef = ic.querySelector(".bolum-bas");
      const html = gundemKarti(o, h);
      if (hedef) hedef.insertAdjacentHTML("beforebegin", html); else ic.insertAdjacentHTML("beforeend", html);
    } catch (_) { /* sunucu modülü kurulmadıysa sessizce geç */ }
  }
  if (typeof gundemEkrani === "function") {
    const eski = gundemEkrani;
    window.gundemEkrani = gundemEkrani = async function () { const r = await eski.apply(this, arguments); await gundemEkle(); return r; };
    if (typeof EKRAN === "object" && EKRAN) EKRAN.gundem = () => gundemEkrani();
  }

  /* ------------------------------------------------------------------ Ana ekran */
  window.smEkrani = async function () {
    stil();
    yukleniyor("Siyaset Merkezi");
    let o; try { o = await rpc("siyaset_merkezi_ozet"); } catch (err) { return hata("Siyaset Merkezi", err); }
    iskelet("Siyaset Merkezi", `
      <div class="kart"><div class="sm-tema">Bugün: ${e(o.tema.ad)}</div><p class="alt">${e(o.tema.alt)}</p></div>
      <div class="bolum-bas"><h2>Haftanın ritmi</h2></div><div class="kart">
        ${satir("takvim", "Siyasi takvim", "Haftanın her gününün bir siyasi teması var", ac("smHaftaEkrani()"))}
        ${satir("meclis", "Şu an seçim olsa", "Haftalık anketten il il Meclis tablosu", ac("smProjeksiyonEkrani()"))}
        ${satir("ozet", "Haftanın özeti", "Her pazar 20.00'de yayımlanır", ac("smOzetEkrani()"))}</div>
      <div class="bolum-bas"><h2>Medya</h2></div><div class="kart">
        ${satir("mikrofon", "Canlı yayınlar", `Basın toplantıları ve tartışma programları${(o.canli || []).length ? ` · <span class="sm-canli">${o.canli.length} canlı</span>` : ""}`, ac("smYayinlarEkrani()"))}
        ${satir("rozet", "Transferler", "Parti değiştiren siyasetçiler ve rozet törenleri", ac("smTransferEkrani()"))}</div>
      <div class="bolum-bas"><h2>Seçim ve devlet</h2></div><div class="kart">
        ${satir("sandik", "Müşahitler, balkon ve tebrik", "Sandık görevlileri, zafer konuşmaları", ac("smSecimEkrani()"))}
        ${satir("bayrak", "Resmî günler", o.resmi_gun ? `Bugün ${e(o.resmi_gun.ad)}` : "Bayram ve anma günü mesajları", ac("smResmiEkrani()"))}</div>
      <div class="bolum-bas"><h2>Saha ve topluluk</h2></div><div class="kart">
        ${satir("stant", "Saha çalışması", "Seçim standları ve kapı kapı ziyaret", ac("smSahaEkrani()"))}
        ${satir("el", "Yol arkadaşı", "Yeni oyunculara deneyimli oyuncu eşliği", ac("smMentorEkrani()"))}</div>`, { geri: true });
  };

  /* ------------------------------------------------------------------ Takvim */
  window.smHaftaEkrani = async function () {
    stil(); yukleniyor("Siyasi takvim");
    let h; try { h = await rpc("siyasi_hafta"); } catch (err) { return hata("Siyasi takvim", err); }
    const s = h.sayilar || {};
    const ek = { meclis: `${s.oylamada || 0} teklif oylamada`, yayin: `Bu hafta ${s.yayin || 0} canlı yayın`, projeksiyon: `Bu hafta ${s.anket || 0} oyuncu ankete katıldı`,
      saha: `Bu hafta ${s.stant || 0} stant, ${s.miting || 0} miting`, ozet: `Bu hafta ${s.transfer || 0} transfer` };
    const git = { meclis: "sekmeAc('meclis')", yayin: ac("smYayinlarEkrani()"), parti: "sekmeAc('parti')", projeksiyon: ac("smProjeksiyonEkrani()"), saha: ac("smSahaEkrani()"), ozet: ac("smOzetEkrani()") };
    iskelet("Siyasi takvim", `
      ${h.resmi_gun ? `<div class="kart"><b>Bugün ${e(h.resmi_gun.ad)}</b><p class="alt">${e(h.resmi_gun.aciklama || "")}</p></div>` : ""}
      <div class="kart">${h.gunler.map(g => `<button class="giris-satir sm-satir" onclick="${git[g.ekran] || ""}" ${g.bugun ? 'style="border-left:3px solid var(--gold);padding-left:8px"' : ""}>
        <span class="orta"><b>${e(g.gun)} · ${e(g.ad)}${g.bugun ? ' <span class="rozet altin">Bugün</span>' : ""}</b><span class="kucuk">${e(g.alt)}${ek[g.ekran] ? " · " + e(ek[g.ekran]) : ""}</span></span><span class="ok">›</span></button>`).join("")}</div>
      ${h.yaklasan_resmi ? `<p class="kucuk">Sıradaki resmî gün: ${e(h.yaklasan_resmi.ad)} · ${tarih(h.yaklasan_resmi.tarih + "T12:00:00")}</p>` : ""}
      <p class="kucuk">Takvim bir öneridir: kanun teklifi, oylama ve miting her gün yapılabilir. Temanın günü geldiğinde ilgili kişilere hatırlatma gider.</p>`, { geri: true });
  };

  /* ------------------------------------------------------------------ Projeksiyon */
  window.smProjeksiyonEkrani = async function () {
    stil(); yukleniyor("Şu an seçim olsa");
    let p; try { p = await rpc("meclis_projeksiyon"); } catch (err) { return hata("Şu an seçim olsa", err); }
    const ps = (p.partiler || []).filter(x => x.sandalye > 0);
    iskelet("Şu an seçim olsa", `
      <div class="kart"><h2>Meclis tablosu</h2>
        <p class="alt">${p.toplam ? `${tarih(p.hafta + "T12:00:00")} haftası anketi · ${p.toplam} katılımcı · baraj %${String(p.baraj).replace(".", ",")}` : ""}</p>
        ${p.uyari ? `<p class="kucuk" style="color:var(--gold2)">${e(p.uyari)}</p>` : ""}
        ${ps.length ? `<div class="sm-bar" role="img" aria-label="Sandalye dağılımı">${ps.map(x => `<i style="width:${x.sandalye / 6}%;background:${e(x.parti.renk)}" title="${e(x.parti.kisa)} ${x.sandalye}"></i>`).join("")}</div>
          <div class="kucuk" style="display:flex;justify-content:space-between"><span>0</span><span>Salt çoğunluk 301</span><span>600</span></div>` : ""}
        ${(p.partiler || []).map(x => `<div class="kv"><span class="k">${partiK(x.parti)}</span><span class="v"><b>${x.sandalye}</b> sandalye · %${String(x.yuzde).replace(".", ",")}${x.baraj_ustu ? "" : ' <span class="rozet">baraj altı</span>'}</span></div>`).join("") || bos("Henüz veri yok.")}
        <button class="btn altin" style="margin-top:10px" onclick="sekmeAc('gundem')">Ankette oyunu ver</button></div>
      ${ps.length ? `<div class="bolum-bas"><h2>İllerde birinci parti</h2></div><div class="kart"><div class="sm-il-izgara">${(p.iller || []).map(i =>
        `<div class="sm-il" style="border-left-color:${e(i.birinci ? i.birinci.renk : "var(--line2)")}" ><b>${e(i.il)} <span style="display:inline;color:var(--mut);font-weight:400">${i.mv}</span></b><span>${e(i.dagilim.map(d => d.kisa + " " + d.s).join(" · "))}</span></div>`).join("")}</div></div>` : ""}
      <p class="kucuk">${e(p.aciklama || "")} Bu tablo yalnızca bir kamuoyu tahminidir; gerçek sonuç sandıkta belli olur.</p>`, { geri: true });
  };

  /* ------------------------------------------------------------------ Haftanın özeti */
  window.smOzetEkrani = async function (hafta) {
    stil(); yukleniyor("Haftanın özeti");
    let o; try { o = await rpc("haftanin_ozeti", { p_hafta: hafta || null }); } catch (err) { return hata("Haftanın özeti", err); }
    const v = o.veri || {};
    const kanun = v.kanunlar || { sayi: 0, liste: [] };
    iskelet("Haftanın özeti", `
      <div class="kart"><h2>${tarih(o.hafta + "T12:00:00")} haftası</h2><p class="alt">${o.kesin ? "Pazar 20.00'de yayımlandı." : "Hafta sürüyor; tablo anlık hesaplanıyor."}</p>
        <div class="kv"><span class="k">Yeni kanun</span><span class="v">${kanun.sayi}</span></div>
        <div class="kv"><span class="k">Transfer</span><span class="v">${(v.transferler || []).length}</span></div>
        <div class="kv"><span class="k">Miting</span><span class="v">${(v.miting || {}).sayi || 0}</span></div>
        <div class="kv"><span class="k">Canlı yayın</span><span class="v">${(v.yayinlar || {}).sayi || 0}</span></div>
        <div class="kv"><span class="k">Stant · kapı ziyareti</span><span class="v">${(v.saha || {}).stant || 0} · ${(v.saha || {}).kapi || 0}</span></div>
        <div class="kv"><span class="k">Yeni vatandaş</span><span class="v">${v.yeni_oyuncu || 0}</span></div></div>
      ${kanun.liste.length ? `<div class="kart"><h2>Yasalaşanlar</h2>${kanun.liste.map(k => `<div class="kv"><span class="k">${e(k.no)} sayılı</span><span class="v">${e(k.baslik)}</span></div>`).join("")}</div>` : ""}
      ${(v.transferler || []).length ? `<div class="kart"><h2>Transferler</h2>${v.transferler.map(t => `<div class="kv"><span class="k">${e(t.kad)}</span><span class="v">${e(t.eski ? t.eski.kisa : "Bağımsız")} → ${e(t.yeni ? t.yeni.kisa : "Bağımsız")}</span></div>`).join("")}</div>` : ""}
      ${(v.anket || []).length ? `<div class="kart"><h2>Anketin ilk sıraları</h2>${v.anket.map(a => `<div class="kv"><span class="k">${partiK(a.parti)}</span><span class="v">${a.oy} oy</span></div>`).join("")}</div>` : ""}
      ${(v.miting || {}).en_kalabalik ? `<div class="kart"><h2>En kalabalık miting</h2><p>${e(v.miting.en_kalabalik.kad)} · ${e(v.miting.en_kalabalik.il)} · ${v.miting.en_kalabalik.kisi} kişi</p></div>` : ""}
      ${v.one_cikan ? `<div class="kart"><h2>Haftanın paylaşımı</h2><div class="sm-alinti">${e(v.one_cikan.metin)}</div><div class="kucuk">${e(v.one_cikan.kad)} · ${v.one_cikan.begeni} beğeni</div></div>` : ""}
      ${(v.yeni_partiler || []).length ? `<div class="kart"><h2>Yeni partiler</h2>${v.yeni_partiler.map(p => `<div style="padding:4px 0">${partiK(p)}</div>`).join("")}</div>` : ""}
      ${(o.arsiv || []).length ? `<div class="bolum-bas"><h2>Arşiv</h2></div><div class="kart">${o.arsiv.map(h => `<button class="giris-satir sm-satir" onclick="ekranAc(()=>window.smOzetEkrani('${e(h)}'))"><span class="orta"><b>${tarih(h + "T12:00:00")} haftası</b></span><span class="ok">›</span></button>`).join("")}</div>` : ""}`, { geri: true });
  };

  /* ------------------------------------------------------------------ Canlı yayınlar */
  const yayinSatir = c => `<button class="giris-satir sm-satir" onclick="ekranAc(()=>window.smYayinEkrani(${c.id}))"><span class="yik sm-yik">${c.tur === "basin" ? SI.mikrofon : SI.tv}</span>
    <span class="orta"><b>${c.durum === "canli" ? '<span class="sm-canli">Canlı</span> ' : ""}${e(c.baslik)}</b>
    <span class="kucuk">${c.tur === "basin" ? "Basın toplantısı" : "Program · " + e(c.gazete ? c.gazete.ad : "")} · ${e(c.sahibi ? c.sahibi.kad : "")} · ${c.durum === "yakinda" ? tarihSaat(c.bas) : c.durum === "canli" ? "bitiş " + saatYaz(c.bit) : tarih(c.bit)}${c.konuklar.length ? " · " + c.konuklar.filter(k => k.durum === "kabul").map(k => e(k.kad)).join(", ") : ""}</span></span><span class="ok">›</span></button>`;

  window.smYayinlarEkrani = async function () {
    stil(); yukleniyor("Canlı yayınlar");
    let l; try { l = await rpc("canli_yayinlar"); } catch (err) { return hata("Canlı yayınlar", err); }
    iskelet("Canlı yayınlar", `
      ${(l.davetlerim || []).length ? `<div class="kart"><h2>Program davetlerin</h2>${l.davetlerim.map(c => `<div style="padding:6px 0"><b>${e(c.baslik)}</b><div class="kucuk">${e(c.gazete ? c.gazete.ad : "")} · ${tarihSaat(c.bas)}</div>
        <div class="sm-dugmeler" style="margin-top:6px"><button class="btn altin" onclick="window.smDavetYanit(${c.id},true)">Katılıyorum</button><button class="btn ikinci" onclick="window.smDavetYanit(${c.id},false)">Katılamam</button></div></div>`).join("")}</div>` : ""}
      ${l.basin_hakki || (l.gazetelerim || []).length ? `<div class="kart"><h2>Yayın düzenle</h2>
        ${l.basin_hakki ? `<button class="btn altin" onclick="window.smBasinAc()">Basın toplantısı yap (30 dk)</button>` : ""}
        ${(l.gazetelerim || []).length ? `<button class="btn ${l.basin_hakki ? "ikinci" : "altin"}" onclick="window.smProgramAc()">Tartışma programı planla (45 dk)</button>` : ""}
        <p class="kucuk">Basın toplantısında gazeteciler (gazete sahipleri ve yazarları) en fazla 2 soru sorar. Programda yalnız moderatör ve konuklar konuşur, izleyiciler en ikna edici konuğu seçer.</p></div>`
        : `<div class="kart"><p class="alt">Basın toplantısını makam sahipleri ve parti yöneticileri, tartışma programını gazete sahipleri düzenler. Herkes izleyip tepki verebilir.</p></div>`}
      <div class="bolum-bas"><h2>Şimdi yayında</h2></div><div class="kart">${(l.canli || []).map(yayinSatir).join("") || bos("Şu an canlı yayın yok.")}</div>
      ${(l.yakinda || []).length ? `<div class="bolum-bas"><h2>Yakında</h2></div><div class="kart">${l.yakinda.map(yayinSatir).join("")}</div>` : ""}
      <div class="bolum-bas"><h2>Son yayınlar</h2></div><div class="kart">${(l.biten || []).map(yayinSatir).join("") || bos("Henüz yayın yapılmadı.")}</div>`, { geri: true });
  };
  window.smDavetYanit = async (id, kabul) => { try { await islem(() => rpc("canli_yayin_davet_yanit", { p_yayin: id, p_kabul: kabul }), kabul ? "Davet kabul edildi" : "Davet reddedildi"); yenidenCiz(); } catch (_) {} };
  window.smBasinAc = () => {
    const m = modal(`<h3 style="font-size:19px;font-weight:800">Basın toplantısı</h3><p class="alt">Hemen başlar, 30 dakika sürer. Gazetecilere ve parti üyelerine haber gider. Günde bir kez.</p>
      <div class="alan"><label for="smBb">Konu</label><input id="smBb" maxlength="90" placeholder="Örneğin: Asgari ücret açıklaması"></div><div class="hata-metin" id="smH"></div>
      <button class="btn altin" id="smG">Kürsüye çık</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    $("#smG", m).onclick = async () => {
      try { const c = await rpc("canli_yayin_ac", { p_tur: "basin", p_baslik: $("#smBb", m).value.trim(), p_bas: null, p_gazete: null }); modalKapat(); ekranAc(() => window.smYayinEkrani(c.id)); }
      catch (err) { $("#smH", m).textContent = hataCevir(err.message); }
    };
  };
  window.smProgramAc = () => {
    const now = new Date(simdi() + 30 * 60e3); now.setSeconds(0, 0);
    const yerel = new Date(now.getTime() - now.getTimezoneOffset() * 60e3).toISOString().slice(0, 16);
    const m = modal(`<h3 style="font-size:19px;font-weight:800">Tartışma programı</h3><p class="alt">45 dakika sürer. Oluşturduktan sonra 2–4 konuk davet et. Abonelerine başladığında haber gider.</p>
      <div class="alan"><label for="smPb">Program konusu</label><input id="smPb" maxlength="90" placeholder="Örneğin: Ekonomi masası"></div>
      <div class="alan"><label for="smPt">Başlangıç</label><input id="smPt" type="datetime-local" value="${yerel}"></div><div class="hata-metin" id="smH"></div>
      <button class="btn altin" id="smG">Programı planla</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    $("#smG", m).onclick = async () => {
      const v = $("#smPt", m).value;
      try { const c = await rpc("canli_yayin_ac", { p_tur: "program", p_baslik: $("#smPb", m).value.trim(), p_bas: v ? new Date(v).toISOString() : null, p_gazete: null }); modalKapat(); ekranAc(() => window.smYayinEkrani(c.id)); }
      catch (err) { $("#smH", m).textContent = hataCevir(err.message); }
    };
  };

  /* ------------------------------------------------------------------ Yayın odası */
  const ROL = { konusmaci: "Kürsü", moderator: "Moderatör", konuk: "Konuk", soru: "Gazeteci" };
  function mesajHtml(m, hepsi) {
    const ust = m.yanit_id ? hepsi.find(x => x.id === m.yanit_id) : null;
    return `<div class="sm-mesaj ${m.rol === "soru" ? "soru" : ""} ${ust ? "yanit" : ""}"><span class="sm-rol">${ROL[m.rol] || ""}</span>${kisi(m.kisi)} <span class="kucuk">${saatYaz(m.zaman)}</span>
      ${ust ? `<div class="kucuk">↳ ${e(ust.kisi ? ust.kisi.kad : "")}: "${e(ust.metin.slice(0, 60))}"</div>` : ""}<p>${e(m.metin)}</p>
      ${m.rol === "soru" && D._smRol === "sahip" && D._smCanli ? `<button class="kucuk" style="background:none;border:0;color:var(--ink2);font-weight:700;padding:4px 0" onclick="window.smYanitla(${m.id})">Yanıtla</button>` : ""}</div>`;
  }
  window.smYayinEkrani = async function (id) {
    stil();
    if (!D._smOda || D._smOda.id !== id) yukleniyor("Canlı yayın");
    let d; try { d = await rpc("canli_yayin_detay", { p_yayin: id, p_son_id: 0 }); } catch (err) { return hata("Canlı yayın", err); }
    D._smOda = { id, yanit: null }; D._smRol = d.rolum; D._smCanli = d.durum === "canli";
    const yazabilir = d.durum === "canli" && (["sahip", "konuk"].includes(d.rolum) || (d.rolum === "gazeteci" && d.sorum < 2));
    const kabul = d.konuklar.filter(k => k.durum === "kabul");
    const oylanir = d.tur === "program" && ["canli", "bitti"].includes(d.durum) && !["sahip", "konuk"].includes(d.rolum) && kabul.length
      && simdi() < new Date(d.bit).getTime() + 15 * 60e3;
    const tepkiAcik = d.rolum !== "sahip" && ["canli", "bitti"].includes(d.durum) && simdi() < new Date(d.bit).getTime() + 15 * 60e3;
    iskelet(d.tur === "basin" ? "Basın toplantısı" : "Tartışma programı", `
      <div class="kart"><h2>${d.durum === "canli" ? '<span class="sm-canli">Canlı</span> ' : ""}${e(d.baslik)}</h2>
        <p class="alt">${d.tur === "basin" ? kisi(d.sahibi) : `${e(d.gazete ? d.gazete.ad : "")} · moderatör ${kisi(d.sahibi)}`}</p>
        <p class="kucuk">${d.durum === "yakinda" ? "Başlangıç " + tarihSaat(d.bas) : d.durum === "canli" ? "Bitiş " + saatYaz(d.bit) : d.durum === "iptal" ? "İptal edildi" : "Yayın sona erdi · " + tarihSaat(d.bit)} · ${d.alkis} alkış · ${d.yuh} yuh</p>
        ${d.konuklar.length ? `<div class="kucuk" style="margin-top:4px">Konuklar: ${d.konuklar.map(k => `${e(k.kad)}${k.durum === "kabul" ? "" : k.durum === "davet" ? " (davetli)" : " (katılmıyor)"}${d.tur === "program" && k.durum === "kabul" ? ` · ${k.oy} oy` : ""}`).join(" · ")}</div>` : ""}</div>
      ${d.rolum === "davetli" ? `<div class="kart"><b>Bu programa davetlisin.</b><div class="sm-dugmeler" style="margin-top:8px"><button class="btn altin" onclick="window.smDavetYanit(${d.id},true)">Katılıyorum</button><button class="btn ikinci" onclick="window.smDavetYanit(${d.id},false)">Katılamam</button></div></div>` : ""}
      <div class="kart"><div class="sm-oda" id="smOda">${d.mesajlar.map(m => mesajHtml(m, d.mesajlar)).join("") || bos(d.durum === "yakinda" ? "Yayın başlamadı." : "Henüz söz alınmadı.")}</div></div>
      ${yazabilir ? `<div class="kart"><div id="smYanitBilgi" class="kucuk"></div><textarea class="sm-metin" id="smYaz" maxlength="400" placeholder="${d.rolum === "gazeteci" ? `Sorunu yaz (kalan hak: ${2 - d.sorum})` : "Söz al…"}"></textarea>
        <button class="btn altin" id="smYazB">${d.rolum === "gazeteci" ? "Soruyu sor" : "Gönder"}</button></div>` : ""}
      ${tepkiAcik ? `<div class="sm-dugmeler" style="margin-bottom:10px"><button class="btn ${d.tepkim === "alkis" ? "altin" : "ikinci"}" onclick="window.smTepki(${d.id},'alkis')">Alkışla</button><button class="btn ${d.tepkim === "yuh" ? "tehlike" : "ikinci"}" onclick="window.smTepki(${d.id},'yuh')">Yuhala</button></div>` : ""}
      ${oylanir ? `<div class="kart"><h2>En ikna edici kim?</h2>${kabul.map(k => `<button class="btn ${d.oyum === k.kad ? "altin" : "ikinci"}" onclick="window.smOyla(${d.id},'${e(k.kad)}')">${e(k.kad)} · ${k.oy} oy</button>`).join("")}<p class="kucuk">Oylama program bittikten 15 dakika sonra kapanır.</p></div>` : ""}
      ${d.rolum === "sahip" && d.tur === "program" && d.durum !== "bitti" && d.durum !== "iptal" ? `<div class="kart"><h2>Konuk davet et</h2><div class="alan"><input id="smKonuk" placeholder="Kullanıcı adı" autocapitalize="off"></div><button class="btn ikinci" onclick="window.smKonukDavet(${d.id})">Davet gönder</button></div>` : ""}
      ${d.rolum === "sahip" && ["canli", "yakinda"].includes(d.durum) ? `<button class="btn tehlike" onclick="window.smBitir(${d.id})">${d.durum === "yakinda" ? "Programı iptal et" : "Yayını bitir"}</button>` : ""}`, { geri: true });
    const oda = $("#smOda"); if (oda) oda.scrollTop = oda.scrollHeight;
    const b = $("#smYazB");
    if (b) b.onclick = async () => {
      const ta = $("#smYaz"); const v = ta.value.trim(); if (!v) return;
      b.disabled = true;
      try { await rpc("canli_yayin_yaz", { p_yayin: id, p_metin: v, p_yanit: D._smOda.yanit }); ta.value = ""; D._smOda.yanit = null; await window.smYayinEkrani(id); }
      catch (err) { toast(hataCevir(err.message), true); b.disabled = false; }
    };
    if (d.durum === "canli" || d.durum === "yakinda") {
      D.canli = setInterval(async () => {
        if (!document.getElementById("smOda") || document.hidden || $("#modal")) return;
        const ta = $("#smYaz"); if (ta && ta.value.trim()) return;   // yazarken ekranı yenileme
        try { const y = await rpc("canli_yayin_detay", { p_yayin: id, p_son_id: 0 });
          if (y.durum !== d.durum || y.mesajlar.length !== d.mesajlar.length || y.alkis !== d.alkis || y.yuh !== d.yuh) window.smYayinEkrani(id); } catch (_) {}
      }, 5000);
    }
  };
  window.smYanitla = mid => { D._smOda.yanit = mid; const b = $("#smYanitBilgi"); if (b) b.textContent = "Seçilen soruyu yanıtlıyorsun."; const t = $("#smYaz"); if (t) t.focus(); };
  window.smTepki = async (id, tur) => { try { await islem(() => rpc("canli_yayin_tepki", { p_yayin: id, p_tur: tur })); window.smYayinEkrani(id); } catch (_) {} };
  window.smOyla = async (id, kad) => { try { await islem(() => rpc("canli_yayin_oyla", { p_yayin: id, p_kad: kad }), "Oyun kaydedildi"); window.smYayinEkrani(id); } catch (_) {} };
  window.smKonukDavet = async id => { const k = ($("#smKonuk") || {}).value; if (!k) return; try { await islem(() => rpc("canli_yayin_davet", { p_yayin: id, p_kad: k.trim() }), "Davet gönderildi"); window.smYayinEkrani(id); } catch (_) {} };
  window.smBitir = async id => { if (!await onayla("Yayını bitir", "Yayın şimdi sona erecek.", "Bitir", true)) return; try { await islem(() => rpc("canli_yayin_bitir", { p_yayin: id })); window.smYayinEkrani(id); } catch (_) {} };

  /* ------------------------------------------------------------------ Transferler */
  window.smTransferEkrani = async function () {
    stil(); yukleniyor("Transferler");
    let l; try { l = await rpc("parti_gecisleri", { p_limit: 40 }); } catch (err) { return hata("Transferler", err); }
    iskelet("Transferler", `<div class="kart"><p class="alt">Makam sahibi ya da kıdemli siyasetçilerin parti değiştirmesi herkese duyurulur. Yeni partinin genel başkanı ya da yardımcısı 72 saat içinde rozet takabilir.</p></div>
      <div class="kart">${l.map(t => `<div class="sm-mesaj"><div>${e(t.kad)}${t.unvan ? ` <span class="kucuk" style="color:var(--gold2)">${e(t.unvan)}</span>` : ""} <span class="kucuk">${tarihSaat(t.zaman)}</span></div>
        <div style="margin-top:4px">${partiK(t.eski)} <span class="kucuk">→</span> ${partiK(t.yeni)}</div>
        ${t.makam ? `<div class="kucuk">${e(t.makam)}</div>` : ""}
        ${t.rozet_at ? `<div class="kucuk" style="margin-top:4px">Rozetini ${e(t.rozet_takan)} taktı${t.rozet_mesaj ? `: "${e(t.rozet_mesaj)}"` : ""}</div>` : ""}
        ${t.rozet_takabilirim ? `<button class="btn altin" style="margin-top:8px" onclick="window.smRozetTak(${t.id},'${e(t.kad)}')">Rozetini tak</button>` : ""}</div>`).join("") || bos("Henüz transfer yok.")}</div>`, { geri: true });
  };
  window.smRozetTak = (id, kad) => metinModal(`${e(kad)}'e rozet tak`, "İstersen bir hoş geldin mesajı ekle. Tören Akış'ta paylaşılır.", 200, "Rozeti tak",
    async v => { await rpc("rozet_tak", { p_gecis: id, p_mesaj: v || null }); toast("Rozet takıldı"); yenidenCiz(); });

  /* ------------------------------------------------------------------ Seçim: balkon, tebrik, müşahit */
  window.smSecimEkrani = async function () {
    stil(); yukleniyor("Seçim sonrası ve sandık");
    let b, m; try { [b, m] = await Promise.all([rpc("balkon_durum"), rpc("musahit_paneli")]); } catch (err) { return hata("Seçim sonrası ve sandık", err); }
    const iller = [...VERI.iller].sort((x, y) => x.ad.localeCompare(y.ad, "tr"));
    iskelet("Seçim sonrası ve sandık", `
      ${b.map(s => `<div class="kart"><h2>${e(TUR_AD[s.tur] || s.tur)} · ${e(s.donem || "")}</h2><p class="alt">Kazanan: ${kisi(s.kazanan)}</p>
        ${s.konusma ? `<div class="kucuk" style="margin-top:6px">Balkon konuşması</div><div class="sm-alinti">${e(s.konusma.metin)}</div>`
          : s.benim ? `<button class="btn altin" onclick="window.smBalkon(${s.secim_id})">Balkon konuşmanı yap</button>` : `<p class="kucuk">Balkon konuşması bekleniyor.</p>`}
        ${s.tebrikler.length ? `<div class="kucuk" style="margin-top:8px">Tebrikler</div>${s.tebrikler.map(t => `<div class="sm-mesaj">${kisi(t)}<p>${e(t.metin)}</p></div>`).join("")}` : ""}
        ${s.tebrik_edebilirim ? `<button class="btn ikinci" onclick="window.smTebrik(${s.secim_id})">Tebrik et</button>` : ""}</div>`).join("")}
      ${(m.gorevlerim || []).length ? `<div class="bolum-bas"><h2>Müşahitlik görevlerin</h2></div><div class="kart">${m.gorevlerim.map(g => `<div class="sm-mesaj"><b>${e(TUR_AD[g.tur] || g.tur)} · ${e(g.il)}</b>
        <div class="kucuk">Oy saatleri ${tarihSaat(g.oy_bas)} – ${saatYaz(g.oy_bit)}${g.sandik_at ? " · sandık başındasın" : ""}${g.tutanak ? " · tutanak: " + (g.tutanak === "temiz" ? "temiz" : "itiraz") : ""}</div>
        ${g.sandik_acik ? `<button class="btn altin" style="margin-top:8px" onclick="window.smSandik(${g.secim_id})">Sandık başına geç</button>` : ""}
        ${g.tutanak_acik ? `<div class="sm-dugmeler" style="margin-top:8px"><button class="btn altin" onclick="window.smTutanak(${g.secim_id},'temiz')">Sayım temiz</button><button class="btn tehlike" onclick="window.smTutanak(${g.secim_id},'itiraz')">İtiraz tutanağı</button></div>` : ""}</div>`).join("")}</div>` : ""}
      <div class="bolum-bas"><h2>Müşahitler</h2></div>
      ${(m.secimler || []).filter(s => s.durum === "bekliyor").map(s => `<div class="kart"><h2>${e(TUR_AD[s.tur] || s.tur)}</h2><p class="kucuk">Oy: ${tarihSaat(s.oy_bas)} – ${tarihSaat(s.oy_bit)}</p>
        ${s.kapsama.length ? `<div class="kucuk" style="margin:6px 0">Kapsama: ${s.kapsama.map(k => `${e(k.parti ? k.parti.kisa : "")} ${k.il} il`).join(" · ")}</div>` : ""}
        ${m.parti ? `${s.atananlar.map(a => `<div class="kv"><span class="k">${e(a.il)}</span><span class="v">${e(a.kad)}${m.yonetici && !a.sandik ? ` <button class="kucuk" style="background:none;border:0;color:var(--al);font-weight:700" onclick="window.smMusahitKaldir(${s.id},${a.il_id})">kaldır</button>` : ""}</span></div>`).join("") || bos("Partin bu seçimde henüz müşahit atamadı.")}` : ""}
        ${m.yonetici ? `<div class="oa-grid" style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px">
          <div class="alan"><label>İl</label><select id="smIl${s.id}" onchange="window.smUyeFiltre(${s.id})">${iller.map(i => `<option value="${i.id}">${e(i.ad)}</option>`).join("")}</select></div>
          <div class="alan"><label>Üye</label><select id="smUye${s.id}"></select></div></div>
          <button class="btn ikinci" onclick="window.smMusahitAta(${s.id})">Müşahit ata</button>` : ""}</div>`).join("") || `<div class="kart">${bos("Yaklaşan seçim yok.")}</div>`}
      <p class="kucuk">Müşahitleri genel başkan ya da teşkilattan sorumlu yardımcı atar; müşahit görev yapacağı ilde yaşayan bir parti üyesidir ve o seçimde aday olamaz. Oy saatlerinde sandık başına geçer (kıdem +1, Sandık Görevlisi rozeti), sonuçlardan sonra 48 saat içinde tutanak yazar. İtiraz tutanakları genel başkana gider; resmî itiraz Adliye'den açılır.</p>`, { geri: true });
    D._smUyeler = m.adaylar || [];
    (m.secimler || []).forEach(s => { const sel = $("#smIl" + s.id); if (sel) { const pp = D.durum && D.durum.profil; if (pp && pp.il_id) sel.value = pp.il_id; window.smUyeFiltre(s.id); } });
  };
  window.smUyeFiltre = sid => {
    const il = +($("#smIl" + sid) || {}).value, u = $("#smUye" + sid); if (!u) return;
    const l = (D._smUyeler || []).filter(x => x.il_id === il);
    u.innerHTML = l.map(x => `<option>${e(x.kad)}</option>`).join("") || `<option value="">Bu ilde üye yok</option>`;
  };
  window.smMusahitAta = async sid => {
    const il = +$("#smIl" + sid).value, kad = $("#smUye" + sid).value; if (!kad) return toast("Bu ilde yaşayan bir üye seç.", true);
    try { await islem(() => rpc("musahit_ata", { p_secim: sid, p_il: il, p_kad: kad }), "Müşahit atandı"); yenidenCiz(); } catch (_) {}
  };
  window.smMusahitKaldir = async (sid, il) => { try { await islem(() => rpc("musahit_kaldir", { p_secim: sid, p_il: il }), "Müşahit kaldırıldı"); yenidenCiz(); } catch (_) {} };
  window.smSandik = async sid => { try { await islem(() => rpc("musahit_sandik", { p_secim: sid }), "Sandık başındasın"); yenidenCiz(); } catch (_) {} };
  window.smTutanak = (sid, tur) => tur === "temiz"
    ? (async () => { try { await islem(() => rpc("musahit_tutanak", { p_secim: sid, p_tur: "temiz", p_metin: null }), "Tutanak kaydedildi"); yenidenCiz(); } catch (_) {} })()
    : metinModal("İtiraz tutanağı", "Gördüğün usulsüzlüğü açıkça yaz. Tutanak genel başkanına gider.", 500, "Tutanağı gönder",
        async v => { await rpc("musahit_tutanak", { p_secim: sid, p_tur: "itiraz", p_metin: v }); toast("Tutanak gönderildi"); yenidenCiz(); });
  window.smBalkon = sid => metinModal("Balkon konuşması", "Zafer konuşman herkese bildirim olarak gider ve Gündem'de yayımlanır. Bir kez yapılır.", 1200, "Balkona çık",
    async v => { await rpc("balkon_konus", { p_secim: sid, p_metin: v }); toast("Konuşman yayımlandı"); yenidenCiz(); });
  window.smTebrik = sid => metinModal("Tebrik mesajı", "Kazanana gider ve herkese açık yayımlanır.", 300, "Tebrik et",
    async v => { await rpc("tebrik_et", { p_secim: sid, p_metin: v }); toast("Tebrik gönderildi"); yenidenCiz(); }, "Seçmenin kararına saygı duyuyor, görevinde başarılar diliyorum.");

  /* ------------------------------------------------------------------ Resmî günler */
  window.smResmiEkrani = async function () {
    stil(); yukleniyor("Resmî günler");
    let r; try { r = await rpc("resmi_gunler"); } catch (err) { return hata("Resmî günler", err); }
    iskelet("Resmî günler", `
      ${r.bugun ? `<div class="kart"><h2>Bugün ${e(r.bugun.ad)}</h2><p class="alt">${e(r.bugun.aciklama || "")}</p>
        ${r.yazabilirim ? `<button class="btn altin" onclick="window.smResmiYaz('${e(r.bugun.ad)}')">Mesaj yayımla</button>` : ""}</div>
        <div class="bolum-bas"><h2>Liderlerin mesajları</h2><span class="kucuk">${r.mesajlar.length}</span></div>
        <div class="kart">${r.mesajlar.map(m => `<div class="sm-mesaj">${kisi(m)} ${m.parti ? partiK(m.parti) : ""}<p style="white-space:pre-wrap">${e(m.metin)}</p></div>`).join("") || bos("Henüz mesaj yayımlanmadı.")}</div>`
        : `<div class="kart"><p class="alt">Bugün resmî bir gün değil. Milli bayramlarda, anma günlerinde ve dini bayramlarda makam sahipleri ve parti yöneticileri birer mesaj yayımlar; sabah herkese hatırlatma gider.</p></div>`}
      <div class="bolum-bas"><h2>Yaklaşan günler</h2></div><div class="kart">${r.yaklasan.map(g => `<div class="kv"><span class="k">${e(g.ad)}</span><span class="v">${tarih(g.tarih + "T12:00:00")}</span></div>`).join("") || bos("Takvimde gün yok.")}</div>
      ${r.gecmis.length ? `<div class="bolum-bas"><h2>Geçmiş günler</h2></div><div class="kart">${r.gecmis.map(g => `<div class="kv"><span class="k">${e(g.ad)}</span><span class="v">${tarih(g.tarih + "T12:00:00")} · ${g.mesaj} mesaj</span></div>`).join("")}</div>` : ""}`, { geri: true });
  };
  window.smResmiYaz = ad => metinModal(`${ad} mesajı`, "Günde bir kez yayımlanır; Gündem'de herkese görünür.", 600, "Yayımla",
    async v => { await rpc("resmi_gun_mesaj_yaz", { p_metin: v }); toast("Mesajın yayımlandı"); yenidenCiz(); });

  /* ------------------------------------------------------------------ Saha */
  const stantKart = s => `<div class="kart"><h2>${s.canli ? '<span class="sm-canli">Açık</span> ' : ""}${e(s.baslik)}</h2>
    <p class="alt">${partiK(s.parti)} · ${e(s.il)} · ${e(s.acan)} · ${s.canli ? "kapanış " + saatYaz(s.bit) : tarih(s.bit)}</p>
    <p class="kucuk">${s.ziyaretci} ziyaretçi · ${s.gonullu} gönüllü</p>
    ${s.canli && !s.partili && !s.ziyaret_ettim ? `<div class="sm-dugmeler"><button class="btn altin" onclick="window.smStantSor(${s.id})">Uğra ve soru sor</button><button class="btn ikinci" onclick="window.smStantUgra(${s.id})">Sadece uğra</button></div>` : ""}
    ${s.canli && s.partili && !s.gonulluyum ? `<button class="btn altin" onclick="window.smStantGonullu(${s.id})">Standa gönüllü ol</button>` : ""}
    ${s.sorular.map(q => `<div class="sm-mesaj soru"><b>${e(q.kad)}</b><p>${e(q.soru)}</p>${q.cevap ? `<div class="kucuk" style="margin-top:4px">↳ ${e(q.cevaplayan)}: ${e(q.cevap)}</div>` : s.partili ? `<button class="kucuk" style="background:none;border:0;color:var(--ink2);font-weight:700;padding:4px 0" onclick="window.smStantCevap(${q.id})">Yanıtla</button>` : ""}</div>`).join("")}</div>`;
  window.smSahaEkrani = async function () {
    stil(); yukleniyor("Saha çalışması");
    let s; try { s = await rpc("stantlar", { p_il: null }); } catch (err) { return hata("Saha çalışması", err); }
    const k = s.kapi || {};
    iskelet("Saha çalışması", `
      <div class="bolum-bas"><h2>${e(s.il)} standları</h2></div>
      ${(s.canli || []).map(stantKart).join("") || `<div class="kart">${bos("İlinde şu an açık stant yok.")}</div>`}
      ${s.acabilirim ? `<div class="kart"><h2>Stant aç</h2><p class="alt">3 saat açık kalır, parti kasasından ${tlYaz(s.bedel)} harcanır. İlde yaşayan herkese haber gider. Partinin o ilde teşkilatı olmalı; her ilde günde bir stant.</p>
        ${s.teskilat_var ? `<div class="alan"><label for="smSb">Stant başlığı</label><input id="smSb" maxlength="80" placeholder="Örneğin: Pazar yeri buluşması"></div><button class="btn altin" onclick="window.smStantAc(${s.il_id})">Stantı aç</button>`
          : `<p class="kucuk">Partinin ${e(s.il)} teşkilatı yok; önce Partiler › parti sayfasından il teşkilatı aç.</p>`}</div>` : ""}
      ${(s.tum_canli || []).length ? `<div class="kart"><h2>Türkiye'de açık standlar</h2>${s.tum_canli.map(x => `<div class="kv"><span class="k">${e(x.il)}</span><span class="v">${x.n}</span></div>`).join("")}</div>` : ""}
      ${(s.son || []).length ? `<div class="bolum-bas"><h2>Son standlar</h2></div>${s.son.map(stantKart).join("")}` : ""}
      <div class="bolum-bas"><h2>Kapı kapı</h2><span class="kucuk">bu hafta ${k.kalan}/${k.hak}</span></div>
      <div class="kart">${k.partili ? `<p class="alt">İlinde yaşayan, başka partiden ya da bağımsız oyunculara haftada 3 kısa ziyaret notu bırakabilirsin. Siyasi ziyaret istemeyenlere ve seni engelleyenlere gitmez.</p>
        ${(k.oneriler || []).map(o => `<div class="kv"><span class="k">${e(o.kad)} <span class="kucuk">${e(o.parti ? o.parti.kisa : "Bağımsız")}</span></span><span class="v">${k.kalan > 0 ? `<button class="btn ikinci" style="margin:0;padding:6px 12px;width:auto" onclick="window.smKapi('${e(o.kad)}')">Kapıyı çal</button>` : ""}</span></div>`).join("") || bos("Şu an ziyaret edilecek komşu yok.")}
        ${(k.gonderdiklerim || []).length ? `<div class="kucuk" style="margin-top:8px">Son ziyaretlerin: ${k.gonderdiklerim.map(g => e(g.kad)).join(", ")}</div>` : ""}`
        : `<p class="alt">Kapı kapı ziyaret için bir partiye üye olmalısın.</p>`}</div>`, { geri: true });
  };
  window.smStantAc = async il => { const b = ($("#smSb") || {}).value; try { await islem(() => rpc("stant_ac", { p_il: il, p_baslik: (b || "").trim() }), "Stant açıldı"); yenidenCiz(); } catch (_) {} };
  window.smStantUgra = async id => { try { await islem(() => rpc("stant_ziyaret", { p_stant: id, p_soru: null }), "Standa uğradın"); yenidenCiz(); } catch (_) {} };
  window.smStantSor = id => metinModal("Standa soru bırak", "Parti üyeleri yanıtlayınca bildirim alırsın.", 280, "Gönder", async v => { await rpc("stant_ziyaret", { p_stant: id, p_soru: v }); toast("Sorun iletildi"); yenidenCiz(); });
  window.smStantCevap = zid => metinModal("Soruyu yanıtla", "", 400, "Yanıtla", async v => { await rpc("stant_cevapla", { p_ziyaret: zid, p_cevap: v }); toast("Yanıt gönderildi"); yenidenCiz(); });
  window.smStantGonullu = async id => { try { await islem(() => rpc("stant_gonullu_ol", { p_stant: id }), "Gönüllü oldun"); yenidenCiz(); } catch (_) {} };
  window.smKapi = kad => metinModal(`${e(kad)} kapısını çal`, "Kısa ve saygılı bir not bırak. Karşı taraf istersen sana özel mesajla yanıt verebilir.", 280, "Notu bırak",
    async v => { await rpc("kapi_kapi", { p_kad: kad, p_metin: v }); toast("Ziyaret notun bırakıldı"); yenidenCiz(); });

  /* ------------------------------------------------------------------ Yol arkadaşı */
  window.smMentorEkrani = async function () {
    stil(); yukleniyor("Yol arkadaşı");
    let m; try { m = await rpc("mentor_durum"); } catch (err) { return hata("Yol arkadaşı", err); }
    iskelet("Yol arkadaşı", `
      <div class="kart"><p class="alt">Yeni oyuncular ilk 14 günlerinde deneyimli bir oyuncuyu yol arkadaşı seçebilir. Yeni oyuncu ilk oyunu (seçimde ya da haftalık ankette) kullandığında ikisine de ${tlYaz(m.odul || 0)} ödül verilir.</p></div>
      ${m.mentorum ? `<div class="kart"><h2>Yol arkadaşın</h2><p>${kisi(m.mentorum)} ${partiK(m.mentorum.parti)}</p>${m.mentorum.odul_at ? `<p class="kucuk">Ödül alındı.</p>` : ""}
        <button class="btn altin" onclick="modalKapat();ekranAc(()=>ozelEkrani('${e(m.mentorum.kad)}'))">Mesaj gönder</button><button class="btn ikinci" onclick="window.smMentorBirak()">Eşliği bitir</button></div>` : ""}
      ${m.acemi_mi && !m.mentorum ? `<div class="kart"><h2>Yol arkadaşı seç</h2>
        <button class="btn altin" onclick="window.smMentorSec(null)">Bana uygun birini seç</button>
        ${(m.mentorlar || []).map(x => `<div class="sm-mesaj">${kisi(x)} ${partiK(x.parti)} <span class="kucuk">${e(x.il || "")}</span>${x.tanitim ? `<p>${e(x.tanitim)}</p>` : ""}<button class="btn ikinci" style="margin-top:6px" onclick="window.smMentorSec('${e(x.kad)}')">Bunu seç</button></div>`).join("") || bos("Şu an gönüllü yok; biraz sonra yeniden bak.")}</div>` : ""}
      <div class="kart"><h2>Gönüllü ol</h2>
        ${m.uygun ? `<p class="alt">${m.gonullu && m.gonullu.aktif ? "Gönüllü listesindesin; yeni oyuncular seni seçebilir (en fazla 5 kişi)." : "Hesabın 14 günden eski ve kıdemin yeterli; gönüllü olabilirsin."}</p>
          <div class="alan"><label for="smTan">Kısa tanıtım</label><input id="smTan" maxlength="200" value="${e(m.gonullu ? m.gonullu.tanitim || "" : "")}" placeholder="Örneğin: Akşamları çevrimiçiyim, Meclis'i anlatırım."></div>
          <button class="btn altin" onclick="window.smMentorGonullu(true)">${m.gonullu && m.gonullu.aktif ? "Tanıtımı güncelle" : "Gönüllü ol"}</button>
          ${m.gonullu && m.gonullu.aktif ? `<button class="btn ikinci" onclick="window.smMentorGonullu(false)">Listeden çık</button>` : ""}`
          : `<p class="alt">Yol arkadaşı olmak için hesabının en az 14 günlük ve kıdem puanının en az 10 olması gerekir.</p>`}
        ${(m.acemilerim || []).length ? `<div class="kucuk" style="margin-top:10px">Eşlik ettiklerin</div>${m.acemilerim.map(a => `<div class="kv"><span class="k">${e(a.kad)}</span><span class="v kucuk">${a.odul_at ? "ödül alındı" : "ilk oy bekleniyor"} · <button style="background:none;border:0;color:var(--ink2);font-weight:700" onclick="ekranAc(()=>ozelEkrani('${e(a.kad)}'))">mesaj</button></span></div>`).join("")}` : ""}</div>`, { geri: true });
  };
  window.smMentorSec = async kad => { try { await islem(() => rpc("mentor_sec", { p_kad: kad }), "Yol arkadaşın belli oldu"); yenidenCiz(); } catch (_) {} };
  window.smMentorBirak = async () => { if (!await onayla("Eşliği bitir", "Yol arkadaşınla eşliğin sona erecek.", "Bitir", true)) return; try { await islem(() => rpc("mentor_birak")); yenidenCiz(); } catch (_) {} };
  window.smMentorGonullu = async aktif => { try { await islem(() => rpc("mentor_gonullu_ol", { p_tanitim: ($("#smTan") || {}).value || null, p_aktif: aktif }), aktif ? "Kaydedildi" : "Listeden çıktın"); yenidenCiz(); } catch (_) {} };

  /* ------------------------------------------------------------------ Oyuncu kartı: parti geçmişi */
  if (typeof oyuncuKart === "function") {
    const eskiK = oyuncuKart;
    window.oyuncuKart = oyuncuKart = async function (kad) {
      const r = await eskiK.apply(this, arguments);
      try {
        const l = await rpc("oyuncu_parti_gecmisi", { p_kad: kad });
        const m = document.querySelector("#modal .modal");
        if (!m || !l.length || m.querySelector(".sm-pg")) return r;
        const html = `<div class="kart sm-pg" style="margin-top:12px"><h2>Parti geçmişi</h2>${l.map(g => `<div class="kv"><span class="k">${e(g.eski ? g.eski.kisa : "Bağımsız")} → ${e(g.yeni ? g.yeni.kisa : "Bağımsız")}${g.rozet ? " · rozet takıldı" : ""}</span><span class="v kucuk">${tarih(g.zaman)}</span></div>`).join("")}</div>`;
        const hedef = [...m.querySelectorAll(".kart")].pop();
        if (hedef) hedef.insertAdjacentHTML("afterend", html);
      } catch (_) {}
      return r;
    };
  }
})();
