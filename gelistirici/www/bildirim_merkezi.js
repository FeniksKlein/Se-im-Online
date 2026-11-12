/* =====================================================================
   BİLDİRİM MERKEZİ (2026-10-23) — sürüm 2026.10.23-1
   05.11.2026 (2026.11.05-1) Bildirimler 2.0: sade, tek yüzeyli tasarım —
   "Bekleyen işler" kartı (ilk 3 + "daha", tekrar eden kalıp bir kez,
   "Hepsini gördüm"), tek satırlık "Seçmenlerine seslen" yayın çubuğu,
   yapışkan bölmeli sekme (Tümü · Sana özel · Siyaset · Duyurular · Yayınlar),
   gün gün tek panelde satırlar, konuya göre simge, başlık/gövde ayrımı,
   satıra dokununca ilgili ekrana gitme, 25'erli "Daha fazla göster".
   Sorun: kişisel bildirimler, Meclis duyuruları, grup kararları ve
   propaganda yayınları aynı listeye alt alta düşüyordu. Oyuncu başına
   haftada ~60 bildirim geldiği için süreli işler (kriz masası, savunma,
   jüri, istinaf, kredi gecikmesi, görev ihmali uyarısı, davetler)
   kalabalığın içinde kayboluyordu.

   · Bildirimler ekranı: "Dikkat isteyen" kartı en üstte sabit kalır
     (son 3 gün; oyuncu "Gördüm" diyene kadar), filtre çipleri
     (Tümü · Sana özel · Meclis ve parti · Duyurular · Yayınlar),
     gün başlıkları ve kategoriye göre görsel ağırlık.
   · Oyun açıkken yeni süreli bildirim gelirse üstte kalıcı bant çıkar.
   · Toast: bir öncekini silmek yerine en fazla 3'lü yığın; hata 5 sn,
     başarı mesajı hatayı itip silemez.

   Sunucu: public.bildirim_yeniler(p_limit) — okunmamış kişisel
   bildirimleri okundu İŞARETLEMEDEN döndürür (129_bildirim_merkezi.sql).
   Sunucuda yoksa yalnızca bant devre dışı kalır; ekran yine çalışır.
   Mevcut bildirimEkrani'ni yeniden yazmaz: orijinal ekranı çizdirir,
   sonra aynı öğeleri (dokunma işleyicileriyle birlikte) gruplara taşır.
   Oyun verisine, kurala ya da RPC'ye yazma yapmaz.
   ===================================================================== */
(function () {
  if (window.__bildirimMerkezi) return; window.__bildirimMerkezi = true;

  /* ---------------- Sınıflandırma ---------------- */
  // Sunucu metinlerinin bir kısmı Türkçe harfsiz yazılıyor; ikisini de yakalamak için katlanır.
  const katla = (s) => String(s == null ? "" : s).toLocaleLowerCase("tr-TR")
    .replace(/ı/g, "i").replace(/ş/g, "s").replace(/ğ/g, "g").replace(/ü/g, "u")
    .replace(/ö/g, "o").replace(/ç/g, "c").replace(/[âà]/g, "a").replace(/î/g, "i").replace(/û/g, "u");

  // Sıra önemlidir: önce herkese giden duyurular, sonra kaçırılmış işler, sonra süreli işler.
  const DUYURU_ONCE = /^(cumhurbaskanligi karari|haftanin ozeti|haftalik anket|sponsorlu|yuksek mahkeme)/;
  const KACTI = /karar vermedin|kacirdin|suresi doldu|suresi gecti/;
  // Başkasının mitingi / basın toplantısı: isteğe bağlı davet, süreli iş sayılmaz.
  const GENEL_DAVET = /meydaninda|mitinge katilip|mitingi basladi|basin toplantisi|canli izle/;
  // Hissedar oylamaları süreli ama sık; "Sana özel"de kalır, Dikkat kartını doldurmaz.
  const HISSEDAR = /genel kuruluna onerge geldi/;
  const ACIL = /saat icinde|gun icinde|karar ver|savunma|jurisine|istinafa basv|davada hakkinizda|davalidir|odenemedi|gecikmede|gecikme|yasal takip|haciz|icra takib|icra satis|girmezsen|gorevden alinacak|davet etti|davet ediyor|teklif etti|yanitla(?!nd)|yanitini .{0,40}ver|ruhsat merkezi|onayini bekliyor|onay bekliyor|yanitini bekliyor|iflas edebilir|zarar ediyor|mitingin basladi|teslim etmeniz/;
  const SEN = /(^|[\s"'(])(sen|seni|sana|senin|sizi|size|sizin|hakkinizda|partiniz|partinizin|partin|goreviniz|cezanizi|cezaniz|yetkiniz|sirketiniz|ittifakiniza|adayligin|kredin|kredini|hesabina|hesabin|cuzdan\w*|maasin|statun|payina|uyeligin|makamin|sirketin|paran|gorevin|teklifin|talebin|basvurun|basvurunu)(?=[\s.,;:!?)"'»]|$)|[a-z](din|dun|tin|tun|digin|dugun|tigin|tugun)(?=[\s.,;:!?)"'»]|$)/;
  const OZEL = /genel kurul|temettu|halka arz|bilanco|ihale|karari kesinlesti|mahkeme kararini|basarim|kredi|miting yetkisi|tahsil edildi|yeni siparis|paylasimina yanit verdi|cimer|spk|rekabet kurumu|affetti|cekilmen|kurucu davetine|genel baskansiz|kadrosunda .{0,20}bos|atayabilirsin|satis tamamlandi|ilan meydani/;
  const MECLIS = /grup karari|kanun teklifi|vergi kanunu|anayasa degisikligi|oylama|meclis|tbmm|veto|yasama|grup konusmasi|grup gunu|grup toplantisi|tuzuk|partimize katildi|partimizden ayrildi|birlesti|kurultay|on secim|grup baskanvekil|partisinin adi|genel baskani yeni|teskilatli/;

  function rotaBul(t) {
    // 27.10.2026: bakanlık masası bildirimleri
    if (/^bakanlik: /.test(t)) {
      if (/ilimizde .{0,80}duzenliyor|katilimciyla tamamlandi/.test(t)) return "bk_etkinlik";
      if (/ek odenek istiyor|devlet butcesi/.test(t)) return "butce";
      return "bakanlik";
    }
    if (/^muzayede:/.test(t)) return "muzayede";
    if (/tv kanallari|tv kanali|tv programina|kanalindaki "|kanalinda "|" programi|" programin|sunuculu|studyoya gir|duellosunu/.test(t)) return "tv";
    if (/ticaret odasi|odalar birligi|sendikasi/.test(t)) return "oda";
    if (/valiligi|valilik|vali havuzu/.test(t)) return "valilik";
    if (/gozalti|muvekkil|mudafi/.test(t)) return "gozalti";
    if (/^kursu:|paylasimina yanit verdi/.test(t)) return "kursu";
    if (/ilan meydani|ilanina .{0,40}teklif|ilani icin karsi teklif|ilani baska bir aliciya|ilani yayindan kalkti|ilaninin 30 gunluk|ilanin oyun yonetimi|^satis tamamlandi: |artik senin \(/.test(t)) return "ilan";
    if (/kriz masasi|yonetim ›|yonetim >|ruhsat merkezi/.test(t)) return "yonetim";
    if (/adliye|dava|juri|istinaf|savunma|mahkeme/.test(t)) return "adliye";
    if (/kredi|taksit|vadesiz|banka/.test(t)) return "banka";
    if (/devlet > hukumet|devlet › hukumet/.test(t)) return "devlet";
    if (/meclis|tbmm|kanun teklifi|oylama gunu|anayasa degisikligi|grup karari/.test(t)) return "meclis";
    if (/kurucular kurulu|kurucu davet|genel baskan yardimcisi|parti sozcusu|parti sayfas|ittifak kartindan/.test(t)) return "parti";
    if (/mitingin basladi|gundem'den mitingine/.test(t)) return "gundem";
    return null;
  }
  function kategori(metin) {
    const t = katla(metin);
    let kat;
    if (DUYURU_ONCE.test(t)) kat = "duyuru";
    else if (KACTI.test(t)) kat = "ozel";
    else if (GENEL_DAVET.test(t)) kat = "duyuru";
    else if (HISSEDAR.test(t)) kat = "ozel";
    else if (ACIL.test(t)) kat = "acil";
    else if (SEN.test(t) || OZEL.test(t)) kat = "ozel";
    else if (MECLIS.test(t)) kat = "meclis";
    else kat = "duyuru";
    return { kat, rota: rotaBul(t) };
  }
  window.bmKategori = kategori;

  const ROTA = {
    yonetim: { ad: "Yönetime git", ac: () => sekmeAc("yonetim"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.yonetim === "function" },
    adliye:  { ad: "Adliye'ye git", ac: () => sekmeAc("adliye"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.adliye === "function" },
    banka:   { ad: "Bankaya git", ac: () => ekranAc(bankaEkrani), var: () => typeof bankaEkrani === "function" },
    kursu:   { ad: "Kürsü’ye git", ac: () => ekranAc(() => kursuEkrani("bildirim")), var: () => typeof kursuEkrani === "function" },
    muzayede:{ ad: "Müzayede’ye git", ac: () => ekranAc(muzayedeEkrani), var: () => typeof muzayedeEkrani === "function" },
    tv:      { ad: "TV Kanalları’na git", ac: () => ekranAc(tvKanallariEkrani), var: () => typeof tvKanallariEkrani === "function" },
    oda:     { ad: "Ticaret Odası’na git", ac: () => ekranAc(() => ticaretOdasiEkrani()), var: () => typeof ticaretOdasiEkrani === "function" },
    valilik: { ad: "Valiliğe git", ac: () => ekranAc(valilikEkrani), var: () => typeof valilikEkrani === "function" },
    gozalti: { ad: "Gözaltı ve Avukat", ac: () => ekranAc(gozaltiMerkeziEkrani), var: () => typeof gozaltiMerkeziEkrani === "function" },
    ilan:    { ad: "İlan Meydanı’na git", ac: () => ekranAc(ilanMeydaniEkrani), var: () => typeof ilanMeydaniEkrani === "function" },
    meclis:  { ad: "Meclis'e git", ac: () => sekmeAc("meclis"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.meclis === "function" },
    parti:   { ad: "Partilere git", ac: () => sekmeAc("parti"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.parti === "function" },
    devlet:  { ad: "Devlet'e git", ac: () => sekmeAc("devlet"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.devlet === "function" },
    gundem:  { ad: "Gündem'e git", ac: () => sekmeAc("gundem"), var: () => typeof EKRAN === "object" && EKRAN && typeof EKRAN.gundem === "function" },
    bakanlik:   { ad: "Bakanlık masasına git", ac: () => bakanlikMasamAc(), var: () => typeof bakanlikMasamAc === "function" },
    bk_etkinlik:{ ad: "Etkinliğe git", ac: () => ekranAc(bakanlikEtkinlikleriEkrani), var: () => typeof bakanlikEtkinlikleriEkrani === "function" },
    butce:      { ad: "Devlet bütçesine git", ac: () => ekranAc(devletButcesiEkrani), var: () => typeof devletButcesiEkrani === "function" }
  };
  function rotaGit(r) { try { if (ROTA[r] && ROTA[r].var()) { bantKapat(); ROTA[r].ac(); } } catch (_) {} }
  window.bmRotaGit = rotaGit;

  /* ---------------- Yerel kayıtlar (yalnız bu cihaz) ---------------- */
  const yerel = {
    oku(k, v) { try { const x = JSON.parse(localStorage.getItem(k)); return x == null ? v : x; } catch (_) { return v; } },
    yaz(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (_) {} }
  };
  const GORDUM = "bm_gordum_v1", UYARILDI = "bm_uyarildi_v1", FILTRE = "bm_filtre_v1";
  function kumeEkle(anahtar, idler, ust) {
    const l = yerel.oku(anahtar, []);
    const s = new Set(l.map(String));
    for (const id of idler) if (!s.has(String(id))) { l.push(String(id)); s.add(String(id)); }
    yerel.yaz(anahtar, l.slice(-(ust || 400)));
  }
  const kumede = (anahtar, id) => yerel.oku(anahtar, []).map(String).includes(String(id));

  /* ---------------- Stil ---------------- */
  // 05.11.2026 — Bildirimler 2.0: tek yüzeyli gün grupları, konu simgeleri, sade sekmeler.
  const CSS = `
.bm-isler [hidden],.bm-kap [hidden],.bm-ses [hidden]{display:none!important}
.bm-ust-yeni{margin-left:auto;flex:none;align-self:center;font-size:12.5px;font-weight:750;color:var(--ink2);background:var(--inkbg);border-radius:999px;padding:5px 11px;white-space:nowrap}
/* Bekleyen işler */
.bm-isler{position:relative;border-radius:20px;padding:4px 14px 2px;margin-bottom:12px;background:linear-gradient(180deg,rgba(240,69,75,.11),rgba(240,69,75,.02) 70%),var(--panel);border:1px solid rgba(240,69,75,.26);box-shadow:0 18px 36px -30px rgba(240,69,75,.9)}
.bm-isler.yigin{margin-bottom:26px}
.bm-isler.yigin::before,.bm-isler.yigin::after{content:"";position:absolute;border:1px solid rgba(240,69,75,.2);border-top:0;background:#1a2244;pointer-events:none}
.bm-isler.yigin::before{left:10px;right:10px;bottom:-8px;height:7px;border-radius:0 0 15px 15px}
.bm-isler.yigin::after{left:22px;right:22px;bottom:-14px;height:6px;border-radius:0 0 12px 12px;background:#171f3e;border-color:rgba(240,69,75,.13)}
.bm-isler-bas{display:flex;align-items:center;gap:10px;width:100%;min-height:52px;padding:6px 0;background:none;border:0;color:inherit;text-align:left}
.bm-isler-ik{flex:none;width:32px;height:32px;border-radius:11px;display:grid;place-items:center;background:rgba(240,69,75,.16);color:var(--al2)}
.bm-isler-bas h2{font-family:var(--disp);font-size:18px;font-weight:700;line-height:1.1;margin:0}
.bm-isler-sayi{flex:none;min-width:22px;height:22px;padding:0 7px;border-radius:11px;background:var(--al);color:#fff;font-size:12.5px;font-weight:800;display:inline-grid;place-items:center}
.bm-isler-ac{margin-left:auto;flex:none;display:inline-flex;align-items:center;gap:4px;color:var(--mut);font-size:12.5px;font-weight:700;white-space:nowrap}
.bm-isler-ac svg{transition:transform .2s}
.bm-isler.acik .bm-isler-ac svg{transform:rotate(180deg)}
.bm-isler-alt{display:flex;justify-content:center;border-top:1px solid rgba(255,255,255,.065)}
.bm-isler-hepsi{min-height:42px;padding:0 10px;background:none;border:0;color:var(--mut);font-size:12.5px;font-weight:700}
.bm-d-oge{padding:11px 0 12px;border-top:1px solid rgba(255,255,255,.065)}
.bm-d-metin{cursor:pointer}
.bm-d-bas{display:block;font-size:14.5px;font-weight:750;color:var(--txt);line-height:1.35}
.bm-d-govde{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;margin-top:2px;font-size:14px;line-height:1.45;color:var(--txt2);overflow-wrap:anywhere}
.bm-d-oge.acik .bm-d-govde{display:block;-webkit-line-clamp:unset;user-select:text;-webkit-user-select:text}
.bm-d-metin.tek .bm-d-govde{margin-top:0;color:var(--txt);font-size:14.5px}
.bm-d-alt{display:flex;align-items:center;gap:6px;margin-top:10px}
.bm-d-alt time{margin-right:auto;font-size:12px;color:var(--faint);font-variant-numeric:tabular-nums;white-space:nowrap}
.bm-dugme{display:inline-flex;align-items:center;min-height:32px;padding:0 13px;border-radius:999px;background:var(--inkbg);color:var(--ink2);border:0;font-size:13px;font-weight:750;white-space:nowrap}
.bm-dugme:active{background:var(--ink);color:#fff}
.bm-dugme.sade{background:transparent;color:var(--mut);padding:0 8px}
/* Yayın çubuğu */
.bm-ses{margin-bottom:12px;border-radius:20px;background:var(--panel);border:1px solid var(--line2);overflow:hidden}
.bm-ses-ana{display:flex;align-items:center;gap:12px;width:100%;padding:12px 12px 12px 12px;background:none;border:0;text-align:left;color:inherit}
.bm-ses-ana:active{background:rgba(255,255,255,.03)}
.bm-ses-ik{flex:none;width:42px;height:42px;border-radius:14px;display:grid;place-items:center;color:#fff;background:linear-gradient(135deg,#8b6cff,#ff4f8b);box-shadow:0 10px 20px -12px #8b6cff}
.bm-ses-orta{flex:1;min-width:0}
.bm-ses-orta b{display:block;font-size:15.5px;font-weight:750;color:var(--txt)}
.bm-ses-orta small{display:block;margin-top:2px;font-size:12.5px;color:var(--mut)}
.bm-ses-git{flex:none;display:inline-flex;align-items:center;height:34px;padding:0 15px;border-radius:999px;background:var(--ink);color:#fff;font-size:13.5px;font-weight:750}
.bm-ses-alt{display:flex;align-items:center;gap:8px;padding:9px 14px;border-top:1px solid var(--line);font-size:12px;color:var(--faint)}
.bm-ses-alt:empty{display:none}
.bm-ses-alt span{flex:1;min-width:0}
.bm-ses-ek{flex:none;background:none;border:0;padding:2px 0;margin:0;width:auto;min-height:0;color:var(--ink2);font-size:12.5px;font-weight:750;white-space:nowrap}
/* Sekmeler */
.bm-cipler{position:sticky;top:-14px;z-index:3;margin:0 -16px 2px;padding:8px 16px;background:rgba(14,21,48,.88);-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px)}
.bm-seg{display:flex;gap:2px;padding:3px;border-radius:14px;background:rgba(255,255,255,.04);border:1px solid var(--line);overflow-x:auto;scrollbar-width:none;-webkit-overflow-scrolling:touch}
.bm-seg::-webkit-scrollbar{display:none}
.bm-cip{flex:1 0 auto;position:relative;min-height:34px;padding:0 9px;border-radius:11px;border:0;background:transparent;color:var(--mut);font-size:13px;font-weight:700;white-space:nowrap;transition:background .18s,color .18s}
.bm-cip.secili{background:var(--panel2);color:var(--txt);box-shadow:inset 0 1px 0 rgba(255,255,255,.07),0 6px 14px -8px rgba(0,0,0,.7)}
.bm-cip .bm-nokta{position:absolute;top:6px;right:3px;width:6px;height:6px;border-radius:50%;background:var(--al)}
/* Liste */
.bm-gun{margin:16px 6px 8px;font-size:12px;font-weight:750;letter-spacing:.07em;text-transform:uppercase;color:var(--faint)}
.bm-liste > .bm-gun:first-child{margin-top:10px}
.bm-grup{background:var(--panel);border:1px solid var(--line);border-radius:18px;overflow:hidden}
.bm-liste.bm-gir .bm-grup{animation:bmGir .22s ease-out both}
@keyframes bmGir{from{opacity:0;transform:translateY(4px)}to{opacity:1;transform:none}}
.bm-grup > .kisisel,.bm-grup > .yayin{position:relative;display:flex;align-items:flex-start;gap:12px;margin:0;padding:13px 14px;background:transparent;border:0;border-radius:0;box-shadow:none;font-size:14px;color:var(--txt2)}
.bm-grup > * + *::before{content:"";position:absolute;top:0;left:64px;right:0;height:1px;background:var(--line)}
.bm-grup > .bm-tik,.bm-grup > .yayin:not([data-benim="1"]){cursor:pointer}
.bm-grup > .bm-tik:active,.bm-grup > .yayin:not([data-benim="1"]):active{background:rgba(255,255,255,.035)}
.bm-ik{flex:none;width:38px;height:38px;border-radius:12px;display:grid;place-items:center;background:rgba(168,149,255,.13);color:var(--ink2)}
.bm-k-acil .bm-ik{background:rgba(240,69,75,.15);color:var(--al2)}
.bm-k-meclis .bm-ik{background:rgba(76,195,255,.12);color:#7fd0ff}
.bm-k-duyuru .bm-ik{background:rgba(152,164,196,.10);color:var(--mut)}
.bm-r-govde{flex:1;min-width:0}
.bm-r-ust{display:flex;align-items:baseline;gap:10px}
.bm-r-bas{flex:1;min-width:0;font-size:14.5px;font-weight:700;line-height:1.35;color:var(--txt);overflow-wrap:anywhere}
.bm-r-ust time{flex:none;display:inline-flex;align-items:center;gap:6px;font-size:12px;color:var(--faint);font-variant-numeric:tabular-nums;white-space:nowrap}
.yeni .bm-r-ust time::after{content:"";width:7px;height:7px;border-radius:50%;background:var(--ink);box-shadow:0 0 0 3px rgba(123,97,255,.18)}
.bm-k-acil.yeni .bm-r-ust time::after{background:var(--al);box-shadow:0 0 0 3px rgba(240,69,75,.18)}
.bm-r-metin{margin-top:3px;font-size:14px;line-height:1.45;color:var(--txt2);overflow-wrap:anywhere;user-select:text;-webkit-user-select:text}
.bm-r-tek .bm-r-bas{font-weight:550}
.bm-k-duyuru:not(.yeni) .bm-r-bas,.bm-k-meclis:not(.yeni) .bm-r-bas{color:var(--txt2)}
.bm-k-duyuru .bm-r-metin{color:var(--mut)}
.bm-grup .bildirim-alt{display:flex;flex-wrap:wrap;gap:8px;margin-top:9px}
.bm-grup .bildirim-alt:empty{display:none}
.bm-grup .bildirim-goster{display:inline-flex;align-items:center;min-height:30px;padding:0 12px;border-radius:999px;border:0;background:var(--inkbg);color:var(--ink2);font-size:12.5px;font-weight:750;white-space:nowrap}
.bm-grup .bm-k-acil .bildirim-goster.bm-git{background:rgba(240,69,75,.14);color:var(--al2)}
.bm-grup .er-bag{display:inline-flex;align-items:center;min-height:30px;margin:0;padding:0 12px;border-radius:999px;border:0;background:var(--inkbg);color:var(--ink2);font-size:12.5px;font-weight:750;white-space:nowrap}
.bm-r-govde > .er-bag{margin-top:9px}
.bm-av{flex:none;width:38px;height:38px;border-radius:50%;overflow:hidden;display:grid;place-items:center;background:var(--pr,#7B61FF);color:#fff;font-size:15px;font-weight:800;box-shadow:0 0 0 2px var(--panel),0 0 0 3.5px var(--pr,#7B61FF)}
.bm-av > *{width:100%!important;height:100%!important;max-width:none!important;border-radius:50%}
.bm-r-kim{margin-top:1px;font-size:12.5px;font-weight:650;color:var(--ink2);overflow-wrap:anywhere}
.bm-r-yayin .bm-r-metin{margin-top:8px;padding:9px 12px;border-radius:4px 14px 14px 14px;background:rgba(255,255,255,.045);color:var(--txt);white-space:pre-wrap}
.bm-daha{display:block;width:100%;margin-top:12px;min-height:44px;border-radius:14px;border:1px dashed var(--line2);background:transparent;color:var(--ink2);font-size:13.5px;font-weight:750}
.bm-bos{text-align:center;padding:34px 16px 30px;color:var(--mut);font-size:13.5px;line-height:1.45}
.bm-bos-ik{width:56px;height:56px;margin:0 auto 12px;border-radius:18px;display:grid;place-items:center;background:var(--inkbg);color:var(--ink2)}
.bm-bos b{display:block;margin-bottom:3px;color:var(--txt);font-size:16px}
@media (max-width:360px){.bm-grup > .kisisel,.bm-grup > .yayin{gap:10px;padding:12px}.bm-grup > * + *::before{left:58px}.bm-ik,.bm-av{width:36px;height:36px}.bm-ses-ana{gap:10px}.bm-ses-ik{width:38px;height:38px;border-radius:13px}.bm-ses-git{width:32px;height:32px;padding:0;justify-content:center;font-size:0}.bm-ses-git::after{content:"›";font-size:22px;line-height:1;margin-top:-2px}.bm-cip{padding:0 7px;font-size:12.5px}.bm-isler-ac b{display:none}}
@media (prefers-reduced-motion:reduce){.bm-liste.bm-gir .bm-grup{animation:none}.bm-cip,.bm-isler-ac svg{transition:none}}
#bmTostYigin{position:fixed;left:16px;right:16px;bottom:calc(var(--safeB) + 90px);z-index:40;display:flex;flex-direction:column;gap:8px;pointer-events:none;max-width:560px;margin:0 auto}
#bmTostYigin .toast{position:relative;left:auto;right:auto;bottom:auto;top:auto;margin:0;pointer-events:auto;cursor:pointer;transition:opacity .18s,transform .18s}
#bmTostYigin .toast.bm-cik{opacity:0;transform:translateY(6px)}
#bmBant{position:fixed;left:12px;right:12px;top:calc(var(--safeT) + 62px);z-index:45;max-width:540px;margin:0 auto;background:rgba(29,40,80,.97);-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);border:1px solid rgba(240,69,75,.45);border-left:4px solid var(--al);border-radius:14px;padding:12px 44px 12px 14px;box-shadow:0 18px 40px -14px rgba(0,0,0,.8);animation:bmBantGel .25s ease-out}
#bmBant .bm-b-ust{font-size:12.5px;font-weight:750;color:var(--al2);display:flex;align-items:center;gap:7px}
#bmBant .bm-b-ust::before{content:"";width:7px;height:7px;border-radius:50%;background:var(--al);animation:nabiz 1.6s ease-in-out infinite}
#bmBant p{margin-top:5px;font-size:14.5px;line-height:1.42;color:var(--txt);display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
#bmBant .bm-b-alt{display:flex;gap:8px;align-items:center;margin-top:10px;flex-wrap:wrap}
#bmBant .bm-b-alt .kucuk{flex-basis:100%}
#bmBant .bm-b-kapat{position:absolute;top:6px;right:6px;width:34px;height:34px;border-radius:9px;color:var(--mut);font-size:22px;line-height:1}
@keyframes bmBantGel{from{opacity:0;transform:translateY(-10px)}to{opacity:1;transform:none}}
@media (prefers-reduced-motion:reduce){#bmBant,#bmBant .bm-b-ust::before{animation:none}#bmTostYigin .toast{transition:none}}
`;
  function stilEkle() {
    if (document.getElementById("bmStil")) return;
    const s = document.createElement("style"); s.id = "bmStil"; s.textContent = CSS;
    (document.head || document.documentElement).appendChild(s);
  }
  stilEkle();

  const kac = (s) => typeof e === "function" ? e(s) : String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const zamanYaz = (z) => { try { return typeof zamanKisa === "function" ? zamanKisa(z) : ""; } catch (_) { return ""; } };

  function gunEtiketi(z) {
    try {
      const p = trParca(z), b = trParca(simdi());
      const gun = (x) => Date.UTC(x.y, x.a - 1, x.g) / 864e5;
      const fark = gun(b) - gun(p);
      if (fark === 0) return "Bugün";
      if (fark === 1) return "Dün";
      return `${p.g} ${AYLAR[p.a - 1]}${p.y !== b.y ? " " + p.y : ""}`;
    } catch (_) { return ""; }
  }

  /* ---------------- Toast yığını ---------------- */
  const eskiToast = window.toast;
  function tostKaldir(t) {
    if (!t || t.dataset.cik) return;
    t.dataset.cik = "1"; clearTimeout(t._bmZ);
    t.classList.add("bm-cik");
    setTimeout(() => t.remove(), 190);
  }
  function tostSure(t) {
    clearTimeout(t._bmZ);
    t._bmZ = setTimeout(() => tostKaldir(t), t.classList.contains("hata") ? 5000 : 2600);
  }
  window.toast = function (m, hata) {
    try {
      let y = document.getElementById("bmTostYigin");
      if (!y) { y = document.createElement("div"); y.id = "bmTostYigin"; y.setAttribute("aria-live", "polite"); document.body.appendChild(y); }
      const metin = String(m == null ? "" : m);
      const canli = [...y.children].filter(x => !x.dataset.cik);
      const ayni = canli.find(x => x.dataset.m === metin);
      if (ayni) { tostSure(ayni); return; }
      // En fazla 3: önce en eski başarı mesajı çıkar, hata mesajları yerinde kalır.
      if (canli.length >= 3) tostKaldir(canli.find(x => !x.classList.contains("hata")) || canli[0]);
      const t = document.createElement("div");
      t.className = "toast" + (hata ? " hata" : ""); t.textContent = metin; t.dataset.m = metin;
      t.setAttribute("role", hata ? "alert" : "status");
      t.onclick = () => tostKaldir(t);
      y.appendChild(t); tostSure(t);
    } catch (_) { if (typeof eskiToast === "function") eskiToast(m, hata); }
  };

  /* ---------------- Bildirimler ekranı ---------------- */
  const eskiEkran = window.bildirimEkrani;
  let filtre = yerel.oku(FILTRE, "tumu");
  const FILTRELER = [["tumu", "Tümü"], ["ozel", "Kişisel"], ["meclis", "Siyaset"], ["duyuru", "Duyuru"], ["yayin", "Yayın"]];
  const SAYFA = 25;           // listede ilk anda gösterilen satır
  let gosterilen = SAYFA;     // "Daha fazla göster" ile artar; filtre değişince sıfırlanır
  let islerAcik = false;      // Bekleyen işler yığını açık mı (oturum boyunca hatırlanır)

  function ekranBizimMi() {
    const h = document.querySelector(".ust h1");
    return !!(h && h.textContent.trim() === "Bildirimler");
  }

  /* Konu simgeleri (24'lük çizgi ikon) */
  const yol = (d) => `<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${d}</svg>`;
  const SIM = {
    zil: yol('<path d="M6 16V11a6 6 0 1 1 12 0v5l1.5 2h-15zM10 20.5a2 2 0 0 0 4 0"/>'),
    meclis: yol('<path d="M3 20.5h18M5 17.5V10M9.5 17.5V10M14.5 17.5V10M19 17.5V10M2.5 8.5 12 3.5l9.5 5z"/>'),
    adliye: yol('<path d="M12 4v16M8 20.5h8M5 7.5h14M5 7.5l-2.6 6a3 3 0 0 0 5.2 0zM19 7.5l-2.6 6a3 3 0 0 0 5.2 0zM12 4a1.4 1.4 0 1 0 0-.01"/>'),
    banka: yol('<rect x="2.5" y="5.5" width="19" height="13" rx="2.6"/><path d="M2.5 10h19M6.5 14.5h4"/>'),
    sehir: yol('<path d="M3 20.5h18M5 20.5V7l7-3v16.5M12 20.5h7v-10l-7-2.5M8 9v.01M8 12.5v.01M8 16v.01M15.5 13v.01M15.5 16.5v.01"/>'),
    parti: yol('<path d="M5.5 21V4M5.5 4.5h11.5l-2.4 4.2 2.4 4.3H5.5"/>'),
    sirket: yol('<path d="M3 17l6-6 4 4 7.5-7.5M15 7.5h5.5V13"/>'),
    zarar: yol('<path d="M3 7l6 6 4-4 7.5 7.5M15 16.5h5.5V11"/>'),
    basin: yol('<path d="M4 5h12.5v13.5A2.5 2.5 0 0 0 19 21H6.5A2.5 2.5 0 0 1 4 18.5zM16.5 9H20v9.5a2.5 2.5 0 0 1-2.5 2.5M7.5 9h5.5M7.5 12.5h5.5M7.5 16h3.5"/>'),
    kursu: yol('<path d="M20.5 11.5a8.5 8.5 0 0 1-12.3 7.6L3.5 20.5l1.4-4.4a8.5 8.5 0 1 1 15.6-4.6z"/>'),
    miting: yol('<path d="M3.5 10v4h3l7 4.5v-13l-7 4.5zM17 9a4 4 0 0 1 0 6M19.6 6.4a7.8 7.8 0 0 1 0 11.2"/>'),
    odul: yol('<path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/>'),
    devlet: yol('<path d="M12 3l8 3v5.6c0 4.6-3.3 8.4-8 9.4-4.7-1-8-4.8-8-9.4V6z"/><path d="M9 12l2 2 4-4"/>'),
    saat: yol('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>'),
    tamam: yol('<circle cx="12" cy="12" r="8.5"/><path d="M8.5 12.2l2.4 2.4 4.6-4.8"/>'),
    asagi: yol('<path d="M6 9.5l6 6 6-6"/>').replace(/width="19" height="19"/, 'width="16" height="16"')
  };
  function konuBul(t, rota) {
    if (/zarar ediyor|iflas/.test(t)) return "zarar";
    if (rota === "kursu" || /^kursu:|paylasim/.test(t)) return "kursu";
    if (/gazete|manset|yayimlandi|haftanin ozeti/.test(t)) return "basin";
    if (/miting|meydan|halk bulusmasi|protesto|basin toplantisi/.test(t)) return "miting";
    if (rota === "adliye" || /dava|mahkeme|juri|istinaf|savunma|baro|avukat/.test(t)) return "adliye";
    if (rota === "banka" || /kredi|taksit|vadesiz|mevduat|havale|banka/.test(t)) return "banka";
    if (rota === "meclis" || /meclis|tbmm|kanun|oylama|grup karari|anayasa/.test(t)) return "meclis";
    if (/basarim|statun|tebrik|rozet/.test(t)) return "odul";
    if (rota === "ilan" || rota === "muzayede" || /sirket|holding|temettu|halka arz|bilanco|ihale|siparis|borsa|hisse/.test(t)) return "sirket";
    if (rota === "yonetim" || /belediye|kriz masasi|ruhsat/.test(t)) return "sehir";
    if (rota === "parti" || /parti|kurultay|genel baskan|ittifak|kurucu/.test(t)) return "parti";
    if (rota === "devlet" || rota === "bakanlik" || rota === "butce" || rota === "bk_etkinlik" || /cumhurbaskan|bakan|hukumet|devlet/.test(t)) return "devlet";
    return "zil";
  }

  /* Metni başlık + gövde diye ayır: "Kriz masası: …" → Kriz masası | … */
  function baslikDuzelt(s) {
    const harf = s.replace(/[^A-Za-zÇĞİÖŞÜçğıöşüÂÎÛâîû]/g, "");
    if (harf.length >= 6 && /\s/.test(s) && harf === harf.toLocaleUpperCase("tr-TR"))
      return s.split(/(\s+)/).map(w => w.length <= 3 ? w : w.charAt(0) + w.slice(1).toLocaleLowerCase("tr-TR")).join("");
    return s;
  }
  function basAyir(metin) {
    const m = String(metin == null ? "" : metin).trim();
    const i = m.indexOf(": ");
    if (i >= 3 && i <= 48) {
      const bas = m.slice(0, i).trim(), govde = m.slice(i + 2).trim();
      if (govde && !/["“«(]/.test(bas)) return { bas: baslikDuzelt(bas), govde };
    }
    const n = m.search(/[.!?](\s)/);
    if (n >= 12 && n <= 64 && n < m.length - 10) return { bas: m.slice(0, m[n] === "." ? n : n + 1), govde: m.slice(n + 1).trim() };
    return { bas: "", govde: m };
  }
  window.bmBasAyir = basAyir;
  const rotaVar = (r) => { try { return !!(r && ROTA[r] && ROTA[r].var()); } catch (_) { return false; } };
  // Aynı kalıptaki tekrarlar (ör. her gün gelen "… zarar ediyor") Bekleyen işler'de bir kez görünsün.
  const saatSade = (z) => { try { return typeof saatYaz === "function" ? saatYaz(z) : zamanYaz(z); } catch (_) { return zamanYaz(z); } };
  const iskeletMetin = (s) => katla(s).replace(/[\d.,:;₺%'’"“”]+/g, "#").replace(/\s+/g, " ").trim();

  function kisiselSatir(o) {
    const { x, n, k } = o;
    const t = katla(x.metin);
    n.classList.add("bm-k-" + k.kat);
    const ik = n.querySelector(":scope > span");
    if (ik) { ik.className = "bm-ik"; ik.removeAttribute("style"); ik.innerHTML = SIM[konuBul(t, k.rota)] || SIM.zil; }
    const govde = n.querySelector(":scope > div");
    if (!govde) return;
    const alt = govde.querySelector(".bildirim-alt");
    if (alt) {
      alt.className = "bildirim-alt";
      const zs = alt.querySelector(":scope > span"); if (zs) zs.remove();
    }
    const git = rotaVar(k.rota) && (k.kat === "acil" || k.kat === "ozel");
    if (git && alt && !alt.querySelector(".bm-git"))
      alt.insertAdjacentHTML("beforeend", `<button type="button" class="bildirim-goster bm-git" onclick="event.stopPropagation();bmRotaGit('${k.rota}')">${kac(ROTA[k.rota].ad)} ›</button>`);
    const p = basAyir(x.metin), z = kac(saatSade(x.zaman));
    govde.removeAttribute("style");
    govde.className = "bm-r-govde";
    govde.innerHTML = p.bas
      ? `<div class="bm-r-ust"><b class="bm-r-bas">${kac(p.bas)}</b><time>${z}</time></div><div class="bm-r-metin">${kac(p.govde)}</div>`
      : `<div class="bm-r-ust"><span class="bm-r-bas">${kac(p.govde)}</span><time>${z}</time></div>`;
    if (!p.bas) n.classList.add("bm-r-tek");
    if (alt) govde.appendChild(alt);
    if (rotaVar(k.rota)) {
      n.classList.add("bm-tik");
      n.onclick = (ev) => { if (ev.target.closest("button,a")) return; if (window.getSelection && String(window.getSelection())) return; rotaGit(k.rota); };
    }
  }

  function yayinSatir(o) {
    const n = o.n, x = o.x;
    const renk = (x.parti && /^#[0-9a-f]{3,8}$/i.test(x.parti.renk || "")) ? x.parti.renk : "#7B61FF";
    const unvan = (n.querySelector(".unv") || {}).textContent || x.unvan || "";
    const tur = (n.querySelector(":scope > .kucuk") || {}).textContent || "";
    let av = "";
    try { if (typeof portre === "function") av = portre(x.kad, renk, 38); } catch (_) { av = ""; }
    if (!av) av = kac(String(x.kad || "?").trim().charAt(0).toLocaleUpperCase("tr-TR"));
    n.removeAttribute("style");
    n.classList.add("bm-r-yayin");
    n.innerHTML = `<span class="bm-av" style="--pr:${renk}">${av}</span><div class="bm-r-govde">
      <div class="bm-r-ust"><b class="bm-r-bas">${kac(x.kad)}</b><time>${kac(saatSade(x.zaman))}</time></div>
      <div class="bm-r-kim">${kac([unvan, tur].filter(Boolean).join(" · "))}</div>
      <div class="bm-r-metin">${kac(x.metin)}</div></div>`;
  }

  function sesCubugu(ic) {
    const eski = ic.querySelector(":scope > .olay.basvuru");
    if (!eski || typeof yayinModal !== "function") return null;
    const rz = eski.querySelector(".rozet"), hak = rz ? parseInt(rz.textContent, 10) : NaN;
    const rk = eski.querySelector("#reklam");
    const k = document.createElement("div");
    k.className = "bm-ses";
    k.innerHTML = `<button type="button" class="bm-ses-ana" id="bmSes"><span class="bm-ses-ik">${SIM.miting.replace(/width="19" height="19"/, 'width="21" height="21"')}</span>
      <span class="bm-ses-orta"><b>Seçmenlerine seslen</b><small>${Number.isFinite(hak) ? (hak > 0 ? `${hak} yayın hakkın var` : "Bugünkü hakların bitti") : "Propaganda yayını gönder"}</small></span>
      <span class="bm-ses-git">Yayınla</span></button>
      <div class="bm-ses-alt"></div>`;
    k.querySelector("#bmSes").onclick = () => yayinModal();
    // Ek hak yalnız günlük haklar bitince işe yarar (sunucu da öyle kullanır): o zaman görünür.
    if (rk && !(hak > 0)) {
      k.querySelector(".bm-ses-alt").innerHTML = `<span>Bir yayın daha göndermek için</span>`;
      const fiyat = (rk.textContent.split("·")[1] || "").trim();
      rk.className = "bm-ses-ek";
      rk.textContent = "+ Ek hak" + (fiyat ? " · " + fiyat : "");
      k.querySelector(".bm-ses-alt").appendChild(rk);
    }
    eski.replaceWith(k);
    return k;
  }

  function bosDurum(baslik, alt) {
    return `<div class="bm-bos"><div class="bm-bos-ik">${SIM.tamam.replace(/width="19" height="19"/, 'width="26" height="26"')}</div><b>${kac(baslik)}</b>${kac(alt)}</div>`;
  }

  function duzenle(liste) {
    const ic = document.getElementById("icerik");
    if (!ic) return;
    sesCubugu(ic);
    if (!Array.isArray(liste)) return;
    if (!liste.length) {
      const b = ic.querySelector(":scope > .bos");
      if (b) b.outerHTML = bosDurum("Her şey yolunda", "Yeni bir gelişme olduğunda burada göreceksin.");
      return;
    }
    const dugumler = [...ic.querySelectorAll(":scope > .yayin, :scope > .kisisel")];
    if (dugumler.length !== liste.length) return; // beklenmeyen düzen: orijinal ekran olduğu gibi kalır
    const ogeler = liste.map((x, i) => {
      const n = dugumler[i];
      if (x.tur === "yayin") { const o = { x, n, kat: "yayin", ust: "yayin" }; yayinSatir(o); return o; }
      const k = kategori(x.metin);
      const o = { x, n, k, kat: k.kat, ust: k.kat === "acil" ? "ozel" : k.kat, rota: k.rota };
      kisiselSatir(o);
      return o;
    });

    // Başlıkta okunmamış sayısı
    const yeniSay = liste.filter(x => x.yeni).length;
    const ust = document.querySelector(".ust");
    if (ust && yeniSay && !ust.querySelector(".bm-ust-yeni")) ust.insertAdjacentHTML("beforeend", `<span class="bm-ust-yeni">${yeniSay} yeni</span>`);

    // Bekleyen işler: son 3 gün, "Gördüm" denmemiş süreli bildirimler; aynı kalıp bir kez.
    const sinir = (typeof simdi === "function" ? simdi() : Date.now()) - 3 * 864e5;
    const gorulen = new Set();
    const dikkat = ogeler.filter(o => {
      if (o.kat !== "acil" || new Date(o.x.zaman).getTime() < sinir || kumede(GORDUM, o.x.id)) return false;
      const s = iskeletMetin(o.x.metin);
      if (gorulen.has(s)) return false;
      gorulen.add(s); return true;
    });
    let isler = null;
    if (dikkat.length) {
      isler = document.createElement("section");
      isler.className = "bm-isler"; isler.id = "bmDikkat";
      const tekli = dikkat.length === 1;
      isler.innerHTML = `${tekli ? `<div class="bm-isler-bas">` : `<button type="button" class="bm-isler-bas" aria-expanded="${islerAcik}">`}<span class="bm-isler-ik">${SIM.saat}</span>
          <h2>Bekleyen işler</h2><span class="bm-isler-sayi">${dikkat.length}</span>
          ${tekli ? "" : `<span class="bm-isler-ac"><b>${islerAcik ? "Daralt" : "Tümünü gör"}</b>${SIM.asagi}</span>`}${tekli ? "</div>" : "</button>"}
        ${dikkat.map(o => { const p = basAyir(o.x.metin); return `<div class="bm-d-oge" data-id="${kac(o.x.id)}">
          <div class="bm-d-metin${p.bas ? "" : " tek"}">${p.bas ? `<b class="bm-d-bas">${kac(p.bas)}</b>` : ""}<span class="bm-d-govde">${kac(p.govde)}</span></div>
          <div class="bm-d-alt"><time>${kac(zamanYaz(o.x.zaman))}</time>
          ${rotaVar(o.rota) ? `<button type="button" class="bm-dugme" onclick="bmRotaGit('${o.rota}')">${kac(ROTA[o.rota].ad)} ›</button>` : ""}
          <button type="button" class="bm-dugme sade" data-gordum="${kac(o.x.id)}">Gördüm</button></div></div>`; }).join("")}
        ${tekli ? "" : `<div class="bm-isler-alt"><button type="button" class="bm-isler-hepsi" data-hepsi="1">Hepsini gördüm</button></div>`}`;
      ic.insertBefore(isler, ic.firstChild);
      // Kapalıyken yalnız ilki görünür, arkada yığın izi; açıkken hepsi ve "Hepsini gördüm".
      const islerCiz = () => {
        const kalan = [...isler.querySelectorAll(".bm-d-oge")];
        if (!kalan.length) { isler.remove(); return; }
        const r = isler.querySelector(".bm-isler-sayi"); if (r) r.textContent = kalan.length;
        const cok = kalan.length > 1;
        kalan.forEach((x, i) => { x.hidden = cok && !islerAcik && i > 0; });
        isler.classList.toggle("acik", cok && islerAcik);
        isler.classList.toggle("yigin", cok && !islerAcik);
        const alt = isler.querySelector(".bm-isler-alt"); if (alt) alt.hidden = !(cok && islerAcik);
        const ac = isler.querySelector(".bm-isler-ac"); if (ac) { ac.hidden = !cok; const b = ac.querySelector("b"); if (b) b.textContent = islerAcik ? "Daralt" : "Tümünü gör"; }
        const bas = isler.querySelector("button.bm-isler-bas"); if (bas) bas.setAttribute("aria-expanded", String(cok && islerAcik));
      };
      isler.querySelectorAll("[data-gordum]").forEach(b => b.onclick = () => {
        kumeEkle(GORDUM, [b.dataset.gordum], 500);
        const oge = b.closest(".bm-d-oge"); if (oge) oge.remove();
        islerCiz();
      });
      const hepsi = isler.querySelector("[data-hepsi]");
      if (hepsi) hepsi.onclick = () => { kumeEkle(GORDUM, dikkat.map(o => o.x.id), 500); isler.remove(); };
      const basBtn = isler.querySelector("button.bm-isler-bas");
      if (basBtn) basBtn.onclick = () => { islerAcik = !islerAcik; islerCiz(); };
      islerCiz();
      isler.querySelectorAll(".bm-d-metin").forEach(m => m.onclick = () => m.parentElement.classList.toggle("acik"));
    }

    const kap = document.createElement("div");
    kap.className = "bm-kap";
    kap.innerHTML = `<div class="bm-cipler"><div class="bm-seg" role="tablist" aria-label="Bildirim türü"></div></div>
      <div class="bm-liste"></div><button type="button" class="bm-daha" hidden></button><div class="bm-sakli" hidden></div>`;
    ic.insertBefore(kap, dugumler[0]);
    const liEl = kap.querySelector(".bm-liste"), cipEl = kap.querySelector(".bm-seg"), dahaEl = kap.querySelector(".bm-daha");
    // Görünmeyen satırlar sayfadan kopmaz: başka modüller (Siyaset Arenası, Ekonomi rehberi) bağlantı düğmelerini hepsine ekleyebilir.
    const saklaEl = kap.querySelector(".bm-sakli");

    function ciz(animasyon) {
      if (!FILTRELER.some(f => f[0] === filtre)) filtre = "tumu";
      const sec = ogeler.filter(o => filtre === "tumu" || o.ust === filtre);
      cipEl.innerHTML = FILTRELER.map(([k, ad]) => {
        const grup = ogeler.filter(o => k === "tumu" || o.ust === k);
        if (k !== "tumu" && !grup.length) return "";
        const yeni = grup.some(o => o.x.yeni) && k !== "tumu";
        return `<button type="button" role="tab" aria-selected="${filtre === k}" class="bm-cip${filtre === k ? " secili" : ""}" data-f="${k}" data-sayi="${grup.length}">${ad}${yeni && filtre !== k ? '<span class="bm-nokta" aria-label="yeni"></span>' : ""}</button>`;
      }).join("");
      cipEl.querySelectorAll("[data-f]").forEach(b => b.onclick = () => {
        if (filtre === b.dataset.f) return;
        filtre = b.dataset.f; yerel.yaz(FILTRE, filtre); gosterilen = SAYFA; ciz(true);
        const ustKenar = kap.offsetTop - 14;
        if (ic.scrollTop > ustKenar) ic.scrollTop = ustKenar;
      });
      liEl.textContent = "";
      liEl.classList.toggle("bm-gir", !!animasyon);
      let sonGun = null, grupEl = null;
      const gorunen = new Set(sec.slice(0, gosterilen));
      for (const o of ogeler) if (!gorunen.has(o)) saklaEl.appendChild(o.n);
      for (const o of sec.slice(0, gosterilen)) {
        const g = gunEtiketi(o.x.zaman);
        if (!grupEl || g !== sonGun) {
          if (g) { const h = document.createElement("div"); h.className = "bm-gun"; h.textContent = g; liEl.appendChild(h); }
          grupEl = document.createElement("div"); grupEl.className = "bm-grup"; liEl.appendChild(grupEl);
          sonGun = g;
        }
        grupEl.appendChild(o.n);
      }
      if (!sec.length) liEl.innerHTML = bosDurum("Burası sakin", "Bu türde bildirim yok.");
      const kalan = sec.length - Math.min(sec.length, gosterilen);
      dahaEl.hidden = kalan <= 0;
      dahaEl.textContent = kalan > 0 ? `Daha fazla göster · ${kalan}` : "";
      const s = cipEl.querySelector(".secili");
      if (s && (s.offsetLeft < cipEl.scrollLeft || s.offsetLeft + s.offsetWidth > cipEl.scrollLeft + cipEl.clientWidth)) cipEl.scrollLeft = Math.max(0, s.offsetLeft - 12);
    }
    dahaEl.onclick = () => { gosterilen += SAYFA; ciz(false); };
    // Hiç ilgili öğe yoksa kayıtlı filtre boş liste göstermesin
    if (filtre !== "tumu" && !ogeler.some(o => o.ust === filtre)) filtre = "tumu";
    ciz(false);
    // Yayın sahiplerinin gerçek portreleri (varsa) yerinde yüklenir.
    try { if (ogeler.some(o => o.kat === "yayin") && typeof portreleriTazele === "function") portreleriTazele(kap).catch(() => {}); } catch (_) {}
  }

  if (typeof eskiEkran === "function") {
    window.bildirimEkrani = async function () {
      let yakalanan = null, eskiRpc = null, apiRef = null;
      try {
        apiRef = typeof API !== "undefined" ? API : null;
        if (apiRef && typeof apiRef.rpc === "function") {
          eskiRpc = apiRef.rpc;
          apiRef.rpc = function (ad, arg) {
            const s = eskiRpc.apply(this, arguments);
            if (ad === "bildirim_kutusu" && s && typeof s.then === "function") s.then(r => { yakalanan = r; }, () => {});
            return s;
          };
        }
      } catch (_) { eskiRpc = null; }
      try { await eskiEkran.apply(this, arguments); }
      finally { if (apiRef && eskiRpc) apiRef.rpc = eskiRpc; }
      try { if (ekranBizimMi()) duzenle(yakalanan); } catch (_) { /* orijinal ekran olduğu gibi kalır */ }
      bantKapat();
    };
  }

  /* ---------------- Yeni süreli bildirim bandı ---------------- */
  let sonSayi = -1, kontrolSuruyor = false, bantKapali = false;
  function bantKapat() { const b = document.getElementById("bmBant"); if (b) b.remove(); }
  function bantGoster(ogeler) {
    if (!ogeler.length || ekranBizimMi()) return;
    bantKapat();
    const o = ogeler[0], ek = ogeler.length - 1;
    const b = document.createElement("div");
    b.id = "bmBant"; b.setAttribute("role", "alert");
    b.innerHTML = `<div class="bm-b-ust">Bekleyen iş</div><p>${kac(o.metin)}</p>
      <div class="bm-b-alt"><span class="kucuk">${ek > 0 ? `+${ek} süreli bildirim daha` : zamanYaz(o.zaman)}</span>
      ${o.rota && ROTA[o.rota] && ROTA[o.rota].var() ? `<button type="button" class="bm-dugme" data-git="${o.rota}">${kac(ROTA[o.rota].ad)}</button>` : ""}
      <button type="button" class="bm-dugme" data-ac="1">Bildirimleri aç</button></div>
      <button type="button" class="bm-b-kapat" aria-label="Kapat">×</button>`;
    b.querySelector(".bm-b-kapat").onclick = bantKapat;
    b.querySelector("[data-ac]").onclick = () => { bantKapat(); try { if (typeof modalKapat === "function") modalKapat(); ekranAc(window.bildirimEkrani); } catch (_) {} };
    const g = b.querySelector("[data-git]"); if (g) g.onclick = () => rotaGit(g.dataset.git);
    document.body.appendChild(b);
  }
  async function yeniKontrol(sayi) {
    if (bantKapali || kontrolSuruyor) return;
    if (typeof API === "undefined" || !API || typeof API.rpc !== "function") return;
    kontrolSuruyor = true;
    try {
      const l = await API.rpc("bildirim_yeniler", { p_limit: 10 });
      if (!Array.isArray(l)) return;
      const uyarilacak = [], taze = (typeof simdi === "function" ? simdi() : Date.now()) - 2 * 864e5;
      for (const x of l) {
        if (kumede(UYARILDI, x.id) || kumede(GORDUM, x.id)) continue;
        if (new Date(x.zaman).getTime() < taze) continue; // eski, süresi büyük olasılıkla geçmiş
        const k = kategori(x.metin);
        if (k.kat === "acil") uyarilacak.push({ id: x.id, metin: x.metin, zaman: x.zaman, rota: k.rota });
      }
      kumeEkle(UYARILDI, l.map(x => x.id), 400);
      if (uyarilacak.length) bantGoster(uyarilacak);
    } catch (err) {
      // Sunucuda fonksiyon yoksa (eski kurulum) bandı sessizce kapat.
      if (/bildirim_yeniler|does not exist|could not find|404|PGRST202/i.test(String(err && (err.message || err.code) || ""))) bantKapali = true;
    } finally { kontrolSuruyor = false; }
  }
  function sayiGeldi(ok) {
    const n = ok && ok.bildirim != null ? Number(ok.bildirim) : NaN;
    if (!Number.isFinite(n)) return;
    const artti = n > Math.max(0, sonSayi);
    sonSayi = n;
    if (artti) yeniKontrol(n);
  }
  const eskiRozet = window.rozetGuncelle;
  if (typeof eskiRozet === "function") {
    window.rozetGuncelle = function (ok) {
      const r = eskiRozet.apply(this, arguments);
      try { sayiGeldi(ok || (typeof D === "object" && D ? D.okunmamis : null)); } catch (_) {}
      return r;
    };
  }
  // Açılışta: oyuncu yokken gelen süreli bildirimler için bir kez bakılır.
  let acilisDenemesi = 0;
  const acilis = setInterval(() => {
    acilisDenemesi++;
    try {
      if (typeof D === "object" && D && D.durum && D.durum.profil) { clearInterval(acilis); if (sonSayi < 0) sayiGeldi(D.okunmamis); }
    } catch (_) {}
    if (acilisDenemesi > 60) clearInterval(acilis);
  }, 2000);
})();
