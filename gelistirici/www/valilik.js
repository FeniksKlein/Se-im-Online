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

  const KX = () => window.SO_KX;
  const n = x => (Number(x) || 0).toLocaleString("tr-TR");
  const plaka = id => String(Number(id) || 0).padStart(2, "0");

  function stil() {
    if (KX()) KX().stil();
    if (document.getElementById("vlStil")) return;
    const s = document.createElement("style"); s.id = "vlStil";
    s.textContent = `
      .vlx{--kx:#4C7BD9}
      .vlx .bos{padding:12px 2px;color:var(--mut)}
      .vlx-kapak{padding:15px 14px 14px;border-radius:20px;margin:0 0 12px;background:radial-gradient(120% 90% at 100% 0%,rgba(76,123,217,.30),transparent 60%),linear-gradient(170deg,#152349,#101833);box-shadow:inset 0 0 0 1px rgba(150,180,255,.22),0 16px 30px -24px #000}
      .vlx-kapak h2{font-family:var(--disp);font-size:24px;line-height:1.1;margin:0;color:#fff}
      .vlx-kapak>p{margin:4px 0 0;font-size:13px;color:#C3CFEE;line-height:1.4}
      .vlx-harita{display:block;width:100%;height:auto;margin:12px 0 4px;touch-action:manipulation}
      .vlx-harita path{fill:#24305A;stroke:#0E1530;stroke-width:.9;stroke-linejoin:round;cursor:pointer;transition:fill .2s}
      .vlx-harita path.dolu{fill:#4C7BD9}
      .vlx-harita path.ev{fill:#33437A}
      .vlx-harita path.dolu.ev{fill:#6C96F0}
      .vlx-harita path.ben{fill:#F2B33D}
      .vlx-harita path.sec{stroke:#fff;stroke-width:2.4;paint-order:stroke}
      .vlx-lejant{display:flex;gap:12px;flex-wrap:wrap;font-size:12px;color:#C3CFEE;margin:2px 0 0}
      .vlx-lejant span{display:inline-flex;align-items:center;gap:6px}
      .vlx-lejant i{width:11px;height:11px;border-radius:3px;display:inline-block}
      .vlx-bilgi{margin-top:12px;padding:12px;border-radius:14px;background:rgba(0,0,0,.25);box-shadow:inset 0 0 0 1px rgba(150,180,255,.18)}
      .vlx-bilgi .vlx-b-ust{display:flex;align-items:center;gap:11px}
      .vlx-plaka{flex:none;display:inline-grid;place-items:center;min-width:44px;height:30px;padding:0 6px;border-radius:6px;font-family:var(--disp);font-size:17px;font-weight:700;color:#10142a;background:#F4F6FB;box-shadow:inset 6px 0 0 #2D5BD0}
      .vlx-bilgi b{font-size:16px}
      .vlx-bilgi p{margin:6px 0 0;font-size:13.5px;line-height:1.45;color:var(--txt2)}
      .vlx-bilgi .tv-iki,.vlx-bilgi .vl-iki{margin-top:10px}
      .vl-satir{display:flex;gap:11px;align-items:center;padding:11px 0;border-bottom:1px solid var(--line2);overflow-wrap:anywhere}
      .vl-satir:last-child{border-bottom:0}
      .vl-satir .vlx-s-g{flex:1;min-width:0}
      .vl-satir .vlx-s-g .kucuk{display:block;margin-top:2px}
      .vl-satir .btn{width:auto;flex:none;margin:0;padding:8px 12px;min-height:40px;font-size:13.5px}
      .vl-iki{display:flex;gap:8px;flex-wrap:wrap}
      .vl-iki .btn{flex:1;min-width:130px;margin:0}
      .vlx-kart{background:var(--panel);border-radius:16px;padding:14px 14px 13px;margin:0 0 10px;box-shadow:inset 0 0 0 1px var(--line)}
      .vlx-kart h2{font-size:17px;line-height:1.25;margin:0 0 6px}
      .vlx-makam{background:linear-gradient(165deg,rgba(242,179,61,.14),transparent 55%),var(--panel);box-shadow:inset 0 0 0 1.5px rgba(242,179,61,.5)}
      .vlx-makam .vlx-m-ust{display:flex;gap:12px;align-items:center;margin-bottom:10px}
      .vlx-makam h2{font-family:var(--disp);font-size:23px;margin:0}
      .vlx-emir{display:grid;gap:8px;margin:8px 0 12px}
      .vlx-emir button{display:flex;flex-direction:column;align-items:flex-start;gap:2px;padding:11px 12px;border-radius:12px;text-align:left;background:var(--panel2);box-shadow:inset 0 0 0 1px var(--line2);color:var(--txt)}
      .vlx-emir button b{font-size:14.5px}
      .vlx-emir button small{font-size:12.5px;color:var(--mut)}
      .vlx-emir button[aria-pressed=true]{box-shadow:inset 0 0 0 2px #F2B33D;background:linear-gradient(160deg,rgba(242,179,61,.14),transparent 70%),var(--panel2)}
      .vlx-bekle{padding:10px 12px;border-radius:12px;background:rgba(242,179,61,.10);font-size:13.5px;color:#FFD98C;margin:0 0 10px}
      .vlx-harf{flex:none;width:38px;height:38px;border-radius:50%;display:grid;place-items:center;font-weight:800;font-size:14px;color:#fff;background:linear-gradient(150deg,hsl(var(--h) 50% 48%),hsl(calc(var(--h) + 35) 45% 28%))}
      .vlx-ozet{display:flex;gap:12px;align-items:center;padding:12px;border-radius:12px;background:var(--panel2);margin:0 0 12px}
      .vlx-ozet b{font-family:var(--disp);font-size:28px;line-height:1;color:#fff}
      .vlx-ozet span{font-size:13px;color:var(--txt2);line-height:1.35}
      /* sınav */
      .vl-sinav-ust{position:sticky;top:0;z-index:2;background:var(--panel,#151E3D);padding:6px 0 10px}
      .vl-sinav-ust .to-bar,.vl-sinav-ust .vlx-bar{height:6px;border-radius:4px;background:var(--panel2);overflow:hidden}
      .vl-sinav-ust .vlx-bar i{display:block;height:100%;width:0;background:#4C7BD9;transition:width .2s}
      .vl-soru{padding:12px 0;border-bottom:1px solid var(--line2)}
      .vl-soru>b{display:block;margin-bottom:8px;font-size:15px;line-height:1.4}
      .vl-soru label{display:flex;gap:10px;align-items:flex-start;padding:10px 11px;margin:0 0 6px;border-radius:11px;background:var(--panel2);box-shadow:inset 0 0 0 1px var(--line2);font-size:14.5px;line-height:1.35;cursor:pointer}
      .vl-soru label:has(input:checked){box-shadow:inset 0 0 0 2px #4C7BD9;background:rgba(76,123,217,.14)}
      .vl-soru input{flex:none;width:18px;height:18px;margin-top:1px;accent-color:#4C7BD9}
      .vl-not h4{margin:12px 0 4px;font-size:14px;color:var(--gold2)}
      .vl-not p{margin:0;font-size:14.5px;line-height:1.5}
      @media (max-width:350px){.vlx-kapak h2{font-size:21px}}`;
    document.head.appendChild(s);
  }

  // Türkiye haritası: valisi olan iller mavi, oyuncunun valisi olduğu il altın, ikamet ili açık ton
  function haritaHtml(d) {
    const H = (window.VERI && VERI.harita) || null; if (!H || !H.il) return "";
    const vali = {}; (d.valiler || []).forEach(v => { vali[v.il_id] = v; });
    const gorev = d.gorevim ? Number(d.gorevim.il_id) : 0, ev = Number(((D.durum || {}).profil || {}).il_id) || 0;
    const ad = {}; (d.iller || []).forEach(i => { ad[i.id] = i.ad; });
    return `<svg class="vlx-harita" viewBox="0 0 ${H.w || 1000} ${H.h || 429}" role="img" aria-label="Türkiye valilik haritası" onclick="vlHaritaTik(event)">${Object.keys(H.il).map(id => {
      const c = [vali[id] ? "dolu" : "", Number(id) === gorev ? "ben" : "", Number(id) === ev ? "ev" : "", Number(id) === Number(window._vlSecIl) ? "sec" : ""].filter(Boolean).join(" ");
      return `<path d="${H.il[id].d}" data-id="${Number(id)}"${c ? ` class="${c}"` : ""}><title>${e(ad[id] || "")}${vali[id] ? " · " + e(vali[id].vali) : ""}</title></path>`; }).join("")}</svg>`;
  }
  function ilBilgiHtml(d, id) {
    if (!id) return `<p class="kucuk" style="color:#C3CFEE;margin-top:8px">Bir ile dokun: valisi, göreve başlama tarihi${d.cb ? " ve atama işlemleri" : ""} burada görünür.</p>`;
    const il = (d.iller || []).find(i => Number(i.id) === Number(id)), v = (d.valiler || []).find(x => Number(x.il_id) === Number(id));
    if (!il) return "";
    return `<div class="vlx-bilgi"><div class="vlx-b-ust"><span class="vlx-plaka">${plaka(id)}</span><div style="min-width:0"><b>${e(il.ad)} Valiliği</b>
        <div class="kucuk">${v ? `Vali <b style="font-size:inherit">${e(v.vali)}</b> · ${tarihSaat(v.bas)} tarihinden beri` : "Vali atanmadı"}</div></div></div>
      ${d.cb ? `<div class="vl-iki"><button class="btn altin" onclick="vlBuIleAta(${Number(id)})">${v ? "Yerine vali ata" : "Bu ile vali ata"}</button>${v ? `<button class="btn ikinci" onclick="vlGorevdenAl(${v.il_id},'${e(v.il)}','${e(v.vali)}')">Görevden al</button>` : ""}</div>`
        : !v ? `<p>Bu ilin valisi yok. Valilik sınavını geçen oyuncular arasından Cumhurbaşkanı atama yapar.</p>` : ""}</div>`;
  }
  window.vlHaritaTik = ev => {
    const p = ev.target && ev.target.closest && ev.target.closest("path[data-id]"); if (!p) return;
    const id = Number(p.dataset.id); window._vlSecIl = id;
    document.querySelectorAll(".vlx-harita path.sec").forEach(x => x.classList.remove("sec")); p.classList.add("sec");
    const b = document.getElementById("vlIlBilgi"); if (b && window._vlDurum) b.innerHTML = ilBilgiHtml(window._vlDurum, id);
  };
  window.vlBuIleAta = id => {
    const s = document.getElementById("vlIl"); if (s) s.value = String(id);
    if (KX()) KX().gec("vl", "atama");
    const a = document.getElementById("vlAday"); if (a) setTimeout(() => a.focus(), 60);
  };

  function kariyerHtml(d) {
    const a = d.akademi, h = d.havuz, t = simdi();
    let ic, no;
    if (!a) {
      no = 0;
      ic = `<p class="alt">Vali olmak için önce Mülki İdare Akademisi'ne kaydolur, 24 saatlik eğitimin ardından 20 soruluk valilik sınavına girersin. 16 doğruyla sınavı geçen oyuncu vali havuzuna alınır; Cumhurbaşkanı havuzdan dilediğini dilediği ile atar.</p>
        ${kv("Kayıt harcı", tl(d.harc))}${kv("Hesap yaşı (en az 7 gün)", d.hesap_uygun ? "Uygun" : "Henüz dolmadı")}${kv("Vali maaşı", tl(d.gunluk_maas) + " / gün")}
        <div class="vl-iki" style="margin-top:12px"><button class="btn altin" ${d.hesap_uygun ? "" : "disabled"} onclick="vlBasvur()">Akademiye kaydol</button><button class="btn ikinci" onclick="vlNotlar()">Ders notları</button></div>`;
    } else if (!a.sinav_gecildi && new Date(a.egitim_bitti).getTime() > t) {
      no = 1;
      ic = `<div class="vlx-ozet"><b>${kalan(new Date(a.egitim_bitti).getTime() - t).replace(/:\d\d$/, "")}</b><span>eğitimin bitmesine<br>Sınav ${tarihSaat(a.egitim_bitti)} tarihinde açılır.</span></div>
        <p class="alt">Bu sürede ders notlarını oku; sınav soruları bu notlardan çıkar.</p>
        <button class="btn ikinci" onclick="vlNotlar()">Ders notlarını oku</button>`;
    } else if (!a.sinav_gecildi) {
      no = 2;
      const bekle = a.son_sinav && new Date(a.son_sinav).getTime() + 864e5 > t;
      ic = `<p class="alt">Eğitimi tamamladın. Sınav 20 sorudur; en az 16 doğru gerekir. Her denemede soru seti değişir.</p>
        ${a.son_puan != null ? kv("Son sınav", a.son_puan + " / 20 · " + a.deneme + ". deneme") : ""}
        ${bekle ? kv("Yeni deneme", tarihSaat(new Date(new Date(a.son_sinav).getTime() + 864e5))) : ""}
        <div class="vl-iki" style="margin-top:12px"><button class="btn altin" ${bekle ? "disabled" : ""} onclick="vlSinav()">Sınava gir</button><button class="btn ikinci" onclick="vlNotlar()">Ders notları</button></div>`;
    } else if (d.gorevim) {
      no = 4;
      ic = `<p class="alt">Valilik sınavını geçtin ve şu an görevdesin. Görevdeki vali havuzdan çıkamaz; önce istifa etmen gerekir.</p>${kv("Sınav", a.son_puan + " / 20")}${kv("Toplam atama", (h || {}).atama_sayisi || 0)}`;
    } else if (h && h.durum === "aday") {
      no = 3;
      ic = `<p class="alt">Vali havuzundasın. Cumhurbaşkanı seni dilediği ile atayabilir; atama için onayın beklenmez. Atanmak istemiyorsan havuzdan çıkabilirsin.</p>
        ${kv("Havuza giriş", tarihSaat(h.giris))}${kv("Toplam atama", h.atama_sayisi)}${kv("Sınav puanın", a.son_puan + " / 20")}
        ${d.siyasi_engel ? `<p class="kucuk" style="color:var(--bad);margin-top:8px">Şu an ${e(d.siyasi_engel)} görevindesin; bu makamı bırakmadan vali atanamazsın.</p>` : ""}
        <button class="btn ikinci" style="margin-top:10px" onclick="vlHavuzCik()">Havuzdan çık</button>`;
    } else {
      no = 3;
      ic = `<p class="alt">Valilik sınavını geçtin ama vali havuzunda değilsin. Sınava yeniden girmeden havuza dönebilirsin.</p>
        <button class="btn altin" onclick="vlHavuzGir()">Havuza dön</button>`;
    }
    return `<section class="vlx-kart"><h2>Valilik kariyerim</h2>${KX() ? KX().adimlar(["Akademi kaydı", "24 saat eğitim", "Sınav", "Vali havuzu", "Göreve atanma"], no) : ""}${ic}</section>`;
  }

  function makamHtml(d) {
    const g = d.gorevim; if (!g) return "";
    const sonraki = g.son_karar ? new Date(g.son_karar).getTime() + 6 * 36e5 : 0, bekle = sonraki > simdi();
    const ilk = Object.keys(EMIR)[0];
    return `<section class="vlx-kart vlx-makam"><div class="vlx-m-ust"><span class="vlx-plaka" style="height:38px;min-width:54px;font-size:21px">${plaka(g.il_id)}</span><div><h2>${e(g.il)} Valiliği</h2><div class="kucuk">Atayan ${e(g.atayan || "—")} · ${tarihSaat(g.bas)} tarihinden beri</div></div></div>
      <p class="alt">İlin valisisin. İl güvenlik emirleri İçişleri Bakanlığı bütçesinden karşılanır; iki emir arasında 6 saat gerekir. İlindeki toplumsal olaylarda sert önlem yetkin vardır (Halk hareketleri ekranı).</p>
      ${kv("Görev süresi", g.bitis ? tarihSaat(g.bitis) + " tarihine kadar" : "Süresiz (Cumhurbaşkanı görevden alana kadar)")}${kv("Günlük maaş", tl(d.gunluk_maas))}${g.son_karar ? kv("Son il emri", tarihSaat(g.son_karar)) : ""}
      <h3 style="font-size:15px;margin:14px 0 2px">İl emri</h3>
      ${bekle ? `<div class="vlx-bekle">Yeni emir ${tarihSaat(sonraki)} tarihinde verilebilir (kalan ${kalan(sonraki - simdi()).replace(/:\d\d$/, "")}).</div>` : ""}
      <input type="hidden" id="vlEmir" value="${ilk}">
      <div class="vlx-emir" role="group" aria-label="İl emri türü">${Object.keys(EMIR).map(k => `<button type="button" data-vl-emir="${k}" aria-pressed="${k === ilk}" onclick="vlEmirSec('${k}')"><b>${EMIR[k][0]}</b><small>${EMIR[k][1]}</small></button>`).join("")}</div>
      <div class="alan"><label for="vlGerekce">Gerekçe (en az 25 karakter)</label><textarea id="vlGerekce" maxlength="1500" rows="3" placeholder="Neden bu önlemi alıyorsun? Gündem'de ve kayıtlarda görünür."></textarea></div>
      <div class="vl-iki"><button class="btn altin" ${bekle ? "disabled" : ""} onclick="vlEmirVer(${g.atama_id})">Emri ver</button><button class="btn tehlike" onclick="vlIstifa()">Valilikten istifa et</button></div></section>`;
  }
  window.vlEmirSec = k => { const h = $("#vlEmir"); if (h) h.value = k; document.querySelectorAll("[data-vl-emir]").forEach(b => b.setAttribute("aria-pressed", String(b.dataset.vlEmir === k))); };

  function cbHtml(d) {
    if (!d.cb) return "";
    const adaylar = (d.adaylar || []).filter(a => !a.engel), vali = {};
    (d.valiler || []).forEach(v => { vali[v.il_id] = v; });
    const bosIl = (d.iller || []).filter(i => !vali[i.id]), doluIl = (d.iller || []).filter(i => vali[i.id]);
    const sec = Number(window._vlSecIl) || 0;
    const opt = i => `<option value="${i.id}"${Number(i.id) === sec ? " selected" : ""}>${e(i.ad)}${vali[i.id] ? " · vali: " + e(vali[i.id].vali) : " · boş"}</option>`;
    return `<section class="vlx-kart" style="box-shadow:inset 0 0 0 1.5px rgba(76,123,217,.55)"><h2>Cumhurbaşkanlığı · vali atamaları</h2>
      <p class="alt">Havuzdaki adayı dilediğin ile atarsın; atama hemen yürürlüğe girer. İlin mevcut valisi varsa görevden alınmış olur; görevdeki bir valiyi seçersen başka ile atanır.</p>
      <div class="vlx-ozet"><b>${n(bosIl.length)}</b><span>ilde vali yok<br>${n(adaylar.filter(a => !a.il).length)} aday atama bekliyor</span></div>
      ${adaylar.length ? `<div class="alan"><label for="vlAday">Aday</label><select id="vlAday">${adaylar.map(a => `<option value="${e(a.kad)}">${e(a.kad)}${a.il ? " · şu an " + e(a.il) + " Valisi" : " · bekliyor"}${a.ev_il ? " · ikamet " + e(a.ev_il) : ""}</option>`).join("")}</select></div>
        <div class="alan"><label for="vlIl">İl</label><select id="vlIl">${bosIl.length ? `<optgroup label="Valisi olmayan iller (${bosIl.length})">${bosIl.map(opt).join("")}</optgroup>` : ""}${doluIl.length ? `<optgroup label="Valisi olan iller (${doluIl.length})">${doluIl.map(opt).join("")}</optgroup>` : ""}</select></div>
        <p class="kucuk">İpucu: haritada bir ile dokunup “Bu ile vali ata” dersen il burada seçili gelir.</p>
        <button class="btn altin" onclick="vlAta()">Vali olarak ata</button>` : bos("Havuzda atanabilecek aday yok. Oyuncular valilik sınavını geçince burada görünür.")}</section>`;
  }

  /* ------------------------------------------------------------------ Devlet › Hükümet: öne çıkan Valilik kartı (60 sn önbellek) */
  let ozetOn = { t: 0, d: null };
  function devletKartVeri(d) {
    const o = { id: "vlDevletKart", ikon: "vali", renk: "76,123,217", acik: "#b5cbff", etiket: "Valilik", git: "Aç", onclick: "ekranAc(valilikEkrani)" };
    if (!d) { o.baslik = "Sınavı geç, vali ol"; o.alt = "Valilik sınavını geçenler vali havuzuna girer; Cumhurbaşkanı havuzdan dilediğini bir ile atar."; return o; }
    const genel = `${d.vali} / 81 ilde vali görevde · havuzda ${d.havuz} aday`;
    if (d.durum === "vali") { o.baslik = `${d.il} Valisisin`; o.alt = "İl emri ver, makamını yönet. " + genel + "."; o.git = "Makamım"; }
    else if (d.cb) { o.etiket = "Valilik · Cumhurbaşkanlığı"; o.baslik = Number(d.bekleyen) > 0 ? `${d.bekleyen} aday atama bekliyor` : "Vali atamaları sende"; o.alt = genel + ". Havuzdan dilediğini dilediğin ile ata."; o.git = "Ata"; }
    else if (d.durum === "sinav") { o.baslik = "Valilik sınavın açık"; o.alt = "20 soru, en az 16 doğru. Geçersen vali havuzuna girersin."; o.git = "Sınava gir"; }
    else if (d.durum === "egitim") { o.baslik = "Akademi eğitimin sürüyor"; o.alt = `Sınav ${tarihSaat(d.egitim_bitti)} tarihinde açılır. Ders notlarını oku.`; }
    else if (d.durum === "bekle") { o.baslik = "Sınava yeniden girebileceksin"; o.alt = `Yeni deneme ${tarihSaat(d.yeni_sinav)} tarihinde açılır.`; }
    else if (d.durum === "havuz") { o.baslik = "Vali havuzundasın"; o.alt = "Cumhurbaşkanı seni bir ile atayabilir. " + genel + "."; }
    else if (d.durum === "ayrildi") { o.baslik = "Vali havuzundan çıktın"; o.alt = "Sınava yeniden girmeden havuza dönebilirsin."; o.git = "Dön"; }
    else { o.baslik = "Sınavı geç, vali ol"; o.alt = genel + ". Cumhurbaşkanı havuzdan dilediğini bir ile atar."; o.git = "Başvur"; }
    return o;
  }
  const devlette = () => { try { const h = document.querySelector("header.ust h1"); return D.sekme === "devlet" && (D.devletSekme || "hukumet") === "hukumet" && !(D.yigin || []).length && !!h && h.textContent.trim() === "Devlet"; } catch (_) { return false; } };
  function devletKartKoy(d) {
    if (!window.SO_ONE_CIKAN || !devlette()) return;
    window.SO_ONE_CIKAN.koy(devletKartVeri(d), ic => {
      const hz = ic.querySelector('.pa-hizli[data-pa-hizli="devlet"]'); if (hz) return { el: hz, yer: "afterend" };
      const sg = ic.querySelector(".segment"); if (sg) return { el: sg, yer: "beforebegin" };
      return { el: ic, yer: "afterbegin" };
    });
  }
  window.valilikDevletKart = async function () {
    try {
      if (!window.SO_ONE_CIKAN) return;
      window.SO_ONE_CIKAN.tekrarla(() => devletKartKoy(ozetOn.d));
      if (ozetOn.d && Date.now() - ozetOn.t < 60000) return;
      ozetOn = { t: Date.now(), d: ozetOn.d };
      const d = await rpc("vali_ozet"); ozetOn = { t: Date.now(), d }; devletKartKoy(d);
    } catch (_) {}
  };

  window.valilikEkrani = async function () {
    stil();
    if (!document.getElementById("vlKok")) yukleniyor("Valilik");
    let d; try { d = await rpc("vali_durum"); } catch (err) { return iskelet("Valilik", `<div class="bos">${e(hataCevir(err.message))}</div><button class="btn ikinci" onclick="yenidenCiz()">Tekrar dene</button>`, { geri: true }); }
    window._vlDurum = d;
    const valiler = d.valiler || [], adaylar = d.adaylar || [];
    if (window._vlSecIl == null && d.gorevim) window._vlSecIl = Number(d.gorevim.il_id);
    const SEK = [].concat(d.gorevim ? [["makam", "Makamım"]] : []).concat(d.cb ? [["atama", "Atama", adaylar.filter(a => !a.engel && !a.il).length ? String(adaylar.filter(a => !a.engel && !a.il).length) : ""]] : [])
      .concat([["kariyer", "Kariyerim"], ["valiler", "Valiler", String(valiler.length)], ["havuz", "Vali havuzu", String(adaylar.length)], ["kararlar", "Kararlar"]]);
    const varsay = SEK[0][0];
    const akt = KX() ? KX().secili("vl", SEK, varsay) : varsay;
    const pano = (k, h) => KX() ? KX().pano("vl", k, akt, h) : h;
    const kisiSatir = (ad, alt, sag) => `<div class="vl-satir"><span class="vlx-harf" style="--h:${KX() ? KX().ton(ad) : 220}" aria-hidden="true">${e(KX() ? KX().harfler(ad, 1) : "?")}</span><div class="vlx-s-g">${alt}</div>${sag || ""}</div>`;
    iskelet("Valilik", `<div id="vlKok" class="vlx">
      <section class="vlx-kapak"><h2>Türkiye valilikleri</h2><p>Valiyi Cumhurbaşkanı atar; il genel idaresinin ve kamu düzeninin başıdır.</p>
        ${haritaHtml(d)}
        <div class="vlx-lejant"><span><i style="background:#4C7BD9"></i>Vali görevde</span><span><i style="background:#24305A;box-shadow:inset 0 0 0 1px #3a4778"></i>Vali yok</span>${d.gorevim ? '<span><i style="background:#F2B33D"></i>Senin ilin</span>' : ""}${Number(((D.durum || {}).profil || {}).il_id) && !(d.gorevim && Number(d.gorevim.il_id) === Number(D.durum.profil.il_id)) ? '<span><i style="background:#33437A;box-shadow:inset 0 0 0 1px #4a5c9a"></i>İkamet ilin</span>' : ""}</div>
        ${KX() ? KX().sayilar([[`${n(valiler.length)}<span style="font-size:14px;color:#C3CFEE"> / 81</span>`, "ilde vali görevde"], [n(adaylar.length), "havuzdaki aday"], [tl(d.gunluk_maas).replace(" ₺", "₺"), "günlük vali maaşı"]]) : ""}
        <div id="vlIlBilgi">${ilBilgiHtml(d, window._vlSecIl)}</div></section>
      ${KX() ? KX().sekmeler("vl", SEK, akt, "#4C7BD9") : ""}
      ${d.gorevim ? pano("makam", makamHtml(d)) : ""}
      ${d.cb ? pano("atama", cbHtml(d)) : ""}
      ${pano("kariyer", kariyerHtml(d))}
      ${pano("valiler", `<section class="vlx-kart"><h2>Görevdeki valiler <span class="kucuk">${valiler.length} / 81 il</span></h2>
        ${valiler.map(v => kisiSatir(v.vali, `<b>${e(v.il)}</b> · ${e(v.vali)}<span class="kucuk">göreve başlama ${tarihSaat(v.bas)}${v.sureli ? " · bitiş " + tarihSaat(v.bitis) : ""}</span>`,
          d.cb ? `<button class="btn ikinci" onclick="vlGorevdenAl(${v.il_id},'${e(v.il)}','${e(v.vali)}')">Görevden al</button>` : "")).join("") || bos("Henüz atanmış vali yok.")}</section>`)}
      ${pano("havuz", `<section class="vlx-kart"><h2>Vali havuzu <span class="kucuk">${adaylar.length} aday</span></h2>
        <p class="alt">Valilik sınavını geçen oyuncular. Cumhurbaşkanı bu listeden atama yapar.</p>
        ${adaylar.map(a => kisiSatir(a.kad, `${kisi(a)}<span class="kucuk">${a.il ? e(a.il) + " Valisi" : "atama bekliyor"} · havuza giriş ${tarih(a.giris)}${a.atama_sayisi ? " · " + a.atama_sayisi + " atama" : ""}${a.engel ? " · siyasi görevde, atanamaz" : ""}${a.ev_il ? " · ikamet " + e(a.ev_il) : ""}</span>`,
          d.cb && !a.engel ? `<button class="btn ikinci" onclick="vlAdayAta('${e(a.kad)}')">Ata</button>` : "")).join("") || bos("Havuz boş.")}</section>`)}
      ${pano("kararlar", `<section class="vlx-kart"><h2>Son kararlar</h2>${(d.gecmis || []).map(g => `<div class="vl-satir"><div class="vlx-s-g"><b>${e(g.kisi || "")}</b> · ${e(OLAY[g.olay] || g.olay)}${g.il ? " · " + e(g.il) : ""} <span class="kucuk">${tarihSaat(g.zaman)}</span>${g.aciklama ? `<span class="kucuk">${e(g.aciklama)}</span>` : ""}</div></div>`).join("") || bos("Henüz karar yok.")}</section>`)}
    </div>`, { geri: D.yigin.length > 0 });
  };
  window.vlAdayAta = kad => { const a = document.getElementById("vlAday"); if (a) a.value = kad; if (KX()) KX().gec("vl", "atama"); const il = document.getElementById("vlIl"); if (il) setTimeout(() => il.focus(), 60); };

  const calis = async (fn, basari) => { try { const r = await fn(); ozetOn.t = 0; if (basari) toast(basari); await window.valilikEkrani(); return r; } catch (err) { toast(hataCevir(err.message), true); } };
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
      <div class="vl-sinav-ust"><p class="alt" style="margin:4px 0 8px"><b id="vlIlerleme">0 / ${sorular.length}</b> cevaplandı · en az 16 doğru gerekir. Puan sunucuda hesaplanır.</p><div class="vlx-bar"><i id="vlIlerlemeB"></i></div></div>
      <div style="max-height:56vh;overflow-y:auto;overscroll-behavior:contain">${sorular.map((q, i) => `<fieldset class="vl-soru" style="border:0;margin:0"><b>${i + 1}. ${e(q.soru)}</b>
        ${q.secenekler.map((s, j) => `<label><input type="radio" name="vlS${q.id}" value="${j + 1}"><span>${e(s)}</span></label>`).join("")}</fieldset>`).join("")}</div>
      <button class="btn altin" id="vlGonder" style="margin-top:12px">Sınavı teslim et</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
    const say = () => { const k = sorular.filter(q => m.querySelector(`input[name="vlS${q.id}"]:checked`)).length;
      const t = m.querySelector("#vlIlerleme"), b = m.querySelector("#vlIlerlemeB"); if (t) t.textContent = k + " / " + sorular.length; if (b) b.style.width = Math.round(100 * k / sorular.length) + "%"; };
    m.addEventListener("change", say);
    $("#vlGonder", m).onclick = async () => {
      const cevap = {};
      for (const q of sorular) { const v = m.querySelector(`input[name="vlS${q.id}"]:checked`);
        if (!v) { const ilk = m.querySelector(`input[name="vlS${q.id}"]`); if (ilk) ilk.closest("fieldset").scrollIntoView({ block: "center" }); return toast("Lütfen bütün soruları cevapla.", true); }
        cevap[q.id] = Number(v.value); }
      $("#vlGonder", m).disabled = true;
      try {
        const r = await rpc("vali_sinav_gonder", { p_cevaplar: cevap });
        modalKapat();
        modal(`<h3 style="font-size:19px;font-weight:800">${r.gecti ? "Sınavı geçtin" : "Sınav sonucu"}</h3>
          <div class="vlx-ozet" style="margin-top:10px"><b>${r.puan} / ${r.toplam}</b><span>doğru<br>${r.gecti ? "Vali havuzuna alındın" : "Geçmek için 16 doğru gerekir"}</span></div>
          <p class="alt">${r.gecti ? "Cumhurbaşkanı seni bir ile atayabilir." : "24 saat sonra yeniden deneyebilirsin; soru seti değişir."}</p>
          ${(r.yanlislar || []).length ? `<details><summary class="kucuk" style="cursor:pointer">Yanlış yanıtladığın sorular</summary>${r.yanlislar.map(x => `<p class="kucuk" style="margin:6px 0">${e(x)}</p>`).join("")}</details>` : ""}
          <button class="btn altin" style="margin-top:12px" onclick="modalKapat();valilikEkrani()">Tamam</button>`);
      } catch (err) { toast(hataCevir(err.message), true); $("#vlGonder", m).disabled = false; }
    };
  };
})();
