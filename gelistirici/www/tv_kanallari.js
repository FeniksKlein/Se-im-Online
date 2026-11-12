/* 11.11.2026 · TV Kanalları — sunucu modülü 198.
   Kanal kurma, maaşlı sunucu, zamanlı canlı program (siyasi düello / söyleşi / haber), konuk daveti, canlı yazışma,
   izleyici sayısı ve listesi, alkış / yuh, düello oylaması, izleyici başına ücretli reklam. Mevcut ekranlara dokunmaz. */
(function () {
  "use strict";
  if (window.SO_TV_KANALLARI_V1) return;
  window.SO_TV_KANALLARI_V1 = true;

  const rpc = (fn, a) => API.rpc(fn, a);
  const tl = x => (Number(x) || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺";
  const kv = (a, b) => `<div class="kv"><span class="k">${a}</span><span class="v">${b}</span></div>`;
  const bos = m => `<div class="bos" style="padding:10px 0">${m}</div>`;
  const kisi = k => k ? `<b>${e(k.kad)}</b>${k.unvan ? ` <span class="kucuk" style="color:var(--gold2)">${e(k.unvan)}</span>` : ""}` : "—";
  const hataEkran = (b, err) => iskelet(b, `<div class="bos">${e(hataCevir(err.message))}</div><button class="btn ikinci" onclick="yenidenCiz()">Tekrar dene</button>`, { geri: true });
  const benimKad = () => { try { return D.durum.profil.kad; } catch (_) { return ""; } };
  // kesintisiz_ekran.js, kullanıcı eylemi olmadan gelen çizimleri erteleyebilir; seçim kutusu gibi düğme dışı eylemleri bildirir
  const eylem = () => { try { if (window.SO_KESINTISIZ) window.SO_KESINTISIZ.eylem = Date.now(); } catch (_) {} };
  const ROL = { sunucu: "Sunucu", konuk: "Konuk", reklam: "Reklam" };
  const SURELER = [[10, "10 dakika"], [15, "15 dakika"], [20, "20 dakika"], [30, "30 dakika"], [45, "45 dakika"], [60, "1 saat"], [90, "1,5 saat"], [120, "2 saat"], [180, "3 saat"]];

  function stil() {
    if (document.getElementById("tvStil")) return;
    const s = document.createElement("style"); s.id = "tvStil";
    s.textContent = `
      .tv-canli{display:inline-block;background:#e5484d;color:#fff;font-size:11px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;padding:2px 8px;border-radius:999px;margin-right:6px;vertical-align:middle;animation:tvNabiz 1.6s ease-in-out infinite}
      @keyframes tvNabiz{50%{opacity:.55}}
      @media (prefers-reduced-motion:reduce){.tv-canli{animation:none}}
      .tv-prog{padding:10px 0;border-bottom:1px solid var(--line2);overflow-wrap:anywhere}
      .tv-prog:last-child{border-bottom:0}
      .tv-prog .btn{margin-top:8px}
      .tv-oda{max-height:52vh;min-height:150px;overflow-y:auto;overscroll-behavior:contain}
      .tv-mesaj{padding:8px 0;border-bottom:1px solid var(--line2);overflow-wrap:anywhere}
      .tv-mesaj:last-child{border-bottom:0}
      .tv-mesaj p{margin:4px 0 0;font-size:15px;line-height:1.45;white-space:pre-wrap}
      .tv-rol{display:inline-block;font-size:11px;font-weight:800;text-transform:uppercase;letter-spacing:.05em;padding:1px 7px;border-radius:999px;border:1px solid currentColor;margin-right:6px;color:var(--gold2)}
      .tv-mesaj.konuk .tv-rol{color:#6ea8fe}
      .tv-mesaj.reklam{background:rgba(255,255,255,.045);border-radius:10px;padding:8px 10px;border-bottom:0;margin:6px 0}
      .tv-mesaj.reklam .tv-rol{color:var(--txt2,#9aa3b5)}
      .tv-iki{display:flex;gap:8px;flex-wrap:wrap}
      .tv-iki .btn{flex:1;min-width:130px;margin:0}
      .tv-satir{padding:9px 0;border-bottom:1px solid var(--line2);overflow-wrap:anywhere}
      .tv-satir:last-child{border-bottom:0}
      .tv-satir .btn{margin-top:6px}
      .tv-izl{margin:8px 0 0;font-size:14px;line-height:1.6;overflow-wrap:anywhere}
      .tv-sponsor{font-size:13px;color:var(--txt2,#9aa3b5);margin-top:6px;overflow-wrap:anywhere}
      .tv-yaz{width:100%;min-height:64px;resize:vertical}`;
    document.head.appendChild(s);
  }

  /* ------------------------------------------------------------------ ortak parçalar */
  function progZaman(p) {
    if (p.durum === "canli") return p.acik_uclu ? "Sunucu bitirene kadar" : "Bitiş " + saatYaz(p.bit);
    if (p.durum === "planli") return tarihSaat(p.bas) + (p.acik_uclu ? " · sunucu bitirene kadar" : " – " + saatYaz(p.bit));
    if (p.durum === "iptal") return "İptal edildi";
    return "Bitti · " + tarihSaat(p.bit);
  }
  function progKart(p, kanalGoster) {
    const canli = p.durum === "canli";
    return `<div class="tv-prog"><div>${canli ? '<span class="tv-canli">Canlı</span>' : ""}<b>${e(p.baslik)}</b></div>
      <div class="kucuk">${kanalGoster ? e(p.kanal) + " · " : ""}${e(p.tur_ad)} · sunucu ${e(p.sunucu || "")}${(p.konuklar || []).length ? " · konuklar: " + p.konuklar.map(e).join(", ") : ""}</div>
      <div class="kucuk">${progZaman(p)} · ${p.izleyici} izleyici${p.reklam ? " · " + p.reklam + " reklam" : ""}</div>
      <button class="btn ${canli ? "altin" : "ikinci"}" onclick="tvStudyoAc(${p.id})">${canli ? "Yayını izle" : p.durum === "planli" ? "Programa git" : "Yayın kaydını oku"}</button></div>`;
  }
  window.tvStudyoAc = id => ekranAc(() => window.tvStudyoEkrani(id));
  window.tvKanalAc = id => ekranAc(() => window.tvKanalEkrani(id));
  const yaziyor = kok => { const k = document.getElementById(kok); return !!k && Array.prototype.some.call(k.querySelectorAll("input,textarea"), x => x.type !== "checkbox" && (x.value || "").trim() !== ""); };

  /* ------------------------------------------------------------------ Gündem: öne çıkan TV kartı + canlı rozeti (45 sn önbellek) */
  let rozetOn = { t: 0, d: null };
  const ozetSifirla = () => { rozetOn.t = 0; };
  function gundemKartVeri(d) {
    const o = { id: "tvGundemKart", ikon: "tv", renk: "229,72,77", acik: "#ffb1b5", etiket: "TV Kanalları", git: "Aç", onclick: "ekranAc(tvKanallariEkrani)", canli: false };
    d = d || {};
    if (d.ilk) {
      o.canli = true; o.etiket = d.ilk.kanal + " · " + d.ilk.tur_ad; o.baslik = d.ilk.baslik;
      o.alt = `${d.ilk.izleyici} kişi izliyor · sunucu ${d.ilk.sunucu || ""}${Number(d.canli) > 1 ? " · " + (d.canli - 1) + " canlı yayın daha" : ""}`;
      o.git = "İzle"; o.onclick = "tvStudyoAc(" + Number(d.ilk.id) + ")";
    } else if (Number(d.davet) > 0) {
      o.baslik = d.davet + " program davetin var"; o.alt = "Bir TV programına konuk olarak çağrıldın; yanıtını bekliyorlar."; o.git = "Yanıtla";
    } else if (Number(d.teklif) > 0) {
      o.baslik = "Sunuculuk teklifin var"; o.alt = "Bir TV kanalı sana günlük ücretle sunuculuk teklif etti."; o.git = "Yanıtla";
    } else if (d.siradaki) {
      o.etiket = "TV Kanalları · yayın akışı"; o.baslik = tarihSaat(d.siradaki.bas) + " · " + d.siradaki.baslik;
      o.alt = `${d.siradaki.kanal} · ${d.siradaki.tur_ad}${Number(d.yakinda) > 1 ? " · " + d.yakinda + " program planlandı" : ""}`; o.git = "Akış";
    } else {
      o.baslik = "Canlı yayınlar ve siyasi düellolar";
      o.alt = Number(d.kanal) > 0 ? `${d.kanal} kanal var; şu an yayın yok. Yayın akışına bak ya da kendi kanalını kur.` : "Henüz kanal yok. İlk TV kanalını sen kur; program yap, reklam al.";
    }
    return o;
  }
  const gundemde = () => { try { const h = document.querySelector("header.ust h1"); return D.sekme === "gundem" && !(D.yigin || []).length && !!h && h.textContent.trim() === "Gündem"; } catch (_) { return false; } };
  function gundemKartKoy(d) {
    if (!window.SO_ONE_CIKAN || !gundemde()) return;
    window.SO_ONE_CIKAN.koy(gundemKartVeri(d), ic => {
      const hz = ic.querySelector('.pa-hizli[data-pa-hizli="gundem"]'); if (hz) return { el: hz, yer: "afterend" };
      const ks = ic.querySelector(".so-gundem-kisa"); if (ks) return { el: ks, yer: "beforebegin" };
      return { el: ic, yer: "afterbegin" };
    });
  }
  window.tvGundemRozet = async function () {
    const yaz = d => { if (!d) return; const h = Number(d.canli) > 0 || d.ilk ? '<span class="tv-canli" style="margin:0 0 0 4px">Canlı</span>' : "";
      document.querySelectorAll(".tv-gundem-rozet").forEach(el => { if (el.innerHTML !== h) el.innerHTML = h; }); };
    try {
      stil();
      if (window.SO_ONE_CIKAN) window.SO_ONE_CIKAN.tekrarla(() => gundemKartKoy(rozetOn.d));
      yaz(rozetOn.d);
      if (rozetOn.d && Date.now() - rozetOn.t < 45000) return;
      rozetOn = { t: Date.now(), d: rozetOn.d };
      const d = await rpc("tv_canli_ozet"); rozetOn = { t: Date.now(), d }; yaz(d); gundemKartKoy(d);
    } catch (_) {}
  };

  /* ------------------------------------------------------------------ ana ekran */
  window.tvKanallariEkrani = async function () {
    stil();
    if (!document.getElementById("tvKok")) yukleniyor("TV Kanalları");
    let d; try { d = await rpc("tv_liste"); } catch (err) { return hataEkran("TV Kanalları", err); }
    const teklif = d.sunucu_teklif || [], davet = d.davetlerim || [], canli = d.canli || [], yakinda = d.yakinda || [], biten = d.biten || [], kanallar = d.kanallar || [], sun = d.sunuculuk || [];
    iskelet("TV Kanalları", `<div id="tvKok">
      ${teklif.map(x => `<section class="kart" style="border:2px solid var(--gold)"><h2>Sunuculuk teklifi</h2>
        <p class="alt"><b>${e(x.kanal)}</b> (sahibi ${e(x.sahip)}) sana günlük <b>${tl(x.gunluk_ucret)}</b> ücretle sunuculuk teklif ediyor. Ücret her gün kanal kasasından cüzdanına ödenir; dilediğinde ayrılabilirsin.</p>
        <div class="tv-iki"><button class="btn altin" onclick="tvSunucuYanit(${x.kanal_id},true)">Kabul et</button><button class="btn ikinci" onclick="tvSunucuYanit(${x.kanal_id},false)">Reddet</button></div></section>`).join("")}
      ${davet.length ? `<section class="kart" style="border:2px solid var(--gold)"><h2>Program davetlerin</h2>${davet.map(p => `<div class="tv-prog"><b>${e(p.baslik)}</b>
        <div class="kucuk">${e(p.kanal)} · ${e(p.tur_ad)} · sunucu ${e(p.sunucu || "")} · ${progZaman(p)}</div>
        <div class="tv-iki" style="margin-top:8px"><button class="btn altin" onclick="tvKonukYanit(${p.id},true,true)">Katılıyorum</button><button class="btn ikinci" onclick="tvKonukYanit(${p.id},false,true)">Katılamam</button></div></div>`).join("")}</section>` : ""}
      <section class="kart"><h2>Şu an yayında</h2>${canli.map(p => progKart(p, true)).join("") || bos("Şu an canlı yayın yok.")}</section>
      <section class="kart"><h2>Yayın akışı</h2><p class="alt">Planlanan programlar. Saati gelince yayın kendiliğinden başlar.</p>${yakinda.map(p => progKart(p, true)).join("") || bos("Planlanmış program yok.")}</section>
      ${d.kanalim ? `<section class="kart"><h2>Kanalım</h2><p class="alt"><b>${e(d.kanalim.ad)}</b> kanalının sahibisin. Program aç, sunucu al, reklamları onayla.</p>
          <button class="btn altin" onclick="tvKanalAc(${d.kanalim.id})">Kanalımı yönet</button></section>`
        : `<section class="kart"><h2>TV kanalı kur</h2>
          <p class="alt">Kendi kanalını kur; canlı programlar ve siyasi düellolar düzenle, maaşlı sunucu çalıştır, yayınlarına reklam alıp para kazan. Yayın lisansı <b>${tl(d.kur_ucret)}</b>, cüzdanından ödenir.</p>
          <div class="alan"><label for="tvKAd">Kanal adı</label><input id="tvKAd" maxlength="40" placeholder="Örn. Başkent TV"></div>
          <div class="alan"><label for="tvKSlogan">Slogan (isteğe bağlı)</label><input id="tvKSlogan" maxlength="120"></div>
          <button class="btn altin" onclick="tvKanalKur()">Kanalı kur</button></section>`}
      ${sun.length ? `<section class="kart"><h2>Sunuculuk yaptığım kanallar</h2>${sun.map(x => `<div class="tv-satir"><b>${e(x.kanal)}</b> <span class="kucuk">günlük ${tl(x.gunluk_ucret)}</span>
          <button class="btn ikinci" onclick="tvKanalAc(${x.kanal_id})">Kanala git, program aç</button></div>`).join("")}</section>` : ""}
      <section class="kart"><h2>Kanallar <span class="kucuk">${kanallar.length}</span></h2>${kanallar.map(k => `<div class="tv-satir">${k.canli ? '<span class="tv-canli">Canlı</span>' : ""}<b>${e(k.ad)}</b>
          <span class="kucuk">sahibi ${e(k.sahip)} · ${k.program} program · ${k.toplam_izleyici} izlenme</span>${k.slogan ? `<div class="kucuk">${e(k.slogan)}</div>` : ""}
          <button class="btn ikinci" onclick="tvKanalAc(${k.id})">Kanalı aç</button></div>`).join("") || bos("Henüz kurulmuş kanal yok. İlk kanalı sen kur.")}</section>
      <section class="kart"><h2>Biten programlar</h2>${biten.map(p => progKart(p, true)).join("") || bos("Henüz biten program yok.")}</section>
    </div>`, { geri: D.yigin.length > 0 });
    const taz = async () => { if (!document.getElementById("tvKok") || document.hidden || $("#modal") || yaziyor("tvKok")) return; window.tvKanallariEkrani(); };
    if (window.CANLI && CANLI.izle) CANLI.izle({ anahtarlar: [], tazele: taz, hizliMs: 30000, yedekMs: 30000, yayilim: 3000 });
  };

  const anaCalis = async (fn, basari, sonra) => { try { const r = await fn(); ozetSifirla(); if (basari) toast(typeof basari === "function" ? basari(r) : basari); if (sonra) await sonra(r); else await yenidenCiz(); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvKanalKur = async () => {
    const ad = ($("#tvKAd").value || "").trim(), sl = ($("#tvKSlogan").value || "").trim();
    if (ad.length < 3) return toast("Kanal adı en az 3 karakter olmalı.", true);
    if (!await onayla("TV kanalı kur", `"${e(ad)}" kanalı kurulacak. Yayın lisansı ${tl(250000)} cüzdanından alınır ve iade edilmez.`, "Kanalı kur")) return;
    return anaCalis(() => rpc("tv_kanal_kur", { p_ad: ad, p_slogan: sl || null }), "Kanalın kuruldu.", r => { $("#tvKAd").value = ""; $("#tvKSlogan").value = ""; window.tvKanalAc(r.id); });
  };
  window.tvSunucuYanit = (kanal, kabul) => anaCalis(() => rpc("tv_sunucu_yanit", { p_kanal: kanal, p_kabul: kabul }), kabul ? "Sunuculuk sözleşmen başladı." : "Teklif reddedildi.");
  window.tvKonukYanit = (prog, kabul, listeden) => anaCalis(() => rpc("tv_konuk_yanit", { p_program: prog, p_kabul: kabul }), kabul ? "Programa konuk oldun." : "Davet reddedildi.",
    listeden && kabul ? () => window.tvStudyoAc(prog) : null);

  /* ------------------------------------------------------------------ kanal ekranı */
  window.tvKanalEkrani = async function (id) {
    stil();
    if (!document.getElementById("tvKanalKok")) yukleniyor("TV kanalı");
    let d; try { d = await rpc("tv_kanal_detay", { p_kanal: id }); } catch (err) { return hataEkran("TV kanalı", err); }
    const sunucular = d.sunucular || [], aktifSun = sunucular.filter(s => s.durum === "aktif"), ben = benimKad();
    const benSunucu = !d.benim && aktifSun.some(s => s.kad === ben);
    const programlar = d.programlar || [], gecmis = d.gecmis || [], bekleyen = d.bekleyen_reklam || [];
    const yonetim = d.benim ? `
      <section class="kart" style="border:2px solid var(--gold)"><h2>Kanal kasası</h2>
        <p class="alt">Reklam gelirleri kasaya girer, sunucu ücretleri kasadan ödenir. Kasadaki parayı cüzdanına çekebilirsin.</p>
        ${kv("Kasa", "<b>" + tl(d.kasa) + "</b>")}
        <div class="alan" style="margin-top:8px"><label for="tvKasaT">Tutar (₺)</label><input id="tvKasaT" type="number" inputmode="numeric" min="100" step="100"></div>
        <div class="tv-iki"><button class="btn ikinci" onclick="tvKasa(${d.id},'yatir')">Kasaya yatır</button><button class="btn altin" onclick="tvKasa(${d.id},'cek')">Cüzdanıma çek</button></div>
        ${(d.hareketler || []).length ? `<details style="margin-top:10px"><summary class="kucuk" style="cursor:pointer">Kasa hareketleri</summary>${d.hareketler.map(h => kv(e(h.aciklama || "") + " · " + tarihSaat(h.zaman), tl(h.tutar))).join("")}</details>` : ""}</section>
      <section class="kart"><h2>Reklam</h2>
        <p class="alt">Reklamverenler programlarına bütçeli reklam verir; sen onaylarsın. Program bitince izleyici sayısı × birim ücret kadar (en çok bütçe) kazanırsın; %${d.reklam_vergisi} reklam vergisi kesilir.</p>
        <div class="alan"><label for="tvUcret">İzleyici başına reklam ücreti (₺, 50 – 2.000)</label><input id="tvUcret" type="number" inputmode="numeric" min="50" max="2000" step="10" data-ilk="${Number(d.izleyici_ucret)}" placeholder="${Number(d.izleyici_ucret)}"></div>
        <div class="alan"><label for="tvSlogan">Slogan</label><input id="tvSlogan" maxlength="120" placeholder="${e(d.slogan || "Slogan yaz")}"></div>
        <button class="btn ikinci" onclick="tvAyar(${d.id})">Kaydet</button>
        <h3 style="margin-top:14px">Onay bekleyen reklam talepleri</h3>
        ${bekleyen.map(r => `<div class="tv-satir"><b>${e(r.marka)}</b> <span class="kucuk">${e(r.sirket || r.veren)} · bütçe ${tl(r.butce)} · izleyici başına ${tl(r.birim)}</span>
          <div class="kucuk">"${e(r.metin)}" · program: ${e(r.program)} (${tarihSaat(r.program_bas)})</div>
          <div class="tv-iki" style="margin-top:6px"><button class="btn altin" onclick="tvReklamKarar(${r.id},true,${d.id})">Onayla</button><button class="btn ikinci" onclick="tvReklamKarar(${r.id},false,${d.id})">Reddet</button></div></div>`).join("") || bos("Bekleyen reklam talebi yok.")}</section>
      <section class="kart"><h2>Sunucular</h2>
        <p class="alt">Bir oyuncuya günlük ücretle sunuculuk teklif et. Kabul ederse ücreti her gün kanal kasasından ödenir; kasa yetmezse sözleşme sona erer.</p>
        ${sunucular.map(s => `<div class="tv-satir">${kisi(s)} <span class="kucuk">${s.durum === "aktif" ? "sunucu · " + tarih(s.bas) + " tarihinden beri" : "teklif bekliyor"} · günlük ${tl(s.gunluk_ucret)}${s.durum === "aktif" ? " · toplam " + tl(s.toplam) : ""}</span>
          <button class="btn ikinci" onclick="tvSunucuCikar(${d.id},'${e(s.kad)}',${s.durum === "aktif"})">${s.durum === "aktif" ? "Sözleşmeyi bitir" : "Teklifi geri çek"}</button></div>`).join("") || bos("Henüz sunucu yok; programları kendin sunabilirsin.")}
        <div class="alan" style="margin-top:10px"><label for="tvSunKad">Kullanıcı adı</label><input id="tvSunKad" autocapitalize="off" maxlength="40"></div>
        <div class="alan"><label for="tvSunUcret">Günlük ücret (₺, 500 – 100.000)</label><input id="tvSunUcret" type="number" inputmode="numeric" min="500" max="100000" step="100"></div>
        <button class="btn ikinci" onclick="tvSunucuTeklif(${d.id})">Sunuculuk teklif et</button></section>` : "";
    const programAc = d.yayinciyim ? `
      <section class="kart" style="border:2px solid var(--gold)"><h2>Program aç</h2>
        <p class="alt">Başlangıcı boş bırakırsan yayın hemen başlar. Tarih ve saat seçersen program yayın akışına girer ve saati gelince kendiliğinden başlar. Konukları programı açtıktan sonra çağırırsın.</p>
        <div class="alan"><label for="tvTur">Tür</label><select id="tvTur"><option value="duello">Siyasi düello (izleyici oylamalı)</option><option value="soylesi">Söyleşi</option><option value="haber">Haber programı</option></select></div>
        <div class="alan"><label for="tvBaslik">Başlık</label><input id="tvBaslik" maxlength="90" placeholder="Örn. Ekonomi düellosu"></div>
        <div class="alan"><label for="tvAcik">Kısa açıklama (isteğe bağlı)</label><input id="tvAcik" maxlength="300"></div>
        <div class="alan"><label for="tvBas">Başlangıç (cihazının saatine göre; boş = hemen)</label><input id="tvBas" type="datetime-local"></div>
        <div class="alan"><label for="tvSure">Süre</label><select id="tvSure">${SURELER.map(s => `<option value="${s[0]}"${s[0] === 30 ? " selected" : ""}>${s[1]}</option>`).join("")}<option value="">Sunucu bitirene kadar (en çok 3 saat)</option></select></div>
        ${d.benim && aktifSun.length ? `<div class="alan"><label for="tvSun">Sunucu</label><select id="tvSun"><option value="">Ben sunacağım</option>${aktifSun.map(s => `<option value="${e(s.kad)}">${e(s.kad)}</option>`).join("")}</select></div>` : ""}
        <button class="btn altin" onclick="tvProgramAc(${d.id})">Programı aç</button></section>` : "";
    iskelet(d.ad, `<div id="tvKanalKok">
      <section class="kart"><h2>${e(d.ad)}</h2>${d.slogan ? `<p class="alt">${e(d.slogan)}</p>` : ""}
        ${kv("Sahibi", kisi(d.sahip))}${kv("Kuruluş", tarih(d.kurulus))}${kv("İzleyici başına reklam ücreti", tl(d.izleyici_ucret))}
        ${kv("Sunucular", aktifSun.map(s => e(s.kad)).join(", ") || "—")}
        ${benSunucu ? `<button class="btn ikinci" style="margin-top:8px" onclick="tvSunucuAyril(${d.id})">Sunuculuktan ayrıl</button>` : ""}</section>
      <section class="kart"><h2>Yayın akışı</h2>${programlar.map(p => progKart(p, false)).join("") || bos("Planlanmış ya da süren program yok.")}</section>
      ${programAc}${yonetim}
      <section class="kart"><h2>Geçmiş programlar</h2>${gecmis.map(p => progKart(p, false)).join("") || bos("Henüz biten program yok.")}</section>
    </div>`, { geri: true });
  };
  const kanalCalis = async (id, fn, basari) => { try { const r = await fn(); ozetSifirla(); if (basari) toast(basari); await window.tvKanalEkrani(id); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvKasa = async (id, yon) => {
    const el = $("#tvKasaT"), t = Math.round(Number(el.value) || 0); if (t < 100) return toast("En az 100 ₺ gir.", true);
    el.value = "";
    return kanalCalis(id, () => rpc("tv_kasa", { p_kanal: id, p_yon: yon, p_tutar: t }), yon === "yatir" ? tl(t) + " kasaya yatırıldı." : tl(t) + " cüzdanına geçti.");
  };
  window.tvAyar = id => {
    const u = $("#tvUcret"), s = $("#tvSlogan"), uv = (u.value || "").trim(), sv = (s.value || "").trim();
    if (!uv && !sv) return toast("Değiştirmek istediğin alanı doldur.", true);
    u.value = ""; s.value = "";
    return kanalCalis(id, () => rpc("tv_kanal_ayar", { p_kanal: id, p_slogan: sv || null, p_izleyici_ucret: uv ? Number(uv) : null }), "Kaydedildi.");
  };
  window.tvReklamKarar = (rid, onay, kanal) => kanalCalis(kanal, () => rpc("tv_reklam_karar", { p_reklam: rid, p_onay: onay }), onay ? "Reklam onaylandı." : "Reklam reddedildi, bütçe iade edildi.");
  window.tvSunucuTeklif = id => {
    const k = $("#tvSunKad"), u = $("#tvSunUcret"), kad = (k.value || "").trim(), uc = Math.round(Number(u.value) || 0);
    if (!kad || uc < 500) return toast("Kullanıcı adı ve en az 500 ₺ günlük ücret gir.", true);
    k.value = ""; u.value = "";
    return kanalCalis(id, () => rpc("tv_sunucu_teklif", { p_kanal: id, p_kad: kad, p_gunluk: uc }), "Teklif gönderildi.");
  };
  window.tvSunucuCikar = async (id, kad, aktif) => {
    if (aktif && !await onayla("Sözleşmeyi bitir", `${e(kad)} ile sunuculuk sözleşmesi sona erecek.`, "Bitir", true)) return;
    return kanalCalis(id, () => rpc("tv_sunucu_bitir", { p_kanal: id, p_kad: kad }), aktif ? "Sözleşme sona erdi." : "Teklif geri çekildi.");
  };
  window.tvSunucuAyril = async id => { if (!await onayla("Sunuculuktan ayrıl", "Bu kanaldaki sunuculuk sözleşmen sona erecek.", "Ayrıl", true)) return; return kanalCalis(id, () => rpc("tv_sunucu_bitir", { p_kanal: id, p_kad: null }), "Kanaldan ayrıldın."); };
  window.tvProgramAc = async id => {
    const baslik = ($("#tvBaslik").value || "").trim(), bas = $("#tvBas").value, sure = $("#tvSure").value, sun = $("#tvSun") ? $("#tvSun").value : "";
    if (baslik.length < 4) return toast("Program başlığı en az 4 karakter olmalı.", true);
    let basIso = null;
    if (bas) { const t = new Date(bas); if (isNaN(t.getTime())) return toast("Başlangıç tarihi geçersiz.", true); basIso = t.toISOString(); }
    try {
      const r = await rpc("tv_program_ac", { p_kanal: id, p_tur: $("#tvTur").value, p_baslik: baslik, p_aciklama: ($("#tvAcik").value || "").trim() || null,
        p_bas: basIso, p_dakika: sure ? Number(sure) : null, p_sunucu: sun || null });
      $("#tvBaslik").value = ""; $("#tvAcik").value = ""; $("#tvBas").value = ""; ozetSifirla();
      toast(r.durum === "canli" ? "Yayın başladı." : "Program yayın akışına eklendi.");
      window.tvStudyoAc(r.id);
    } catch (err) { toast(hataCevir(err.message), true); }
  };

  /* ------------------------------------------------------------------ stüdyo (yayın) ekranı */
  function mesajHtml(m) {
    if (m.rol === "reklam") return `<div class="tv-mesaj reklam"><span class="tv-rol">Reklam</span><p>${e(m.metin)}</p></div>`;
    return `<div class="tv-mesaj ${m.rol === "konuk" ? "konuk" : "sunucu"}"><span class="tv-rol">${ROL[m.rol] || ""}</span>${kisi(m.kisi)} <span class="kucuk">${saatYaz(m.zaman)}</span><p>${e(m.metin)}</p></div>`;
  }
  const odaHtml = d => (d.mesajlar || []).map(mesajHtml).join("") || bos(d.durum === "planli" ? "Yayın henüz başlamadı." : d.durum === "iptal" ? "Program iptal edildi." : "Henüz söz alınmadı.");
  function sayacHtml(d) {
    const z = d.izleyiciler || {};
    return `${d.durum === "canli" ? `<b>${z.anlik || 0}</b> kişi izliyor · toplam ${z.toplam || 0} izleyici` : `${z.toplam || 0} izleyici`} · ${d.alkis} alkış · ${d.yuh} yuh`;
  }
  function izleyiciHtml(d) {
    const z = d.izleyiciler || {}, l = z.liste || [], n = d.durum === "canli" ? (z.anlik || 0) : (z.toplam || 0);
    return `<details ${window._tvIzlAcik ? "open" : ""} ontoggle="window._tvIzlAcik=this.open"><summary style="cursor:pointer"><b>${d.durum === "canli" ? "Şu an izleyenler" : "İzleyenler"} (${n})</b></summary>
      <p class="tv-izl">${l.map(e).join(" · ") || "Henüz izleyici yok."}${n > l.length ? ` · ve ${n - l.length} kişi daha` : ""}</p></details>`;
  }
  const konusmaci = d => d.rolum === "sunucu" || d.rolum === "konuk";
  function tepkiHtml(d) {
    const acik = !konusmaci(d) && (d.durum === "canli" || (d.durum === "bitti" && d.oy_penceresi));
    if (!acik) return "";
    return `<div class="tv-iki" style="margin-bottom:10px"><button class="btn ${d.tepkim === "alkis" ? "altin" : "ikinci"}" onclick="tvTepki(${d.id},'alkis')">Alkışla</button><button class="btn ${d.tepkim === "yuh" ? "tehlike" : "ikinci"}" onclick="tvTepki(${d.id},'yuh')">Yuhala</button></div>`;
  }
  function oyHtml(d) {
    const kabul = (d.konuk_liste || []).filter(k => k.durum === "kabul");
    if (d.tur !== "duello" || !kabul.length) return "";
    if (d.oy_acik && !konusmaci(d)) return `<section class="kart"><h2>En ikna edici kim?</h2>${kabul.map(k => `<button class="btn ${d.oyum === k.kad ? "altin" : "ikinci"}" onclick="tvOyla(${d.id},'${e(k.kad)}')">${e(k.kad)} · ${k.oy} oy</button>`).join("")}
      <p class="kucuk">Oylama, düello bittikten 15 dakika sonra kapanır. Oyunu değiştirebilirsin.</p></section>`;
    return `<section class="kart"><h2>İzleyici oylaması</h2>${kabul.slice().sort((a, b) => b.oy - a.oy).map(k => kv(e(k.kad), k.oy + " oy")).join("")}
      ${d.oy_acik ? '<p class="kucuk">Oylama sürüyor; sunucu ve konuklar oy kullanamaz.</p>' : d.durum === "bitti" ? '<p class="kucuk">Oylama kapandı.</p>' : ""}</section>`;
  }
  const imza = d => [d.durum, d.rolum, (d.konuk_liste || []).map(k => k.kad + ":" + k.durum).join(","), (d.reklamlarim || []).map(r => r.id + ":" + r.durum).join(","), (d.reklamlar || []).length, d.oy_acik ? 1 : 0].join("|");
  const hazirla = d => { d.oy_penceresi = d.durum === "bitti" && simdi() < new Date(d.bit).getTime() + 15 * 60e3; return d; };

  function kismiGuncelle(d) {
    const oda = document.getElementById("tvOda");
    if (oda && Number(oda.dataset.n) !== (d.mesajlar || []).length) {
      const dipte = oda.scrollHeight - oda.scrollTop - oda.clientHeight < 60;
      oda.innerHTML = odaHtml(d); oda.dataset.n = (d.mesajlar || []).length;
      if (dipte) oda.scrollTop = oda.scrollHeight;
    }
    const yaz = (id, html) => { const el = document.getElementById(id); if (el && el.innerHTML !== html) el.innerHTML = html; };
    yaz("tvSayac", sayacHtml(d)); yaz("tvIzl", izleyiciHtml(d)); yaz("tvTepkiK", tepkiHtml(d)); yaz("tvOyK", oyHtml(d));
  }

  window.tvStudyoEkrani = async function (id, hazir) {
    stil();
    if (window._tvStudyoId !== id || !document.getElementById("tvStudyo")) yukleniyor("TV yayını");
    let d = hazir; if (!d) { try { d = await rpc("tv_detay", { p_program: id }); } catch (err) { return hataEkran("TV yayını", err); } }
    hazirla(d);
    window._tvStudyoId = id;
    const canli = d.durum === "canli", planli = d.durum === "planli", acik = canli || planli;
    const yetkili = d.rolum === "sunucu" || d.kanal_sahibi;
    const konuklar = d.konuk_liste || [], reklamlar = d.reklamlar || [], benimRek = d.reklamlarim || [];
    const aktifRek = benimRek.some(r => r.durum === "bekliyor" || r.durum === "onay");
    const REK_DURUM = { bekliyor: "Onay bekliyor", onay: "Onaylandı", ret: "Reddedildi, bütçe iade edildi", iptal: "İptal edildi, bütçe iade edildi", yayinlandi: "Yayınlandı", iade: "Bütçe iade edildi" };
    iskelet(d.kanal || "TV yayını", `<div id="tvStudyo" data-imza="${e(imza(d))}">
      <section class="kart"><h2>${canli ? '<span class="tv-canli">Canlı</span>' : ""}${e(d.baslik)}</h2>
        <p class="alt"><button class="kucuk" style="background:none;border:0;padding:0;color:var(--gold2);font-weight:750" onclick="tvKanalAc(${d.kanal_id})">${e(d.kanal)}</button> · ${e(d.tur_ad)} · sunucu ${kisi(d.sunucu_kisi)}</p>
        ${d.aciklama ? `<p class="kucuk">${e(d.aciklama)}</p>` : ""}
        <p class="kucuk">${planli ? "Başlangıç " + tarihSaat(d.bas) + (d.acik_uclu ? " · sunucu bitirene kadar" : " · bitiş " + saatYaz(d.bit)) + " (kalan " + kalan(new Date(d.bas).getTime() - simdi()) + ")" : progZaman(d)}</p>
        <p class="kucuk" id="tvSayac">${sayacHtml(d)}</p>
        ${konuklar.length ? `<div class="kucuk" style="margin-top:4px">Konuklar: ${konuklar.map(k => `${e(k.kad)}${k.durum === "kabul" ? "" : k.durum === "davet" ? " (davetli)" : " (katılmıyor)"}`).join(" · ")}</div>` : ""}
        ${reklamlar.length ? `<div class="tv-sponsor">Bu yayının reklamverenleri: ${reklamlar.map(r => e(r.marka)).join(" · ")}</div>` : ""}</section>
      ${d.rolum === "davetli" && acik ? `<section class="kart" style="border:2px solid var(--gold)"><b>Bu programa konuk olarak davetlisin.</b>
        <div class="tv-iki" style="margin-top:8px"><button class="btn altin" onclick="tvKonukYanit(${d.id},true)">Katılıyorum</button><button class="btn ikinci" onclick="tvKonukYanit(${d.id},false)">Katılamam</button></div></section>` : ""}
      <section class="kart"><div class="tv-oda" id="tvOda" data-n="${(d.mesajlar || []).length}">${odaHtml(d)}</div></section>
      ${canli && konusmaci(d) ? `<section class="kart"><textarea class="tv-yaz" id="tvYaz" maxlength="600" placeholder="${d.rolum === "sunucu" ? "Yayını yönet, soru sor…" : "Söz al…"}"></textarea>
        <button class="btn altin" id="tvYazB" onclick="tvYaz(${d.id})">Gönder</button></section>` : ""}
      <div id="tvTepkiK">${tepkiHtml(d)}</div>
      <div id="tvOyK">${oyHtml(d)}</div>
      <section class="kart" id="tvIzl">${izleyiciHtml(d)}</section>
      ${yetkili && acik ? `<section class="kart"><h2>Yayın yönetimi</h2>
        <div class="alan"><label for="tvKonukKad">Konuk çağır (kullanıcı adı, en çok 6 konuk)</label><input id="tvKonukKad" autocapitalize="off" maxlength="40"></div>
        <div class="tv-iki"><button class="btn ikinci" onclick="tvKonukDavet(${d.id})">Davet gönder</button>
          <button class="btn tehlike" onclick="tvBitir(${d.id},${planli})">${planli ? "Programı iptal et" : "Yayını bitir"}</button></div></section>` : ""}
      ${benimRek.length ? `<section class="kart"><h2>Reklamım</h2>${benimRek.map(r => `<div class="tv-satir"><b>${e(r.marka)}</b> <span class="kucuk">${e(r.sirket || "cüzdanımdan")} · bütçe ${tl(r.butce)} · ${REK_DURUM[r.durum] || r.durum}${r.durum === "yayinlandi" ? " · ödenen " + tl(r.odenen) + ", iade " + tl(r.iade) : ""}</span>
          ${r.durum === "bekliyor" || (r.durum === "onay" && planli) ? `<button class="btn ikinci" onclick="tvReklamIptal(${r.id},${d.id})">Reklamı iptal et, bütçeyi geri al</button>` : ""}</div>`).join("")}</section>` : ""}
      ${acik && !d.kanal_sahibi && !aktifRek ? `<section class="kart"><details id="tvRekD" ontoggle="if(this.open)tvReklamKaynak(${d.id})"><summary style="cursor:pointer"><b>Bu programa reklam ver</b></summary>
        <p class="alt" style="margin-top:8px">İzleyici başına <b>${tl(d.izleyici_ucret)}</b> ödenir. Bütçe peşin ayrılır; program bitince izleyici sayısı kadarı kanala ödenir, kalanı sana iade edilir. Kanal sahibi onaylayınca reklamın yayında görünür; onaylanmazsa bütçenin tamamı geri döner.</p>
        <div class="alan"><label for="tvRMarka">Marka ya da ad</label><input id="tvRMarka" maxlength="40"></div>
        <div class="alan"><label for="tvRMetin">Reklam metni</label><input id="tvRMetin" maxlength="200"></div>
        <div class="alan"><label for="tvRButce">Bütçe (₺, 5.000 – 5.000.000)</label><input id="tvRButce" type="number" inputmode="numeric" min="5000" max="5000000" step="1000" oninput="tvReklamOzet(${Number(d.izleyici_ucret)})"></div>
        <div class="alan"><label for="tvRKaynak">Ödeme kaynağı</label><select id="tvRKaynak"><option value="">Cüzdanım</option></select></div>
        <div class="kucuk" id="tvROzet"></div>
        <button class="btn altin" style="margin-top:8px" onclick="tvReklamVer(${d.id})">Reklam talebi gönder</button></details></section>` : ""}
    </div>`, { geri: true });
    const kok = document.getElementById("tvStudyo");
    if (!kok || kok.dataset.imza !== imza(d)) return;      // çizim ertelendi (oyuncu meşgul); zamanlayıcı yeniden dener
    const oda = $("#tvOda"); if (oda) oda.scrollTop = oda.scrollHeight;
    const ta = $("#tvYaz");
    if (ta) ta.onkeydown = ev => { if (ev.key === "Enter" && !ev.shiftKey && window.matchMedia && matchMedia("(pointer:fine)").matches) { ev.preventDefault(); window.tvYaz(id); } };
    if (acik || d.oy_penceresi) {
      const taz = async () => {
        if (window._tvStudyoId !== id || !document.getElementById("tvStudyo") || document.hidden) return;
        let y; try { y = hazirla(await rpc("tv_detay", { p_program: id })); } catch (_) { return; }
        if (window._tvStudyoId !== id || !document.getElementById("tvStudyo")) return;
        const k = document.getElementById("tvStudyo");
        if (imza(y) !== k.dataset.imza && !$("#modal") && (y.durum !== d.durum || !yaziyor("tvStudyo"))) {
          if (y.durum !== d.durum) eylem();                 // yayın başladı / bitti: ekran her durumda yenilenir
          return window.tvStudyoEkrani(id, y);
        }
        kismiGuncelle(y);
      };
      window._tvTaz = taz;
      const basaKalan = planli ? new Date(d.bas).getTime() - simdi() : null;
      if (window.CANLI && CANLI.izle) CANLI.izle({ anahtarlar: ["yayin:tv" + id], tazele: taz, hizliMs: canli ? 5000 : 15000, yedekMs: 20000, yayilim: 1500, pencereMs: 1200,
        sonraMs: basaKalan != null && basaKalan > 0 ? basaKalan + 900 : null });
      else D.canli = setInterval(taz, 6000);
    }
  };
  const studyoCalis = async (id, fn, basari) => { try { const r = await fn(); ozetSifirla(); if (basari) toast(basari); await window.tvStudyoEkrani(id, r && r.rolum ? r : null); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvYaz = async id => {
    const ta = $("#tvYaz"), b = $("#tvYazB"); if (!ta) return;
    const v = (ta.value || "").trim(); if (!v) return;
    if (b) b.disabled = true;
    try { await rpc("tv_yaz", { p_program: id, p_metin: v }); ta.value = ""; if (window._tvTaz) await window._tvTaz(); const oda = $("#tvOda"); if (oda) oda.scrollTop = oda.scrollHeight; }
    catch (err) { toast(hataCevir(err.message), true); }
    const b2 = $("#tvYazB"); if (b2) b2.disabled = false;
    const t2 = $("#tvYaz"); if (t2) t2.focus();
  };
  window.tvTepki = async (id, tur) => { try { kismiGuncelle(hazirla(await rpc("tv_tepki", { p_program: id, p_tur: tur }))); } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvOyla = async (id, kad) => { try { kismiGuncelle(hazirla(await rpc("tv_oyla", { p_program: id, p_kad: kad }))); toast("Oyun kaydedildi."); } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvKonukDavet = id => { const el = $("#tvKonukKad"), k = (el.value || "").trim(); if (!k) return toast("Kullanıcı adı gir.", true); el.value = ""; return studyoCalis(id, () => rpc("tv_konuk_davet", { p_program: id, p_kad: k }), "Davet gönderildi."); };
  window.tvBitir = async (id, planli) => {
    if (!await onayla(planli ? "Programı iptal et" : "Yayını bitir", planli ? "Program iptal edilecek; verilen reklam bütçeleri iade edilir." : "Yayın şimdi sona erecek ve reklam gelirleri hesaplanacak.", planli ? "İptal et" : "Bitir", true)) return;
    return studyoCalis(id, () => rpc("tv_bitir", { p_program: id }), planli ? "Program iptal edildi." : "Yayın sona erdi.");
  };
  window.tvReklamKaynak = async id => {
    const sec = $("#tvRKaynak"); if (!sec || sec.dataset.dolu) return;
    try {
      const k = await rpc("tv_reklam_kaynak", { p_program: id });
      sec.dataset.dolu = "1";
      sec.innerHTML = `<option value="">Cüzdanım (${tl(k.cuzdan)})</option>` + (k.sirketler || []).map(s => `<option value="${s.id}">${e(s.ad)} kasası (${tl(s.kasa)})</option>`).join("");
    } catch (_) {}
  };
  window.tvReklamOzet = birim => {
    const b = Math.round(Number(($("#tvRButce") || {}).value) || 0), o = $("#tvROzet"); if (!o) return;
    o.textContent = b >= 5000 && birim > 0 ? `Bu bütçe en çok ${Math.floor(b / birim).toLocaleString("tr-TR")} izleyiciyi karşılar; daha az izleyici olursa fark iade edilir.` : "";
  };
  window.tvReklamVer = async id => {
    const marka = ($("#tvRMarka").value || "").trim(), metin = ($("#tvRMetin").value || "").trim(), butce = Math.round(Number($("#tvRButce").value) || 0), kaynak = $("#tvRKaynak").value;
    if (marka.length < 2 || metin.length < 5) return toast("Marka en az 2, reklam metni en az 5 karakter olmalı.", true);
    if (butce < 5000) return toast("Reklam bütçesi en az 5.000 ₺ olmalı.", true);
    if (!await onayla("Reklam ver", `${tl(butce)} bütçe ${kaynak ? "şirket kasasından" : "cüzdanından"} ayrılacak. Kullanılmayan kısım program bitince iade edilir.`, "Talebi gönder")) return;
    try {
      const r = await rpc("tv_reklam_ver", { p_program: id, p_marka: marka, p_metin: metin, p_butce: butce, p_sirket: kaynak ? Number(kaynak) : null });
      ["tvRMarka", "tvRMetin", "tvRButce"].forEach(x => { const el = document.getElementById(x); if (el) el.value = ""; });
      toast("Reklam talebin kanal sahibine iletildi."); await window.tvStudyoEkrani(id, r);
    } catch (err) { toast(hataCevir(err.message), true); }
  };
  window.tvReklamIptal = async (rid, id) => { if (!await onayla("Reklamı iptal et", "Reklam talebin geri çekilecek ve bütçenin tamamı iade edilecek.", "İptal et", true)) return; return studyoCalis(id, () => rpc("tv_reklam_iptal", { p_reklam: rid }), "Reklam iptal edildi, bütçe iade edildi."); };
})();
