/* 11.11.2026 · Valilik: Mülki İdare Akademisi, valilik sınavı, vali havuzu, Cumhurbaşkanı ataması — sunucu modülü 197.
   Avukatlıktaki akış: başvuru → 24 saat eğitim → 20 soruluk sınav (16 doğru) → vali havuzu. Mevcut ekranlara dokunmaz. */
(function () {
  "use strict";
  if (window.SO_VALILIK_V1) return;
  window.SO_VALILIK_V1 = true;

  const rpc = (fn, a) => API.rpc(fn, a);
  const tl = x => (Number(x) || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺";
  const kv = (a, b) => `<div class="kv"><span class="k">${a}</span><span class="v">${b}</span></div>`;
  const bos = m => `<div class="bos" style="padding:10px 0">${m}</div>`;
  const kisi = k => k ? `<b>${e(k.kad)}</b>${k.unvan ? ` <span class="kucuk" style="color:var(--gold2)">${e(k.unvan)}</span>` : ""}` : "—";
  const OLAY = { atama: "Atandı", alindi: "Görevden alındı", istifa: "İstifa etti", nakil: "Başka ile atandı", dustu: "Görevi sona erdi" };
  const EMIR = { devriye: ["Devriye ve asayiş", "Memnuniyet +0,3 · gelişim +0,2 · bütçe 150.000 ₺"], takviye: ["Takviye güvenlik", "Gelişim +0,6 · memnuniyet −0,5 · bütçe 500.000 ₺"], uzlasma: ["Uzlaşma masası", "Memnuniyet +0,8 · bütçe 100.000 ₺"] };

  const NOTLAR = [
    ["İl ve vali", "Türkiye'de 81 il vardır. Mülki idare bölümleri il ve ilçedir. İlin genel idaresinin başı validir; ilçenin başında kaymakam, köyün başında muhtar bulunur. İl yönetiminin temel kanunu 5442 sayılı İl İdaresi Kanunu'dur."],
    ["Valinin konumu", "Vali, ilde Cumhurbaşkanı'nın temsilcisi ve idari yürütme vasıtasıdır. Valileri Cumhurbaşkanı atar ve görevden alır. İllerde hükümet politikasının uygulanmasından ve kamu hizmetlerinin eşgüdümünden vali sorumludur. Vali görevi başında olmadığında kendisine vali yardımcısı vekâlet eder."],
    ["Anayasa", "İdare, kuruluş ve görevleriyle bir bütündür; merkezden yönetim ve yerinden yönetim esaslarına dayanır. İllerin idaresi yetki genişliği esasına dayanır. Mahalli idareler il özel idaresi, belediye ve köydür; merkezî idarenin bunlar üzerindeki denetim yetkisine idari vesayet denir. Belediye başkanı seçimle gelir; kanun yapmak TBMM'nin işidir, valinin değil."],
    ["Yetkiler", "İldeki genel kolluk (emniyet ve jandarma) valinin emrindedir; ilin huzur ve güvenliğinden vali sorumludur. Vali, adli ve askerî kuruluşlar dışındaki devlet dairelerini denetler. Kanun ve Cumhurbaşkanlığı kararnamelerinin verdiği yetkiyi kullanmak için genel emir çıkarabilir. İl idare kuruluna vali başkanlık eder. İlde görevli memurlar hakkında soruşturma iznini vali verir."],
    ["Kamu düzeni ve afet", "Vali bir toplantı ya da gösteri yürüyüşünü en çok bir ay erteleyebilir; kamu düzeni için ildeki belirli yerlere giriş ve çıkışı en çok 15 gün sınırlayabilir. İlde afet ve acil durum yönetiminin sorumlusu validir."],
    ["İl özel idaresi", "Büyükşehir olmayan illerde il özel idaresinin başı validir. Büyükşehir olan illerde il özel idaresi kaldırılmış, yerine valiye bağlı Yatırım İzleme ve Koordinasyon Başkanlığı kurulmuştur. Bir ilin kurulması, kaldırılması ya da adının değiştirilmesi kanunla yapılır."],
    ["Olağanüstü hâl", "Olağanüstü hâli Cumhurbaşkanı ilan eder; süresi altı ayı geçemez ve karar TBMM'nin onayına sunulur."],
    ["Oyundaki kurallar", "Vali olabilmek için valilik sınavını geçip vali havuzuna girmek gerekir. Akademiye başvurduktan sonra 24 saat eğitim görülür; sınav 20 sorudur, en az 16 doğru gerekir; başarısız olan 24 saat sonra yeniden girer. Havuzdaki adayı Cumhurbaşkanı dilediği ile atar, dilediği zaman görevden alır ya da başka ile atar. Bir ilde tek vali olur. Milletvekili, bakan ya da belediye başkanı gibi seçilmiş/siyasi makam sahipleri vali olamaz. Havuzda bekleyen aday dilediğinde çıkar ve sınava yeniden girmeden geri dönebilir; görevdeki vali havuzdan çıkmak için önce istifa etmelidir. Vali, ilindeki toplumsal olaylarda kamu düzeni için sert önlem alabilir ve milletvekili maaşı düzeyinde günlük maaş alır."]
  ];

  function stil() {
    if (document.getElementById("vlStil")) return;
    const s = document.createElement("style"); s.id = "vlStil";
    s.textContent = `
      .vl-satir{padding:9px 0;border-bottom:1px solid var(--line2);overflow-wrap:anywhere}
      .vl-satir:last-child{border-bottom:0}
      .vl-iki{display:flex;gap:8px;flex-wrap:wrap}
      .vl-iki .btn{flex:1;min-width:130px;margin:0}
      .vl-soru{padding:10px 0;border-bottom:1px solid var(--line2)}
      .vl-soru b{display:block;margin-bottom:6px;font-size:14.5px;line-height:1.4}
      .vl-soru select{width:100%}
      .vl-not h4{margin:12px 0 4px;font-size:14px;color:var(--gold2)}
      .vl-not p{margin:0;font-size:14.5px;line-height:1.5}`;
    document.head.appendChild(s);
  }

  function kariyerHtml(d) {
    const a = d.akademi, h = d.havuz, t = simdi();
    let ic;
    if (!a) {
      ic = `<p class="alt">Vali olmak için önce Mülki İdare Akademisi'ne kaydolur, 24 saatlik eğitimin ardından 20 soruluk valilik sınavına girersin. 16 doğruyla sınavı geçen oyuncu vali havuzuna alınır; Cumhurbaşkanı havuzdan dilediğini dilediği ile atar.</p>
        ${kv("Kayıt harcı", tl(d.harc))}${kv("Hesap yaşı (en az 7 gün)", d.hesap_uygun ? "Uygun" : "Henüz dolmadı")}${kv("Vali maaşı", tl(d.gunluk_maas) + " / gün")}
        <div class="vl-iki" style="margin-top:10px"><button class="btn altin" ${d.hesap_uygun ? "" : "disabled"} onclick="vlBasvur()">Akademiye kaydol</button><button class="btn ikinci" onclick="vlNotlar()">Ders notları</button></div>`;
    } else if (!a.sinav_gecildi && new Date(a.egitim_bitti).getTime() > t) {
      ic = `<p class="alt">24 saatlik eğitim sürüyor. Sınav <b>${tarihSaat(a.egitim_bitti)}</b> tarihinde açılır (kalan ${kalan(new Date(a.egitim_bitti).getTime() - t)}).</p>
        <button class="btn ikinci" onclick="vlNotlar()">Ders notlarını oku</button>`;
    } else if (!a.sinav_gecildi) {
      const bekle = a.son_sinav && new Date(a.son_sinav).getTime() + 864e5 > t;
      ic = `<p class="alt">Eğitimi tamamladın. Sınav 20 sorudur; en az 16 doğru gerekir. Her denemede soru seti değişir.</p>
        ${a.son_puan != null ? kv("Son sınav", a.son_puan + " / 20 · " + a.deneme + ". deneme") : ""}
        ${bekle ? kv("Yeni deneme", tarihSaat(new Date(new Date(a.son_sinav).getTime() + 864e5))) : ""}
        <div class="vl-iki" style="margin-top:10px"><button class="btn altin" ${bekle ? "disabled" : ""} onclick="vlSinav()">Sınava gir</button><button class="btn ikinci" onclick="vlNotlar()">Ders notları</button></div>`;
    } else if (d.gorevim) {
      ic = `<p class="alt">Valilik sınavını geçtin ve şu an görevdesin. Görevdeki vali havuzdan çıkamaz; önce istifa etmen gerekir.</p>${kv("Sınav", a.son_puan + " / 20")}${kv("Toplam atama", (h || {}).atama_sayisi || 0)}`;
    } else if (h && h.durum === "aday") {
      ic = `<p class="alt">Vali havuzundasın. Cumhurbaşkanı seni dilediği ile atayabilir; atama için onayın beklenmez. Atanmak istemiyorsan havuzdan çıkabilirsin.</p>
        ${kv("Havuza giriş", tarihSaat(h.giris))}${kv("Toplam atama", h.atama_sayisi)}
        ${d.siyasi_engel ? `<p class="kucuk" style="color:var(--bad)">Şu an ${e(d.siyasi_engel)} görevindesin; bu makamı bırakmadan vali atanamazsın.</p>` : ""}
        <button class="btn ikinci" style="margin-top:8px" onclick="vlHavuzCik()">Havuzdan çık</button>`;
    } else {
      ic = `<p class="alt">Valilik sınavını geçtin ama vali havuzunda değilsin. Sınava yeniden girmeden havuza dönebilirsin.</p>
        <button class="btn altin" onclick="vlHavuzGir()">Havuza dön</button>`;
    }
    return `<section class="kart"><h2>Valilik kariyerim</h2>${ic}</section>`;
  }

  function makamHtml(d) {
    const g = d.gorevim; if (!g) return "";
    return `<section class="kart" style="border:2px solid var(--gold)"><h2>${e(g.il)} Valiliği</h2>
      <p class="alt">İlin valisisin. İl güvenlik emirleri İçişleri Bakanlığı bütçesinden karşılanır; iki emir arasında 6 saat gerekir. İlindeki toplumsal olaylarda sert önlem yetkin vardır (Halk hareketleri ekranı).</p>
      ${kv("Göreve başlama", tarihSaat(g.bas))}${kv("Atayan", e(g.atayan || "—"))}${kv("Görev süresi", g.bitis ? tarihSaat(g.bitis) + " tarihine kadar" : "Süresiz (Cumhurbaşkanı görevden alana kadar)")}${kv("Günlük maaş", tl(d.gunluk_maas))}
      <div class="alan" style="margin-top:10px"><label for="vlEmir">İl emri</label><select id="vlEmir">${Object.keys(EMIR).map(k => `<option value="${k}">${EMIR[k][0]} — ${EMIR[k][1]}</option>`).join("")}</select></div>
      <div class="alan"><label for="vlGerekce">Gerekçe (en az 25 karakter)</label><textarea id="vlGerekce" maxlength="1500" rows="3"></textarea></div>
      <div class="vl-iki"><button class="btn altin" onclick="vlEmirVer(${g.atama_id})">Emri ver</button><button class="btn tehlike" onclick="vlIstifa()">Valilikten istifa et</button></div></section>`;
  }

  function cbHtml(d) {
    if (!d.cb) return "";
    const adaylar = (d.adaylar || []).filter(a => !a.engel);
    return `<section class="kart" style="border:2px solid var(--gold)"><h2>Cumhurbaşkanlığı · vali atamaları</h2>
      <p class="alt">Havuzdaki adayı dilediğin ile atarsın; atama hemen yürürlüğe girer. İlin mevcut valisi varsa görevden alınmış olur; görevdeki bir valiyi seçersen başka ile atanır.</p>
      ${adaylar.length ? `<div class="alan"><label for="vlAday">Aday</label><select id="vlAday">${adaylar.map(a => `<option value="${e(a.kad)}">${e(a.kad)}${a.il ? " · şu an " + e(a.il) + " Valisi" : " · bekliyor"}${a.ev_il ? " · ikamet " + e(a.ev_il) : ""}</option>`).join("")}</select></div>
        <div class="alan"><label for="vlIl">İl</label><select id="vlIl">${(d.iller || []).map(i => { const v = (d.valiler || []).find(x => x.il_id === i.id); return `<option value="${i.id}">${e(i.ad)}${v ? " · vali: " + e(v.vali) : " · boş"}</option>`; }).join("")}</select></div>
        <button class="btn altin" onclick="vlAta()">Vali olarak ata</button>` : bos("Havuzda atanabilecek aday yok. Oyuncular valilik sınavını geçince burada görünür.")}</section>`;
  }

  window.valilikEkrani = async function () {
    stil();
    if (!document.getElementById("vlKok")) yukleniyor("Valilik");
    let d; try { d = await rpc("vali_durum"); } catch (err) { return iskelet("Valilik", `<div class="bos">${e(hataCevir(err.message))}</div><button class="btn ikinci" onclick="yenidenCiz()">Tekrar dene</button>`, { geri: true }); }
    window._vlDurum = d;
    const valiler = d.valiler || [], adaylar = d.adaylar || [];
    iskelet("Valilik", `<div id="vlKok">
      ${makamHtml(d)}${cbHtml(d)}${kariyerHtml(d)}
      <section class="kart"><h2>Görevdeki valiler <span class="kucuk">${valiler.length} / 81 il</span></h2>
        ${valiler.map(v => `<div class="vl-satir"><b>${e(v.il)}</b> · ${e(v.vali)} <span class="kucuk">göreve başlama ${tarihSaat(v.bas)}${v.sureli ? " · bitiş " + tarihSaat(v.bitis) : ""}</span>
          ${d.cb ? `<button class="btn ikinci" onclick="vlGorevdenAl(${v.il_id},'${e(v.il)}','${e(v.vali)}')">Görevden al</button>` : ""}</div>`).join("") || bos("Henüz atanmış vali yok.")}</section>
      <section class="kart"><h2>Vali havuzu <span class="kucuk">${adaylar.length} aday</span></h2>
        <p class="alt">Valilik sınavını geçen oyuncular. Cumhurbaşkanı bu listeden atama yapar.</p>
        ${adaylar.map(a => `<div class="vl-satir">${kisi(a)} <span class="kucuk">${a.il ? e(a.il) + " Valisi" : "atama bekliyor"} · havuza giriş ${tarih(a.giris)}${a.atama_sayisi ? " · " + a.atama_sayisi + " atama" : ""}${a.engel ? " · siyasi görevde, atanamaz" : ""}</span></div>`).join("") || bos("Havuz boş.")}</section>
      <section class="kart"><h2>Son kararlar</h2>${(d.gecmis || []).map(g => `<div class="vl-satir"><b>${e(g.kisi || "")}</b> · ${e(OLAY[g.olay] || g.olay)}${g.il ? " · " + e(g.il) : ""} <span class="kucuk">${tarihSaat(g.zaman)}</span>${g.aciklama ? `<div class="kucuk">${e(g.aciklama)}</div>` : ""}</div>`).join("") || bos("Henüz karar yok.")}</section>
    </div>`, { geri: D.yigin.length > 0 });
  };

  const calis = async (fn, basari) => { try { const r = await fn(); if (basari) toast(basari); await window.valilikEkrani(); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.vlBasvur = async () => { if (!await onayla("Mülki İdare Akademisi", `Kayıt harcı ${tl((window._vlDurum || {}).harc || 25000)} cüzdanından alınır. 24 saatlik eğitimden sonra valilik sınavına girebilirsin.`, "Kaydol")) return; return calis(() => rpc("vali_basvur"), "Akademiye kaydoldun."); };
  window.vlHavuzCik = async () => { if (!await onayla("Havuzdan çık", "Vali havuzundan çıkarsan Cumhurbaşkanı seni atayamaz. Sınava yeniden girmeden dilediğinde geri dönebilirsin.", "Havuzdan çık", true)) return; return calis(() => rpc("vali_havuz_cik"), "Havuzdan çıktın."); };
  window.vlHavuzGir = () => calis(() => rpc("vali_havuz_gir"), "Vali havuzuna döndün.");
  window.vlIstifa = async () => { if (!await onayla("Valilikten istifa", "Görevin sona erer; vali havuzunda aday olarak kalırsın.", "İstifa et", true)) return; return calis(() => rpc("vali_istifa"), "Valilik görevinden ayrıldın."); };
  window.vlAta = async () => { const k = $("#vlAday").value, il = Number($("#vlIl").value), ad = $("#vlIl").selectedOptions[0].textContent.split(" · ")[0];
    if (!await onayla("Vali ataması", `${e(k)}, ${e(ad)} Valiliğine atanacak. Atama hemen yürürlüğe girer.`, "Ata")) return; return calis(() => rpc("vali_ata", { p_kad: k, p_il: il }), "Atama yapıldı."); };
  window.vlGorevdenAl = async (il, ad, vali) => { if (!await onayla("Görevden al", `${e(ad)} Valisi ${e(vali)} görevden alınacak ve vali havuzuna dönecek.`, "Görevden al", true)) return; return calis(() => rpc("vali_gorevden_al", { p_il: il, p_gerekce: null }), "Vali görevden alındı."); };
  window.vlEmirVer = id => { const g = ($("#vlGerekce").value || "").trim(); if (g.length < 25) return toast("Gerekçe en az 25 karakter olmalı.", true);
    return calis(() => rpc("icisleri_il_emir_ver", { p_atama: id, p_tur: $("#vlEmir").value, p_gerekce: g }), "İl emri verildi."); };

  window.vlNotlar = function () {
    modal(`<h3 style="font-size:19px;font-weight:800">Mülki İdare ders notları</h3>
      <p class="alt" style="margin-top:6px">Sınav soruları bu notlardan çıkar. Notlar oyun içindir; resmî mevzuat metni değildir.</p>
      <div class="vl-not" style="max-height:60vh;overflow-y:auto">${NOTLAR.map(n => `<h4>${n[0]}</h4><p>${n[1]}</p>`).join("")}</div>
      <button class="btn ikinci" style="margin-top:12px" onclick="modalKapat()">Kapat</button>`);
  };
  window.vlSinav = function () {
    const sorular = (window._vlDurum || {}).sorular || [];
    if (!sorular.length) return toast("Sınav henüz açılmadı.", true);
    const m = modal(`<h3 style="font-size:19px;font-weight:800">Valilik sınavı</h3>
      <p class="alt" style="margin-top:6px">20 soruyu cevapla; en az 16 doğru gerekir. Puan sunucuda hesaplanır.</p>
      <div style="max-height:58vh;overflow-y:auto">${sorular.map((q, i) => `<div class="vl-soru"><b>${i + 1}. ${e(q.soru)}</b>
        <select id="vlS${q.id}"><option value="">Seç…</option>${q.secenekler.map((s, j) => `<option value="${j + 1}">${e(s)}</option>`).join("")}</select></div>`).join("")}</div>
      <button class="btn altin" id="vlGonder" style="margin-top:12px">Sınavı teslim et</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    $("#vlGonder", m).onclick = async () => {
      const cevap = {};
      for (const q of sorular) { const v = m.querySelector("#vlS" + q.id).value; if (!v) return toast("Lütfen bütün soruları cevapla.", true); cevap[q.id] = Number(v); }
      $("#vlGonder", m).disabled = true;
      try {
        const r = await rpc("vali_sinav_gonder", { p_cevaplar: cevap });
        modalKapat();
        modal(`<h3 style="font-size:19px;font-weight:800">${r.gecti ? "Sınavı geçtin" : "Sınav sonucu"}</h3>
          <p class="alt" style="margin-top:6px">${r.puan} / ${r.toplam} doğru. ${r.gecti ? "Vali havuzuna alındın; Cumhurbaşkanı seni bir ile atayabilir." : "Geçmek için 16 doğru gerekir. 24 saat sonra yeniden deneyebilirsin."}</p>
          ${(r.yanlislar || []).length ? `<details><summary class="kucuk" style="cursor:pointer">Yanlış yanıtladığın sorular</summary>${r.yanlislar.map(x => `<p class="kucuk" style="margin:6px 0">${e(x)}</p>`).join("")}</details>` : ""}
          <button class="btn altin" style="margin-top:12px" onclick="modalKapat();valilikEkrani()">Tamam</button>`);
      } catch (err) { toast(hataCevir(err.message), true); $("#vlGonder", m).disabled = false; }
    };
  };
})();
