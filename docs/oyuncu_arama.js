(function () {
  "use strict";

  // Mevcut oyuncu kartini, ozel mesaj ve engelleme yetkilerini yeniden kullanir.
  const SAYFA_BOYU = 30;
  let filtre = { ad: "", il: null, parti: null, gosterilen: 0 };
  let istekNo = 0;
  let bekleme = null;

  function stilEkle() {
    if (document.getElementById("oyuncu-arama-stil")) return;
    const stil = document.createElement("style");
    stil.id = "oyuncu-arama-stil";
    stil.textContent = `
      .oa-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
      .oa-liste{display:flex;flex-direction:column;gap:7px}
      .oa-satir{width:100%;text-align:left;display:flex;align-items:center;gap:12px;padding:12px;
        border:1px solid var(--line2);border-radius:12px;background:var(--panel2);color:var(--txt);
        cursor:pointer;font:inherit}
      .oa-satir:focus-visible{outline:2px solid var(--gold);outline-offset:2px}
      .oa-satir .oa-metin{flex:1;min-width:0}
      .oa-satir .oa-ad{font-weight:800;font-size:15px;overflow-wrap:anywhere}
      .oa-satir .oa-alt{font-size:12px;color:var(--mut);margin-top:3px}
      .oa-satir .oa-ok{color:var(--gold2);font-size:23px}
      .oa-adet{margin:8px 0 12px}
      @media(max-width:370px){.oa-grid{grid-template-columns:1fr}}
    `;
    document.head.appendChild(stil);
  }

  function gecerliFiltre(x) {
    const n = Number(x);
    return x === undefined || x === null || x === "" || !Number.isSafeInteger(n) ? null : n;
  }

  window.oyuncuAramaAc = function (secim) {
    const s = secim || {};
    filtre = { ad: "", il: gecerliFiltre(s.il), parti: gecerliFiltre(s.parti), gosterilen: 0 };
    clearTimeout(bekleme);
    ++istekNo;
    if (document.getElementById("modal")) modalKapat();
    ekranAc(window.oyuncuAramaEkrani);
  };

  window.oyuncuAramaEkrani = function () {
    stilEkle();
    const iller = [...VERI.iller].sort((a, b) => a.ad.localeCompare(b.ad, "tr"));
    const partiler = (Array.isArray(PARTI_ON) ? PARTI_ON : [])
      .filter(p => !p.kapali).sort((a, b) => a.ad.localeCompare(b.ad, "tr"));

    iskelet("Oyuncu Ara", `
      <div class="kart"><h2>Oyuncu bul</h2>
        <p class="alt">Kullanıcı adıyla ara; istersen il ve parti seçerek sonuçları daralt. Oyuncuya dokunduğunda profili, mesaj ve engelleme seçenekleri açılır.</p>
        <form id="oaForm">
          <div class="alan"><label for="oaAd">Kullanıcı adı</label>
            <input id="oaAd" type="search" maxlength="40" placeholder="Örneğin ArvenTora" autocapitalize="off" autocomplete="off" spellcheck="false" value="${e(filtre.ad)}"></div>
          <div class="oa-grid">
            <div class="alan"><label for="oaIl">İl</label><select id="oaIl">
              <option value="">Tüm iller</option>
              ${iller.map(i => `<option value="${i.id}" ${i.id === filtre.il ? "selected" : ""}>${e(i.ad)}</option>`).join("")}
            </select></div>
            <div class="alan"><label for="oaParti">Parti</label><select id="oaParti">
              <option value="">Tüm partiler</option>
              <option value="0" ${filtre.parti === 0 ? "selected" : ""}>Bağımsız</option>
              ${partiler.map(p => `<option value="${p.id}" ${Number(p.id) === filtre.parti ? "selected" : ""}>${e(p.ad)}</option>`).join("")}
            </select></div>
          </div>
          <button type="submit" class="btn altin">Oyuncu ara</button>
          <button type="button" id="oaTemizle" class="btn ikinci">Filtreleri temizle</button>
        </form>
      </div>
      <div class="kart"><h2>Sonuçlar</h2><div id="oaDurum" class="kucuk oa-adet" role="status" aria-live="polite">Oyuncular aranıyor…</div>
        <div id="oaListe" class="oa-liste"></div>
        <button type="button" id="oaDaha" class="btn ikinci" style="display:none;margin-top:12px">Daha fazla oyuncu göster</button>
      </div>`, { geri: true });

    const form = document.getElementById("oaForm");
    const ad = document.getElementById("oaAd");
    const il = document.getElementById("oaIl");
    const parti = document.getElementById("oaParti");
    const liste = document.getElementById("oaListe");
    const daha = document.getElementById("oaDaha");
    const durum = document.getElementById("oaDurum");

    function guncelle() {
      filtre.ad = ad.value.trim();
      filtre.il = gecerliFiltre(il.value);
      filtre.parti = gecerliFiltre(parti.value);
      ++istekNo;
      clearTimeout(bekleme);
      bekleme = setTimeout(() => getir(false), 260);
    }

    async function getir(devam) {
      if (!liste.isConnected) return;
      const no = ++istekNo;
      const once = devam ? filtre.gosterilen : 0;
      if (!devam) {
        filtre.gosterilen = 0;
        liste.innerHTML = '<div class="yukleniyor">Aranıyor…</div>';
      }
      daha.style.display = "none";
      durum.textContent = devam ? "Diğer oyuncular yükleniyor…" : "Oyuncular aranıyor…";
      try {
        const veri = await API.rpc("oyuncu_arama", {
          p_aranan: filtre.ad, p_il: filtre.il, p_parti: filtre.parti,
          p_limit: SAYFA_BOYU, p_offset: once
        });
        if (no !== istekNo || !liste.isConnected) return;
        const oyuncular = Array.isArray(veri.oyuncular) ? veri.oyuncular : [];
        const toplam = Number(veri.toplam) || 0;
        const html = oyuncular.map(k => `
          <button type="button" class="oa-satir" data-oyuncu-kad="${e(k.kad)}" aria-label="${e(k.kad)} profilini göster">
            ${typeof portre === "function" ? portre(k.kad, k.parti && k.parti.renk, 44) : amblemKutu(k.parti, 44)}
            <span class="oa-metin"><span class="oa-ad">${e(k.kad)}</span>
              <span class="oa-alt" style="display:block">${e(k.il_ad)} · ${e(k.parti ? k.parti.kisa : "Bağımsız")}${k.unvan ? ` · ${e(k.unvan)}` : ""}</span></span>
            <span class="oa-ok" aria-hidden="true">›</span>
          </button>`).join("");
        if (devam) liste.insertAdjacentHTML("beforeend", html);
        else liste.innerHTML = html || '<div class="bos">Bu filtrelere uygun oyuncu bulunamadı.</div>';
        filtre.gosterilen = once + oyuncular.length;
        durum.textContent = toplam ? `${toplam} oyuncudan ${filtre.gosterilen} tanesi gösteriliyor.` : "Eşleşen oyuncu yok.";
        daha.style.display = filtre.gosterilen < toplam && oyuncular.length ? "block" : "none";
        if (typeof portreleriTazele === "function") portreleriTazele(liste).catch(() => {});
      } catch (err) {
        if (no !== istekNo || !liste.isConnected) return;
        if (!devam) liste.innerHTML = "";
        durum.textContent = hataCevir(err.message);
        daha.style.display = "none";
        const tekrar = document.createElement("button");
        tekrar.type = "button";
        tekrar.className = "btn ikinci";
        tekrar.textContent = "Tekrar dene";
        tekrar.onclick = () => getir(devam);
        liste.appendChild(tekrar);
      }
    }

    form.addEventListener("submit", ev => {
      ev.preventDefault();
      clearTimeout(bekleme);
      filtre.ad = ad.value.trim();
      filtre.il = gecerliFiltre(il.value);
      filtre.parti = gecerliFiltre(parti.value);
      getir(false);
    });
    ad.addEventListener("input", guncelle);
    il.addEventListener("change", guncelle);
    parti.addEventListener("change", guncelle);
    document.getElementById("oaTemizle").onclick = () => {
      ad.value = ""; il.value = ""; parti.value = "";
      guncelle();
    };
    daha.onclick = () => getir(true);
    liste.addEventListener("click", ev => {
      const b = ev.target.closest("[data-oyuncu-kad]");
      if (b) oyuncuKart(b.dataset.oyuncuKad);
    });
    getir(false);
  };
})();
