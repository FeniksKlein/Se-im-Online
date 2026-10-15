/* =====================================================================
   Meclis araştırması (Meclis › Araştırma) ve herkese açık vekil oy kaydı (oyuncu kartı)
   Sunucu: gelistirici/sql/99_meclis_oy_kaydi_arastirma.sql
   Ana ekran fonksiyonlarını sarar; eski sunucuda RPC yoksa sessizce eski davranış sürer.
   ===================================================================== */
(function(){
  if (typeof MECLIS_SEKME === "undefined" || window.__meclisArastirmaYuklu) return;
  window.__meclisArastirmaYuklu = true;

  const MAR_DURUM = { imza: "İmza toplanıyor", oylamada: "Genel Kurul oylaması", kurulus: "Komisyon kuruluyor", calisma: "Komisyon çalışıyor",
    rapor_oylama: "Rapor oylaması", tamamlandi: "Rapor yayımlandı", reddedildi: "Reddedildi", dustu: "Düştü", kaduk: "Kadük", geri_cekildi: "Geri çekildi" };
  const MAR_ROZET = { imza: "altin", oylamada: "kirmizi", kurulus: "altin", calisma: "altin", rapor_oylama: "kirmizi", tamamlandi: "yesil" };
  const OY_AD = { kabul: "Kabul", ret: "Ret", cekimser: "Çekimser" };
  const OY_RENK = { kabul: "var(--good)", ret: "var(--al2)", cekimser: "var(--mut)" };
  const kisiLink = k => k ? `<a class="bag" href="#" onclick="oyuncuKart('${e(k)}');return false">${e(k)}</a>` : "—";
  const geriSay = (an, etiket) => an ? `<div class="alt" style="margin-top:8px">${etiket}: ${tarihSaat(an)}</div><div class="sayac" style="font-size:28px" data-an="${new Date(an).getTime()}">${kalan(new Date(an).getTime() - simdi())}</div>` : "";

  // ---------- Meclis sekmesine "Araştırma" ekle ----------
  MECLIS_SEKME.push(["arastirma", "Araştırma"]);
  const eskiMeclisHtml = meclisHtml;
  meclisHtml = async function(){
    if (D.meclisSekme !== "arastirma") return eskiMeclisHtml.apply(this, arguments);
    const alt = `<div class="segment mc-seg">${MECLIS_SEKME.map(([k, a]) => `<button class="${k === "arastirma" ? "aktif" : ""}" onclick="meclisSekmeAc('${k}')">${a}</button>`).join("")}</div>`;
    const kaydir = () => { const s = document.querySelector(".mc-seg"), b = s && s.querySelector(".aktif"); if (s && b) s.scrollLeft = b.offsetLeft - s.clientWidth + b.offsetWidth + 8; };
    setTimeout(kaydir, 30); setTimeout(kaydir, 250);
    try { return alt + marListeHtml(await API.rpc("meclis_arastirmalar", { p_limit: 30 })); }
    catch (err) { return alt + `<div class="bos">${e(hataCevir(err.message))}</div>`; }
  };

  function marSatir(a){
    return `<div class="liste-satir" style="cursor:pointer;display:block" onclick="ekranAc(()=>meclisArastirmaEkrani(${Number(a.id)}))">
      <div style="display:flex;justify-content:space-between;gap:8px;align-items:flex-start"><b style="flex:1;min-width:0">${a.no ? a.no + ". " : ""}${e(a.konu)}</b>
        <span class="rozet ${MAR_ROZET[a.durum] || ""}">${MAR_DURUM[a.durum] || e(a.durum)}</span></div>
      <div class="kucuk" style="margin-top:4px">${e(a.teklif_eden)} ${a.parti ? `<span style="color:${e(a.parti.renk)}">${e(a.parti.kisa)}</span>` : ""}
        ${a.durum === "imza" ? ` · ${a.imza} imza` : ""}${["kurulus","calisma","rapor_oylama","tamamlandi"].includes(a.durum) && a.uye ? ` · ${a.uye} üye` : ""}${a.baskan ? ` · Başkan ${e(a.baskan)}` : ""}
        ${a.son ? ` · ${kalan(new Date(a.son).getTime() - simdi())} kaldı` : a.sonuc_at ? ` · ${tarih(a.sonuc_at)}` : ""}</div>
      ${a.bekleyen_oy ? `<div style="margin-top:6px"><span class="rozet kirmizi">Oyunu bekliyor</span></div>` : ""}</div>`;
  }

  function marListeHtml(l){
    D._marListe = l;
    const davet = (l.davetlerim || []).map(d => `<div class="olay oy" style="cursor:pointer" onclick="ekranAc(()=>meclisArastirmaEkrani(${Number(d.arastirma_id)}))">
        <div class="baslik"><b>Komisyon seni dinlemek istiyor</b><span class="rozet kirmizi">${kalan(new Date(d.son).getTime() - simdi())}</span></div>
        <p class="alt" style="margin-top:6px">"${e(d.konu)}" araştırma komisyonundan ${e(d.soran)} soruyor. Cevap vermezsen rapora "gelmedi" diye geçer.</p></div>`).join("");
    return `${davet}
      <div class="kart"><h2>Meclis araştırması</h2>
        <p class="alt">Bir konuda bilgi edinmek için Meclis'in yaptığı incelemedir (Anayasa md. 98). Önerge en az ${l.imza_yeter} vekilin imzasıyla Genel Kurul'a gelir; kabul edilirse partilerin sandalye oranına göre ${l.uye_sayisi} üyeli komisyon kurulur. Komisyon bakanları, belediye başkanlarını ya da herhangi bir oyuncuyu dinler ve herkese açık rapor yazar.</p>
        ${l.vekilim && !l.tbmm_baskani ? `<button class="btn altin" onclick="marOnergeModal()">+ Araştırma önergesi ver</button>` : l.tbmm_baskani ? `<div class="kucuk">Meclis Başkanı önerge vermez ve oy kullanmaz.</div>` : `<div class="kucuk">Önergeyi milletvekilleri verir; raporları ve oyları herkes görebilir.</div>`}</div>
      <div class="kart"><h2>Gündemdeki araştırmalar</h2>${(l.aktif || []).map(marSatir).join("") || `<div class="bos">Şu anda açık bir Meclis araştırması yok.</div>`}</div>
      ${(l.biten || []).length ? `<div class="kart"><h2>Sonuçlananlar</h2>${l.biten.map(marSatir).join("")}</div>` : ""}`;
  }

  window.marOnergeModal = function(){
    const m = modal(`<h3>Meclis araştırması önergesi</h3>
      <p class="alt">Önergen 24 saat imzaya açık kalır. Yeterli imza toplanınca Genel Kurul 24 saat oylar.</p>
      <div class="alan"><label>Araştırma konusu</label><input id="marKonu" maxlength="150" placeholder="Örn. Su kesintilerinin nedenleri ve sorumluları"></div>
      <div class="alan"><label>Gerekçe (en az 50 karakter)</label><textarea id="marGerekce" class="alanmetin" maxlength="3000"></textarea></div>
      <button class="btn altin" id="marOK">Önergeyi ver</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    $("#marOK", m).onclick = async () => {
      const b = $("#marOK", m); b.disabled = true;
      try { const d = await API.rpc("meclis_arastirma_ver", { p_konu: $("#marKonu", m).value, p_gerekce: $("#marGerekce", m).value });
        modalKapat(); toast("Önergen verildi; imza toplanıyor."); ekranAc(() => meclisArastirmaEkrani(d.id)); }
      catch (err) { b.disabled = false; toast(hataCevir(err.message), true); }
    };
  };

  // ---------- Ayrıntı ekranı ----------
  window.meclisArastirmaEkrani = async function(id){
    yukleniyor("Meclis araştırması");
    try { marCiz(await API.rpc("meclis_arastirma_detay", { p_id: id })); }
    catch (err) { iskelet("Meclis araştırması", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); }
  };

  function oySayimHtml(o, baslik, not){
    if (!o) return "";
    const top = (o.kabul || 0) + (o.ret || 0) + (o.cekimser || 0);
    return `<div class="kart"><h2>${baslik}</h2>
      ${["kabul","ret","cekimser"].map(t => `<div style="margin:6px 0"><div style="display:flex;justify-content:space-between"><b>${OY_AD[t]}</b><span>${o[t] || 0}</span></div>
        <div class="bar"><i style="width:${top ? (o[t] || 0) * 100 / top : 0}%;background:${t === "ret" ? "var(--acc)" : OY_RENK[t]}"></i></div></div>`).join("")}
      ${not ? `<div class="kucuk">${not}</div>` : ""}
      <div style="margin-top:8px">${(o.liste || []).map(v => `<span class="rozet" style="margin:2px;color:${OY_RENK[v.oy]}">${v.parti ? `<span style="width:8px;height:8px;border-radius:2px;background:${e(v.parti.renk)};display:inline-block"></span> ` : ""}${e(v.kad)}</span>`).join("") || `<span class="kucuk">Henüz oy yok.</span>`}</div>
      ${top ? `<div class="kucuk" style="margin-top:6px">Açık oylama: her vekilin oyu herkese açıktır.</div>` : ""}</div>`;
  }

  function oyButonlari(id, secili){
    return `<div class="oybtn">${["kabul","ret","cekimser"].map(t => `<button class="${secili === t ? "sec-" + t : ""}" onclick="marOy(${id},'${t}')">${OY_AD[t]}</button>`).join("")}</div>`;
  }

  function marCiz(a){
    D._mar = a;
    const ben = a.ben || {}, id = Number(a.id);
    let h = `<div class="kart"><span class="rozet ${MAR_ROZET[a.durum] || ""}">${MAR_DURUM[a.durum] || e(a.durum)}</span>
      <h3 style="font-size:20px;margin-top:8px">${a.no ? a.no + " sayılı Meclis araştırması: " : ""}${e(a.konu)}</h3>
      <div class="alt">Önerge sahibi: ${kisiLink(a.teklif_eden)} ${a.parti ? `<span style="color:${e(a.parti.renk)}">${e(a.parti.kisa)}</span>` : ""} · ${tarihSaat(a.olusturma)}</div>
      ${geriSay(a.son, { imza: "İmza süresinin bitişi", oylamada: "Oylamanın bitişi", kurulus: "Komisyon kuruluşunun bitişi", calisma: "Çalışma süresinin bitişi", rapor_oylama: "Rapor oylamasının bitişi" }[a.durum])}
      ${a.sonuc_metin ? `<p class="alt" style="margin-top:8px">${e(a.sonuc_metin)}</p>` : ""}</div>`;

    // Bana gelen davet
    (a.dinlemeler || []).filter(d => d.bana && d.durum === "bekliyor").forEach(d => {
      h += `<div class="olay oy"><div class="baslik"><b>Komisyon seni dinlemek istiyor</b><span class="rozet kirmizi">${kalan(new Date(d.son).getTime() - simdi())}</span></div>
        <p class="alt" style="margin-top:6px">${e(d.soran)} soruyor:</p><p style="white-space:pre-wrap;margin:6px 0">${e(d.soru)}</p>
        <button class="btn altin" onclick="marCevapModal(${Number(d.id)})">Yazılı cevap ver</button></div>`;
    });

    // Aşamaya göre işlem kartı
    if (a.durum === "imza") {
      h += `<div class="olay basvuru"><div class="baslik"><b>İmza toplama</b><span class="rozet ${a.imza >= a.imza_yeter ? "yesil" : "altin"}">${a.imza} / ${a.imza_yeter} imza</span></div>
        <p class="alt" style="margin-top:6px">Genel Kurul'a gelmesi için en az ${a.imza_yeter} vekilin imzası gerekir. İmzalar herkese açıktır.</p>
        <div style="margin:6px 0">${(a.imzalar || []).map(k => `<span class="rozet" style="margin:2px">${e(k)}</span>`).join("")}</div>
        ${ben.vekil && !ben.teklif_eden && !ben.tbmm_baskani ? `<button class="btn ${ben.imzaladim ? "ikinci" : "altin"}" onclick="marImza(${id},${!ben.imzaladim})">${ben.imzaladim ? "İmzanı geri çek" : "İmza ver"}</button>` : ""}
        ${ben.teklif_eden ? `<button class="btn tehlike" onclick="marGeriCek(${id})">Önergeyi geri çek</button>` : ""}</div>`;
    }
    if (a.durum === "oylamada" && ben.vekil && !ben.tbmm_baskani) {
      h += `<div class="olay oy"><div class="baslik"><b>Araştırma açılsın mı?</b><span class="rozet kirmizi">Açık oylama</span></div>
        <p class="alt" style="margin-top:6px">Kabul için en az ${a.toplanti_yeter} vekil oy kullanmalı ve en az ${a.karar_yeter} kabul oyu retten fazla olmalı. Süre bitene kadar oyunu değiştirebilirsin.</p>
        ${oyButonlari(id, ben.ongorusme_oyum)}</div>`;
    }
    if (a.durum === "kurulus") {
      const serbest = a.serbest_an && simdi() >= new Date(a.serbest_an).getTime();
      h += `<div class="olay basvuru"><div class="baslik"><b>Komisyon kuruluyor</b><span class="rozet altin">${a.uye} / ${a.uye_sayisi} üye</span></div>
        <p class="alt" style="margin-top:6px">Üyelikler partilerin Meclis'teki sandalye oranına göre dağıtıldı. ${serbest ? "Kuruluşun son 12 saatindesin: dolmayan yerlere her vekil katılabilir." : `Partilerin doldurmadığı yerler ${tarihSaat(a.serbest_an)} itibarıyla herkese açılır.`} Üyeler aralarından başkanı seçer.</p>
        ${(a.kontenjan || []).map(k => `<div class="kv"><span class="k">${partiRozet(k.parti)}</span><span class="v">${k.dolu} / ${k.koltuk}</span></div>`).join("")}
        ${ben.vekil && !ben.tbmm_baskani ? `<button class="btn ${ben.uye ? "ikinci" : "altin"}" onclick="marUye(${id},${!ben.uye})">${ben.uye ? "Komisyondan ayrıl" : "Komisyona katıl"}</button>` : ""}</div>`;
    }
    if (a.durum === "rapor_oylama" && ben.uye) {
      h += `<div class="olay oy"><div class="baslik"><b>Raporu oyla</b><span class="rozet kirmizi">Komisyon üyesi</span></div>
        <p class="alt" style="margin-top:6px">Rapor, kabul oyları retten fazla olursa kabul edilir.${ben.baskan ? "" : " Katılmıyorsan muhalefet şerhi yazabilirsin; şerhler raporla birlikte yayımlanır."}</p>
        ${oyButonlari(id, ben.rapor_oyum)}
        ${ben.baskan ? "" : `<button class="btn ikinci" style="margin-top:8px" onclick="marSerhModal(${id})">${ben.serh_yazdim ? "Şerhini düzenle" : "Muhalefet şerhi yaz"}</button>`}</div>`;
    }

    // Gerekçe
    h += `<div class="kart"><h2>Gerekçe</h2><div class="metin"><p style="white-space:pre-wrap">${e(a.gerekce)}</p></div></div>`;

    // Komisyon
    if ((a.uyeler || []).length) {
      h += `<div class="kart"><h2>Araştırma komisyonu</h2>
        ${a.uyeler.map(u => `<div class="liste-satir" style="cursor:pointer" onclick="oyuncuKart('${e(u.kad)}')">${typeof portre === "function" ? portre(u.kad, u.parti && u.parti.renk, 36) : ""}
          <div class="orta"><b>${e(u.kad)}</b><div class="kucuk">${u.baskan ? "Komisyon Başkanı · " : ""}${u.parti ? e(u.parti.kisa) : "Bağımsız"}${a.durum === "kurulus" && u.oy_aldi ? ` · ${u.oy_aldi} başkanlık oyu` : ""}</div></div>
          ${a.durum === "kurulus" && ben.uye ? `<button class="btn ${ben.baskan_oyum === u.kad ? "altin" : "ikinci"}" style="width:auto;margin:0;padding:6px 10px;font-size:12px" onclick="event.stopPropagation();marBaskanOy(${id},'${e(u.kad)}')">${ben.baskan_oyum === u.kad ? "Oyun" : "Başkan olsun"}</button>` : ""}</div>`).join("")}
        ${a.durum === "calisma" && ben.uye ? `<button class="btn altin" style="margin-top:8px" onclick="marDavetModal(${id})">Komisyona birini davet et</button>` : ""}
        ${a.durum === "calisma" && ben.baskan ? `<button class="btn" style="margin-top:8px" onclick="marRaporModal(${id})">Raporu yaz ve sun</button><div class="kucuk">Rapor sunulunca cevaplanmamış davetler "gelmedi" olarak kapanır ve 24 saatlik rapor oylaması başlar.</div>` : ""}</div>`;
    }

    // Dinlemeler
    if ((a.dinlemeler || []).length) {
      h += `<div class="kart"><h2>Dinlenenler (${a.dinlemeler.length})</h2>${a.dinlemeler.map(d => `<div class="liste-satir" style="display:block">
          <div style="display:flex;justify-content:space-between;gap:8px"><b>${kisiLink(d.davetli)}${d.davetli_unvan ? ` <span class="kucuk">${e(d.davetli_unvan)}</span>` : ""}</b>
            <span class="rozet ${d.durum === "cevaplandi" ? "yesil" : d.durum === "gelmedi" ? "kirmizi" : "altin"}">${{ cevaplandi: "Cevapladı", gelmedi: "Gelmedi", bekliyor: "Bekleniyor" }[d.durum]}</span></div>
          <div class="kucuk" style="margin-top:4px">Soran ${e(d.soran)} · ${tarihSaat(d.zaman)}</div>
          <p style="white-space:pre-wrap;margin:6px 0">${e(d.soru)}</p>
          ${d.cevap ? `<div class="olay" style="margin:6px 0 0"><b>Cevap</b><p style="white-space:pre-wrap;margin-top:4px">${e(d.cevap)}</p><div class="kucuk">${tarihSaat(d.cevap_at)}</div></div>` : ""}</div>`).join("")}</div>`;
    }

    // Rapor
    if (a.rapor) {
      h += `<div class="kart"><h2>Komisyon raporu</h2>${a.rapor_sonuc ? `<span class="rozet ${a.rapor_sonuc === "kabul" ? "yesil" : "kirmizi"}">${a.rapor_sonuc === "kabul" ? "Komisyonda kabul edildi" : "Komisyonda kabul edilmedi"}</span>` : ""}
        <div class="metin" style="margin-top:8px"><p style="white-space:pre-wrap">${e(a.rapor)}</p></div>
        ${a.oneriler ? `<div class="kart" style="margin:10px 0 0;background:var(--panel2)"><div class="kucuk">Önerilen tedbirler</div><p style="white-space:pre-wrap;margin-top:4px">${e(a.oneriler)}</p></div>` : ""}
        <div class="kucuk" style="margin-top:6px">Komisyon Başkanı ${e(a.baskan || "")} · ${tarihSaat(a.rapor_at)}</div></div>`;
      if ((a.serhler || []).length) h += `<div class="kart"><h2>Muhalefet şerhleri</h2>${a.serhler.map(s => `<div class="liste-satir" style="display:block"><b>${kisiLink(s.kad)}</b><p style="white-space:pre-wrap;margin-top:4px">${e(s.metin)}</p></div>`).join("")}</div>`;
    }

    h += oySayimHtml(a.ongorusme && (a.ongorusme.liste || []).length || a.durum === "oylamada" ? a.ongorusme : null, "Genel Kurul öngörüşme oylaması",
      `Dolu sandalye ${a.dolu} · toplantı yeter sayısı ${a.toplanti_yeter} · kabul için en az ${a.karar_yeter} ve retten fazla`);
    h += oySayimHtml(a.rapor_oy, "Komisyonda rapor oylaması", "");
    h += `<button class="btn ikinci" onclick="ekranAc(()=>sohbetEkrani('meclis'))">Genel Kurul'da tartış</button>`;
    iskelet("Meclis araştırması", h, { geri: true });
  }

  const yenile = () => D._mar && meclisArastirmaEkrani(D._mar.id);
  const cagir = async (fn, args, mesaj) => { try { marCiz(await API.rpc(fn, args)); if (mesaj) toast(mesaj); } catch (err) { toast(hataCevir(err.message), true); } };
  window.marOy = (id, oy) => cagir("meclis_arastirma_oy", { p_id: id, p_oy: oy }, "Oyun kaydedildi.");
  window.marImza = (id, ver) => cagir("meclis_arastirma_imza", { p_id: id, p_imza: ver }, ver ? "İmzan eklendi." : "İmzan geri çekildi.");
  window.marUye = (id, katil) => cagir("meclis_arastirma_uye_ol", { p_id: id, p_katil: katil }, katil ? "Komisyona katıldın." : "Komisyondan ayrıldın.");
  window.marBaskanOy = (id, kad) => cagir("meclis_arastirma_baskan_oy", { p_id: id, p_aday: kad }, "Başkanlık oyun kaydedildi.");
  window.marGeriCek = async (id) => {
    if (!await onayla("Önergeyi geri çek", "Önerge Meclis gündeminden çıkarılacak.", "Geri çek", true)) return;
    cagir("meclis_arastirma_geri_cek", { p_id: id }, "Önerge geri çekildi.");
  };
  function metinModal(baslik, aciklama, alanlar, buton, gonder){
    const m = modal(`<h3>${baslik}</h3>${aciklama ? `<p class="alt">${aciklama}</p>` : ""}
      ${alanlar.map(a => `<div class="alan"><label>${a.etiket}</label>${a.tek ? `<input id="${a.id}" maxlength="${a.max}" value="${e(a.deger || "")}">` : `<textarea id="${a.id}" class="alanmetin" maxlength="${a.max}">${e(a.deger || "")}</textarea>`}</div>`).join("")}
      <button class="btn altin" id="mmOK">${buton}</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    $("#mmOK", m).onclick = async () => {
      const b = $("#mmOK", m); b.disabled = true;
      const v = {}; alanlar.forEach(a => v[a.id] = $("#" + a.id, m).value);
      try { const r = await gonder(v); modalKapat(); return r; } catch (err) { b.disabled = false; toast(hataCevir(err.message), true); }
    };
  }
  window.marDavetModal = (id) => metinModal("Komisyona davet", "Davet ettiğin oyuncu bildirim alır ve 48 saat içinde yazılı cevap verir. Cevap vermezse rapora \"gelmedi\" diye geçer.",
    [{ id: "mdKad", etiket: "Davet edilecek oyuncunun kullanıcı adı", tek: true, max: 40 }, { id: "mdSoru", etiket: "Sorun (20–1000 karakter)", max: 1000 }],
    "Daveti gönder", async v => { marCiz(await API.rpc("meclis_arastirma_davet", { p_id: id, p_kad: v.mdKad, p_soru: v.mdSoru })); toast("Davet gönderildi."); });
  window.marCevapModal = (did) => metinModal("Komisyona yazılı cevap", "Cevabın komisyon raporunda herkese açık yayımlanır.",
    [{ id: "mcCevap", etiket: "Cevabın (20–2000 karakter)", max: 2000 }],
    "Cevabı gönder", async v => { marCiz(await API.rpc("meclis_arastirma_cevap", { p_dinleme: did, p_cevap: v.mcCevap })); toast("Cevabın komisyona iletildi."); });
  window.marRaporModal = (id) => metinModal("Komisyon raporu", "Tespitlerini yaz. Dinlenenlerin cevapları ve gelmeyenler raporun altında otomatik yer alır.",
    [{ id: "mrRapor", etiket: "Rapor (100–6000 karakter)", max: 6000 }, { id: "mrOneri", etiket: "Önerilen tedbirler (isteğe bağlı)", max: 2000 }],
    "Raporu sun", async v => { marCiz(await API.rpc("meclis_arastirma_rapor", { p_id: id, p_rapor: v.mrRapor, p_oneriler: v.mrOneri })); toast("Rapor sunuldu; oylama başladı."); });
  window.marSerhModal = (id) => metinModal("Muhalefet şerhi", "Rapora neden katılmadığını yaz. Şerhin raporla birlikte yayımlanır.",
    [{ id: "msMetin", etiket: "Şerh (20–1500 karakter)", max: 1500 }],
    "Şerhi kaydet", async v => { marCiz(await API.rpc("meclis_arastirma_serh", { p_id: id, p_metin: v.msMetin })); toast("Şerhin kaydedildi."); });
  window.meclisArastirmaYenile = yenile;

  // ---------- Oyuncu kartına herkese açık oy kaydı ----------
  const OYT_AD = { kanun: "Kanun", gensoru: "Gensoru", guvenoyu: "Güvenoyu", erken_secim: "Erken seçim", arastirma: "Araştırma", komisyon: "Komisyon" };
  function oyKaydiSatir(x){
    const git = x.tur === "kanun" || x.tur === "komisyon" ? `onclick="modalKapat();ekranAc(()=>kanunEkrani(${Number(x.ref)}))" style="cursor:pointer"`
      : x.tur === "arastirma" ? `onclick="modalKapat();ekranAc(()=>meclisArastirmaEkrani(${Number(x.ref)}))" style="cursor:pointer"` : "";
    return `<div class="kv" ${git}><span class="k"><span class="kucuk">${OYT_AD[x.tur] || ""} · ${e(x.asama)} · ${tarih(x.zaman)}</span><br>${e(x.baslik)}</span>
      <span class="v" style="color:${OY_RENK[x.oy]};font-weight:800;white-space:nowrap">${OY_AD[x.oy] || e(x.oy)}${x.aykiri ? `<br><span class="rozet altin" title="Partisinin grup kararına aykırı oy">Grup kararına aykırı</span>` : ""}</span></div>`;
  }
  function oyKaydiKart(r, tam){
    const o = r.ozet || {}, kat = o.oturum ? Math.round(o.katildi * 100 / o.oturum) : null;
    const liste = tam ? r.kayit : (r.kayit || []).slice(0, 5);
    return `<h2>Meclis oy kaydı</h2>
      <div class="mc-sayilar" style="margin-top:6px">
        <div><b>${kat == null ? "—" : "%" + kat}</b><span>katılım</span></div><div><b style="color:var(--good)">${o.kabul || 0}</b><span>kabul</span></div>
        <div><b style="color:var(--al2)">${o.ret || 0}</b><span>ret</span></div><div><b>${o.cekimser || 0}</b><span>çekimser</span></div></div>
      <div class="kucuk" style="margin:6px 0">${o.oturum ? `Vekilliği sırasında sonuçlanan ${o.oturum} Genel Kurul oylamasının ${o.katildi} tanesine katıldı.` : "Vekilliği sırasında sonuçlanmış Genel Kurul oylaması yok."}${o.aykiri ? ` Partisinin grup kararına ${o.aykiri} kez aykırı oy verdi.` : ""}${r.tbmm_baskani ? " Meclis Başkanı olduğu için Genel Kurul'da oy kullanmaz." : ""}</div>
      ${(liste || []).map(oyKaydiSatir).join("") || `<div class="alt">Henüz açık oylamada oy kullanmadı.</div>`}
      ${!tam && (r.kayit || []).length > 5 ? `<button class="btn ikinci" style="margin-top:8px" onclick="vekilOyKaydiModal('${e(r.kad)}')">Tüm oylarını gör (${o.toplam})</button>` : ""}
      <div class="kucuk" style="margin-top:6px">Genel Kurul'daki açık oylar herkese açıktır. Anayasa değişikliği ve Meclis içi seçimler gizli oyla yapıldığı için gösterilmez.</div>`;
  }
  window.vekilOyKaydiModal = async function(kad){
    const m = modal(`<div class="yukleniyor">Yükleniyor…</div>`);
    try { const r = await API.rpc("vekil_oy_kaydi", { p_kad: kad, p_limit: 200 });
      m.querySelector(".modal").innerHTML = `<div class="tutamak"></div><h3 style="font-size:22px">${e(r.kad || kad)}</h3>${oyKaydiKart(r, true)}<button class="btn ikinci" onclick="oyuncuKart('${e(r.kad || kad)}')">Oyuncu kartına dön</button>`; }
    catch (err) { m.querySelector(".modal").innerHTML = `<div class="bos">${e(hataCevir(err.message))}</div>`; }
  };
  if (typeof oyuncuKart === "function") {
    const eskiKart = oyuncuKart;
    oyuncuKart = async function(kad){
      const sonuc = await eskiKart.apply(this, arguments);
      try {
        const r = await API.rpc("vekil_oy_kaydi", { p_kad: kad, p_limit: 40 });
        if (!r || !r.vekil) return sonuc;
        const md = document.querySelector("#modal .modal");
        if (!md || md.querySelector(".oy-kaydi-kart")) return sonuc;
        const kart = document.createElement("div"); kart.className = "kart oy-kaydi-kart"; kart.style.marginTop = "12px";
        kart.innerHTML = oyKaydiKart(r, false);
        const gecmis = Array.from(md.querySelectorAll(".kart")).find(k => (k.querySelector("h2") || {}).textContent === "Siyasi geçmiş");
        if (gecmis) gecmis.after(kart); else md.querySelector(".btn") ? md.insertBefore(kart, md.querySelector(".btn")) : md.appendChild(kart);
      } catch (_) { /* eski sunucu: oy kaydı yok */ }
      return sonuc;
    };
  }
})();
