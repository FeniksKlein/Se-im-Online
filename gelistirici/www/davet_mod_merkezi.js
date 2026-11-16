/* 16.11.2026 · Davet merkezi (oyuncu getirene kademeli ödül) + Moderatör görev alanı ve Finans denetim masası */
(function () {
  const tl = (n) => (typeof tlYaz === "function" ? tlYaz(n) : (Math.round(+n || 0)).toLocaleString("tr-TR") + " ₺");
  const esc = (x) => (typeof e === "function" ? e(x) : String(x == null ? "" : x));

  async function davetEkrani() {
    yukleniyor("Davet et, kazan");
    let b, a;
    try { [b, a] = await Promise.all([API.rpc("davet_bilgim"), API.rpc("davet_aktiflik_bilgim")]); }
    catch (err) { iskelet("Davet et, kazan", `<div class="bos">${esc(hataCevir(err.message))}</div>`, { geri: true }); return; }
    const ay = b.ayar || {}, s = b.sayilar || {};
    const kademe = (a.kademeler || []).map(k => `<div class="kv"><span class="k">${k.gun} farklı gün aktif</span><span class="v">${tl(k.tutar)}</span></div>`).join("");
    const liste = (a.davetliler || []).map(d => {
      const sonraki = (a.kademeler || []).find(k => k.gun > d.aktif_gun);
      return `<div class="liste-satir"><div class="orta"><b>${esc(d.kad)}</b><div class="kucuk">${d.durum === "odendi" ? "Oy hakkı kazandı" : d.durum === "bekliyor" ? "Oy hakkı bekleniyor" : "Geçersiz"} · ${d.aktif_gun} gün aktif${sonraki ? ` · sonraki ödül ${sonraki.gun}. günde (${tl(sonraki.tutar)})` : ""}${d.alt_davet ? ` · ${d.alt_davet} kişiyi davet etti` : ""}</div></div><span class="rozet">${tl(d.kazanc)}</span></div>`;
    }).join("") || `<div class="bos">Henüz davet ettiğin oyuncu yok.</div>`;
    iskelet("Davet et, kazan", `
      <div class="kart"><h2>Davet kodun</h2>
        <div style="font-size:30px;font-weight:800;letter-spacing:4px;margin:6px 0">${esc(b.kod || "—")}</div>
        <button class="btn altin" id="dvKopya">Kodu kopyala</button>
        <p class="kucuk">Arkadaşın hesabını açtıktan sonraki ${ay.giris_gun || 7} gün içinde bu kodu girer. Oy hakkı kazanınca sana ${tl(ay.odul_eden)}, ona ${tl(ay.odul_edilen)} yatar.</p></div>
      <div class="kart"><h2>Aktiflik ödülleri</h2>
        <p class="kucuk">Davet ettiğin oyuncu oyunda farklı günlerde aktif oldukça sana ek ödül yatar. Onun davet ettiği oyuncular aktif oldukça sana da %${a.ikinci_kademe_oran} pay gelir. Aynı cihazdan açılan hesaplar sayılmaz; haftalık en fazla ${tl(a.haftalik_tavan)}.</p>
        ${kademe}
        <div class="kv"><span class="k">Doğrudan aktiflik kazancı</span><span class="v">${tl(a.toplam_aktiflik)}</span></div>
        <div class="kv"><span class="k">Davet ağı (2. kademe) kazancı</span><span class="v">${tl(a.toplam_ag)}</span></div>
        <div class="kv"><span class="k">Son 7 gün</span><span class="v">${tl(a.son7_gun)} / ${tl(a.haftalik_tavan)}</span></div></div>
      <div class="kart"><h2>Davet ettiklerim (${(s.odendi || 0) + (s.bekliyor || 0)})</h2>${liste}</div>
      ${b.kod_girebilir ? `<div class="kart"><h2>Seni davet eden var mı?</h2><div class="alan"><input id="dvKod" maxlength="8" placeholder="6 haneli davet kodu" autocapitalize="characters"></div><button class="btn" id="dvGir">Kodu gir</button><p class="kucuk">Son gün: ${typeof tarihSaat === "function" ? tarihSaat(b.kod_son) : ""}</p></div>` : ""}
      ${b.beni_davet_eden ? `<div class="kart"><b>Seni davet eden:</b> ${esc(b.beni_davet_eden.kad)} · ${esc(b.beni_davet_eden.durum)}${b.beni_davet_eden.eksik ? `<div class="kucuk">${esc(b.beni_davet_eden.eksik)}</div>` : ""}</div>` : ""}`, { geri: true });
    const k = $("#dvKopya"); if (k) k.onclick = async () => { try { await navigator.clipboard.writeText(b.kod); toast("Davet kodu kopyalandı."); } catch (_) { toast(b.kod); } };
    const g = $("#dvGir"); if (g) g.onclick = async () => { try { await API.rpc("davet_kodu_gir", { p_kod: $("#dvKod").value }); toast("Davet kodu kaydedildi."); davetEkrani(); } catch (err) { toast(hataCevir(err.message), true); } };
  }

  async function finansMasasiEkrani(gun) {
    gun = gun || 7;
    yukleniyor("Finans denetim masası");
    let r;
    try { r = await API.rpc("finans_denetim_ozet", { p_gun: gun }); }
    catch (err) { iskelet("Finans denetim masası", `<div class="bos">${esc(hataCevir(err.message))}</div>`, { geri: true }); return; }
    const kt = r.kredi_toplam || {}, dv = r.davet_odulleri || {};
    const sat = (a, b, c) => `<div class="liste-satir"><div class="orta"><b>${a}</b><div class="kucuk">${b}</div></div><span class="rozet">${c}</span></div>`;
    iskelet("Finans denetim masası", `
      <div class="kart"><div class="satir">${[1, 7, 30].map(g => `<button class="rozet ${g === r.gun ? "yesil" : ""}" data-fg="${g}">${g} gün</button>`).join("")}</div>
        <div class="gosterge" style="margin-top:8px">
          <div><div class="ad">Açık devlet kredisi</div><div class="deger">${tl(kt.devlet_acik)}</div></div>
          <div><div class="ad">Açık banka (oyuncu) kredisi</div><div class="deger">${tl(kt.oyb_acik)}</div></div>
          <div><div class="ad">Açık şirket kredisi</div><div class="deger">${tl(kt.sirket_acik)}</div></div>
          <div><div class="ad">Dönemde kullanılan kredi</div><div class="deger">${tl(kt.donem_kullanim)}</div></div>
          <div><div class="ad">MASAK bekleyen</div><div class="deger ${r.masak_bekleyen ? "kotu" : ""}">${r.masak_bekleyen}</div></div></div>
        <button class="btn altin" onclick="typeof masakEkrani==='function'&&ekranAc(masakEkrani)">MASAK kuyruğunu aç</button></div>
      <div class="kart"><h2>Krediden hemen sonra şirkete sermaye</h2>${(r.kredi_sermaye || []).map(x => sat(esc(x.kad), esc(x.aciklama), tl(x.tutar))).join("") || `<div class="bos">Kayıt yok.</div>`}</div>
      <div class="kart"><h2>En büyük açık krediler</h2>${(r.buyuk_krediler || []).map(x => sat(esc(x.kad), `${esc(x.kaynak)} · ${x.vade_gun} gün · günlük ${tl(x.taksit)} · ${esc(x.durum)}`, tl(x.kalan))).join("") || `<div class="bos">Açık kredi yok.</div>`}</div>
      <div class="kart"><h2>En hızlı servet girişi</h2>${(r.servet_artisi || []).map(x => sat(esc(x.kad), x.kredi ? `bunun ${tl(x.kredi)} kısmı kredi` : "kredi yok", tl(x.giris))).join("") || `<div class="bos">Kayıt yok.</div>`}</div>
      <div class="kart"><h2>Davet ödülleri</h2><div class="kv"><span class="k">Aktiflik ödülleri</span><span class="v">${tl(dv.aktiflik)}</span></div><div class="kv"><span class="k">Kayıt ödülleri</span><span class="v">${tl(dv.kayit)}</span></div>
        ${(dv.en_cok || []).map(x => sat(esc(x.kad), "davet aktiflik ödülü", tl(x.tutar))).join("")}</div>`, { geri: true });
    document.querySelectorAll("[data-fg]").forEach(b => b.onclick = () => finansMasasiEkrani(+b.dataset.fg));
  }

  async function modGorevKarti() {
    const ic = $("#icerik"); if (!ic || ic.querySelector(".dm-gorev")) return;
    let g; try { g = await API.rpc("mod_gorevim"); } catch (_) { return; }
    const yt = typeof yetkim === "function" ? yetkim() : { var_: () => false };
    const kq = g.kuyruk || {};
    const html = `<div class="kart dm-gorev"><h2>${g.yonetici ? "Moderatör görev dağılımı" : "Ana görevim"}</h2>
      ${!g.yonetici ? `<p><b>${esc(g.ad || "Ana görev atanmadı")}</b></p><p class="kucuk">${esc(g.aciklama || "Yönetici sana bir sorumluluk alanı atadığında burada görünür.")}${g.not ? " · Not: " + esc(g.not) : ""}</p>` : ""}
      <div class="kucuk">Ekip: ${(g.ekip || []).map(x => `${esc(x.kad)} (${esc(x.ana_gorev || "görev yok")})`).join(", ") || "moderatör yok"}</div>
      ${yt.var_("ekonomi") ? `<div class="kucuk" style="margin-top:6px">MASAK bekleyen: <b>${kq.masak_yeni || 0}</b> · Kredi sonrası sermaye (7 gün): <b>${kq.kredi_sermaye_7g || 0}</b> · Şüpheli davet (7 gün): <b>${kq.davet_suistimal_7g || 0}</b></div>
        <button class="btn altin" onclick="ekranAc(finansMasasiEkrani)">Finans denetim masası</button>` : ""}</div>`;
    ic.insertAdjacentHTML("afterbegin", html);
  }

  if (typeof iskelet === "function") {
    const eski = iskelet;
    window.iskelet = iskelet = function (baslik) {
      const r = eski.apply(this, arguments);
      try { if (baslik === "Yönetici paneli" || baslik === "Moderatör paneli") modGorevKarti(); } catch (_) {}
      return r;
    };
  }
  window.davetEkrani = davetEkrani;
  window.finansMasasiEkrani = finansMasasiEkrani;
})();
