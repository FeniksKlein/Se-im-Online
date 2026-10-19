/* Cumhurbaşkanlığı: aday vitrini, slogan, bildirge ve seçim çalışmaları. */
(function () {
  "use strict";
  const TURLER = [
    { kod: "sosyal_medya", ad: "Sosyal medya kampanyası", bedel: 2000, ornek: "Seçim mesajını dijital mecralarda duyur" },
    { kod: "afis", ad: "Afiş ve tanıtım", bedel: 5000, ornek: "Seçim afişleri ve broşür dağıtımı" },
    { kod: "halk_bulusmasi", ad: "Halk buluşması", bedel: 10000, ornek: "Seçmenlerle açık toplantı" },
    { kod: "tv", ad: "Televizyon konuşması", bedel: 20000, ornek: "Ulusa seslenen seçim konuşması" }
  ];
  const ad = (kod) => (TURLER.find(x => x.kod === kod) || {}).ad || kod;
  const adayBul = (v) => (v.adaylar || []).find(x => x.benim);
  const kart = (v) => {
    const secim = v && v.takvim && v.takvim.find(s => s.tur === "cb" && s.durum !== "tamam" &&
      ["yakinda", "basvuru", "oy", "sayim"].includes(s.asama));
    if (!secim) return "";
    return `<div class="olay basvuru"><div class="baslik"><b>🇹🇷 Cumhurbaşkanlığı seçim kampanyaları</b><span class="rozet altin">${secim.ara ? "Erken seçim" : "Seçim"}</span></div>
      <p class="alt" style="margin-top:6px">Adayların sloganlarını, seçim bildirgelerini ve etkinliklerini incele. Aday veya aday adayıysan kendi kampanyanı yönet.</p>
      <button class="btn altin" onclick="cbKampanyaEkrani(${Number(secim.id)})">Adaylar ve kampanyalar ›</button></div>`;
  };

  window.cbKampanyaGundemKart = kart;

  window.cbKampanyaEkrani = async function (secimId) {
    if (typeof yukleniyor === "function") yukleniyor("Cumhurbaşkanlığı kampanyaları");
    let v;
    try { v = await API.rpc("cb_kampanya_bilgi", { p_secim: Number(secimId) }); }
    catch (err) {
      iskelet("Cumhurbaşkanlığı kampanyaları", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true });
      return;
    }
    const benim = adayBul(v);
    const acik = v.duzenlenebilir;
    const etkinlikler = v.etkinlikler || [];
    const adaylar = v.adaylar || [];
    const adayHtml = adaylar.map(x => `<div class="kart" style="border-left:4px solid ${/^#[a-fA-F0-9]{3,8}$/.test(x.renk || "") ? x.renk : "#8a739b"}">
      <div style="display:flex;align-items:center;justify-content:space-between;gap:8px"><h3 style="margin:0">${e(x.kad)} ${x.benim ? "· Sen" : ""}</h3><span class="rozet ${x.kesin ? "yesil" : "altin"}">${x.kesin ? "Kesin aday" : "Aday adayı"}</span></div>
      <div class="kucuk">${e(x.parti || "Bağımsız")} ${x.kisa ? "· " + e(x.kisa) : ""}</div>
      ${x.slogan ? `<h3 style="margin:12px 0 4px;color:var(--gold2)">“${e(x.slogan)}”</h3>` : `<p class="alt">Henüz slogan belirlenmedi.</p>`}
      ${x.vizyon ? `<p style="white-space:pre-wrap">${e(x.vizyon)}</p>` : ""}
      ${(x.vaatler || []).length ? `<div class="kucuk" style="font-weight:800;margin-top:8px">Öne çıkan vaatler</div><ul style="padding-left:20px">${x.vaatler.map(t => `<li>${e(t)}</li>`).join("")}</ul>` : ""}
      ${x.benim && acik ? `<button class="btn altin" onclick="cbKampanyaDuzenle(${Number(v.secim_id)})">Slogan ve bildirgemi düzenle</button>` : ""}
    </div>`).join("");
    const benimPanel = benim && acik ? `<div class="kart"><h2>Seçim çalışmalarım</h2>
      <p class="alt">Slogan ve bildirge ücretsizdir. Etkinlikler cüzdanından ödenir ve Türkiye Gündem'e yansır. Her seçimde en fazla 6 etkinlik; aralarında en az 30 dakika bulunmalı.</p>
      <div class="vit-dugme">${TURLER.map(x => `<button class="btn ikinci" onclick="cbKampanyaEtkinlikModal(${Number(v.secim_id)},'${x.kod}')">${e(x.ad)} · ${tlYaz(x.bedel)}</button>`).join("")}</div>
      <button class="btn ikinci" onclick="cbKampanyaMitingAc()">🎤 Canlı meydan mitingi planla</button>
      <p class="kucuk" style="margin-top:7px">Etkinlikler seçim sandığı açılmadan önce; canlı mitingler ise mevcut miting kurallarına göre düzenlenir. Etkinlikler otomatik oy kazandırmaz.</p></div>` : "";
    const govde = `<div class="kart"><h2>🇹🇷 Cumhurbaşkanlığı seçimi</h2>
      <p class="alt">Oy verme: ${tarihSaat(v.oy_bas)} – ${tarihSaat(v.oy_bit)}. Adayların seçim programlarını burada karşılaştırabilirsin.</p>
      ${benim ? `<span class="rozet yesil">✓ ${benim.kesin ? "Kesin adaylığın var" : "Aday adaylığın var"}</span>` : `<span class="rozet">Bu seçimde kayıtlı adaylığın yok</span>`}
      ${!adaylar.length ? `<p class="alt">Henüz kayıtlı Cumhurbaşkanı adayı yok.</p>` : ""}</div>
      ${benimPanel}<div class="bolum-bas"><h2>Adayların kampanyaları</h2></div>${adayHtml}
      <div class="bolum-bas"><h2>Seçim etkinlikleri</h2></div><div class="kart">${etkinlikler.length ? etkinlikler.map(x => `<div class="liste-satir"><div class="orta"><b>${e(x.kad)} · ${e(ad(x.tur))}</b><div>${e(x.baslik)}</div><div class="kucuk">${tarihSaat(x.zaman)}</div></div></div>`).join("") : `<p class="alt">Henüz kampanya etkinliği düzenlenmedi.</p>`}</div>`;
    iskelet("Cumhurbaşkanlığı kampanyaları", govde, { geri: true });
  };

  window.cbKampanyaDuzenle = async function (sid) {
    let v;
    try { v = await API.rpc("cb_kampanya_bilgi", { p_secim: sid }); }
    catch (err) { toast(hataCevir(err.message), true); return; }
    const ben = adayBul(v);
    if (!ben || !v.duzenlenebilir) { toast("Aktif Cumhurbaşkanı adaylığın bulunmuyor.", true); return; }
    const m = modal(`<h3>Cumhurbaşkanlığı seçim kampanyam</h3>
      <p class="alt">Seçmenin seni hangi sözle hatırlayacağını belirle. Vizyon ve vaatler diğer tüm oyunculara görünür.</p>
      <div class="alan"><label for="cbkSlogan">Kampanya sloganı (3–80 karakter)</label>
        <input id="cbkSlogan" maxlength="80" placeholder="Örnek: Birlikte daha güçlü Türkiye" value="${e(ben.slogan || "")}"></div>
      <div class="alan"><label for="cbkVizyon">Seçim bildirgesi / vizyon (en fazla 1000 karakter)</label>
        <textarea id="cbkVizyon" maxlength="1000" rows="5" placeholder="Hedeflerini, ekonomi ve demokrasi yaklaşımını anlat">${e(ben.vizyon || "")}</textarea></div>
      <div class="alan"><label for="cbkVaat">Öne çıkan vaatler (en fazla 5; her satır ayrı vaat)</label>
        <textarea id="cbkVaat" maxlength="850" rows="5" placeholder="Ekonomide istikrar\nEğitimde fırsat eşitliği">${e((ben.vaatler || []).join("\n"))}</textarea></div>
      <div class="hata-metin" id="cbkHata"></div><button class="btn altin" id="cbkKaydet">Kampanyamı yayımla</button>`);
    $("#cbkKaydet", m).onclick = async () => {
      const dugme = $("#cbkKaydet", m);
      const vaatler = $("#cbkVaat", m).value.split("\n").map(x => x.trim()).filter(Boolean);
      if (vaatler.length > 5 || vaatler.some(x => x.length > 160)) { $("#cbkHata", m).textContent = "En fazla 5 vaat, her biri en fazla 160 karakter olabilir."; return; }
      dugme.disabled = true;
      try {
        await API.rpc("cb_kampanya_kaydet", { p_secim: sid, p_slogan: $("#cbkSlogan", m).value, p_vizyon: $("#cbkVizyon", m).value, p_vaatler: vaatler });
        modalKapat(); toast("Seçim kampanyan yayımlandı."); cbKampanyaEkrani(sid);
      } catch (err) { dugme.disabled = false; $("#cbkHata", m).textContent = hataCevir(err.message); }
    };
  };

  window.cbKampanyaEtkinlikModal = function (sid, tur) {
    const o = TURLER.find(x => x.kod === tur);
    if (!o) return;
    const m = modal(`<h3>${e(o.ad)}</h3><p class="alt">Bu etkinlik ${tlYaz(o.bedel)} tutar. Cüzdanından düşülür; seçim günlüğünde ve Gündem haberlerinde görünür.</p>
      <div class="alan"><label for="cbkEtkinlik">Etkinliğin mesajı (5–120 karakter)</label><textarea id="cbkEtkinlik" maxlength="120" rows="3" placeholder="${e(o.ornek)}"></textarea></div>
      <div class="hata-metin" id="cbkEtHata"></div><button class="btn altin" id="cbkEtKaydet">${tlYaz(o.bedel)} öde ve duyur</button>`);
    $("#cbkEtKaydet", m).onclick = async () => {
      const btn = $("#cbkEtKaydet", m); btn.disabled = true;
      try {
        await API.rpc("cb_kampanya_etkinlik", { p_secim: sid, p_tur: tur, p_baslik: $("#cbkEtkinlik", m).value });
        modalKapat(); toast("Kampanya etkinliğin yayımlandı."); cbKampanyaEkrani(sid);
      } catch (err) { btn.disabled = false; $("#cbkEtHata", m).textContent = hataCevir(err.message); }
    };
  };

  window.cbKampanyaMitingAc = async function () {
    try {
      const haklar = await API.rpc("miting_haklarim");
      const h = (haklar || []).find(x => x.tur === "cb" && !x.duzenledi) || (haklar || []).find(x => x.tur === "cb_on" && !x.duzenledi);
      if (!h) { toast("Bu seçim için kullanılabilir canlı miting hakkın yok.", true); return; }
      mitingDuzenleModal(h);
    } catch (err) { toast(hataCevir(err.message), true); }
  };
})();
