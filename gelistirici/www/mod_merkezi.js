/* 18.11.2026 · MODERASYON MERKEZİ
   Yönetici ve moderatörlerin tek giriş noktası (Profilim › Yönetici/Moderasyon paneli):
   - Pano: kişiye özel iş kuyrukları, "Sıradaki işi getir", ekip ve kişisel istatistik
   - Kayıt masası (kart kart karar), Şikâyet masası, Sohbet nöbeti, Destek masası,
     Yaptırım talepleri (dört göz), Çoklu hesap, MASAK, Duyuru
   - Oyuncu dosyası (360°): kimlik, kısıt geçmişi, şikâyetler, notlar, bağlı hesaplar, MASAK
   - Yönetici: Ekip yönetimi (7 uzmanlık birimi), performans, denetim günlüğü
   Yetki her zaman sunucuda doğrulanır; buradaki gizleme yalnız sadelik içindir. */
(function () {
  if (typeof iskelet !== "function" || typeof API === "undefined") return;
  const esc = (x) => (typeof e === "function" ? e(x) : String(x == null ? "" : x));
  const hc = (m) => (typeof hataCevir === "function" ? hataCevir(m) : m);
  const hata = (err) => toast(hc(err && err.message ? err.message : String(err)), true);
  const sayi = (n) => (typeof fmt === "function" ? fmt(+n || 0) : String(+n || 0));
  const tl = (n) => (typeof tlYaz === "function" ? tlYaz(n) : sayi(Math.round(+n || 0)) + " ₺");
  const tsaat = (x) => (x ? (typeof tarihSaat === "function" ? tarihSaat(x) : new Date(x).toLocaleString("tr-TR")) : "—");
  const simdiMs = () => Date.now() + (typeof saatFarki === "number" ? saatFarki : 0);
  function once(x) {
    if (!x) return "—";
    const dk = Math.max(0, Math.round((simdiMs() - new Date(x).getTime()) / 60000));
    if (dk < 1) return "az önce"; if (dk < 60) return dk + " dk önce";
    const sa = Math.round(dk / 60); if (sa < 24) return sa + " sa önce";
    const g = Math.round(sa / 24); return g < 30 ? g + " gün önce" : tsaat(x);
  }
  const dkGecti = (x) => (x ? (simdiMs() - new Date(x).getTime()) / 60000 : 0);

  /* ---------- Simgeler (çizgi ikon; emoji yok) ---------- */
  const S = (d, w) => `<svg viewBox="0 0 24 24" width="${w || 22}" height="${w || 22}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${d}</svg>`;
  const IK = {
    kimlik: S('<rect x="3" y="5" width="18" height="14" rx="2.5"/><circle cx="9" cy="11" r="2.2"/><path d="M5.8 16c.7-1.6 1.9-2.4 3.2-2.4s2.5.8 3.2 2.4M14.5 10h4M14.5 13.5h3"/>'),
    sohbet: S('<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20.5l1.4-4.6A8 8 0 1 1 21 12z"/><path d="M8.5 12h.01M12 12h.01M15.5 12h.01"/>'),
    sikayet: S('<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>'),
    tv: S('<rect x="3" y="7" width="18" height="13" rx="2.5"/><path d="m8 3 4 4 4-4"/>'),
    gazete: S('<path d="M4 5h13v14H6a2 2 0 0 1-2-2V5zM17 9h3v8a2 2 0 0 1-2 2M7 9h7M7 12.5h7M7 16h4"/>'),
    masak: S('<path d="M12 2v20M17 6.5c-.8-1.5-2.6-2.5-5-2.5-3 0-5 1.5-5 3.7 0 5 10 2.6 10 7.6 0 2.2-2 3.7-5 3.7-2.6 0-4.5-1-5.3-2.7"/>'),
    sandik: S('<path d="M4 11h16v9H4zM8 11V4h8v7M10 7h4"/>'),
    terazi: S('<path d="M12 3v17M5 20h14M3 7h18M6 7l-3 5h6L6 7zM18 7l-3 5h6l-3-5z"/>'),
    megafon: S('<path d="M3 11v2a1 1 0 0 0 1 1h3l6 5V5L7 10H4a1 1 0 0 0-1 1zM17 8a5 5 0 0 1 0 8M20 5a9 9 0 0 1 0 14"/>'),
    destek: S('<circle cx="12" cy="12" r="9"/><path d="M9.5 9.3a2.6 2.6 0 0 1 5 .9c0 1.7-2.5 2.3-2.5 3.8M12 17.2h.01"/>'),
    goz: S('<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>'),
    ara: S('<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>'),
    ekip: S('<circle cx="9" cy="8" r="3.4"/><path d="M2.5 20c.8-3.5 3.4-5.5 6.5-5.5s5.7 2 6.5 5.5"/><circle cx="17.5" cy="9" r="2.6"/><path d="M16.5 14.6c2.6.2 4.4 2 5 5"/>'),
    gunluk: S('<path d="M5 3h11l3 3v15H5z"/><path d="M9 9h6M9 13h6M9 17h4"/>'),
    sim: S('<path d="m13 2-9 12h7l-1 8 9-12h-7z"/>'),
    kalkan: S('<path d="M12 3 4.5 6v5.5c0 4.6 3.2 8.2 7.5 9.5 4.3-1.3 7.5-4.9 7.5-9.5V6z"/><path d="m9 12 2 2 4-4"/>'),
    tik: S('<path d="m5 12.5 4.5 4.5L19 7.5"/>', 18),
    carpi: S('<path d="M6 6l12 12M18 6 6 18"/>', 18),
    not: S('<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m14 6 4 4"/>', 18),
    ok: S('<path d="m9 6 6 6-6 6"/>', 18),
    kilit: S('<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>', 18),
    ayar: S('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>')
  };

  const RUTBE = { moderator: "Moderatör", kidemli: "Kıdemli moderatör", sorumlu: "Birim sorumlusu" };
  const ISLEM = Object.assign({}, typeof MOD_ISLEM === "object" ? MOD_ISLEM : {}, {
    kisit_mali: "para çıkışını dondurdu", kisit_secim: "seçim kısıtı koydu", kisit_uzat: "kısıtı uzattı (ikinci imza)", kisit_kaldir: "kısıtı kaldırdı",
    toplu_gizle: "son içeriklerini topluca gizledi", destek_devir: "talebi başka masaya devretti", masa_yetkileri: "masa yaptırım yetkilerini yürürlüğe koydu",
    kayit_onay: "başvuruyu kabul etti", tv_yayin_kes: "TV yayınını kesti", tv_kanal_kapat: "TV kanalını kapattı", tv_kanal_ac: "TV kanalını yeniden açtı", icerik_kaldir: "içeriği yayından kaldırdı", icerik_geri: "içeriği geri yükledi", pano_kaldir: "pano reklamını kaldırdı", kurum_durdur: "kurumun yayınlarını durdurdu", kurum_durdur_talep: "yayın durdurma talebi açtı", kurum_durdur_onay: "yayın durdurmaya ikinci imza attı", kurum_durdur_ret: "yayın durdurma talebini reddetti", kurum_durdur_kaldir: "yayın durdurmayı kaldırdı", kurum_ad: "kurum adını düzeltti", kurum_kapat: "kurumu kapattı", kurum_ac: "kurumu yeniden açtı", kayit_ret: "başvuruyu reddetti", talep_ac: "yaptırım talebi açtı", talep_onay: "talebi onayladı",
    talep_ret: "talebi reddetti", talep_geri: "talebini geri çekti", not_ekle: "dosyaya not ekledi", destek_yanit: "destek talebini yanıtladı",
    destek_kapat: "destek talebini kapattı", yk_sustur: "susturdu", mod_uyari: "resmî uyarı verdi", mod_para_cezasi: "para cezası kesti", yk_engel_sureli: "süreli engelledi / uzaklaştırdı", yk_engel_kalici: "kalıcı engelledi",
    yk_engel_kaldir: "engeli kaldırdı", masak_temiz: "MASAK: temiz dedi", masak_ihtar: "MASAK: ihtar verdi", masak_el_koy: "MASAK: el koydu",
    moderator_birim: "birimini/yetkisini değiştirdi", moderator_sadelestir: "yetkilerini birimine göre sadeleştirdi", moderator_gorev: "ana görevini değiştirdi",
    yk_bildirim: "bildirim gönderdi", sohbet_izle: "grup sohbetini açtı", ifsa_suphe: "moderatör olduğunu açıklamaya çalıştı (mesaj engellendi)", mod_taklit: "kendini yönetimden gösterdi (mesaj engellendi)", sozlesme_kabul: "gizlilik sözleşmesini kabul etti", devir: "kararı tarafsız moderatöre devretti", admin_duyuru: "duyuru yayımladı", yk_para: "para işlemi yaptı", yk_kidem: "kıdem işlemi yaptı",
    duyuru: "duyuru yayımladı", sohbet_resmi: "sohbete yönetim adına yazdı", yardim_yanit: "Yardım Masası'nda yönetim adına yanıt verdi", istinaf_oy: "istinaf dosyasında oy kullandı", istinaf_ihmal: "istinaf görevini yapmadı (üye değiştirildi)",
    cihaz_yasak_kaldir: "cihaz yasağını kaldırdı", cihaz_yasak_ac: "cihazı yeniden yasakladı",
    mod_mesaj: "oyuncuya özel mesaj yazdı", mod_yazili_uyari: "oyuncuya yazılı uyarı gönderdi"
  });
  const ISARET = { baglanti: ["Bağlantı", "#4fc1d6"], telefon: ["Telefon no", "#c86cd8"], kisisel: ["E-posta", "#c86cd8"], buyuk_harf: ["Büyük harf", "#e0a43a"],
    tekrar: ["Tekrar/spam", "#e0a43a"], kufur: ["Küfür şüphesi", "#e5574f"], sert: ["Sert ifade", "#f07f3c"] };
  const NEDEN = { hakaret: "hakaret", nefret: "nefret söylemi", taciz: "taciz", spam: "spam", uygunsuz: "uygunsuz içerik", diger: "diğer" };
  const KUYRUK = {
    talep:   { ad: "Yaptırım talepleri", alt: "Kararını bekleyen", ik: "terazi", renk: "#e5574f", sla: 60,   ac: () => ekranAc(mmTalepler) },
    kayit:   { ad: "Kayıt başvuruları", alt: "Onay bekleyen", ik: "kimlik", renk: "#5b8def", sla: 30,    ac: () => ekranAc(mmKayit) },
    sikayet: { ad: "Şikâyetler", alt: "Açık şikâyet", ik: "sikayet", renk: "#c86cd8", sla: 240,          ac: () => ekranAc(mmSikayet) },
    sohbet:  { ad: "Sohbet nöbeti", alt: "Son 1 saat", ik: "sohbet", renk: "#e0a43a", sla: 0,            ac: () => ekranAc(mmNobet) },
    destek:  { ad: "Destek talepleri", alt: "Yanıt bekleyen", ik: "destek", renk: "#9a7bff", sla: 720,   ac: () => ekranAc(mmDestek) },
    masak:   { ad: "MASAK", alt: "İncelenmemiş işlem", ik: "masak", renk: "#3fb67a", sla: 1440,          ac: () => typeof masakEkrani === "function" ? ekranAc(masakEkrani) : toast("MASAK ekranı bu sürümde yok.", true) },
    coklu:   { ad: "Çoklu hesap", alt: "Onaysız ortak cihaz", ik: "sandik", renk: "#4fc1d6", sla: 0,     ac: () => ekranAc(mmCoklu) },
    kutu:    { ad: "Talep kutusu", alt: "Yönetime Yaz", ik: "destek", renk: "#9a7bff", sla: 240,         ac: () => ekranAc(mmKutu) }
  };
  const SIRA = ["talep", "kayit", "sikayet", "kutu", "destek", "masak", "coklu"];

  /* ---------- Görünüm (tek seferlik CSS) ---------- */
  function css() {
    if (document.getElementById("mmCss")) return;
    const s = document.createElement("style"); s.id = "mmCss";
    s.textContent = `
.mm-hero{position:relative;overflow:hidden;border-radius:20px;padding:16px 15px 14px;margin-bottom:12px;background:radial-gradient(120% 140% at 100% 0%,var(--mm-r,#7b61ff)33 0%,transparent 55%),linear-gradient(160deg,var(--panel2),var(--panel));border:1px solid var(--line2)}
.mm-hero>small{display:block;color:var(--mut);font-size:13px;letter-spacing:.2px}
.mm-hero h2{font-family:var(--disp);font-size:26px;line-height:1.1;margin:2px 0 8px}
.mm-cipler{display:flex;flex-wrap:wrap;gap:6px}
.mm-cip{display:inline-flex;align-items:center;gap:6px;min-height:30px;padding:4px 11px;border-radius:999px;font-size:13.5px;font-weight:650;background:var(--panel3);color:var(--txt2);border:1px solid var(--line2)}
.mm-cip i{width:8px;height:8px;border-radius:50%;background:var(--c,#7b61ff);display:inline-block}
.mm-istat{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:12px}
.mm-istat div{background:rgba(255,255,255,.04);border:1px solid var(--line);border-radius:14px;padding:9px 10px}
.mm-istat b{display:block;font-family:var(--disp);font-size:22px;line-height:1}
.mm-istat span{font-size:12.5px;color:var(--mut)}
.mm-sirada{display:flex;align-items:center;gap:12px;width:100%;min-height:62px;border:0;border-radius:18px;padding:12px 14px;margin:0 0 12px;text-align:left;color:#fff;font:inherit;cursor:pointer;background:linear-gradient(135deg,var(--ink),#5a43d9);box-shadow:0 10px 24px -12px var(--ink)}
.mm-sirada .ik{width:40px;height:40px;border-radius:12px;display:grid;place-items:center;background:rgba(255,255,255,.16);flex:none}
.mm-sirada b{display:block;font-size:17px}.mm-sirada span{font-size:13.5px;opacity:.85}
.mm-sirada.bos{background:linear-gradient(135deg,#1f6f53,#174f3d);box-shadow:none}
.mm-izgara{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:12px}
.mm-karo{position:relative;display:flex;flex-direction:column;align-items:flex-start;gap:6px;min-height:118px;padding:12px;border-radius:18px;border:1px solid var(--line2);background:linear-gradient(170deg,color-mix(in srgb,var(--c) 16%,var(--panel)) 0%,var(--panel) 70%);color:var(--txt);text-align:left;font:inherit;cursor:pointer}
.mm-karo .ik{width:36px;height:36px;border-radius:11px;display:grid;place-items:center;color:var(--c);background:color-mix(in srgb,var(--c) 18%,transparent)}
.mm-karo b{font-family:var(--disp);font-size:30px;line-height:1}
.mm-karo .ad{font-weight:700;font-size:14.5px;line-height:1.2}
.mm-karo .alt{font-size:12.5px;color:var(--mut)}
.mm-karo.acil{border-color:var(--al);box-shadow:0 0 0 1px var(--al) inset}
.mm-karo.acil::after{content:"";position:absolute;top:12px;right:12px;width:9px;height:9px;border-radius:50%;background:var(--al);box-shadow:0 0 0 0 var(--al);animation:mmNabiz 1.6s infinite}
.mm-karo.sifir b{color:var(--faint)}
@keyframes mmNabiz{0%{box-shadow:0 0 0 0 rgba(240,69,75,.6)}70%{box-shadow:0 0 0 10px rgba(240,69,75,0)}100%{box-shadow:0 0 0 0 rgba(240,69,75,0)}}
.mm-arac{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;margin-bottom:12px}
.mm-arac button{display:flex;flex-direction:column;align-items:center;gap:6px;min-height:76px;min-width:0;overflow-wrap:anywhere;padding:10px 4px;border-radius:16px;border:1px solid var(--line2);background:var(--panel);color:var(--txt2);font:inherit;font-size:12.5px;font-weight:650;line-height:1.15;cursor:pointer}
.mm-arac button .ik{color:var(--ink2)}
.mm-ara{display:flex;gap:8px;align-items:center;background:var(--panel2);border:1px solid var(--line2);border-radius:14px;padding:4px 6px 4px 12px}
.mm-ara input{flex:1;min-width:0;background:transparent;border:0;color:var(--txt);font-size:16px;padding:10px 0;outline:none}
.mm-oneri{margin-top:6px}
.mm-satir{display:flex;align-items:center;gap:10px;padding:10px 4px;border-bottom:1px solid var(--line);cursor:pointer}
.mm-satir:last-child{border-bottom:0}
.mm-satir .orta{flex:1;min-width:0}.mm-satir .orta b{display:block;overflow:hidden;text-overflow:ellipsis}
.mm-satir .kucuk{font-size:13px;color:var(--mut)}
.mm-nokta{width:9px;height:9px;border-radius:50%;background:var(--faint);flex:none}.mm-nokta.on{background:var(--good);box-shadow:0 0 0 3px rgba(52,201,138,.18)}
.mm-etiket{display:inline-flex;align-items:center;gap:4px;padding:2px 8px;border-radius:999px;font-size:12px;font-weight:700;background:color-mix(in srgb,var(--c,#7b61ff) 18%,transparent);color:var(--c,#a895ff);white-space:nowrap}
.mm-baslik{display:flex;align-items:center;justify-content:space-between;gap:8px;margin:4px 2px 8px}
.mm-baslik h3{font-size:16px;font-weight:800;margin:0}
.mm-baslik a,.mm-baslik button.link{color:var(--ink2);font-size:14px;font-weight:650;background:none;border:0;padding:6px 0;cursor:pointer}
.mm-filtre{display:flex;gap:6px;overflow-x:auto;padding:2px 0 10px;scrollbar-width:none}.mm-filtre::-webkit-scrollbar{display:none}
.mm-filtre button{flex:none;min-height:36px;padding:6px 13px;border-radius:999px;border:1px solid var(--line2);background:var(--panel);color:var(--txt2);font:inherit;font-size:14px;font-weight:650;cursor:pointer}
.mm-filtre button.on{background:var(--ink);border-color:var(--ink);color:#fff}
.mm-baloncuk{background:var(--panel2);border:1px solid var(--line);border-radius:14px 14px 14px 4px;padding:9px 11px;margin:6px 0;font-size:15px;line-height:1.45;word-break:break-word;white-space:pre-wrap}
.mm-mesaj{padding:10px 2px;border-bottom:1px solid var(--line);cursor:pointer}
.mm-mesaj.gizli{opacity:.48}.mm-mesaj.gizli .mm-baloncuk{text-decoration:line-through}
.mm-mesaj.isaretli .mm-baloncuk{border-color:color-mix(in srgb,var(--al) 55%,transparent)}
.mm-mesaj .mm-u{display:flex;align-items:center;gap:6px;flex-wrap:wrap;font-size:13px;color:var(--mut)}
.mm-mesaj .mm-u b{color:var(--txt);font-size:14.5px}
.mm-kart{background:var(--panel);border:1px solid var(--line2);border-radius:18px;padding:14px;margin-bottom:12px}
.mm-kart.vurgu{border-color:color-mix(in srgb,var(--c,#7b61ff) 60%,transparent);background:linear-gradient(170deg,color-mix(in srgb,var(--c,#7b61ff) 10%,var(--panel)),var(--panel))}
.mm-uyari svg{width:20px;height:20px;flex:none;margin-top:1px}
.mm-uyari{display:flex;gap:10px;align-items:flex-start;padding:11px 12px;border-radius:14px;background:var(--albg);border:1px solid color-mix(in srgb,var(--al) 45%,transparent);color:var(--txt);font-size:14.5px;line-height:1.4;margin:8px 0}
.mm-uyari.sari{background:rgba(242,179,61,.12);border-color:rgba(242,179,61,.4)}
.mm-uyari.yesil{background:rgba(52,201,138,.12);border-color:rgba(52,201,138,.4)}
.mm-iki{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:10px}
.mm-btn{display:flex;align-items:center;justify-content:center;gap:8px;min-height:50px;width:100%;box-sizing:border-box;border-radius:14px;border:1px solid var(--line2);background:var(--panel2);color:var(--txt);font:inherit;font-size:15.5px;font-weight:700;cursor:pointer;padding:8px 12px;text-align:center;line-height:1.2}
.mm-btn.yesil{background:#1f9d6a;border-color:#1f9d6a;color:#fff}.mm-btn.kirmizi{background:var(--al);border-color:var(--al);color:#fff}
.mm-btn.mor{background:var(--ink);border-color:var(--ink);color:#fff}.mm-btn.cizgi{background:transparent}
.mm-btn:disabled{opacity:.5}
select.mm-girdi{min-height:50px}select.mm-girdi option{background:#1b2030;color:#f2f5ff}
.mm-resmi-sablon{display:flex;flex-direction:column;gap:6px}
.mm-resmi-sablon button{width:100%;min-width:0;box-sizing:border-box;min-height:46px;padding:9px 12px;border-radius:12px;border:1px solid var(--line2);background:var(--panel2);color:var(--txt);font:inherit;font-size:14.5px;line-height:1.4;text-align:left;white-space:normal;cursor:pointer}
.mm-aksiyon{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px}
.mm-aksiyon button{min-height:40px;padding:7px 12px;border-radius:12px;border:1px solid var(--line2);background:var(--panel2);color:var(--txt);font:inherit;font-size:14px;font-weight:650;cursor:pointer}
.mm-aksiyon button.k{border-color:color-mix(in srgb,var(--al) 60%,transparent);color:var(--al2)}
.mm-aksiyon button.y{border-color:rgba(52,201,138,.5);color:#5fe0aa}
.mm-yigin{position:relative}
.mm-basvuru{border-radius:22px;padding:18px 16px;background:linear-gradient(165deg,var(--panel2),var(--panel));border:1px solid var(--line2);box-shadow:0 18px 40px -24px #000}
.mm-basvuru .ad{font-family:var(--disp);font-size:30px;line-height:1.05;margin:6px 0 2px;word-break:break-word}
.mm-basvuru .kad{font-size:16px;color:var(--ink2);font-weight:700}
.mm-kv{display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-bottom:1px solid var(--line);font-size:14.5px}.mm-kv:last-child{border-bottom:0}
.mm-kv span:first-child{color:var(--mut)}.mm-kv span:last-child{text-align:right;font-weight:650}
.mm-ilerleme{height:6px;border-radius:9px;background:var(--panel3);overflow:hidden;margin:4px 0 12px}.mm-ilerleme i{display:block;height:100%;background:var(--ink);border-radius:9px;transition:width .3s}
.mm-kontrol{display:grid;gap:6px;margin-top:10px}
.mm-kontrol div{display:flex;gap:8px;align-items:center;font-size:14px;color:var(--txt2)}.mm-kontrol svg{color:var(--good);flex:none}
.mm-sekme{display:flex;gap:4px;background:var(--panel);border:1px solid var(--line2);border-radius:14px;padding:4px;margin:0 0 12px;overflow-x:auto;scrollbar-width:none}.mm-sekme::-webkit-scrollbar{display:none}
.mm-sekme button{flex:1 0 auto;min-height:38px;padding:6px 12px;border-radius:10px;border:0;background:transparent;color:var(--mut);font:inherit;font-size:14px;font-weight:700;cursor:pointer;white-space:nowrap}
.mm-sekme button.on{background:var(--panel3);color:var(--txt)}
.mm-dosya-ust{display:flex;gap:12px;align-items:center}
.mm-dosya-ust .portre-kutu{width:64px;height:64px;border-radius:18px;overflow:hidden;flex:none;background:var(--panel3)}
.mm-dosya-ust .portre-kutu svg{width:100%;height:100%}
.mm-dosya-ust h2{font-family:var(--disp);font-size:24px;line-height:1.05;margin:0;word-break:break-word}
.mm-birim{border-radius:18px;border:1px solid var(--line2);background:var(--panel);margin-bottom:10px;overflow:hidden}
.mm-birim .mm-u{display:flex;gap:10px;align-items:center;padding:12px 12px 8px;border-top:4px solid var(--c)}
.mm-birim .mm-u .ik{width:38px;height:38px;border-radius:12px;display:grid;place-items:center;color:var(--c);background:color-mix(in srgb,var(--c) 18%,transparent);flex:none}
.mm-birim .mm-u b{display:block;font-size:15.5px}
.mm-birim .mm-u small{font-size:12.5px;color:var(--mut)}
.mm-doluluk{margin-left:auto;font-weight:800;font-size:14px;padding:3px 10px;border-radius:999px;background:rgba(52,201,138,.15);color:#5fe0aa;flex:none}
.mm-doluluk.eksik{background:var(--albg);color:var(--al2)}
.mm-birim .uyeler{padding:0 12px 6px}
.mm-birim .ekle{display:block;width:100%;border:0;border-top:1px dashed var(--line2);background:transparent;color:var(--ink2);font:inherit;font-weight:700;font-size:14.5px;min-height:46px;cursor:pointer}
.mm-secim{display:grid;grid-template-columns:1fr 1fr;gap:6px}
.mm-secim button{min-height:48px;border-radius:12px;border:1px solid var(--line2);background:var(--panel2);color:var(--txt2);font:inherit;font-size:13.5px;font-weight:700;padding:6px 8px;text-align:left;display:flex;gap:8px;align-items:center;cursor:pointer;line-height:1.15}
.mm-secim button i{width:10px;height:10px;border-radius:50%;background:var(--c);flex:none}
.mm-secim button.on{border-color:var(--c,var(--ink));background:color-mix(in srgb,var(--c,#7b61ff) 18%,var(--panel2));color:var(--txt)}
.mm-anahtar{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:10px 2px;border-bottom:1px solid var(--line)}
.mm-anahtar .orta{flex:1;min-width:0}.mm-anahtar .orta b{font-size:14.5px}.mm-anahtar .orta div{font-size:12.5px;color:var(--mut);line-height:1.35}
.mm-anahtar input{width:22px;height:22px;flex:none;accent-color:var(--ink)}
.mm-alan{display:block;margin:10px 0 4px;font-size:15px;font-weight:700;color:var(--txt2)}
.mm-girdi{display:block;width:100%;min-width:0;box-sizing:border-box;font-size:16px;color:var(--txt);background:var(--panel2);border:1px solid var(--line2);border-radius:12px;padding:12px;color-scheme:dark}
textarea.mm-girdi{min-height:88px;resize:vertical;line-height:1.45}
.mm-tablo{width:100%;border-collapse:collapse;font-size:13.5px}
.mm-tablo th{text-align:left;color:var(--mut);font-weight:700;padding:6px 4px;border-bottom:1px solid var(--line2)}
.mm-tablo td{padding:8px 4px;border-bottom:1px solid var(--line)}
.mm-tablo td.s{text-align:right;font-variant-numeric:tabular-nums;font-weight:700}
.mm-bos{padding:22px 10px;text-align:center;color:var(--mut);font-size:14.5px}
.mm-bos b{display:block;color:var(--txt);font-size:16px;margin:8px 0 2px}
.mm-bos .ik{width:52px;height:52px;margin:0 auto;border-radius:16px;display:grid;place-items:center;background:rgba(52,201,138,.14);color:#5fe0aa}
.mm-kilit{display:inline-flex;align-items:center;gap:4px;font-size:12.5px;font-weight:700;color:var(--warn)}
.mm-alt{font-size:13px;color:var(--mut);line-height:1.4}
.mm-cy{padding:12px 2px;border-bottom:1px solid var(--line)}.mm-cy:last-child{border-bottom:0}
.mm-cy .cyb{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:3px}
.mm-cy .cyb b{font-size:16px;min-width:0;overflow-wrap:anywhere}
.mm-cy a{color:var(--ink2);font-weight:700;cursor:pointer;text-decoration:none}
`;
    document.head.appendChild(s);
  }

  /* ---------- Ortak yardımcılar ---------- */
  let M = null; // son mod_merkez yanıtı
  const yv = (k) => !!(M && M.ben && (M.ben.yonetici || (M.ben.yetkiler || []).includes(k)));
  const bos = (baslik, metin) => `<div class="mm-bos"><div class="ik">${IK.kalkan}</div><b>${esc(baslik)}</b>${esc(metin || "")}</div>`;
  async function merkezYukle() { M = await API.rpc("mod_merkez"); return M; }
  function sayfa(baslik, govde) { css(); iskelet(baslik, govde, { geri: true }); }
  function hataSayfa(baslik, err) { sayfa(baslik, `<div class="mm-kart">${esc(hc(err.message || String(err)))}</div>`); }
  function sec(html) { const d = document.createElement("div"); d.innerHTML = html; return d; }
  function sheet(html) { css(); return modal(html); }
  function cipSec(kutu, cb) {
    kutu.querySelectorAll("[data-v]").forEach(b => b.onclick = () => { kutu.querySelectorAll("[data-v]").forEach(x => x.classList.remove("on")); b.classList.add("on"); cb && cb(b.dataset.v); });
  }

  /* =====================================================================
     1) PANO
     ===================================================================== */
  async function modMerkezi(sessiz) {
    css();
    if (sessiz !== true) {
      yukleniyor("Moderasyon Merkezi");
      try { await merkezYukle(); } catch (err) { hataSayfa("Moderasyon Merkezi", err); return; }
    }
    const b = M.ben, ist = M.istatistik || {}, q = M.kuyruk || {};
    if (!b.yonetici && !b.sozlesme_at) return sozlesmeEkrani();
    const birim = (M.birimler || []).find(x => x.kod === b.birim);
    const renk = birim ? birim.renk : "#7b61ff";
    const saat = new Date(simdiMs()).getHours();
    const selam = saat < 6 ? "İyi geceler" : saat < 12 ? "Günaydın" : saat < 18 ? "İyi günler" : "İyi akşamlar";
    // Sıradaki iş
    let sirada = null;
    for (const k of SIRA) { const x = q[k]; if (x && x.sayi > 0) { sirada = k; break; } }
    const karolar = Object.keys(KUYRUK).filter(k => q[k]).map(k => {
      const K = KUYRUK[k], x = q[k], n = k === "sohbet" ? (x.isaretli || 0) : (x.sayi || 0);
      const acil = K.sla && x.en_eski && dkGecti(x.en_eski) > K.sla;
      const alt = k === "sohbet" ? `${sayi(x.sayi)} mesaj · ${n} işaretli` : (x.en_eski && n ? "en eskisi " + once(x.en_eski) : K.alt);
      return `<button class="mm-karo ${acil ? "acil" : ""} ${n ? "" : "sifir"}" style="--c:${K.renk}" data-k="${k}"><span class="ik">${IK[K.ik]}</span><b>${sayi(n)}</b><span class="ad">${K.ad}</span><span class="alt">${esc(alt)}</span></button>`;
    }).join("");
    const ekibim = birim ? (birim.uyeler || []) : [];
    const araclar = [
      ["ara", "Oyuncu dosyası", "ara"], yv("duyuru") ? ["megafon", "Duyuru", "duyuru"] : null,
      ["gunluk", b.yonetici ? "Denetim günlüğü" : "İşlemlerim", "gunluk"], ["terazi", "Taleplerim", "taleplerim"],
      yv("sikayet") ? ["sikayet", "Kürsü şikâyetleri", "kursu"] : null, yv("sikayet") ? ["tv", "TV yayınları", "tv"] : null, yv("sikayet") ? ["gazete", "Medya denetimi", "medya"] : null, ["kilit", "Kısıtlar ve yetkilerim", "kisit"],
      yv("hesap_kapat") ? ["kalkan", "Yasaklı cihazlar", "cihaz"] : null, ["destek", "Talep kutusu", "kutu"],
      typeof window.yardimMasasiAc === "function" ? ["sohbet", "Yardım Masası", "yardim"] : null,
      b.yonetici ? ["ekip", "Ekip yönetimi", "ekip"] : ["ekip", "Ekip", "ekipgor"],
      yv("ekonomi") && typeof finansMasasiEkrani === "function" ? ["masak", "Finans masası", "finans"] : null,
      (b.yonetici || yv("para") || yv("makam")) && typeof kontrolMerkezi === "function" ? ["ayar", "Kontrol Merkezi", "km"] : null,
      typeof yoneticiEkraniKlasik === "function" ? ["gunluk", "Klasik panel", "klasik"] : null
    ].filter(Boolean);
    sayfa("Moderasyon Merkezi", `
      <section class="mm-hero" style="--mm-r:${renk}">
        <small>${selam}</small>
        <h2>${esc(b.kad)}</h2>
        <div class="mm-cipler">
          ${b.yonetici ? `<span class="mm-cip" style="--c:#d9b45b"><i></i>Oyun kurucusu</span>` : ""}
          ${b.birim_ad ? `<span class="mm-cip" style="--c:${renk}"><i></i>${esc(b.birim_ad)}</span>` : (!b.yonetici ? `<span class="mm-cip" style="--c:#98a4c4"><i></i>Birim atanmadı</span>` : "")}
          ${!b.yonetici ? `<span class="mm-cip">${esc(RUTBE[b.rutbe] || "Moderatör")}</span>` : ""}
          ${!b.yonetici && b.kod ? `<span class="mm-cip" style="--c:#34c98a" title="Oyunculara giden bildirim, duyuru ve yanıtlarda adın yerine bu unvan görünür"><i></i>Unvanın: Oyun Yöneticisi ${esc(b.kod)}</span>` : ""}
        </div>
        <div class="mm-istat">
          <div><b>${sayi(ist.bugun)}</b><span>bugün işlemim</span></div>
          <div><b>${sayi(ist.hafta)}</b><span>7 gün${ist.sira ? ` · ${ist.sira}. sıra` : ""}</span></div>
          <div><b>${sayi(ist.cevrimici)}<small style="font-size:14px;color:var(--mut)">/${sayi(ist.ekip)}</small></b><span>ekip çevrimiçi</span></div>
        </div>
      </section>
      ${b.yonetici && M.kritik_uyari ? `<div class="mm-uyari sari">${IK.kilit}<div><b>${M.kritik_uyari} moderatörde kritik yetki açık</b> (para, görev, kurallar, e-posta). Ekip yönetiminden birimlerine göre sadeleştirebilirsin.<div style="margin-top:6px"><button class="mm-btn cizgi" style="min-height:40px" data-ac="ekip">Ekip yönetimini aç</button></div></div></div>` : ""}
      ${!b.yonetici && !b.birim ? `<div class="mm-uyari sari">${IK.kalkan}<div>Henüz bir uzmanlık birimine atanmadın. Bu sürede yeni oyuncu başvurularını onaylayabilir ve sana verilen yetkileri kullanabilirsin.</div></div>` : ""}
      ${b.not ? `<div class="mm-uyari yesil">${IK.not}<div><b>Yönetici notu:</b> ${esc(b.not)}</div></div>` : ""}
      <button class="mm-sirada ${sirada ? "" : "bos"}" data-ac="sirada"><span class="ik">${sirada ? IK.sim : IK.tik}</span><div style="flex:1">
        <b>${sirada ? "Sıradaki işi getir" : "Bekleyen iş yok"}</b>
        <span>${sirada ? `${KUYRUK[sirada].ad} · ${q[sirada].sayi} bekliyor` : "Tüm kuyruklar temiz. Sohbet nöbetine göz atabilirsin."}</span></div>${IK.ok}</button>
      <div class="mm-ara">${IK.ara}<input id="mmAra" placeholder="Oyuncu ara: kullanıcı adı" autocapitalize="off" autocomplete="off" enterkeyhint="search"></div>
      <div class="mm-oneri" id="mmOneri"></div>
      <div class="mm-baslik" style="margin-top:12px"><h3>İş kuyrukların</h3><button class="link" data-ac="yenile">Yenile</button></div>
      <div class="mm-izgara">${karolar || `<div class="mm-kart" style="grid-column:1/-1">Sana tanımlı bir iş kuyruğu yok.</div>`}</div>
      <div class="mm-baslik"><h3>Araçlar</h3></div>
      <div class="mm-arac">${araclar.map(a => `<button data-ac="${a[2]}"><span class="ik">${IK[a[0]]}</span>${a[1]}</button>`).join("")}</div>
      ${ekibim.length ? `<div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Birim arkadaşların</h3></div>${ekibim.map(u => `<div class="mm-satir" data-dosya="${esc(u.kad)}"><span class="mm-nokta ${u.cevrimici ? "on" : ""}"></span><div class="orta"><b>${esc(u.kad)}</b><div class="kucuk">${esc(RUTBE[u.rutbe] || "Moderatör")} · ${u.cevrimici ? "çevrimiçi" : "son görülme " + once(u.son_gorulme)}</div></div></div>`).join("")}</div>` : ""}
      ${(M.son_islemlerim || []).length ? `<div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Son işlemlerim</h3><button class="link" data-ac="gunluk">Tümü</button></div>${M.son_islemlerim.map(k => `<div class="mm-satir" style="cursor:default"><div class="orta"><b style="font-weight:650">${esc(ISLEM[k.islem] || k.islem)}${k.hedef ? ` · ${esc(k.hedef)}` : ""}</b><div class="kucuk">${once(k.zaman)}</div></div></div>`).join("")}</div>` : ""}
      <p class="mm-alt" style="text-align:center;margin:6px 0 14px">Her işlem kayda geçer. Yöneticiye ve diğer moderatörlere işlem yapılamaz.</p>`);
    const ic = $("#icerik");
    ic.querySelectorAll("[data-k]").forEach(x => x.onclick = () => KUYRUK[x.dataset.k].ac());
    ic.querySelectorAll("[data-dosya]").forEach(x => x.onclick = () => mmDosyaAc(x.dataset.dosya));
    ic.querySelectorAll("[data-ac]").forEach(x => x.onclick = () => {
      const a = x.dataset.ac;
      if (a === "sirada") { if (sirada) KUYRUK[sirada].ac(); else if (q.sohbet) ekranAc(mmNobet); return; }
      if (a === "yenile") return modMerkezi();
      if (a === "ara") return $("#mmAra").focus();
      if (a === "duyuru") return ekranAc(mmDuyuru);
      if (a === "gunluk") return ekranAc(mmGunluk);
      if (a === "taleplerim") return ekranAc(mmTalepler);
      if (a === "kursu") return ekranAc(mmKursu);
      if (a === "tv") return ekranAc(mmTv);
      if (a === "medya") return ekranAc(mmMedya);
      if (a === "kisit") return ekranAc(mmKisitlar);
      if (a === "cihaz") return ekranAc(mmCihaz);
      if (a === "kutu") return ekranAc(mmKutu);
      if (a === "yardim") return window.yardimMasasiAc();
      if (a === "ekip") return ekranAc(mmEkip);
      if (a === "ekipgor") return ekranAc(mmEkipGor);
      if (a === "finans") return ekranAc(finansMasasiEkrani);
      if (a === "km") return kontrolMerkezi();
      if (a === "klasik") return ekranAc(yoneticiEkraniKlasik);
    });
    oyuncuAramaBagla($("#mmAra"), $("#mmOneri"));
    // Pano açıkken 60 sn'de bir sessiz tazele (kuyruk sayıları)
    canliDurdur();
    D.canli = setInterval(async () => {
      if (document.hidden || !$("#mmAra") || document.activeElement === $("#mmAra") || $("#modal")) return;
      try { const eski = JSON.stringify(M.kuyruk); await merkezYukle(); if (JSON.stringify(M.kuyruk) !== eski) modMerkezi(true); } catch (_) {}
    }, 60000);
  }

  function sozlesmeEkrani() {
    const k = [
      ["Kimliğini gizli tut", "Oyunda, sohbette, özel mesajda, gazetede ya da oyun dışında (sosyal medya dahil) moderatör olduğunu söyleme, ima etme. Bunu yazarsan mesajın yayınlanmaz ve yöneticiye bildirilir."],
      ["Ekip arkadaşlarını açık etme", "Kimin moderatör olduğunu kimseye söyleme. Oyunculara giden bildirim, duyuru, talep yanıtı ve Yardım Masası yanıtlarında adın yerine görev unvanın (“Oyun Yöneticisi” ve kodun) görünür; İstinaf Dairesi üyeliğin de gizlidir."],
      ["Normal oyuncu gibi oyna", "Seçime gir, parti kur, ticaret yap; ama moderatör yetkini kendi oyunun, partin ya da arkadaşların için asla kullanma."],
      ["Kendi partiline kıyak yok", "Kendi partinden bir oyuncunun içeriğini gizleyebilir, kanıtla susturabilirsin; ama onun lehine karar veremezsin (sorun yok, temiz, talebi reddetme, susturmayı kaldırma). Böyle bir dosya kendiliğinden tarafsız bir moderatöre devredilir; talep açman gerekmez. Aynı cihazı kullandığın ya da aranızda dava olan oyuncuya hiçbir işlem yapamazsın."],
      ["Gördüğünü dışarı taşıma", "Grup sohbetleri, şikâyetler, MASAK kayıtları ve oyuncu dosyaları gizlidir. Ekran görüntüsü paylaşma, kimseye anlatma."],
      ["Her işlem kayıt altında", "Yaptığın her işlem ve açtığın her kapalı sohbet denetim günlüğüne yazılır; yönetici görür. Kurallara uymamak moderatörlükten alınma sebebidir."]
    ];
    sayfa("Moderasyon Merkezi", `<section class="mm-hero"><small>Göreve başlamadan önce</small><h2>Moderatör gizlilik ve tarafsızlık sözleşmesi</h2>
      <p class="mm-alt" style="margin:0">Oyuncular kimin moderatör olduğunu bilmez; bu, ayrımcılık algısını önler ve herkese eşit davranıldığından emin olmamızı sağlar.</p></section>
      ${k.map((x, i) => `<div class="mm-kart"><div style="display:flex;gap:10px;align-items:flex-start"><span class="mm-etiket" style="--c:#7b61ff;min-width:26px;justify-content:center">${i + 1}</span><div><b style="font-size:15.5px">${esc(x[0])}</b><div class="mm-alt" style="margin-top:3px;font-size:14px">${esc(x[1])}</div></div></div></div>`).join("")}
      <label class="mm-anahtar" style="border:0"><div class="orta"><b>Okudum, kabul ediyorum</b><div>Kabul tarihin kayda geçer.</div></div><input type="checkbox" id="mmSozOk"></label>
      <button class="mm-btn mor" id="mmSozKabul" disabled>Sözleşmeyi kabul et ve devam et</button>`);
    $("#mmSozOk").onchange = (ev) => { $("#mmSozKabul").disabled = !ev.target.checked; };
    $("#mmSozKabul").onclick = async () => { try { await API.rpc("mod_sozlesme_kabul"); toast("Sözleşme kabul edildi. İyi nöbetler!"); modMerkezi(); } catch (err) { hata(err); } };
  }

  function oyuncuAramaBagla(inp, kutu) {
    if (!inp) return;
    let zam = null, son = "";
    const ara = async () => {
      const v = inp.value.trim(); if (v === son) return; son = v;
      if (v.length < 2) { kutu.innerHTML = ""; return; }
      try {
        const r = await API.rpc("yk_oyuncular", { p_ara: v, p_filtre: "hepsi", p_sirala: "ad", p_limit: 8, p_offset: 0 });
        if (inp.value.trim() !== v) return;
        kutu.innerHTML = (r.liste || []).length ? `<div class="mm-kart" style="padding:4px 12px">${r.liste.map(o => `<div class="mm-satir" data-kad="${esc(o.kad)}"><span class="mm-nokta ${o.son_gorulme && dkGecti(o.son_gorulme) < 15 ? "on" : ""}"></span><div class="orta"><b>${esc(o.kad)}</b><div class="kucuk">${esc(o.il || "")}${o.parti ? " · " + esc(o.parti.kisa) : ""}${o.makam ? " · " + esc(o.makam) : ""}</div></div>${o.yasakli ? `<span class="mm-etiket" style="--c:#e5574f">engelli</span>` : o.susturma_bitis ? `<span class="mm-etiket" style="--c:#e0a43a">susturulmuş</span>` : (o.yonetici || o.moderator) ? `<span class="mm-etiket" style="--c:#d9b45b">yönetim</span>` : ""}${IK.ok}</div>`).join("")}</div>`
          : `<div class="mm-alt" style="padding:6px 4px">“${esc(v)}” ile eşleşen oyuncu yok.</div>`;
        kutu.querySelectorAll("[data-kad]").forEach(x => x.onclick = () => mmDosyaAc(x.dataset.kad));
      } catch (err) { kutu.innerHTML = `<div class="mm-alt">${esc(hc(err.message))}</div>`; }
    };
    inp.oninput = () => { clearTimeout(zam); zam = setTimeout(ara, 280); };
    inp.onkeydown = (ev) => { if (ev.key === "Enter") { const v = inp.value.trim(); if (v) mmDosyaAc(v); } };
  }

  /* =====================================================================
     2) KAYIT MASASI — kart kart karar
     ===================================================================== */
  const RET = [
    ["Gerçek siyasetçi adı kullanılamaz.", "Gerçek siyasetçi"],
    ["Kamuoyunca bilinen gerçek bir kişinin adı kullanılamaz.", "Bilinen kişi"],
    ["Ad soyad gerçekçi değil; gerçek bir ad ve soyad yaz.", "Gerçekçi değil"],
    ["Kullanıcı adı uygunsuz ya da yanıltıcı.", "Uygunsuz kullanıcı adı"],
    ["Ad soyad ya da kullanıcı adı hakaret/argo içeriyor.", "Hakaret/argo"],
    ["Mükerrer hesap: engellenen ya da hâlen hesabı olan bir oyuncu yeni hesapla başvuramaz.", "Mükerrer hesap"]
  ];
  // 23.11.2026 · Cihaz yasağı: başvurunun cihaz/bağlantı uyarıları (sunucu: admin_kayit_basvurulari → cihaz_uyari)
  const cihazSatir = (x) => ((x && x.cihaz_uyari && x.cihaz_uyari.satirlar) || []);
  const cihazGuclu = (x) => !!(x && x.cihaz_uyari && x.cihaz_uyari.guclu);
  const cihazKutu = (sr) => `<div class="mm-uyari ${sr.seviye === "guclu" ? "" : "sari"}">${IK.kalkan}<div>${sr.seviye === "guclu" ? "<b>Mükerrer hesap uyarısı.</b> " : ""}${esc(sr.metin)}</div></div>`;
  const KM = { liste: [], i: 0, karar: 0, gorunum: "kart" };
  async function mmKayit() {
    yukleniyor("Kayıt masası");
    let l, u;
    try { [l, u] = await Promise.all([API.rpc("admin_kayit_basvurulari"), API.rpc("mod_ustlenmeler", { p_tur: "kayit" })]); }
    catch (err) { hataSayfa("Kayıt masası", err); return; }
    KM.tum = l; KM.liste = l.filter(x => x.durum === "beklemede").sort((a, b) => new Date(a.basvuru_at) - new Date(b.basvuru_at)); KM.ust = u || {};
    KM.i = 0; KM.karar = 0;
    kayitCiz();
  }
  function kayitCiz() {
    const L = KM.liste, toplam = L.length + KM.karar;
    if (KM.gorunum === "liste") return kayitListe();
    // başkasının incelediğini atla
    while (KM.i < L.length && KM.ust[L[KM.i].user_id] && !KM.ust[L[KM.i].user_id].ben) KM.i++;
    const x = L[KM.i];
    const digerInc = L.filter(y => KM.ust[y.user_id] && !KM.ust[y.user_id].ben).length;
    const ust = `<div class="mm-filtre"><button class="on" data-g="kart">Tek tek</button><button data-g="liste">Liste ve geçmiş</button></div>`;
    if (!x) {
      sayfa("Kayıt masası", ust + (digerInc ? `<div class="mm-uyari sari">${IK.kilit}<div>${digerInc} başvuruya şu an başka bir moderatör bakıyor.</div></div>` : "")
        + bos(KM.karar ? `Harika iş: ${KM.karar} karar verdin` : "Bekleyen başvuru yok", "Yeni başvuru geldiğinde Moderasyon Merkezi'nde sayısı görünür.")
        + `<button class="mm-btn" id="mmKYen">Yenile</button>`);
      $("#mmKYen").onclick = mmKayit; gorunumBagla(); return;
    }
    API.rpc("mod_ustlen", { p_tur: "kayit", p_anahtar: x.user_id }).then(r => {
      if (r && r.tamam === false) { KM.ust[x.user_id] = { kad: r.inceleyen }; toast(`${r.inceleyen} bu başvuruya bakıyor; sıradakine geçildi.`); kayitCiz(); }
    }).catch(() => {});
    const yuzde = toplam ? Math.round((KM.karar / toplam) * 100) : 0;
    const uyari = x.uyari ? `<div class="mm-uyari">${IK.kilit}<div><b>Bilinen kişi adına benziyor:</b> ${esc(x.uyari)}. Gerçek siyasetçi ve kamuoyunca bilinen kişi adları reddedilir.</div></div>` : "";
    const onceki = (x.onceki_red || []).length ? `<div class="mm-uyari sari">${IK.gunluk}<div><b>Daha önce ${x.onceki_red.length} kez reddedildi.</b>${x.onceki_red.slice(0, 3).map(r => `<div class="mm-alt">“${esc(r.ad_soyad || "")}” · ${esc(r.neden || "")} · ${esc(r.veren || "")}</div>`).join("")}</div></div>` : "";
    sayfa("Kayıt masası", `${ust}
      <div class="mm-baslik" style="margin-top:0"><h3>${KM.i + 1} / ${L.length} bekleyen</h3><span class="mm-alt">${KM.karar} karar</span></div>
      <div class="mm-ilerleme"><i style="width:${yuzde}%"></i></div>
      <div class="mm-basvuru">
        <span class="mm-etiket" style="--c:#5b8def">Yeni oyuncu başvurusu</span>
        <div class="ad">${esc(x.ad_soyad || "Ad soyad yok")}</div>
        <div class="kad">@${esc(x.kad)}</div>
        <div style="margin-top:12px">
          <div class="mm-kv"><span>İl</span><span>${esc(x.il || "—")}</span></div>
          <div class="mm-kv"><span>Başvuru</span><span>${once(x.basvuru_at)}</span></div>
          <div class="mm-kv"><span>Hesap açılışı</span><span>${tsaat(x.olusturma)}</span></div>
          ${x.red_sayisi ? `<div class="mm-kv"><span>Ret sayısı</span><span>${x.red_sayisi}</span></div>` : ""}
        </div>
        ${uyari}${cihazSatir(x).map(cihazKutu).join("")}${onceki}
        <div class="mm-kontrol">
          <div>${IK.tik}Ad soyad gerçek bir siyasetçiye ya da bilinen kişiye ait değil</div>
          <div>${IK.tik}Ad ve soyad gerçekçi, hakaret ya da şaka içermiyor</div>
          <div>${IK.tik}Kullanıcı adı uygun, kimseyi taklit etmiyor</div>
        </div>
      </div>
      <div class="mm-iki"><button class="mm-btn kirmizi" id="mmRed">${IK.carpi}Reddet</button><button class="mm-btn yesil" id="mmKabul">${IK.tik}Kabul et</button></div>
      <button class="mm-btn cizgi" style="margin-top:8px" id="mmAtla">Şimdilik atla</button>
      ${digerInc ? `<p class="mm-alt" style="margin-top:8px">${digerInc} başvuruya başka bir moderatör bakıyor; onlar sana gösterilmez.</p>` : ""}`);
    gorunumBagla();
    const karar = async (onay, neden, goruldu) => {
      document.querySelectorAll(".mm-btn").forEach(b => b.disabled = true);
      try {
        if (goruldu) await API.rpc("mod_kayit_karar", { p_user: x.user_id, p_onay: onay, p_neden: neden || null, p_uyari_goruldu: true });
        else await API.rpc("admin_kayit_karar2", { p_user: x.user_id, p_onay: onay, p_neden: neden || null });
        toast(onay ? `${x.kad} oyuna kabul edildi.` : `${x.kad} reddedildi.`);
        KM.karar++; L.splice(KM.i, 1); kayitCiz();
      } catch (err) { hata(err); document.querySelectorAll(".mm-btn").forEach(b => b.disabled = false); }
    };
    $("#mmKabul").onclick = () => {
      if (!cihazGuclu(x)) return karar(true);
      const m = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">Mükerrer hesap uyarısı</h3>
        <p class="mm-alt" style="margin:4px 0 8px">Bu başvuru engellenmiş bir hesapla bağlantılı görünüyor. Büyük olasılıkla aynı kişi yeni bir adla başvuruyor.</p>
        ${cihazSatir(x).filter(sr => sr.seviye === "guclu").map(cihazKutu).join("")}
        <button class="mm-btn kirmizi" style="margin-top:10px" id="mmCuRed">${IK.carpi}Reddet (önerilen)</button>
        <button class="mm-btn cizgi" style="margin-top:8px" id="mmCuOnay">Uyarıyı gördüm, yine de kabul et</button>
        <button class="mm-btn cizgi" style="margin-top:8px" id="mmCuVaz">Vazgeç</button>`);
      $("#mmCuVaz", m).onclick = modalKapat;
      $("#mmCuRed", m).onclick = () => { modalKapat(); karar(false, RET[5][0]); };
      $("#mmCuOnay", m).onclick = () => { modalKapat(); karar(true, null, true); };
    };
    $("#mmAtla").onclick = () => { API.rpc("mod_ustlen", { p_tur: "kayit", p_anahtar: x.user_id, p_birak: true }).catch(() => {}); KM.i++; if (KM.i >= L.length) KM.i = 0; kayitCiz(); };
    $("#mmRed").onclick = () => {
      const m = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">Reddetme gerekçesi</h3><p class="mm-alt" style="margin:4px 0 8px">Oyuncu gerekçeyi görür ve farklı ad soyadla yeniden başvurabilir.</p>
        <div class="mm-secim" id="mmRetSec">${RET.map((r, i) => `<button data-v="${i}" style="--c:#e5574f"><i></i>${r[1]}</button>`).join("")}</div>
        <label class="mm-alan" for="mmRetMetin">Gerekçe</label><textarea class="mm-girdi" id="mmRetMetin" maxlength="300">${esc(x.uyari ? RET[0][0] : cihazGuclu(x) ? RET[5][0] : "")}</textarea>
        <button class="mm-btn kirmizi" style="margin-top:10px" id="mmRetOk">Reddet</button><button class="mm-btn cizgi" style="margin-top:8px" id="mmRetVaz">Vazgeç</button>`);
      cipSec($("#mmRetSec", m), v => { $("#mmRetMetin", m).value = RET[+v][0]; });
      $("#mmRetVaz", m).onclick = modalKapat;
      $("#mmRetOk", m).onclick = () => { const n = $("#mmRetMetin", m).value.trim(); if (n.length < 5) { toast("Kısa bir gerekçe yaz.", true); return; } modalKapat(); karar(false, n); };
    };
  }
  function gorunumBagla() { document.querySelectorAll("[data-g]").forEach(b => b.onclick = () => { KM.gorunum = b.dataset.g; kayitCiz(); }); }
  function kayitListe() {
    const L = KM.liste, G = (KM.tum || []).filter(x => x.durum !== "beklemede").slice(0, 40);
    sayfa("Kayıt masası", `<div class="mm-filtre"><button data-g="kart">Tek tek</button><button class="on" data-g="liste">Liste ve geçmiş</button></div>
      <div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Bekleyen (${L.length})</h3></div>
        ${L.map(x => `<div class="mm-satir" style="cursor:default"><div class="orta"><b>${esc(x.ad_soyad || "—")} <span class="kucuk">@${esc(x.kad)}</span></b><div class="kucuk">${esc(x.il || "")} · ${once(x.basvuru_at)}${KM.ust[x.user_id] && !KM.ust[x.user_id].ben ? ` · <span class="mm-kilit">${IK.kilit}${esc(KM.ust[x.user_id].kad)} inceliyor</span>` : ""}</div></div>${x.uyari ? `<span class="mm-etiket" style="--c:#e5574f">uyarı</span>` : ""}${cihazGuclu(x) ? `<span class="mm-etiket" style="--c:#e5574f">mükerrer?</span>` : cihazSatir(x).some(sr => sr.seviye === "zayif") ? `<span class="mm-etiket" style="--c:#e0a43a">cihaz</span>` : ""}</div>`).join("") || `<div class="mm-alt">Bekleyen başvuru yok.</div>`}</div>
      <div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Son kararlar</h3></div>
        ${G.map(x => `<div class="mm-satir" style="cursor:default"><div class="orta"><b>${esc(x.ad_soyad || "—")} <span class="kucuk">@${esc(x.kad)}</span></b><div class="kucuk">${esc(x.karar_veren || "")} · ${once(x.karar_at)}${x.ret_neden ? " · " + esc(x.ret_neden) : ""}</div></div><span class="mm-etiket" style="--c:${x.durum === "onaylandi" ? "#34c98a" : "#e5574f"}">${x.durum === "onaylandi" ? "kabul" : "ret"}</span></div>`).join("") || `<div class="mm-alt">Henüz karar yok.</div>`}</div>`);
    gorunumBagla();
  }

  /* =====================================================================
     3) ŞİKÂYET MASASI
     ===================================================================== */
  async function mmSikayet() {
    yukleniyor("Şikâyet masası");
    let l, u;
    try { [l, u] = await Promise.all([API.rpc("admin_sikayetler", { p_durum: "yeni" }), API.rpc("mod_ustlenmeler", { p_tur: "sikayet" })]); }
    catch (err) { hataSayfa("Şikâyet masası", err); return; }
    if (!M) try { await merkezYukle(); } catch (_) {}
    l.sort((a, b) => (b.sayi - a.sayi) || (new Date(a.ilk) - new Date(b.ilk)));
    const TUR = { mesaj: "Sohbet mesajı", ozel: "Özel mesaj", yayin: "Propaganda yayını", oyuncu: "Oyuncu" };
    const anah = (x) => `${x.tur}:${x.kayit_id || 0}:${x.hedef}`;
    const kartlar = l.map((x, i) => {
      const inc = u[anah(x)], baskasi = inc && !inc.ben;
      const gec = dkGecti(x.ilk) > 240;
      return `<div class="mm-kart ${gec ? "vurgu" : ""}" style="--c:#e5574f" data-i="${i}">
        <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px">${esc(x.hedef)}</b><span style="display:flex;gap:6px;flex-wrap:wrap;justify-content:flex-end">${x.devir ? `<span class="mm-etiket" style="--c:#7b61ff">tarafsız karar bekliyor</span>` : ""}<span class="mm-etiket" style="--c:#e5574f">${x.sayi} şikâyet</span></span></div>
        <div class="mm-alt" style="margin-top:2px">${TUR[x.tur] || x.tur} · ${(x.nedenler || []).map(n => NEDEN[n] || n).join(", ")} · ${once(x.ilk)} · toplam ${x.hedef_sikayet_toplam}${x.gizli ? " · gizlendi" : ""}</div>
        ${baskasi ? `<div class="mm-kilit" style="margin-top:6px">${IK.kilit}${esc(inc.kad)} inceliyor</div>` : ""}
        ${x.icerik ? `<div class="mm-baloncuk">${esc(x.icerik)}</div>` : ""}
        ${x.kilit ? `<div class="mm-kilit" style="margin-top:6px;display:flex;align-items:flex-start;gap:6px;font-size:14px;line-height:1.4">${IK.terazi}Aynı partidesiniz: ceza verebilirsin; "sorun yok" kararı tarafsız moderatörde.</div>` : ""}
        <div class="mm-aksiyon">
          ${x.kilit ? (x.devir ? "" : `<button class="y" data-k="yok_say">Tarafsız moderatöre devret</button>`) : `<button class="y" data-k="yok_say">Sorun yok</button>`}<button data-k="gizle">Gizle</button>
          ${yv("sustur") ? `<button data-k="gizle_sustur1">Gizle + 1 gün</button><button data-k="gizle_sustur7">Gizle + 7 gün</button>` : ""}
          ${yv("hesap_kapat") ? `<button class="k" data-k="kapat">${M.ben.yonetici ? "Hesabı kapat" : "İncelemeye al + kalıcı engel talebi"}</button>` : `<button class="k" data-talep="1">Yaptırım talebi</button>`}
          <button data-dosya="1">Dosya</button>
        </div></div>`;
    }).join("");
    sayfa("Şikâyet masası", `<div class="mm-uyari sari">${IK.destek}<div>Mağaza kuralı gereği şikâyetlere <b>24 saat</b> içinde bakılmalı. 4 saati geçenler vurgulanır.</div></div>
      ${kartlar || bos("Açık şikâyet yok", "Oyuncular bir içeriği şikâyet ettiğinde burada görünür.")}`);
    document.querySelectorAll("[data-i]").forEach(k => {
      const x = l[+k.dataset.i];
      k.addEventListener("click", () => API.rpc("mod_ustlen", { p_tur: "sikayet", p_anahtar: anah(x) }).catch(() => {}), { once: true });
      k.querySelectorAll("[data-k]").forEach(b => b.onclick = async (ev) => {
        ev.stopPropagation();
        if (b.dataset.k === "kapat" && !await (M.ben.yonetici
              ? onayla("Hesabı kapat", `${esc(x.hedef)} adlı oyuncunun hesabı kapatılacak; görevleri düşer, mesajları gizlenir.`, "Kapat", true)
              : onayla("İncelemeye al", `İçerik gizlenir, ${esc(x.hedef)} 24 saat oyuna giremez ve kalıcı engel talebin ikinci bir görevlinin onayına gider.`, "Uygula", true))) return;
        try { const r = await API.rpc("admin_sikayet_karar", { p_tur: x.tur, p_kayit: x.kayit_id || null, p_hedef_kad: x.hedef, p_islem: b.dataset.k });
          const dv = b.dataset.k === "yok_say" && Array.isArray(r) && r.some(z => anah(z) === anah(x) && z.devir);
          toast(dv ? "Çıkar çatışması: karar tarafsız moderatöre devredildi." : "Karar uygulandı."); mmSikayet(); }
        catch (err) { hata(err); }
      });
      const t = k.querySelector("[data-talep]"); if (t) t.onclick = (ev) => { ev.stopPropagation(); talepAc(x.hedef, { kanit: x.icerik }); };
      const d = k.querySelector("[data-dosya]"); if (d) d.onclick = (ev) => { ev.stopPropagation(); mmDosyaAc(x.hedef); };
    });
  }

  /* =====================================================================
     4) SOHBET NÖBETİ
     ===================================================================== */
  const NB = { kanal: "", isaretli: false, resmi: false, tum: false, kanallar: [] };
  async function mmNobet() {
    yukleniyor("Sohbet nöbeti");
    let r;
    try { r = await API.rpc("mod_sohbet_nobeti", { p_kanal: NB.kanal || null, p_isaretli: NB.isaretli, p_once: null, p_limit: 80 }); }
    catch (err) { hataSayfa("Sohbet nöbeti", err); return; }
    if (!M) try { await merkezYukle(); } catch (_) {}
    NB.resmi = !!r.resmi_yetki; NB.tum = !!r.tum_yetki;
    // Yönetim adına yazılabilecek kanallar: açık kanallar + son 24 saatte hareket olan iller (ve yetki varsa gruplar)
    NB.kanallar = [["genel", "Genel"], ["yardim", "Yardım Masası"], ["meclis", "Meclis"]].concat((r.kanallar || []).filter(k => k.kanal.includes(":") && (!k.grup || NB.tum)).slice(0, 30).map(k => [k.kanal, k.ad]));
    const kanallar = [["", "Açık kanallar"]].concat(r.tum_yetki ? [["*", "Her şey"], ["grup", "Tüm gruplar"]] : [], [["genel", "Genel"], ["yardim", "Yardım Masası"], ["meclis", "Meclis"], ["il", "Tüm iller"]])
      .concat((r.kanallar || []).filter(k => k.kanal.startsWith("il:") || k.grup).slice(0, 14).map(k => [k.kanal, k.ad.replace(" sohbeti", "")]));
    sayfa("Sohbet nöbeti", `
      <div class="mm-filtre" id="mmNbK">${kanallar.map(k => `<button data-v="${esc(k[0])}" class="${NB.kanal === k[0] ? "on" : ""}">${esc(k[1])}</button>`).join("")}</div>
      <div class="mm-filtre"><button id="mmNbI" class="${NB.isaretli ? "on" : ""}">Yalnız işaretliler</button><button id="mmNbY">Yenile</button></div>
      ${NB.resmi ? `<button class="mm-btn yesil" id="mmNbR" style="margin:0 0 10px">${IK.kalkan}Yönetim adına sohbete yaz</button>` : ""}
      <p class="mm-alt" style="margin:-2px 2px 8px">${r.tum_yetki ? "Parti, parti yönetimi, ittifak, kabine, belediye ve oyuncuların özel grupları dahil bütün sohbetleri görebilirsin. Açtığın her kapalı kanal denetim günlüğüne yazılır. Birebir özel mesajlar yalnız şikâyet edilirse görünür." : "Herkese açık kanallar. Grup sohbetlerini görme yetkisi Sohbet ve Küfür Denetimi birimindedir."} Mesaja dokun: gizle, sustur, dosya.</p>
      <div id="mmNbL"></div>`);
    nobetListe(r.mesajlar || []);
    $("#mmNbK").querySelectorAll("[data-v]").forEach(b => b.onclick = () => { NB.kanal = b.dataset.v; mmNobet(); });
    $("#mmNbI").onclick = () => { NB.isaretli = !NB.isaretli; mmNobet(); };
    $("#mmNbY").onclick = mmNobet;
    const nbR = $("#mmNbR"); if (nbR) nbR.onclick = () => resmiYazAc(NB.kanal && NB.kanallar.some(k => k[0] === NB.kanal) ? NB.kanal : "genel");
    canliDurdur();
    D.canli = setInterval(async () => {
      if (document.hidden || !$("#mmNbL") || $("#modal")) return;
      try { const y = await API.rpc("mod_sohbet_nobeti", { p_kanal: NB.kanal || null, p_isaretli: NB.isaretli, p_once: null, p_limit: 80 }); nobetListe(y.mesajlar || []); } catch (_) {}
    }, 20000);
  }
  function nobetListe(L) {
    const kutu = $("#mmNbL"); if (!kutu) return;
    kutu.innerHTML = L.length ? `<div class="mm-kart" style="padding:4px 12px">${L.map((m, i) => `<div class="mm-mesaj ${m.gizli ? "gizli" : ""} ${(m.isaret || []).length && !m.gizli ? "isaretli" : ""}" data-i="${i}">
        <div class="mm-u"><b>${esc(m.kad)}</b>${m.gorevli ? `<span class="mm-etiket" style="--c:#34c98a">yönetim adına</span>` : m.moderator ? `<span class="mm-etiket" style="--c:#d9b45b">yönetim</span>` : ""}${m.susturulmus ? `<span class="mm-etiket" style="--c:#e0a43a">susturulmuş</span>` : ""}<span>· ${esc(m.kanal_ad)} · ${once(m.zaman)}</span>${m.sikayet ? `<span class="mm-etiket" style="--c:#e5574f">${m.sikayet} şikâyet</span>` : ""}${m.grup ? `<span class="mm-etiket" style="--c:#4fc1d6">grup</span>` : ""}${m.gizli ? `<span class="mm-etiket" style="--c:#98a4c4">gizli</span>` : ""}</div>
        <div class="mm-baloncuk">${esc(m.metin)}</div>
        ${(m.isaret || []).length ? `<div class="mm-cipler">${m.isaret.map(k => `<span class="mm-etiket" style="--c:${(ISARET[k] || ["", "#e0a43a"])[1]}">${(ISARET[k] || [k])[0]}</span>`).join("")}</div>` : ""}
      </div>`).join("")}</div>` : bos(NB.isaretli ? "İşaretli mesaj yok" : "Mesaj yok", NB.isaretli ? "Bağlantı, telefon, küfür şüphesi, sert ifade, büyük harf ya da spam içeren mesajlar burada toplanır." : "");
    kutu.querySelectorAll("[data-i]").forEach(x => x.onclick = () => mesajIslem(L[+x.dataset.i]));
  }
  function mesajIslem(m) {
    const sus = yv("sustur");
    const md = sheet(`<h3 style="font-size:18px;font-weight:800;margin:0">${esc(m.kad)} · ${esc(m.kanal_ad)}</h3><div class="mm-alt">${tsaat(m.zaman)}</div>
      <div class="mm-baloncuk" style="margin-top:10px">${esc(m.metin)}</div>
      ${m.gorevli ? `<div class="mm-uyari yesil">${IK.kalkan}<div>Oyun yönetimi adına yazılmış mesaj. Yazanın adı gösterilmez; ${yonSilebilir(m) ? "kendi mesajını silebilirsin." : "yanlış ya da uygunsuzsa yöneticiye ilet."}</div></div>
        ${yonSilebilir(m) ? (m.gizli ? (M && M.ben && M.ben.yonetici ? `<button class="mm-btn yesil" style="margin-top:8px" id="mmYonGeri">Silinen mesajı geri aç</button>` : "") : `<button class="mm-btn kirmizi" style="margin-top:8px" id="mmYonSil">Yönetim mesajını sil</button>`) : ""}` : m.moderator && !(M && M.ben && M.ben.yonetici && M.ben.kad !== m.kad) ? `<div class="mm-uyari sari">${IK.kilit}<div>Bu mesaj oyun yönetiminden birine ait; işlem yapılamaz.</div></div>` : `
      <div class="mm-iki">${m.gizli ? `<button class="mm-btn yesil" data-k="yok_say">Geri aç</button>` : `<button class="mm-btn" data-k="gizle">Mesajı gizle</button>`}
        ${sus ? `<button class="mm-btn kirmizi" data-k="gizle_sustur1">Gizle + 1 gün sustur</button>` : `<button class="mm-btn kirmizi" data-talep="1">Yaptırım talebi</button>`}</div>
      ${sus ? `<button class="mm-btn" style="margin-top:8px" data-uyar="1">Resmî uyarı ver (24 saatte 3. uyarıda otomatik susturma)</button><div class="mm-alan">Hızlı susturma (mesaj kalır · tekrar edende süre kendiliğinden artar)</div><div class="mm-aksiyon">${[[0.25, "15 dk"], [0.5, "30 dk"], [1, "1 saat"], [3, "3 saat"], [24, "24 saat"], [72, "3 gün"]].map(s => `<button data-s="${s[0]}">${s[1]}</button>`).join("")}</div>` : ""}`}
      ${NB.resmi && (!m.grup || NB.tum) ? `<button class="mm-btn yesil" style="margin-top:8px" id="mmMsgR">${IK.kalkan}Bu kanala yönetim adına yaz</button>` : ""}
      ${m.gorevli || m.moderator ? "" : `<button class="mm-btn" style="margin-top:8px" id="mmMsgY">${IK.sohbet}Oyuncuya özel mesaj yaz / uyar</button>`}
      <div class="mm-iki">${m.gorevli ? "" : `<button class="mm-btn cizgi" data-dosya="1">${IK.ara}Oyuncu dosyası</button>`}<button class="mm-btn cizgi" id="mmKap">Kapat</button></div>`);
    $("#mmKap", md).onclick = modalKapat;
    /* 26.11.2026: yönetim adına yazılan mesajı silme / kurucu için geri açma (sunucu: mod_sohbet_sil) */
    [["#mmYonSil", false], ["#mmYonGeri", true]].forEach(([sec, geri]) => { const b = $(sec, md); if (b) b.onclick = async () => {
      b.disabled = true;
      try { await API.rpc("mod_sohbet_sil", { p_mesaj: m.id, p_geri: geri }); modalKapat(); toast(geri ? "Mesaj yeniden görünür." : "Mesaj silindi."); mmNobetYenile(); }
      catch (err) { b.disabled = false; hata(err); }
    }; });
    const my = $("#mmMsgY", md); if (my) my.onclick = () => { modalKapat(); oyuncuyaYazAc(m.kad, true); };
    const mr = $("#mmMsgR", md); if (mr) mr.onclick = () => { modalKapat(); resmiYazAc(m.kanal, m.kanal_ad); };
    const dsy = $("[data-dosya]", md); if (dsy) dsy.onclick = () => { modalKapat(); mmDosyaAc(m.kad); };
    md.querySelectorAll("[data-k]").forEach(b => b.onclick = async () => {
      try { await API.rpc("admin_sikayet_karar", { p_tur: "mesaj", p_kayit: m.id, p_hedef_kad: m.kad, p_islem: b.dataset.k }); modalKapat(); toast(b.dataset.k === "yok_say" ? "Mesaj yeniden görünür." : "Mesaj gizlendi."); mmNobetYenile(); }
      catch (err) { hata(err); }
    });
    md.querySelectorAll("[data-s]").forEach(b => b.onclick = async () => {
      try { const r = await API.rpc("yk_sustur", { p_kad: m.kad, p_saat: +b.dataset.s, p_neden: "Sohbet kurallarına aykırı mesaj: " + String(m.metin).slice(0, 120) }); modalKapat(); toast(`${m.kad} ${r && r.susturma_bitis ? tsaat(r.susturma_bitis) + " tarihine kadar" : b.textContent} susturuldu.`); mmNobetYenile(); }
      catch (err) { hata(err); }
    });
    const uy = $("[data-uyar]", md); if (uy) uy.onclick = () => { modalKapat(); kucukCezaAc("uyari", m.kad, `${m.kanal_ad} · ${tsaat(m.zaman)}: ${m.metin}`, () => mmNobetYenile()); };
    const t = $("[data-talep]", md); if (t) t.onclick = () => { modalKapat(); talepAc(m.kad, { kanit: `${m.kanal_ad} · ${tsaat(m.zaman)}: ${m.metin}`, tur: "sustur" }); };
  }
  /* Yönetim adına yazılmış mesajı bu kişi silebilir mi: kurucu hepsini, moderatör kendi imzasını taşıyanı (sunucu ayrıca denetler) */
  function yonSilebilir(m) {
    if (!m || !m.gorevli || !M || !M.ben) return false;
    if (M.ben.yonetici) return true;
    return !!M.ben.kod && String(m.kad || "").trim() === ("Oyun Yöneticisi " + M.ben.kod).trim();
  }
  /* 20.11.2026 · Sohbete yönetim adına yaz: mesaj kanalda "Oyun Yöneticisi G-03" imzasıyla görünür, moderatörün adı görünmez.
     Yetki sunucuda doğrulanır (mod_sohbet_yaz); kanalın üyesi olmak gerekmez. */
  const RESMI_SABLON = ["Lütfen üslubunuza dikkat edin. Hakaret ve küfür yasaktır; devamında susturma uygulanır.",
    "Bu tartışma burada kapanmıştır. Sürdürenler hakkında işlem yapılacaktır.",
    "Aynı mesajı tekrar tekrar göndermek (spam) yasaktır.",
    "Kişisel bilgi, telefon numarası ve dış bağlantı paylaşmayın.",
    "Soru, sorun ve şikâyetleriniz için Ben › Yönetime Yaz'dan talep açabilirsiniz; bir görevli sizinle özel olarak ilgilenir."];
  function resmiYazAc(kanal, kanalAd) {
    let liste = NB.kanallar.slice();
    if (kanal && !liste.some(k => k[0] === kanal)) liste.unshift([kanal, kanalAd || kanal]);
    if (!liste.length) liste = [["genel", "Genel"]];
    const imza = M && M.ben ? (M.ben.yonetici ? "Oyun Kurucusu" : "Oyun Yöneticisi " + (M.ben.kod || "")) : "Oyun Yönetimi";
    const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">Yönetim adına sohbete yaz</h3>
      <div class="mm-uyari yesil" style="margin-top:8px">${IK.kalkan}<div>Mesajın kanalda <b>${esc(imza.trim())}</b> imzasıyla görünür; adın, partin ve unvanın görünmez. Her mesaj denetim günlüğüne yazılır.</div></div>
      <label class="mm-alan" for="mmRK">Kanal</label>
      <select class="mm-girdi" id="mmRK">${liste.map(k => `<option value="${esc(k[0])}" ${k[0] === kanal ? "selected" : ""}>${esc(k[1])}</option>`).join("")}</select>
      <label class="mm-alan" for="mmRM">Mesaj</label>
      <textarea class="mm-girdi" id="mmRM" maxlength="1000" placeholder="Uyarı ya da bilgilendirme yaz"></textarea>
      <div class="mm-alt" id="mmRS" style="text-align:right">0 / 1000</div>
      <div class="mm-alan">Hazır uyarılar</div>
      <div class="mm-resmi-sablon" id="mmRH">${RESMI_SABLON.map((t, i) => `<button type="button" data-i="${i}">${esc(t)}</button>`).join("")}</div>
      <button class="mm-btn yesil" style="margin-top:12px" id="mmROk">${IK.kalkan}Yönetim adına gönder</button>
      <button class="mm-btn cizgi" style="margin-top:8px" id="mmRVaz">Vazgeç</button>`);
    const ta = $("#mmRM", md), say = $("#mmRS", md), ok = $("#mmROk", md);
    const sayYaz = () => { say.textContent = ta.value.length + " / 1000"; };
    ta.addEventListener("input", sayYaz);
    $("#mmRH", md).querySelectorAll("[data-i]").forEach(b => b.onclick = () => { ta.value = RESMI_SABLON[+b.dataset.i]; sayYaz(); ta.focus(); });
    $("#mmRVaz", md).onclick = modalKapat;
    ok.onclick = async () => {
      const metin = ta.value.trim();
      if (!metin) { toast("Önce mesajı yaz.", true); return; }
      ok.disabled = true;
      try {
        const y = await API.rpc("mod_sohbet_yaz", { p_kanal: $("#mmRK", md).value, p_metin: metin });
        modalKapat(); toast(`Mesaj ${(y && y.kanal_ad) || "kanalda"} içinde yönetim adına yayımlandı.`); mmNobetYenile();
      } catch (err) { ok.disabled = false; hata(err); }
    };
  }
  async function mmNobetYenile() { try { const y = await API.rpc("mod_sohbet_nobeti", { p_kanal: NB.kanal || null, p_isaretli: NB.isaretli, p_once: null, p_limit: 80 }); nobetListe(y.mesajlar || []); } catch (_) {} }

  /* =====================================================================
     5) DESTEK MASASI
     ===================================================================== */
  const SABLON = [
    ["Teşekkürler, inceliyoruz", "Bildirimin için teşekkürler. Konuyu inceliyoruz; sonuçlanınca sana haber vereceğiz."],
    ["Sorun giderildi", "Bildirdiğin sorun giderildi. Uygulamayı kapatıp açarak tekrar dener misin?"],
    ["Güncelleme gerekli", "Bu sorun yeni sürümde düzeltildi. Mağazadan uygulamayı güncelleyip tekrar dener misin?"],
    ["Oyun kuralı", "Bu durum bir oyun kuralıdır, hata değildir. Ayrıntılar için oyundaki rehber ekranına bakabilirsin."],
    ["Ek bilgi lazım", "Sorunu çözebilmemiz için hangi ekranda, ne zaman ve ne yaparken oluştuğunu biraz daha ayrıntılı yazar mısın?"]
  ];
  async function mmDestek(tum) {
    yukleniyor("Destek masası");
    let l;
    try { l = await API.rpc("mod_destek", { p_durum: tum ? "tum" : "acik" }); } catch (err) { hataSayfa("Destek masası", err); return; }
    const KAT = { hata: ["Hata", "#e5574f"], hesap: ["Hesap", "#5b8def"], oyuncu: ["Oyuncu", "#c86cd8"], oneri: ["Öneri", "#3fb67a"], diger: ["Diğer", "#98a4c4"] };
    sayfa("Destek masası", `<div class="mm-filtre"><button class="${tum ? "" : "on"}" data-t="0">Açık</button><button class="${tum ? "on" : ""}" data-t="1">Son 30 gün</button></div>
      ${l.map((d, i) => `<div class="mm-kart" data-i="${i}">
        <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px">#${d.id} · ${esc(d.kad)}</b><span class="mm-etiket" style="--c:${(KAT[d.kategori] || KAT.diger)[1]}">${(KAT[d.kategori] || KAT.diger)[0]}</span></div>
        <div class="mm-alt">${once(d.zaman)}${d.platform ? " · " + esc(d.platform) : ""}${d.surum ? " · sürüm " + esc(d.surum) : ""}${d.onceki ? ` · daha önce ${d.onceki} talep` : ""}</div>
        <div class="mm-baloncuk">${esc(d.metin)}</div>
        ${d.yanit ? `<div class="mm-alt" style="margin-top:4px"><b>Yanıt (${esc(d.yanitlayan || "")}):</b> ${esc(d.yanit)}</div>` : ""}
        ${d.durum !== "kapali" ? `<div class="mm-filtre" style="margin-top:6px">${SABLON.map((s, j) => `<button data-s="${j}">${s[0]}</button>`).join("")}</div>
          <textarea class="mm-girdi" maxlength="1000" placeholder="Yanıtın (oyuncuya bildirim olarak gider)"></textarea>
          <div class="mm-iki"><button class="mm-btn mor" data-y="0">Yanıtla</button><button class="mm-btn" data-y="1">Yanıtla ve kapat</button></div>` : `<span class="mm-etiket" style="--c:#98a4c4">kapalı</span>`}
      </div>`).join("") || bos("Açık destek talebi yok", "Oyuncular Profilim › Destek'ten yazdığında burada görünür.")}`);
    document.querySelectorAll("[data-t]").forEach(b => b.onclick = () => mmDestek(b.dataset.t === "1"));
    document.querySelectorAll(".mm-kart[data-i]").forEach(k => {
      const d = l[+k.dataset.i], ta = k.querySelector("textarea");
      k.querySelectorAll("[data-s]").forEach(b => b.onclick = () => { ta.value = SABLON[+b.dataset.s][1]; ta.focus(); });
      k.querySelectorAll("[data-y]").forEach(b => b.onclick = async () => {
        const kapat = b.dataset.y === "1", m = ta.value.trim();
        if (!m && !kapat) { toast("Yanıt yaz.", true); return; }
        try { await API.rpc("mod_destek_yanitla", { p_id: d.id, p_metin: m || null, p_kapat: kapat }); toast(kapat ? "Yanıtlandı ve kapatıldı." : "Yanıt gönderildi."); mmDestek(tum); }
        catch (err) { hata(err); }
      });
    });
  }

  /* =====================================================================
     6) YAPTIRIM TALEPLERİ (dört göz)
     ===================================================================== */
  const TT = { engel: ["Hesap engeli", "#e5574f"], sustur: ["Susturma", "#e0a43a"], eskalasyon: ["Yöneticiye iletildi", "#d9b45b"] };
  const sureYaz = (x) => x.tur === "sustur" ? `${x.sure} saat` : x.tur === "engel" ? (x.sure ? `${x.sure} gün` : "kalıcı") : "";
  const DURUM = { acik: ["bekliyor", "#e0a43a"], onaylandi: ["onaylandı", "#34c98a"], reddedildi: ["reddedildi", "#e5574f"], geri_cekildi: ["geri çekildi", "#98a4c4"] };
  function talepKart(x, mod) {
    const hd = x.hedef_durum || {};
    return `<div class="mm-kart" style="--c:${TT[x.tur][1]}" data-id="${x.id}">
      <div style="display:flex;gap:8px;align-items:center;justify-content:space-between;flex-wrap:wrap"><b style="font-size:16px">${esc(x.hedef)}</b>
        <span class="mm-etiket" style="--c:${TT[x.tur][1]}">${TT[x.tur][0]}${sureYaz(x) ? " · " + sureYaz(x) : ""}</span></div>
      <div class="mm-alt">#${x.id} · ${esc(x.talep_eden)} açtı · ${once(x.zaman)}${hd.sikayet ? ` · ${hd.sikayet} şikâyet` : ""}${hd.onceki_yaptirim ? ` · önceki yaptırım ${hd.onceki_yaptirim}` : ""}${hd.yasakli ? " · şu an engelli" : ""}</div>
      <div class="mm-baloncuk"><b>Gerekçe:</b> ${esc(x.gerekce)}${x.kanit ? `\n\n<b>Kanıt:</b> ${esc(x.kanit)}` : ""}</div>
      ${x.devir ? `<div class="mm-kilit" style="margin-top:6px;display:flex;align-items:flex-start;gap:6px;font-size:14px;line-height:1.4">${IK.terazi}Ret kararı tarafsız moderatör bekliyor.</div>` : mod === "karar" && x.kilit ? `<div class="mm-kilit" style="margin-top:6px;display:flex;align-items:flex-start;gap:6px;font-size:14px;line-height:1.4">${IK.terazi}Aynı partidesiniz: onaylayabilirsin; ret kararı tarafsız moderatörde.</div>` : ""}
      ${mod === "karar" ? `<div class="mm-iki"><button class="mm-btn cizgi" data-red="1">${x.kilit ? "Reddi devret" : "Reddet"}</button><button class="mm-btn ${x.tur === "eskalasyon" ? "mor" : "kirmizi"}" data-onay="1">${x.tur === "eskalasyon" ? "İncelendi" : "Onayla ve uygula"}</button></div>`
        : `<div style="display:flex;gap:8px;align-items:center;justify-content:space-between;margin-top:6px"><span class="mm-etiket" style="--c:${DURUM[x.durum][1]}">${DURUM[x.durum][0]}</span>${x.karar_veren ? `<span class="mm-alt">${esc(x.karar_veren)}${x.karar_not ? " · " + esc(x.karar_not) : ""}</span>` : ""}${mod === "benim" && x.durum === "acik" ? `<button class="mm-btn cizgi" style="width:auto;min-height:38px" data-geri="1">Geri çek</button>` : ""}</div>`}
      <div class="mm-aksiyon"><button data-dosya="${esc(x.hedef)}">Dosyayı aç</button></div></div>`;
  }
  async function mmTalepler() {
    yukleniyor("Yaptırım talepleri");
    let r; try { r = await API.rpc("mod_talepler"); } catch (err) { hataSayfa("Yaptırım talepleri", err); return; }
    sayfa("Yaptırım talepleri", `<div class="mm-uyari yesil">${IK.terazi}<div><b>Dört göz ilkesi:</b> Engelleme yetkisi olmayan moderatör talep açar; Yaptırım Kurulu ya da yönetici onaylar. Kimse kendi talebine karar veremez.</div></div>
      <div class="mm-baslik"><h3>Kararını bekleyenler (${r.karar.length})</h3></div>${r.karar.map(x => talepKart(x, "karar")).join("") || `<div class="mm-kart mm-alt">Kararını bekleyen talep yok.</div>`}
      ${r.benim.length ? `<div class="mm-baslik"><h3>Taleplerim</h3></div>${r.benim.map(x => talepKart(x, "benim")).join("")}` : ""}
      ${r.diger_acik.length ? `<div class="mm-baslik"><h3>Ekipte açık diğer talepler</h3></div>${r.diger_acik.map(x => talepKart(x, "goster")).join("")}` : ""}
      ${r.son_kararlar.length ? `<details class="mm-kart"><summary style="font-weight:800;cursor:pointer">Son 7 günün kararları (${r.son_kararlar.length})</summary>${r.son_kararlar.map(x => talepKart(x, "goster")).join("")}</details>` : ""}`);
    document.querySelectorAll("[data-dosya]").forEach(b => b.onclick = () => mmDosyaAc(b.dataset.dosya));
    document.querySelectorAll(".mm-kart[data-id]").forEach(k => {
      const id = +k.dataset.id;
      const on = k.querySelector("[data-onay]"), red = k.querySelector("[data-red]"), geri = k.querySelector("[data-geri]");
      if (on) on.onclick = async () => { if (!await onayla("Talebi onayla", "Yaptırım hemen uygulanır ve oyuncuya bildirilir.", "Onayla", true)) return;
        try { await API.rpc("mod_talep_karar", { p_id: id, p_onay: true, p_not: null }); toast("Onaylandı ve uygulandı."); mmTalepler(); } catch (err) { hata(err); } };
      if (red) red.onclick = async () => { const n = prompt("Reddetme gerekçesi (talebi açan görür):", ""); if (n === null) return;
        try { const s = await API.rpc("mod_talep_karar", { p_id: id, p_onay: false, p_not: n });
          const dv = !!(s && Array.isArray(s.karar) && s.karar.some(z => z.id === id && z.devir));
          toast(dv ? "Çıkar çatışması: ret kararı tarafsız moderatöre devredildi." : "Talep reddedildi."); mmTalepler(); } catch (err) { hata(err); } };
      if (geri) geri.onclick = async () => { try { await API.rpc("mod_talep_geri_cek", { p_id: id }); toast("Talep geri çekildi."); mmTalepler(); } catch (err) { hata(err); } };
    });
  }
  function talepAc(kad, o) {
    o = o || {};
    let tur = o.tur || "sustur", sure = tur === "sustur" ? 24 : 3;
    const SURE = { sustur: [[1, "1 saat"], [6, "6 saat"], [24, "24 saat"], [72, "3 gün"], [168, "7 gün"]], engel: [[1, "1 gün"], [3, "3 gün"], [7, "7 gün"], [30, "30 gün"], [0, "Kalıcı"]] };
    const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">Talep aç · ${esc(kad)}</h3>
      <p class="mm-alt" style="margin:4px 0 8px">Talebin, karar yetkisi olan moderatörlere ve yöneticiye bildirim olarak gider.</p>
      <div class="mm-secim" id="mmTT">${[["sustur", "Susturma", "#e0a43a"], ["engel", "Hesap engeli", "#e5574f"], ["eskalasyon", "Yöneticiye ilet", "#d9b45b"]].map(t => `<button data-v="${t[0]}" style="--c:${t[2]}" class="${t[0] === tur ? "on" : ""}"><i></i>${t[1]}</button>`).join("")}</div>
      <div id="mmTS"></div>
      <label class="mm-alan" for="mmTG">Gerekçe</label><textarea class="mm-girdi" id="mmTG" maxlength="500" placeholder="Ne oldu? Hangi kural ihlal edildi? (en az 10 karakter)"></textarea>
      <label class="mm-alan" for="mmTK">Kanıt (isteğe bağlı)</label><textarea class="mm-girdi" id="mmTK" maxlength="600" placeholder="Mesaj metni, kanal, saat…">${esc(o.kanit || "")}</textarea>
      <button class="mm-btn mor" style="margin-top:10px" id="mmTOk">Talebi gönder</button><button class="mm-btn cizgi" style="margin-top:8px" id="mmTVaz">Vazgeç</button>`);
    const sureCiz = () => {
      const k = $("#mmTS", md);
      if (tur === "eskalasyon") { k.innerHTML = `<p class="mm-alt" style="margin-top:8px">Yönetici dosyayı inceler; otomatik yaptırım uygulanmaz.</p>`; return; }
      k.innerHTML = `<div class="mm-alan">Önerilen süre</div><div class="mm-filtre">${SURE[tur].map(s => `<button data-v="${s[0]}" class="${+s[0] === sure ? "on" : ""}">${s[1]}</button>`).join("")}</div>`;
      cipSec(k, v => sure = +v);
    };
    cipSec($("#mmTT", md), v => { tur = v; sure = v === "sustur" ? 24 : 3; sureCiz(); });
    sureCiz();
    $("#mmTVaz", md).onclick = modalKapat;
    $("#mmTOk", md).onclick = async () => {
      try { const r = await API.rpc("mod_talep_ac", { p_tur: tur, p_kad: kad, p_sure: tur === "eskalasyon" ? null : sure, p_gerekce: $("#mmTG", md).value, p_kanit: $("#mmTK", md).value });
        modalKapat(); toast(`Talep #${r.id} açıldı; ${r.bildirilen} yetkiliye bildirildi.`); }
      catch (err) { hata(err); }
    };
  }

  /* =====================================================================
     7) OYUNCU DOSYASI
     ===================================================================== */
  const DS = { kad: null, sekme: "ozet" };
  function mmDosyaAc(kad) { DS.kad = kad; DS.sekme = "ozet"; ekranAc(mmDosya); }
  async function mmDosya() {
    yukleniyor("Oyuncu dosyası");
    let d; try { d = await API.rpc("mod_dosya", { p_kad: DS.kad }); } catch (err) { hataSayfa("Oyuncu dosyası", err); return; }
    if (!M) try { await merkezYukle(); } catch (_) {}
    DS.kad = d.kad;
    const y = d.yetkim || {}, so = d.sikayet_ozet || {};
    const durum = [
      d.yasakli ? [`Engelli${d.engel_bitis ? " · " + tsaat(d.engel_bitis) + "'e kadar" : " · kalıcı"}`, "#e5574f"] : null,
      d.susturma_bitis ? [`Susturulmuş · ${tsaat(d.susturma_bitis)}'e kadar`, "#e0a43a"] : null,
      d.adaylik_yasagi_bitis ? [`Aday olamaz · ${tsaat(d.adaylik_yasagi_bitis)}`, "#c86cd8"] : null,
      d.korunan ? [d.yonetici ? "Oyun kurucusu" : "Moderatör" + (d.birim ? " · " + d.birim : ""), "#d9b45b"] : null,
      d.onayli ? ["Gerçek kişi onaylı", "#34c98a"] : null
    ].filter(Boolean);
    const sekmeler = [["ozet", "Özet"], ["gecmis", `Geçmiş (${(d.gecmis || []).length})`], ["mesaj", "Mesajlar"], ["not", `Notlar (${(d.notlar || []).length})`]]
      .concat(d.bagli ? [["bagli", `Bağlantılar (${d.bagli.length})`]] : [], d.masak ? [["masak", "MASAK"]] : []);
    let govde = "";
    if (DS.sekme === "ozet") govde = `<div class="mm-kart">
        <div class="mm-kv"><span>İl</span><span>${esc(d.il || "—")}</span></div>
        <div class="mm-kv"><span>Parti</span><span>${d.parti ? esc(d.parti.ad) + (d.parti.gb ? " · Genel Başkan" : "") : "Bağımsız"}</span></div>
        <div class="mm-kv"><span>Unvan</span><span>${esc(d.unvan || "—")}</span></div>
        <div class="mm-kv"><span>Görevler</span><span>${(d.makamlar || []).map(m => esc(m.ad)).join(", ") || "—"}</span></div>
        <div class="mm-kv"><span>Para · Kıdem</span><span>${tl(d.para)} · ${sayi(d.kidem)}</span></div>
        <div class="mm-kv"><span>Hesap açılışı</span><span>${tsaat(d.olusturma)}</span></div>
        <div class="mm-kv"><span>Son görülme</span><span>${d.cevrimici ? "çevrimiçi" : once(d.son_gorulme)}</span></div>
        ${d.eposta ? `<div class="mm-kv"><span>E-posta</span><span>${esc(d.eposta)}</span></div>` : ""}
        <div class="mm-kv"><span>Hakkındaki şikâyet</span><span>${so.toplam || 0} (açık ${so.acik || 0}, ${so.kisi || 0} kişi)</span></div>
        <div class="mm-kv"><span>Yaptığı şikâyet</span><span>${d.sikayet_ettigi || 0}</span></div>
      </div>
      ${(d.talepler || []).length ? `<div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Yaptırım talepleri</h3></div>${d.talepler.map(t => `<div class="mm-satir" style="cursor:default"><div class="orta"><b style="font-weight:650">${TT[t.tur][0]}${sureYaz(t) ? " · " + sureYaz(t) : ""}</b><div class="kucuk">${esc(t.talep_eden)} · ${once(t.zaman)} · ${esc(t.gerekce)}</div></div><span class="mm-etiket" style="--c:${DURUM[t.durum][1]}">${DURUM[t.durum][0]}</span></div>`).join("")}</div>` : ""}`;
    else if (DS.sekme === "gecmis") govde = `<div class="mm-kart" style="padding:4px 12px">${(d.gecmis || []).map(k => `<div class="mm-satir" style="cursor:default"><div class="orta"><b style="font-weight:650">${esc(k.kad)} ${esc(ISLEM[k.islem] || k.islem)}</b><div class="kucuk">${once(k.zaman)}${k.ayrinti ? " · " + esc(k.ayrinti) : ""}</div></div></div>`).join("") || `<div class="mm-alt" style="padding:12px 0">Bu oyuncu hakkında moderasyon kaydı yok.</div>`}</div>`;
    else if (DS.sekme === "mesaj") govde = `<div class="mm-kart" style="padding:4px 12px">${(d.mesajlar || []).map(m => `<div class="mm-mesaj ${m.gizli ? "gizli" : ""}" style="cursor:default"><div class="mm-u"><span>${esc(m.kanal)} · ${once(m.zaman)}</span>${m.grup ? `<span class="mm-etiket" style="--c:#4fc1d6">grup</span>` : ""}${m.gizli ? `<span class="mm-etiket" style="--c:#98a4c4">gizli</span>` : ""}</div><div class="mm-baloncuk">${esc(m.metin)}</div></div>`).join("") || `<div class="mm-alt" style="padding:12px 0">Son mesajı yok.</div>`}</div>`;
    else if (DS.sekme === "not") govde = `<div class="mm-kart"><p class="mm-alt" style="margin-top:0">Notları yalnız oyun yönetimi görür. Uyarıları, şüpheleri ve verilen sözleri buraya yaz; bir sonraki moderatör bağlamı bilsin.</p>
        <textarea class="mm-girdi" id="mmNot" maxlength="500" placeholder="Örn. Genel sohbette hakaret nedeniyle sözlü uyarıldı."></textarea><button class="mm-btn mor" style="margin-top:8px" id="mmNotK">Not ekle</button></div>
        <div class="mm-kart" style="padding:4px 12px" id="mmNotL">${notListe(d.notlar)}</div>`;
    else if (DS.sekme === "bagli") govde = `<div class="mm-kart" style="padding:4px 12px">${d.bagli.map(b => `<div class="mm-satir" data-kad="${esc(b.kad)}"><div class="orta"><b>${esc(b.kad)}</b><div class="kucuk">açılış ${tsaat(b.olusturma)}</div></div>${b.yasakli ? `<span class="mm-etiket" style="--c:#e5574f">kapalı</span>` : ""}${IK.ok}</div>`).join("") || `<div class="mm-alt" style="padding:12px 0">Aynı cihazdan açılmış başka hesap yok.</div>`}</div>`;
    else if (DS.sekme === "masak") govde = `<div class="mm-kart" style="padding:4px 12px">${d.masak.map(x => `<div class="mm-satir" style="cursor:default"><div class="orta"><b style="font-weight:650">${esc(x.tur)} · ${tl(x.tutar)}</b><div class="kucuk">${once(x.zaman)} · ${esc(x.aciklama || "")}</div></div><span class="mm-etiket" style="--c:${x.durum === "yeni" ? "#e0a43a" : x.durum === "temiz" ? "#34c98a" : "#e5574f"}">${esc(x.durum)}</span></div>`).join("") || `<div class="mm-alt" style="padding:12px 0">MASAK kaydı yok.</div>`}</div>
        ${typeof masakEkrani === "function" ? `<button class="mm-btn" id="mmMasakAc">MASAK kuyruğunu aç</button>` : ""}`;
    const benY = !!((d.yetkim && d.yetkim.yonetici) || (M && M.ben && M.ben.yonetici)), kendim = !!(M && M.ben && M.ben.kad === d.kad);
    const leheKilit = !benY && !!d.lehe_kilit;
    const aksiyon = (d.korunan && (!benY || kendim)) ? `<div class="mm-uyari sari">${IK.kilit}<div>Bu hesap oyun yönetiminden; moderatörler işlem yapamaz. Gerekirse "Yöneticiye ilet" kullan.</div></div>` : d.cikar_catismasi ? `
      <div class="mm-uyari sari">${IK.terazi}<div><b>${esc(d.cikar_catismasi)}</b> Bu oyuncuya doğrudan yaptırım uygulayamazsın; talep aç, tarafsız başka bir moderatör karar versin.</div></div>
      <div class="mm-kart"><div class="mm-aksiyon"><button class="k" data-a="talep">Yaptırım talebi</button><button data-a="ilet">Yöneticiye ilet</button><button data-a="not">Not ekle</button></div></div>` : `
      ${leheKilit ? `<div class="mm-uyari sari">${IK.terazi}<div><b>${esc(d.lehe_kilit)}</b> Ceza yönünde işlem yapabilirsin (susturma, yaptırım talebi). Bu oyuncu lehine karar (susturmayı ya da engeli kaldırma) tarafsız moderatörde; gerekirse "Yöneticiye ilet" kullan.</div></div>` : ""}
      <div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>İşlemler</h3></div>
        <div class="mm-aksiyon">
          <button data-a="yaz">Mesaj yaz / uyar</button>
          ${y.sustur ? `<button data-a="uyari">Resmî uyarı</button><button data-a="para">Para cezası</button>` : ""}
          ${y.sustur ? (d.susturma_bitis ? (leheKilit ? "" : `<button class="y" data-a="susKaldir">Susturmayı kaldır</button>`) : `<button data-a="sustur">Sustur</button>`) : ""}
          ${y.hesap_kapat ? (d.yasakli ? (leheKilit ? "" : `<button class="y" data-a="engelKaldir">Engeli kaldır</button>`) : `<button class="k" data-a="engel">Uzaklaştır / Engelle</button>`) : ""}
          <button class="k" data-a="talep">Yaptırım talebi</button>
          ${y.mali_dondur || y.yonetici ? `<button class="k" data-a="mali">Para çıkışını dondur</button>` : ""}
          ${y.secim_kisit || y.yonetici ? `<button class="k" data-a="secim">Seçim kısıtı</button>` : ""}
          ${yv("sikayet") ? `<button data-a="toplu">Son içeriklerini gizle</button>` : ""}
          <button data-a="ilet">Yöneticiye ilet</button>
          <button data-a="not">Not ekle</button>
          ${y.yonetici && typeof kmOyuncuAc === "function" ? `<button data-a="km">Kontrol Merkezi'nde aç</button>` : ""}
        </div></div>`;
    const kisitKart = (d.kisitlar || []).length ? `<div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Yürürlükteki yaptırımlar</h3></div>${d.kisitlar.map(k => kisitSatir(k, y.yonetici)).join("")}</div>` : "";
    const sn = d.sinirlar || {};
    const sinirNot = !y.yonetici && (sn.engel || {}).var ? `<p class="mm-alt" style="margin:6px 2px 0">Tek imza: engel ${esc(sn.engel.tek)}${(sn.sustur || {}).var ? ", susturma " + esc(sn.sustur.tek) : ""}${(sn.mali || {}).var ? ", dondurma " + esc(sn.mali.tek) : ""}${(sn.secim || {}).var ? ", seçim kısıtı " + esc(sn.secim.tek) : ""}. Daha uzunu ve kalıcı engel ikinci imzayla.${d.ust_makam ? " <b>Üst makam:</b> engel her zaman iki imza ister." : ""}${d.sandik_acik ? " <b>Sandık açık:</b> engel iki imza ister." : ""}</p>` : "";
    sayfa("Oyuncu dosyası", `
      <section class="mm-hero" style="--mm-r:${d.parti ? esc(d.parti.renk) : "#7b61ff"}">
        <div class="mm-dosya-ust"><div class="portre-kutu">${typeof portre === "function" ? portre(d.kad, d.parti && d.parti.renk) : ""}</div>
          <div style="min-width:0"><h2>${esc(d.kad)}</h2><div class="mm-alt" style="font-size:14px">${esc(d.ad_soyad || "Ad soyad yok")}${d.il ? " · " + esc(d.il) : ""}</div>
          <div class="mm-alt"><span class="mm-nokta ${d.cevrimici ? "on" : ""}" style="display:inline-block;vertical-align:middle;margin-right:4px"></span>${d.cevrimici ? "çevrimiçi" : "son görülme " + once(d.son_gorulme)}</div></div></div>
        ${durum.length ? `<div class="mm-cipler" style="margin-top:10px">${durum.map(c => `<span class="mm-etiket" style="--c:${c[1]}">${esc(c[0])}</span>`).join("")}</div>` : ""}
        <div class="mm-istat"><div><b>${so.toplam || 0}</b><span>şikâyet</span></div><div><b>${(d.gecmis || []).length}</b><span>moderasyon kaydı</span></div><div><b>${(d.notlar || []).length}</b><span>not</span></div></div>
      </section>
      ${aksiyon}${sinirNot}
      ${kisitKart}
      <div class="mm-sekme">${sekmeler.map(s => `<button class="${DS.sekme === s[0] ? "on" : ""}" data-s="${s[0]}">${s[1]}</button>`).join("")}</div>
      ${govde}`);
    document.querySelectorAll(".mm-sekme [data-s]").forEach(b => b.onclick = () => { DS.sekme = b.dataset.s; mmDosya(); });
    document.querySelectorAll("[data-kad]").forEach(b => b.onclick = () => mmDosyaAc(b.dataset.kad));
    const mk = $("#mmMasakAc"); if (mk) mk.onclick = () => ekranAc(masakEkrani);
    const nk = $("#mmNotK"); if (nk) nk.onclick = async () => {
      try { const l = await API.rpc("mod_not_ekle", { p_kad: d.kad, p_metin: $("#mmNot").value }); $("#mmNot").value = ""; $("#mmNotL").innerHTML = notListe(l); d.notlar = l; toast("Not eklendi."); } catch (err) { hata(err); }
    };
    document.querySelectorAll("[data-a]").forEach(b => b.onclick = () => dosyaIslem(b.dataset.a, d));
    kisitBagla(() => mmDosya());
  }
  const notListe = (l) => (l || []).map(n => `<div class="mm-satir" style="cursor:default"><div class="orta"><div style="font-size:15px;line-height:1.45;white-space:pre-wrap">${esc(n.metin)}</div><div class="kucuk">${esc(n.yazan)} · ${once(n.zaman)}</div></div></div>`).join("") || `<div class="mm-alt" style="padding:12px 0">Henüz not yok.</div>`;
  const sureMetni = (s) => (!s ? "—" : s < 1 ? Math.round(s * 60) + " dk" : s < 48 ? (+s.toFixed(1)) + " saat" : (+(s / 24).toFixed(1)) + " gün");
  /* 22.11.2026 · Küçük cezalar: resmî uyarı ve para cezası (sunucu: mod_uyari, mod_para_cezasi; yetki 'sustur') */
  function kucukCezaAc(tur, kad, kanit, sonra) {
    const para = tur === "para", yon = !!(M && M.ben && M.ben.yonetici);
    const TUT = [[1000, "1.000 ₺"], [2500, "2.500 ₺"], [5000, "5.000 ₺"], [10000, "10.000 ₺"]].concat(yon ? [[50000, "50.000 ₺"], [250000, "250.000 ₺"]] : []);
    const HAZIR = ["Irkçı / ayrımcı ifade", "Hakaret veya küfür", "Bölücü içerik", "Sohbeti doldurma (flood/spam)", "Kışkırtıcı / nefret söylemi"];
    let tutar = 2500;
    const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">${para ? "Para cezası" : "Resmî uyarı"} · ${esc(kad)}</h3>
      <p class="mm-alt" style="margin:4px 0 8px">${para ? "Ceza oyuncunun cüzdanından alınır ve Hazine'ye gelir yazılır; cüzdanda yetmezse cüzdandaki kadarı alınır. Aynı oyuncuya 1 saatte bir kesilebilir." + (yon ? "" : " Tek başına en çok 10.000 ₺.") : "Oyuncuya kayıtlı resmî uyarı gider; kısıt uygulanmaz. 24 saat içinde 3. uyarıda oyuncu kendiliğinden susturulur."}</p>
      <div class="mm-alt" id="mmKCOz" style="margin:0 0 8px"></div>
      ${para ? `<div class="mm-filtre" id="mmKCT">${TUT.map(s => `<button data-v="${s[0]}" class="${s[0] === tutar ? "on" : ""}">${s[1]}</button>`).join("")}</div>` : ""}
      <div class="mm-alan">Hazır gerekçe</div><div class="mm-filtre" id="mmKCH">${HAZIR.map((h, i) => `<button data-v="${i}">${esc(h)}</button>`).join("")}</div>
      <label class="mm-alan" for="mmKCG">Gerekçe (oyuncu görür)</label><textarea class="mm-girdi" id="mmKCG" maxlength="300" placeholder="Örn. Genel sohbette ırkçı ifade."></textarea>
      <button class="mm-btn kirmizi" style="margin-top:10px" id="mmKCOk">${para ? "Cezayı kes" : "Uyarıyı gönder"}</button><button class="mm-btn cizgi" style="margin-top:8px" id="mmKCVaz">Vazgeç</button>`);
    if (para) cipSec($("#mmKCT", md), x => tutar = +x);
    cipSec($("#mmKCH", md), x => { $("#mmKCG", md).value = HAZIR[+x] + "."; });
    API.rpc("mod_kucuk_cezalar", { p_kad: kad }).then(k => { const e = $("#mmKCOz", md); if (e && k) e.textContent = `Son 24 saatte ${k.uyari_24s} uyarı · son 30 günde ${k.uyari_30g} uyarı, ${k.sustur_30g} susturma, ${tl(k.para_30g)} para cezası.`; }).catch(() => {});
    $("#mmKCVaz", md).onclick = modalKapat;
    $("#mmKCOk", md).onclick = async () => {
      const g = $("#mmKCG", md).value.trim();
      if (g.length < 5) { toast("Kısa bir gerekçe yaz ya da hazır gerekçe seç.", true); return; }
      try {
        const r = para ? await API.rpc("mod_para_cezasi", { p_kad: kad, p_tutar: tutar, p_gerekce: g, p_kanit: kanit })
                       : await API.rpc("mod_uyari", { p_kad: kad, p_gerekce: g, p_kanit: kanit });
        modalKapat();
        toast(para ? `${kad}: ${tl(r.ceza)} ceza kesildi (${tl(r.tahsil)} tahsil edildi).`
                   : r.oto_susturma ? `${kad}: 3. uyarı, oyuncu otomatik susturuldu.` : `${kad}: ${r.uyari_sayisi}. uyarı gönderildi (24 saat).`);
        sonra && sonra();
      } catch (err) { hata(err); }
    };
  }
  /* 23.11.2026 · Oyuncuya özel mesaj / yazılı uyarı (sunucu: mod_oyuncuya_yaz). Yazışma oyuncunun Yönetime Yaz ekranına
     düşer, oyuncu karşılık yazabilir; karşılık Talep kutusu'na gelir. Yazanın adı görünmez, görev kodu görünür. */
  function oyuncuyaYazAc(kad, uyariOn, sonra) {
    let uyari = !!uyariOn;
    const HAZIR = ["Lütfen sohbette üslubuna dikkat et; hakaret ve küfür yasaktır. Tekrarında yaptırım uygulanır.",
      "Paylaşımın oyun kurallarına aykırı bulundu. Lütfen kuralları gözden geçir; tekrarında yaptırım uygulanır.",
      "Hesabınla ilgili bir konuda bilgine ihtiyacımız var. Uygun olduğunda bu mesaja karşılık yazar mısın?"];
    const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">Oyuncuya yaz · ${esc(kad)}</h3>
      <p class="mm-alt" style="margin:4px 0 8px">Mesaj oyuncuya bildirim olarak gider ve <b>Ben › Yönetime Yaz</b> ekranında görünür; oyuncu karşılık yazabilir, karşılığı Talep kutusu'na düşer. Adın görünmez, görev kodun görünür.</p>
      <div class="mm-alan">Tür</div>
      <div class="mm-filtre" id="mmOYT"><button data-v="0" class="${uyari ? "" : "on"}">Mesaj</button><button data-v="1" class="${uyari ? "on" : ""}">Yazılı uyarı</button></div>
      <div class="mm-alt" id="mmOYA" style="margin:6px 0 0"></div>
      <div class="mm-alan">Hazır metin</div>
      <div class="mm-filtre" id="mmOYH"><button data-v="0">Üslup</button><button data-v="1">Kural ihlali</button><button data-v="2">Bilgi isteği</button></div>
      <label class="mm-alan" for="mmOYM">Mesajın (10-1000 karakter)</label>
      <textarea class="mm-girdi" id="mmOYM" maxlength="1000" placeholder="Oyuncuya yazacağın mesaj"></textarea>
      <button class="mm-btn mor" style="margin-top:10px" id="mmOYOk">Gönder</button>
      <button class="mm-btn cizgi" style="margin-top:8px" id="mmOYVaz">Vazgeç</button>`);
    const acikla = () => { $("#mmOYA", md).textContent = uyari ? "Yazılı uyarı yaptırım değildir; kısıt uygulamaz ama oyuncunun dosyasına işlenir. Susturmaya götüren uyarı için Resmî uyarı kullanılır." : "Bilgi vermek ya da soru sormak için."; $("#mmOYOk", md).textContent = uyari ? "Uyarıyı gönder" : "Mesajı gönder"; };
    acikla();
    cipSec($("#mmOYT", md), v => { uyari = v === "1"; acikla(); });
    cipSec($("#mmOYH", md), v => { $("#mmOYM", md).value = HAZIR[+v]; if (+v < 2 && !uyari) { uyari = true; $("#mmOYT", md).querySelectorAll("button").forEach(b => b.classList.toggle("on", b.dataset.v === "1")); acikla(); } });
    $("#mmOYVaz", md).onclick = modalKapat;
    $("#mmOYOk", md).onclick = async () => {
      const m = $("#mmOYM", md).value.trim();
      if (m.length < 10) { toast("Mesaj en az 10 karakter olmalı.", true); return; }
      $("#mmOYOk", md).disabled = true;
      try {
        const r = await API.rpc("mod_oyuncuya_yaz", { p_kad: kad, p_metin: m, p_uyari: uyari });
        modalKapat(); toast(`${kad}: ${uyari ? "yazılı uyarı" : "mesaj"} gönderildi (#${r.id}).`); sonra && sonra();
      } catch (err) { hata(err); const b = $("#mmOYOk", md); if (b) b.disabled = false; }
    };
  }
  function dosyaIslem(a, d) {
    if (a === "talep") return talepAc(d.kad, { tur: "sustur" });
    if (a === "ilet") return talepAc(d.kad, { tur: "eskalasyon" });
    if (a === "mali" || a === "secim") return kisitUygula(d.kad, a, (d.sinirlar || {})[a], !!(d.yetkim || {}).yonetici, () => mmDosya());
    if (a === "toplu") return topluGizle(d.kad, () => mmDosya());
    if (a === "km") return kmOyuncuAc(d.kad);
    if (a === "not") { DS.sekme = "not"; mmDosya(); return; }
    if (a === "yaz") return oyuncuyaYazAc(d.kad, null, () => mmDosya());
    if (a === "uyari" || a === "para") return kucukCezaAc(a, d.kad, null, () => mmDosya());
    if (a === "susKaldir") return (async () => { try { await API.rpc("yk_sustur", { p_kad: d.kad, p_saat: 0, p_neden: null }); toast("Susturma kaldırıldı."); mmDosya(); } catch (err) { hata(err); } })();
    if (a === "engelKaldir") return (async () => { if (!await onayla("Engeli kaldır", `${esc(d.kad)} yeniden oyuna girebilecek.`, "Kaldır")) return; try { await API.rpc("yk_engel_kaldir", { p_kad: d.kad }); toast("Engel kaldırıldı."); mmDosya(); } catch (err) { hata(err); } })();
    const sus = a === "sustur";
    const SEC = sus ? [[0.25, "15 dk"], [0.5, "30 dk"], [1, "1 saat"], [3, "3 saat"], [6, "6 saat"], [24, "24 saat"], [72, "3 gün"], [168, "7 gün"]] : [[1 / 24, "1 saat"], [3 / 24, "3 saat"], [6 / 24, "6 saat"], [0.5, "12 saat"], [1, "1 gün"], [3, "3 gün"], [7, "7 gün"], [30, "30 gün"], [0, "Kalıcı"]];
    let v = sus ? 1 : 3 / 24;
    const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">${sus ? "Sohbette sustur" : "Uzaklaştır / engelle"} · ${esc(d.kad)}</h3>
      <p class="mm-alt" style="margin:4px 0 8px">${sus ? "Oyuncu süre boyunca hiçbir sohbete yazamaz; oyunun geri kalanını oynar. Son 30 günde tekrar eden oyuncuda süre kendiliğinden artar (2. kez en az 1 saat, 3. kez 6 saat, 4. kez 1 gün, 5. kez 3 gün, sonrası 7 gün)." : "Oyuncu süre boyunca oyuna giremez; görevleri ve verileri korunur. 1 günden kısa süre oyuncuya \"uzaklaştırma\" olarak bildirilir. Tek başına en çok 24 saat; daha uzunu ve kalıcı engel ikinci imzayla."}</p>
      ${sus ? `<div class="mm-alt" id="mmSKad" style="margin:0 0 8px"></div>` : ""}
      <div class="mm-filtre" id="mmSS">${SEC.map(s => `<button data-v="${s[0]}" class="${s[0] === v ? "on" : ""}">${s[1]}</button>`).join("")}</div>
      <label class="mm-alan" for="mmSG">Gerekçe (oyuncu görür)</label><textarea class="mm-girdi" id="mmSG" maxlength="200" placeholder="Örn. Genel sohbette tekrarlanan hakaret."></textarea>
      <button class="mm-btn kirmizi" style="margin-top:10px" id="mmSOk">${sus ? "Sustur" : "Uygula"}</button><button class="mm-btn cizgi" style="margin-top:8px" id="mmSVaz">Vazgeç</button>`);
    cipSec($("#mmSS", md), x => v = +x);
    if (sus) API.rpc("mod_kucuk_cezalar", { p_kad: d.kad }).then(k => { const e = $("#mmSKad", md); if (e && k) e.textContent = k.sustur_30g ? `Son 30 günde ${k.sustur_30g} kez susturuldu; yeni susturma en az ${sureMetni(k.sonraki_sustur_alt_saat)} olur.` : "Son 30 günde susturulmamış."; }).catch(() => {});
    $("#mmSVaz", md).onclick = modalKapat;
    $("#mmSOk", md).onclick = async () => {
      const g = $("#mmSG", md).value.trim();
      if (!sus && g.length < 5) { toast("Engel için kısa bir gerekçe yaz.", true); return; }
      try {
        const r = sus ? await API.rpc("yk_sustur", { p_kad: d.kad, p_saat: v, p_neden: g || null })
                      : await API.rpc("yk_engelle", { p_kad: d.kad, p_gun: v || null, p_neden: g, p_hesabi_kapat: false });
        modalKapat();
        toast(sus ? (r && r.susturma_bitis ? `Oyuncu ${tsaat(r.susturma_bitis)} tarihine kadar susturuldu.` : "Oyuncu susturuldu.")
                  : (r && r.ikinci_imza ? "Bu süre ikinci imza istiyor; yaptırım talebi açıldı." : v && v < 1 ? "Oyuncu uzaklaştırıldı." : "Oyuncu engellendi."));
        mmDosya();
      } catch (err) { hata(err); }
    };
  }

  /* =====================================================================
     8) ÇOKLU HESAP · DUYURU · GÜNLÜK · EKİP (moderatör görünümü)
     ===================================================================== */
  function mmCoklu() {
    sayfa("Çoklu hesap", `<div class="mm-uyari sari">${IK.sandik}<div>Aynı cihazdan açılan hesaplar güçlü, aynı bağlantı adresi (IP) zayıf işarettir; aile, okul ve mobil operatör aynı IP'yi paylaşabilir. Gerçek kişi olduğuna kanaat getirdiğin hesabı onayla; sahte hesap için yaptırım talebi aç ya da engelle.</div></div>
      <div class="mm-ara">${IK.ara}<input id="mmCAra" placeholder="Hesap adıyla dosya aç" autocapitalize="off"></div><div class="mm-oneri" id="mmCOn"></div>
      ${yv("hesap_kapat") ? `<button class="mm-btn cizgi" style="margin-top:10px" id="mmCyGit">${IK.kalkan}Yasaklı cihazlar</button>` : ""}
      <div id="ysuphe" style="margin-top:10px"><div class="mm-alt">Yükleniyor…</div></div>`);
    if ($("#mmCyGit")) $("#mmCyGit").onclick = () => ekranAc(mmCihaz);
    oyuncuAramaBagla($("#mmCAra"), $("#mmCOn"));
    if (typeof yoneticiSupheCiz === "function") yoneticiSupheCiz();
  }
  /* =====================================================================
     YASAKLI CİHAZLAR (23.11.2026) — kalıcı engellenen hesapların telefon/tarayıcıları
     Sunucu: mod_cihaz_yasaklari, mod_cihaz_yasak_ayarla (zz_20261123_cihaz_yasak.sql)
     ===================================================================== */
  const CY = { veri: null };
  async function mmCihaz() {
    yukleniyor("Yasaklı cihazlar");
    try { CY.veri = await API.rpc("mod_cihaz_yasaklari"); } catch (err) { hataSayfa("Yasaklı cihazlar", err); return; }
    cihazCiz();
  }
  function cihazCiz() {
    const v = CY.veri || {}, A = v.aktif || [], K = v.kaldirilan || [], DN = v.denemeler || [];
    const hesap = (h) => `<a data-dosya="${esc(h.kad)}">${esc(h.kad)}</a> <span class="mm-alt">(${h.yasakli ? "engelli" : h.muaf ? "muaf" : "bu cihazdan giremez"})</span>`;
    sayfa("Yasaklı cihazlar", `
      <div class="mm-uyari sari">${IK.kalkan}<div>Bir hesap <b>kalıcı</b> engellenince kullandığı telefon ve tarayıcılar kendiliğinden bu listeye girer. Listedeki cihazdan yeni hesap açılamaz, başvuru yapılamaz ve oyuna girilemez. Hesabın engeli kaldırılırsa cihaz yasağı da kalkar.</div></div>
      <div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Yasaklı cihazlar (${A.length})</h3><button class="link" id="mmCyYen">Yenile</button></div>
        ${A.map(y => `<div class="mm-cy">
          <div class="cyb"><b>${esc(y.kaynak || "—")}</b><span class="mm-etiket" style="--c:#e5574f">yasaklı</span></div>
          <div class="mm-alt">${esc(y.neden || "Gerekçe yazılmamış")} · ${tsaat(y.zaman)}${y.ekleyen ? " · " + esc(y.ekleyen) : ""}</div>
          ${(y.hesaplar || []).length ? `<div style="margin-top:8px;font-size:14.5px;line-height:1.5"><span class="mm-alt">Bu cihazda görülen hesaplar</span><br>${y.hesaplar.map(hesap).join(", ")}</div>` : ""}
          <div style="margin-top:6px;font-size:14.5px"><span class="mm-alt">Engellenen deneme</span><br>${y.deneme && +y.deneme.hesap ? `${sayi(y.deneme.hesap)} ayrı hesap · ${sayi(y.deneme.toplam)} kez · son ${once(y.deneme.son)}` : "henüz yok"}</div>
          ${v.kaldirabilir ? `<button class="mm-btn cizgi" style="margin-top:10px" data-cyk="${y.id}">Cihaz yasağını kaldır</button>` : ""}
        </div>`).join("") || `<div class="mm-alt">Yasaklı cihaz yok.</div>`}</div>
      <div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Engellenen denemeler</h3></div>
        ${DN.map(d => `<div class="mm-satir" style="cursor:default"><div class="orta"><b>${esc(d.kad || "Yeni hesap (başvurusu yok)")}</b><div class="kucuk">${esc(d.kaynak || "—")} hesabının cihazından · ${sayi(d.sayi)} kez · son ${once(d.son)}</div></div><span class="mm-etiket" style="--c:#e0a43a">${d.hesap_var ? "hesabı var" : d.kad ? "başvuru" : "yeni"}</span></div>`).join("") || `<div class="mm-alt">Yasaklı cihazdan giriş ya da başvuru denemesi yok.</div>`}</div>
      ${K.length ? `<details class="mm-kart"><summary style="font-weight:800;cursor:pointer">Kaldırılan yasaklar (${K.length})</summary>
        ${K.map(y => `<div class="mm-cy"><div class="cyb"><b>${esc(y.kaynak || "—")}</b><span class="mm-etiket" style="--c:#98a4c4">kaldırıldı</span></div>
          <div class="mm-alt">${esc(y.kaldirma_not || "")} · ${esc(y.kaldiran || "sistem")} · ${tsaat(y.kaldirma_zaman)}</div>
          ${v.kaldirabilir ? `<button class="mm-btn cizgi" style="margin-top:10px" data-cya="${y.id}">Yeniden yasakla</button>` : ""}</div>`).join("")}</details>` : ""}
      ${v.kaldirabilir ? "" : `<p class="mm-alt" style="text-align:center;margin:6px 0 14px">Cihaz yasağını kurucu ve Oyuncu Masası kaldırabilir.</p>`}`);
    const ic = $("#icerik");
    $("#mmCyYen").onclick = mmCihaz;
    ic.querySelectorAll("[data-dosya]").forEach(el => el.onclick = () => mmDosyaAc(el.dataset.dosya));
    ic.querySelectorAll("[data-cyk]").forEach(el => el.onclick = () => cihazKarar(+el.dataset.cyk, false));
    ic.querySelectorAll("[data-cya]").forEach(el => el.onclick = () => cihazKarar(+el.dataset.cya, true));
  }
  function cihazKarar(id, ac) {
    const m = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">${ac ? "Cihazı yeniden yasakla" : "Cihaz yasağını kaldır"}</h3>
      <p class="mm-alt" style="margin:4px 0 8px">${ac ? "Bu cihazdan yeniden başvuru yapılamaz ve oyuna girilemez." : "Bu cihazdan yeniden hesap açılabilir ve oyuna girilebilir. Yalnız yanlışlıkla yasaklandığından eminsen kaldır."} İşlem kayda geçer ve kurucuya bildirilir.</p>
      <label class="mm-alan" for="mmCyNot">Gerekçe (en az 10 karakter)</label>
      <textarea class="mm-girdi" id="mmCyNot" maxlength="300"></textarea>
      <button class="mm-btn ${ac ? "kirmizi" : "mor"}" style="margin-top:10px" id="mmCyOk">${ac ? "Yeniden yasakla" : "Yasağı kaldır"}</button>
      <button class="mm-btn cizgi" style="margin-top:8px" id="mmCyVaz">Vazgeç</button>`);
    $("#mmCyVaz", m).onclick = modalKapat;
    $("#mmCyOk", m).onclick = async () => {
      const n = $("#mmCyNot", m).value.trim();
      if (n.length < 10) { toast("En az 10 karakterlik gerekçe yaz.", true); return; }
      $("#mmCyOk", m).disabled = true;
      try {
        CY.veri = await API.rpc("mod_cihaz_yasak_ayarla", { p_id: id, p_aktif: ac, p_not: n });
        modalKapat(); toast(ac ? "Cihaz yeniden yasaklandı." : "Cihaz yasağı kaldırıldı."); cihazCiz();
      } catch (err) { hata(err); const b = $("#mmCyOk", m); if (b) b.disabled = false; }
    };
  }
  function mmDuyuru() {
    const HED = [["cevrimici", "Çevrimiçi olanlar"], ["aktif", "Son 7 gün aktif"], ["yeni", "Yeni oyuncular (3 gün)"], ["herkes", "Herkes"], ["oyuncu", "Tek oyuncu"]];
    let hedef = "cevrimici";
    sayfa("Duyuru", `<div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Bildirim gönder</h3></div>
        <div class="mm-filtre" id="mmDH">${HED.map(h => `<button data-v="${h[0]}" class="${h[0] === hedef ? "on" : ""}">${h[1]}</button>`).join("")}</div>
        <div id="mmDKad" style="display:none"><label class="mm-alan" for="mmDK">Kullanıcı adı</label><input class="mm-girdi" id="mmDK" autocapitalize="off"></div>
        <label class="mm-alan" for="mmDM">Metin</label><textarea class="mm-girdi" id="mmDM" maxlength="500" placeholder="Başına görev unvanın eklenir (ör. “Oyun Yöneticisi G-06: …”)."></textarea>
        <button class="mm-btn mor" style="margin-top:10px" id="mmDG">Bildirimi gönder</button></div>
      <div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Herkese açık duyuru</h3></div><p class="mm-alt" style="margin-top:0">Bildirimler ekranında resmî duyuru olarak yayımlanır; sonuna görev unvanın eklenir. En fazla 5000 karakter.</p>
        <textarea class="mm-girdi" id="mmDY" maxlength="5000" style="min-height:180px" placeholder="Örn. Bu gece 03:00-03:30 arası bakım yapılacak."></textarea>
        <div class="mm-alt" id="mmDYS" style="text-align:right;margin-top:4px" aria-live="polite">0 / 5000</div>
        <button class="mm-btn" style="margin-top:10px" id="mmDYG">Duyuruyu yayımla</button></div>`);
    cipSec($("#mmDH"), v => { hedef = v; $("#mmDKad").style.display = v === "oyuncu" ? "" : "none"; });
    const dySay = () => { const n = $("#mmDY").value.length, el = $("#mmDYS"); if (el) { el.textContent = `${n} / 5000`; el.style.color = n > 4800 ? "#e0a43a" : ""; } };
    $("#mmDY").addEventListener("input", dySay);
    $("#mmDG").onclick = async () => {
      const m = $("#mmDM").value.trim(); if (!m) { toast("Metin yaz.", true); return; }
      if (hedef === "herkes" && !await onayla("Herkese bildirim", "Bildirim oyundaki tüm oyunculara gidecek.", "Gönder")) return;
      try { const r = await API.rpc("yk_bildirim", { p_hedef: hedef, p_deger: hedef === "oyuncu" ? $("#mmDK").value.trim() : null, p_metin: m }); toast(`${r.kisi} oyuncuya gönderildi.`); $("#mmDM").value = ""; } catch (err) { hata(err); }
    };
    $("#mmDYG").onclick = async () => {
      const m = $("#mmDY").value.trim(); if (!m) { toast("Metin yaz.", true); return; }
      if (!await onayla("Duyuruyu yayımla", "Duyuru tüm oyunculara gider ve geri alınamaz.", "Yayımla")) return;
      try { const r = await API.rpc("admin_duyuru", { p_metin: m }); toast(`Duyuru ${r.kitle || ""} oyuncuya gönderildi.`); $("#mmDY").value = ""; dySay(); } catch (err) { hata(err); }
    };
  }
  const GN = { kad: "", liste: [] };
  async function mmGunluk() {
    yukleniyor("Denetim günlüğü");
    let l, ekip = [];
    try { l = await API.rpc("mod_gunluk", { p_kad: GN.kad || null, p_limit: 80, p_once: null }); } catch (err) { hataSayfa("Denetim günlüğü", err); return; }
    if (!M) try { await merkezYukle(); } catch (_) {}
    const yon = M && M.ben && M.ben.yonetici;
    if (yon) (M.birimler || []).forEach(b => (b.uyeler || []).forEach(u => ekip.push(u.kad)));
    if (yon) try { const a = await API.rpc("admin_mod_ekip"); ekip = a.moderatorler.map(x => x.kad); } catch (_) {}
    GN.liste = l;
    sayfa(yon ? "Denetim günlüğü" : "İşlemlerim", `
      ${yon ? `<div class="mm-filtre" id="mmGF"><button data-v="" class="${GN.kad ? "" : "on"}">Herkes</button>${ekip.map(k => `<button data-v="${esc(k)}" class="${GN.kad === k ? "on" : ""}">${esc(k)}</button>`).join("")}</div>` : `<p class="mm-alt" style="margin:0 2px 8px">Yaptığın her işlem burada. Yönetici tüm ekibin günlüğünü görür.</p>`}
      <div class="mm-kart" style="padding:4px 12px" id="mmGL">${gunlukSatir(l)}</div>
      ${l.length >= 80 ? `<button class="mm-btn" id="mmGD">Daha eski kayıtlar</button>` : ""}`);
    const f = $("#mmGF"); if (f) f.querySelectorAll("[data-v]").forEach(b => b.onclick = () => { GN.kad = b.dataset.v; mmGunluk(); });
    const dd = $("#mmGD"); if (dd) dd.onclick = async () => {
      try { const ek = await API.rpc("mod_gunluk", { p_kad: GN.kad || null, p_limit: 80, p_once: GN.liste[GN.liste.length - 1].id }); GN.liste = GN.liste.concat(ek); $("#mmGL").innerHTML = gunlukSatir(GN.liste); if (ek.length < 80) dd.remove(); } catch (err) { hata(err); }
    };
  }
  const gunlukSatir = (l) => l.map(k => `<div class="mm-satir" style="cursor:default"><div class="orta"><b style="font-weight:650">${esc(k.kad)} ${esc(ISLEM[k.islem] || k.islem)}${k.hedef ? ` · <span style="color:var(--ink2)">${esc(k.hedef)}</span>` : ""}</b><div class="kucuk">${tsaat(k.zaman)}${k.ayrinti ? " · " + esc(k.ayrinti) : ""}</div></div></div>`).join("") || `<div class="mm-alt" style="padding:12px 0">Kayıt yok.</div>`;

  async function mmEkipGor() {
    yukleniyor("Ekip");
    try { await merkezYukle(); } catch (err) { hataSayfa("Ekip", err); return; }
    sayfa("Ekip", `<p class="mm-alt" style="margin:0 2px 10px">Oyun yönetimi 7 uzmanlık biriminden oluşur. Her moderatör yeni oyuncu başvurularını onaylayabilir; diğer işler birimine göre dağıtılır.</p>
      ${(M.birimler || []).map(b => `<div class="mm-birim" style="--c:${b.renk}"><div class="mm-u"><span class="ik">${IK[b.ikon] || IK.kalkan}</span><div style="min-width:0"><b>${esc(b.ad)}</b><small>${esc(b.aciklama)}</small></div></div>
        <div class="uyeler">${(b.uyeler || []).map(u => `<div class="mm-satir" style="cursor:default"><span class="mm-nokta ${u.cevrimici ? "on" : ""}"></span><div class="orta"><b>${esc(u.kad)}</b><div class="kucuk">${esc(RUTBE[u.rutbe] || "Moderatör")}</div></div></div>`).join("") || `<div class="mm-alt" style="padding:8px 0 10px">Bu birimde henüz kimse yok.</div>`}</div></div>`).join("")}`);
  }

  /* =====================================================================
     9) YÖNETİCİ · EKİP YÖNETİMİ
     ===================================================================== */
  const EK = { veri: null, sekme: "birim" };
  async function mmEkip() {
    yukleniyor("Ekip yönetimi");
    try { EK.veri = await API.rpc("admin_mod_ekip"); } catch (err) { hataSayfa("Ekip yönetimi", err); return; }
    ekipCiz();
  }
  function ekipCiz() {
    const V = EK.veri, mods = V.moderatorler || [];
    const hedefToplam = (V.birimler || []).reduce((s, b) => s + (b.hedef || 0), 0);
    const cev = mods.filter(m => m.cevrimici).length, hafta = mods.reduce((s, m) => s + (m.islem_7g || 0), 0);
    const kritik = mods.filter(m => (m.kritik || []).length);
    const birimsiz = mods.filter(m => !m.birim_gecerli);
    const eksik = (V.birimler || []).filter(b => mods.filter(m => m.birim === b.kod).length < b.hedef).length;
    const uyeSatir = (m) => `<div class="mm-satir" data-m="${esc(m.kad)}"><span class="mm-nokta ${m.cevrimici ? "on" : ""}"></span><div class="orta"><b>${m.kod ? `<span class="mm-etiket" style="--c:#34c98a">${esc(m.kod)}</span> ` : ""}${esc(m.kad)}${m.rutbe !== "moderator" ? ` <span class="mm-etiket" style="--c:#d9b45b">${esc(RUTBE[m.rutbe])}</span>` : ""}</b>
      <div class="kucuk">7 gün ${m.islem_7g} işlem · ${m.cevrimici ? "çevrimiçi" : once(m.son_gorulme)}${(m.ek || []).length ? ` · +${m.ek.length} ek yetki` : ""}${(m.kritik || []).length ? ` · <span style="color:var(--al2)">kritik: ${m.kritik.join(", ")}</span>` : ""}${m.sozlesme_at ? "" : ` · <span style="color:var(--warn)">sözleşme bekliyor</span>`}</div></div>${IK.ok}</div>`;
    let govde = "";
    if (EK.sekme === "birim") {
      govde = `${kritik.length ? `<div class="mm-uyari">${IK.kilit}<div><b>${kritik.length} moderatörde kritik yetki açık</b> (para ve kıdem, görev verme, kurallar, e-posta görme). Bu yetkiler oyunun ekonomisini ve siyasetini doğrudan değiştirir.
          <div class="mm-alt" style="margin-top:4px">“Sadeleştir” birimi atanmış herkesi yalnız biriminin yetkilerine indirir. Birimi olmayanlara dokunmaz.</div>
          <button class="mm-btn kirmizi" style="margin-top:8px;min-height:44px" id="mmSade">Yetkileri birimlere göre sadeleştir</button></div></div>` : ""}
        ${birimsiz.length ? `<div class="mm-kart vurgu" style="--c:#e0a43a"><div class="mm-baslik" style="margin-top:0"><h3>Birim bekleyenler (${birimsiz.length})</h3></div><p class="mm-alt" style="margin-top:0">Bu moderatörlerin henüz uzmanlık birimi yok. Dokun ve bir birime ata.</p>${birimsiz.map(uyeSatir).join("")}</div>` : ""}
        ${(V.birimler || []).map(b => {
          const u = mods.filter(m => m.birim === b.kod), az = u.length < b.hedef;
          return `<div class="mm-birim" style="--c:${b.renk}"><div class="mm-u"><span class="ik">${IK[b.ikon] || IK.kalkan}</span><div style="min-width:0"><b>${esc(b.ad)}</b><small>${esc(b.aciklama)}</small></div><span class="mm-doluluk ${az ? "eksik" : ""}">${u.length}/${b.hedef}</span></div>
            <div class="uyeler">${u.map(uyeSatir).join("") || `<div class="mm-alt" style="padding:6px 0 10px">Boş birim.</div>`}</div>
            <button class="ekle" data-ekle="${b.kod}">+ ${esc(b.ad.split(" ")[0])} birimine moderatör ekle</button></div>`;
        }).join("")}`;
    } else if (EK.sekme === "taraf") {
      const T = EK.taraf || { moderatorler: [], son: [], devirler: [] };
      const KAY = { sikayet: "Şikâyet", akis: "Kürsü şikâyeti", masak: "MASAK kaydı", talep: "Yaptırım talebi" };
      const oran = (o, n) => n ? `%${o}` : "–";
      const liste = (T.moderatorler || []).filter(m => m.ceza_ayni + m.lehe_ayni + m.devir + m.ceza_diger + m.lehe_diger > 0);
      govde = `<div class="mm-uyari yesil">${IK.terazi}<div><b>Kural:</b> Moderatör kendi partilisine ceza verebilir; lehine karar veremez, o dosya kendiliğinden tarafsız moderatöre devredilir. Tarafsız moderatör yoksa ya da 2 saat bakılmazsa sana bildirim gelir.
          <div class="mm-alt" style="margin-top:4px">Oranlar ${tsaat(T.baslangic)} tarihinden beri sayılır. "Ceza oranı": o gruptaki kararların yüzde kaçı ceza. İki grup arasında büyük fark varsa moderatör işaretlenir.</div></div></div>
        <div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Tarafsız karar bekleyenler (${(T.devirler || []).length})</h3></div>
          ${(T.devirler || []).map(d => `<div class="mm-satir" ${d.hedef ? `data-dosya="${esc(d.hedef)}"` : `style="cursor:default"`}><div class="orta"><b>${esc(d.hedef || "Parti kaydı")}</b><div class="kucuk">${KAY[d.kaynak] || esc(d.kaynak)} · ${esc(d.devreden)} devretti · ${once(d.zaman)}</div></div>${d.yoneticide ? `<span class="mm-etiket" style="--c:#e5574f">karar sende</span>` : `<span class="mm-etiket" style="--c:#7b61ff">moderatörde</span>`}</div>`).join("") || `<div class="mm-alt" style="padding:4px 0 8px">Bekleyen devir yok.</div>`}</div>
        <div class="mm-kart" style="overflow-x:auto"><div class="mm-baslik" style="margin-top:0"><h3>Ceza oranı: kendi partisi / diğerleri</h3></div>
          ${liste.length ? `<table class="mm-tablo"><thead><tr><th>Moderatör</th><th class="s">Kendi partisi</th><th class="s">Diğerleri</th><th class="s">Devir</th></tr></thead><tbody>
          ${liste.map(m => `<tr data-m="${esc(m.kad)}" style="cursor:pointer"><td>${esc(m.kad)}<div class="mm-alt">${esc(m.parti || "partisiz")}${m.isaret ? ` · <span style="color:var(--al2);font-weight:700">${m.isaret === "yumusak" ? "kendi partisine yumuşak" : "kendi partisine sert"}</span>` : ""}</div></td>
            <td class="s">${oran(m.oran_ayni, m.ceza_ayni + m.lehe_ayni + m.devir)}<div class="mm-alt">${m.ceza_ayni}/${m.ceza_ayni + m.lehe_ayni + m.devir}</div></td>
            <td class="s">${oran(m.oran_diger, m.ceza_diger + m.lehe_diger)}<div class="mm-alt">${m.ceza_diger}/${m.ceza_diger + m.lehe_diger}</div></td><td class="s">${m.devir}</td></tr>`).join("")}
          </tbody></table>` : `<div class="mm-alt" style="padding:4px 0 8px">Henüz sayılacak karar yok.</div>`}</div>
        <div class="mm-kart" style="padding:4px 12px"><div class="mm-baslik"><h3>Aynı partiliye yapılan son işlemler</h3></div>
          ${(T.son || []).map(k => `<div class="mm-satir" ${k.hedef ? `data-dosya="${esc(k.hedef)}"` : `style="cursor:default"`}><div class="orta"><b style="font-weight:650">${esc(k.kad)} ${esc(ISLEM[k.islem] || k.islem)}</b><div class="kucuk">${esc(k.hedef || "")} · ${once(k.zaman)}${k.ayrinti ? " · " + esc(k.ayrinti) : ""}</div></div><span class="mm-etiket" style="--c:${k.yon === "ceza" ? "#e5574f" : k.yon === "devir" ? "#7b61ff" : "#98a4c4"}">${k.yon === "ceza" ? "ceza" : k.yon === "devir" ? "devir" : k.yon === "lehe" ? "lehe" : "diğer"}</span></div>`).join("") || `<div class="mm-alt" style="padding:12px 0">Henüz aynı partiliye yapılmış işlem yok.</div>`}</div>`;
    } else {
      const sirali = mods.slice().sort((a, b) => b.islem_7g - a.islem_7g);
      govde = `<div class="mm-kart" style="overflow-x:auto"><table class="mm-tablo"><thead><tr><th>Moderatör</th><th class="s">Bugün</th><th class="s">7 gün</th><th class="s">30 gün</th><th class="s">Kayıt</th></tr></thead><tbody>
        ${sirali.map(m => `<tr data-m="${esc(m.kad)}" style="cursor:pointer"><td><span class="mm-nokta ${m.cevrimici ? "on" : ""}" style="display:inline-block;margin-right:6px"></span>${esc(m.kad)}<div class="mm-alt">${esc(((V.birimler || []).find(b => b.kod === m.birim) || {}).ad || "birim yok")}</div></td><td class="s">${m.islem_1g}</td><td class="s">${m.islem_7g}</td><td class="s">${m.islem_30g}</td><td class="s">${m.kayit_7g}</td></tr>`).join("")}
        </tbody></table><p class="mm-alt">“Kayıt”: son 7 günde verdiği başvuru kararı. Son işlem ve son görülme kartta görünür.</p></div>`;
    }
    sayfa("Ekip yönetimi", `
      <section class="mm-hero"><small>Oyun yönetimi</small><h2>${mods.length} / ${hedefToplam} moderatör</h2>
        <div class="mm-istat"><div><b>${cev}</b><span>çevrimiçi</span></div><div><b>${sayi(hafta)}</b><span>7 günde işlem</span></div><div><b class="${eksik ? "" : ""}">${eksik}</b><span>eksik birim</span></div></div></section>
      <button class="mm-btn mor" id="mmYeni" style="margin-bottom:12px">+ Yeni moderatör ekle</button>
      <div class="mm-sekme"><button class="${EK.sekme === "birim" ? "on" : ""}" data-s="birim">Birimler</button><button class="${EK.sekme === "perf" ? "on" : ""}" data-s="perf">Performans</button><button class="${EK.sekme === "taraf" ? "on" : ""}" data-s="taraf">Tarafsızlık</button><button data-s="gunluk">Denetim günlüğü</button></div>
      ${govde}`);
    document.querySelectorAll(".mm-sekme [data-s]").forEach(b => b.onclick = async () => { if (b.dataset.s === "gunluk") return ekranAc(mmGunluk);
      if (b.dataset.s === "taraf") { try { EK.taraf = await API.rpc("admin_mod_tarafsizlik", { p_gun: 30 }); } catch (err) { hata(err); return; } }
      EK.sekme = b.dataset.s; ekipCiz(); });
    document.querySelectorAll("[data-m]").forEach(x => x.onclick = () => modDuzenle(mods.find(m => m.kad === x.dataset.m)));
    document.querySelectorAll("[data-dosya]").forEach(x => x.onclick = () => mmDosyaAc(x.dataset.dosya));
    document.querySelectorAll("[data-ekle]").forEach(x => x.onclick = () => modDuzenle(null, x.dataset.ekle));
    $("#mmYeni").onclick = () => modDuzenle(null, null);
    const sd = $("#mmSade"); if (sd) sd.onclick = async () => {
      if (!await onayla("Yetkileri sadeleştir", "Birimi olan her moderatörün yetkileri yalnız biriminin yetkilerine (ve temel kayıt onayına) indirilecek. Ek ve kritik yetkiler kalkacak.", "Sadeleştir", true)) return;
      try { EK.veri = await API.rpc("admin_mod_sadelestir"); toast(`${EK.veri.sadelesen} moderatörün yetkisi sadeleştirildi.`); ekipCiz(); } catch (err) { hata(err); }
    };
  }
  function modDuzenle(m, birimOn) {
    const V = EK.veri, yeni = !m;
    let birim = m ? (m.birim_gecerli ? m.birim : null) : birimOn, rutbe = m ? m.rutbe : "moderator";
    const ek = new Set(m ? (m.birim_gecerli ? m.ek : (m.yetkiler || []).filter(x => x !== "kayit")) : []);
    const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">${yeni ? "Yeni moderatör" : esc(m.kad)}</h3>
      ${m ? `<div class="mm-alt">${m.ad_soyad ? esc(m.ad_soyad) + " · " : ""}${m.cevrimici ? "çevrimiçi" : "son görülme " + once(m.son_gorulme)} · 7 gün ${m.islem_7g} işlem</div>` : ""}
      ${yeni ? `<label class="mm-alan" for="mmMK">Kullanıcı adı</label><input class="mm-girdi" id="mmMK" autocapitalize="off" autocomplete="off" placeholder="Oyuncunun kullanıcı adı"><div id="mmMKO"></div>` : ""}
      <div class="mm-alan">Uzmanlık birimi</div>
      <div class="mm-secim" id="mmMB">${V.birimler.map(b => `<button data-v="${b.kod}" style="--c:${b.renk}" class="${b.kod === birim ? "on" : ""}"><i></i>${esc(b.ad)}</button>`).join("")}</div>
      <div class="mm-alt" id="mmMBA" style="margin-top:6px"></div>
      <div class="mm-alan">Rütbe</div>
      <div class="mm-filtre" id="mmMR">${Object.entries(RUTBE).map(([k, a]) => `<button data-v="${k}" class="${k === rutbe ? "on" : ""}">${a}</button>`).join("")}</div>
      <details style="margin-top:6px"><summary style="font-weight:800;cursor:pointer;min-height:40px;display:flex;align-items:center">Ek yetkiler (isteğe bağlı)</summary><div id="mmMY"></div></details>
      <label class="mm-alan" for="mmMN">Görev notu (moderatör görür)</label><textarea class="mm-girdi" id="mmMN" maxlength="300" placeholder="Örn. Akşam 20-24 arası sohbet nöbeti senin.">${esc(m && m.not || "")}</textarea>
      <button class="mm-btn mor" style="margin-top:10px" id="mmMKay">${yeni ? "Moderatör yap" : "Kaydet"}</button>
      ${m ? `<button class="mm-btn cizgi" style="margin-top:8px" id="mmMGun">İşlem günlüğü</button><button class="mm-btn cizgi" style="margin-top:8px;color:var(--al2)" id="mmMCik">Moderatörlükten çıkar</button>` : ""}
      <button class="mm-btn cizgi" style="margin-top:8px" id="mmMVaz">Kapat</button>`);
    const yetkiCiz = () => {
      const b = V.birimler.find(x => x.kod === birim);
      $("#mmMBA", md).innerHTML = b ? `<b>Birimden gelen yetkiler:</b> ${b.yetkiler.map(k => esc((V.yetkiler.find(y => y.kod === k) || {}).ad || k)).join(", ")}` : `Bir birim seç. <b>Kayıt onayı</b> her moderatörde zorunlu olarak bulunur.`;
      $("#mmMY", md).innerHTML = V.yetkiler.filter(y => !y.temel && !(b && b.yetkiler.includes(y.kod))).map(y => `<label class="mm-anahtar"><div class="orta"><b>${esc(y.ad)}${y.kritik ? ` <span class="mm-etiket" style="--c:#e5574f">kritik</span>` : ""}</b><div>${esc(y.aciklama)}</div></div><input type="checkbox" data-y="${y.kod}" ${ek.has(y.kod) ? "checked" : ""}></label>`).join("");
      $("#mmMY", md).querySelectorAll("[data-y]").forEach(c => c.onchange = () => c.checked ? ek.add(c.dataset.y) : ek.delete(c.dataset.y));
    };
    cipSec($("#mmMB", md), v => { birim = v; yetkiCiz(); });
    cipSec($("#mmMR", md), v => rutbe = v);
    yetkiCiz();
    if (yeni) oyuncuOneri($("#mmMK", md), $("#mmMKO", md));
    $("#mmMVaz", md).onclick = modalKapat;
    $("#mmMKay", md).onclick = async () => {
      const kad = yeni ? $("#mmMK", md).value.trim() : m.kad;
      if (!kad) { toast("Kullanıcı adı yaz.", true); return; }
      if (!birim) { toast("Bir uzmanlık birimi seç.", true); return; }
      const b = V.birimler.find(x => x.kod === birim);
      const ekl = [...ek].filter(k => !b.yetkiler.includes(k));
      const kritikVar = ekl.some(k => (V.yetkiler.find(y => y.kod === k) || {}).kritik);
      if (kritikVar && !await onayla("Kritik yetki", "Seçtiğin ek yetkilerden biri kritik (para, görev, kurallar ya da e-posta). Emin misin?", "Evet, ver", true)) return;
      try { EK.veri = await API.rpc("admin_mod_kaydet", { p_kad: kad, p_birim: birim, p_rutbe: rutbe, p_ek: ekl, p_not: $("#mmMN", md).value }); modalKapat(); toast(yeni ? `${kad} moderatör oldu.` : "Kaydedildi."); ekipCiz(); }
      catch (err) { hata(err); }
    };
    if (m) {
      $("#mmMGun", md).onclick = () => { modalKapat(); GN.kad = m.kad; ekranAc(mmGunluk); };
      $("#mmMCik", md).onclick = async () => {
        modalKapat();
        if (!await onayla("Moderatörlükten çıkar", `${esc(m.kad)} adlı oyuncunun tüm moderatör yetkileri alınacak.`, "Çıkar", true)) return;
        try { await API.rpc("admin_moderator_ayarla", { p_kad: m.kad, p_yetkiler: [] }); toast("Moderatörlükten çıkarıldı."); mmEkip(); } catch (err) { hata(err); }
      };
    }
  }
  function oyuncuOneri(inp, kutu) {
    let zam = null;
    inp.oninput = () => { clearTimeout(zam); zam = setTimeout(async () => {
      const v = inp.value.trim(); if (v.length < 2) { kutu.innerHTML = ""; return; }
      try { const r = await API.rpc("yk_oyuncular", { p_ara: v, p_filtre: "hepsi", p_sirala: "ad", p_limit: 5, p_offset: 0 });
        kutu.innerHTML = `<div class="mm-filtre" style="padding-top:6px">${(r.liste || []).filter(o => !o.yonetici).map(o => `<button data-k="${esc(o.kad)}">${esc(o.kad)}${o.moderator ? " · mod" : ""}</button>`).join("")}</div>`;
        kutu.querySelectorAll("[data-k]").forEach(b => b.onclick = () => { inp.value = b.dataset.k; kutu.innerHTML = ""; });
      } catch (_) {}
    }, 280); };
  }


  /* =====================================================================
     10) TALEP KUTUSU (Yönetime Yaz) · KÜRSÜ ŞİKÂYETLERİ · KISITLAR VE YETKİLER  (20.11.2026)
     ===================================================================== */
  const KT = { tum: false };
  const KDURUM = { yeni: ["yanıt bekliyor", "#e0a43a"], yanitlandi: ["yanıtlandı", "#34c98a"], kapali: ["kapalı", "#98a4c4"] };
  async function mmKutu() {
    yukleniyor("Talep kutusu");
    let r; try { r = await API.rpc("mod_kutu", { p_durum: KT.tum ? "tum" : "acik" }); } catch (err) { hataSayfa("Talep kutusu", err); return; }
    const l = r.talepler || [];
    sayfa("Talep kutusu", `<div class="mm-uyari yesil">${IK.destek}<div>Oyuncuların <b>Yönetime Yaz</b> ile açtığı talepler çevrimiçi bir görevliye otomatik atanır; 30 dakika yanıt verilmezse başka görevliye geçer. Herkes bütün talepleri görür; bir talebi <b>Üstlen</b> ile alabilirsin. İş bitince <b>Kapat</b>. Yanıtın oyuncuya görev kodunla gider; adın görünmez.</div></div>
      ${r.bana_atanan ? `<div class="mm-uyari sari">${IK.destek}<div>Sana atanmış <b>${r.bana_atanan}</b> talep yanıt bekliyor (en üstte).</div></div>` : ""}
      <div class="mm-filtre"><button class="${KT.tum ? "" : "on"}" data-t="0">Yanıt bekleyen</button><button class="${KT.tum ? "on" : ""}" data-t="1">Son 30 gün</button></div>
      ${l.map((d, i) => `<div class="mm-kart ${d.durum === "yeni" && dkGecti(d.son_hareket) > 240 ? "vurgu" : ""}" data-i="${i}" style="--c:#9a7bff">
        <div style="display:flex;gap:8px;align-items:center;justify-content:space-between;flex-wrap:wrap"><b style="font-size:16px">#${d.id} · ${esc(d.kad)}</b><span class="mm-etiket" style="--c:${(KDURUM[d.durum] || KDURUM.yeni)[1]}">${(KDURUM[d.durum] || KDURUM.yeni)[0]}</span></div>
        ${d.durum !== "kapali" && "atanan_kod" in d ? `<div class="mm-alt" style="margin-top:2px">${d.bana_atandi ? `<b style="color:#34c98a">Sana atandı</b>` : d.atanan_kod ? `Görevli: <b>${esc(d.atanan_kod)}</b>` : `<b style="color:#e0a43a">Henüz görevli atanmadı</b>`}</div>` : ""}
        <div class="mm-alt">${esc(d.konu_ad)} · ${esc(d.masa_ad)} · ${once(d.zaman)}${d.hedef ? ` · hakkında: <b>${esc(d.hedef)}</b>` : ""}${d.onceki ? ` · daha önce ${d.onceki} talep` : ""}${d.hedef_sikayet ? ` · bu oyuncu hakkında ${d.hedef_sikayet} talep daha` : ""}${d.platform ? " · " + esc(d.platform) : ""}</div>
        ${(d.mesajlar || []).map(m => `<div class="mm-baloncuk" style="${m.gorevli ? "border-left:3px solid #34c98a" : ""}"><b>${m.gorevli ? esc(m.yazan) : esc(d.kad)}</b> · ${once(m.zaman)}\n${esc(m.metin)}</div>`).join("")}
        ${d.durum !== "kapali" ? `<textarea class="mm-girdi" maxlength="1000" placeholder="Yanıtın (oyuncuya bildirim olarak gider)"></textarea>
          <div class="mm-iki"><button class="mm-btn mor" data-y="0">Yanıtla</button><button class="mm-btn" data-y="1">Yanıtla ve kapat</button></div>
          <div class="mm-iki" style="margin-top:6px">${"atanan_kod" in d && !d.bana_atandi ? `<button class="mm-btn" data-ustlen="1">Üstlen</button>` : ""}<button class="mm-btn cizgi" data-kapat="1">Yanıtsız kapat</button></div>` : ""}
        <div class="mm-aksiyon">${d.hedef ? `<button data-dosya="${esc(d.hedef)}">Şikâyet edilenin dosyası</button>` : ""}<button data-dosya="${esc(d.kad)}">Yazanın dosyası</button>${d.durum !== "kapali" ? `<button data-devret="1">Başka masaya devret</button>` : ""}</div>
      </div>`).join("") || bos(KT.tum ? "Son 30 günde talep yok" : "Yanıt bekleyen talep yok", "Oyuncular Ben › Yönetime yaz ekranından yazdığında burada görünür.")}`);
    document.querySelectorAll("[data-t]").forEach(b => b.onclick = () => { KT.tum = b.dataset.t === "1"; mmKutu(); });
    document.querySelectorAll(".mm-kart[data-i]").forEach(k => {
      const d = l[+k.dataset.i], ta = k.querySelector("textarea");
      k.querySelectorAll("[data-dosya]").forEach(b => b.onclick = () => mmDosyaAc(b.dataset.dosya));
      k.querySelectorAll("[data-y]").forEach(b => b.onclick = async () => {
        const kapat = b.dataset.y === "1", m = ta.value.trim();
        if (!m && !kapat) { toast("Yanıt yaz.", true); return; }
        try { await API.rpc("mod_kutu_yanitla", { p_id: d.id, p_metin: m || null, p_kapat: kapat }); toast(kapat ? "Yanıtlandı ve kapatıldı." : "Yanıt gönderildi."); mmKutu(); }
        catch (err) { hata(err); }
      });
      const us = k.querySelector("[data-ustlen]");
      if (us) us.onclick = async () => { try { await API.rpc("mod_kutu_ustlen", { p_id: d.id }); toast("Talep sende."); mmKutu(); } catch (err) { hata(err); } };
      const kp = k.querySelector("[data-kapat]");
      if (kp) kp.onclick = async () => { try { await API.rpc("mod_kutu_yanitla", { p_id: d.id, p_metin: null, p_kapat: true }); toast("Talep kapatıldı."); mmKutu(); } catch (err) { hata(err); } };
      const dv = k.querySelector("[data-devret]");
      if (dv) dv.onclick = () => {
        const secenek = (r.masalar || []).filter(x => x.kod !== d.masa).concat(d.masa !== "kurucu" ? [{ kod: "kurucu", ad: "Kurucu (oyun yönetimi)" }] : []);
        const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">Talebi devret · #${d.id}</h3><p class="mm-alt" style="margin:4px 0 8px">Konu başka bir masanın alanındaysa oraya gönder.</p>
          ${secenek.map(x => `<button class="mm-btn" style="margin-top:8px" data-m="${esc(x.kod)}">${esc(x.ad)}</button>`).join("")}
          <button class="mm-btn cizgi" style="margin-top:8px" id="mmKVaz">Vazgeç</button>`);
        $("#mmKVaz", md).onclick = modalKapat;
        md.querySelectorAll("[data-m]").forEach(x => x.onclick = async () => {
          try { await API.rpc("mod_kutu_devret", { p_id: d.id, p_masa: x.dataset.m, p_not: null }); modalKapat(); toast("Talep devredildi."); mmKutu(); } catch (err) { hata(err); }
        });
      };
    });
  }

  async function mmKursu() {
    yukleniyor("Kürsü şikâyetleri");
    let l; try { l = await API.rpc("admin_akis_sikayetleri"); } catch (err) { hataSayfa("Kürsü şikâyetleri", err); return; }
    let kl = []; try { kl = (await API.rpc("mod_kursu_kaldirilanlar")) || []; } catch (_) { /* eski sunucu: liste gösterilmez */ }
    const sus = yv("sustur");
    sayfa("Kürsü şikâyetleri", `<div class="mm-uyari sari">${IK.sikayet}<div>Oyuncuların şikâyet ettiği Kürsü paylaşımları. Bölücü, hakaret ve spam içeriği gizle; gerekiyorsa sustur ya da oyuncu dosyasından engelle. Şikâyet edilmemiş bir paylaşımı kaldırmak için Kürsü'de paylaşımın ⋯ menüsünden “Paylaşımı kaldır”ı seç.</div></div>
      ${(l || []).map((x, i) => `<div class="mm-kart" style="--c:#e5574f" data-i="${i}">
        <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px">${esc(x.kad)}</b><span class="mm-etiket" style="--c:#e5574f">${x.sayi} şikâyet</span></div>
        <div class="mm-alt">${(x.nedenler || []).map(n => NEDEN[n] || n).join(", ")} · ${once(x.ilk)}${x.gizli ? " · gizlendi" : ""}${x.devir ? " · tarafsız karar bekliyor" : ""}</div>
        <div class="mm-baloncuk">${esc(x.metin)}</div>
        <div class="mm-aksiyon">${x.kilit ? (x.devir ? "" : `<button class="y" data-k="yok_say">Tarafsız moderatöre devret</button>`) : `<button class="y" data-k="yok_say">Sorun yok</button>`}<button data-k="gizle">Gizle</button>
          ${sus ? `<button data-k="gizle_sustur1">Gizle + 1 gün sustur</button>` : ""}<button data-dosya="${esc(x.kad)}">Dosya</button></div></div>`).join("") || bos("Açık Kürsü şikâyeti yok", "Oyuncular bir paylaşımı şikâyet ettiğinde burada görünür.")}
      ${kl.length ? `<div class="mm-baslik" style="margin-top:18px"><h3>Kaldırılan paylaşımlar</h3><span class="kucuk">son 14 gün · ${kl.length}</span></div>` + kl.map((x, i) => `<div class="mm-kart" style="--c:#6b7385" data-kl="${i}">
        <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px">${esc(x.kad)}</b><span class="mm-etiket" style="--c:#6b7385">Kaldırıldı</span></div>
        <div class="mm-alt">${once(x.zaman)}${x.sikayet ? " · " + x.sikayet + " şikâyet" : ""}</div>
        <div class="mm-baloncuk">${esc(x.metin)}</div>
        <div class="mm-aksiyon"><button class="y" data-geri="${x.id}">Geri yükle</button><button data-dosya="${esc(x.kad)}">Dosya</button></div></div>`).join("") : ""}`);
    document.querySelectorAll(".mm-kart[data-kl]").forEach(k => {
      k.querySelectorAll("[data-dosya]").forEach(b => b.onclick = () => mmDosyaAc(b.dataset.dosya));
      k.querySelectorAll("[data-geri]").forEach(b => b.onclick = async () => {
        try { await API.rpc("admin_akis_karar", { p_id: Number(b.dataset.geri), p_islem: "yok_say" }); toast("Paylaşım geri yüklendi."); mmKursu(); } catch (err) { hata(err); }
      });
    });
    document.querySelectorAll(".mm-kart[data-i]").forEach(k => {
      const x = l[+k.dataset.i];
      k.querySelectorAll("[data-dosya]").forEach(b => b.onclick = () => mmDosyaAc(b.dataset.dosya));
      k.querySelectorAll("[data-k]").forEach(b => b.onclick = async () => {
        try { await API.rpc("admin_akis_karar", { p_id: x.id, p_islem: b.dataset.k }); toast("Karar uygulandı."); mmKursu(); } catch (err) { hata(err); }
      });
    });
  }

  // 23.11.2026 · TV yayınını kes / kanalı kapat (sql/zz_20261123_mod_tv_kapat.sql)
  async function mmTv(veri) {
    let d = veri;
    if (!d) { yukleniyor("TV yayınları"); try { d = await API.rpc("mod_tv_liste"); } catch (err) { hataSayfa("TV yayınları", err); return; } }
    const pr = d.programlar || [], kn = d.kanallar || [], kp = d.kapali || [];
    const progKart = (x, i) => `<div class="mm-kart" style="--c:${x.durum === "canli" ? "#e5574f" : "#5b8def"}">
        <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px;overflow-wrap:anywhere">${esc(x.baslik)}</b><span class="mm-etiket" style="--c:${x.durum === "canli" ? "#e5574f" : "#5b8def"}">${x.durum === "canli" ? "Canlı" : "Planlı"}</span></div>
        <div class="mm-alt">${esc(x.kanal)} · sunucu ${esc(x.sunucu || "—")} · sahip ${esc(x.sahip || "—")}${x.durum === "canli" ? " · " + sayi(x.izleyici) + " izleyici" : " · " + tsaat(x.bas)}</div>
        <div class="mm-aksiyon"><button data-kes="${i}">${x.durum === "canli" ? "Yayını kes" : "Programı iptal et"}</button><button data-kkapat="${x.kanal_id}">Kanalı kapat</button>${x.sunucu ? `<button class="y" data-dosya="${esc(x.sunucu)}">Sunucu dosyası</button>` : ""}</div></div>`;
    const kanalSatir = x => `<div class="mm-kart" style="--c:#98a4c4">
        <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px;overflow-wrap:anywhere">${esc(x.ad)}</b>${x.canli ? `<span class="mm-etiket" style="--c:#e5574f">${x.canli} canlı</span>` : ""}</div>
        <div class="mm-alt">Sahibi ${esc(x.sahip || "—")}${x.slogan ? " · " + esc(x.slogan) : ""}${x.planli ? " · " + x.planli + " planlı program" : ""}</div>
        <div class="mm-aksiyon"><button data-kkapat="${x.id}">Kanalı kapat</button>${x.sahip ? `<button class="y" data-dosya="${esc(x.sahip)}">Sahip dosyası</button>` : ""}</div></div>`;
    const kapaliSatir = x => `<div class="mm-kart" style="--c:#6b7385">
        <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px;overflow-wrap:anywhere">${esc(x.ad)}</b><span class="mm-etiket" style="--c:#6b7385">Kapalı</span></div>
        <div class="mm-alt">Sahibi ${esc(x.sahip || "—")} · ${tsaat(x.zaman)} · ${esc(x.kapatan || "")}</div>
        ${x.gerekce ? `<div class="mm-alt" style="white-space:pre-wrap">${esc(x.gerekce)}</div>` : ""}
        <div class="mm-aksiyon"><button class="y" data-kac="${x.id}">Yeniden aç</button></div></div>`;
    sayfa("TV yayınları", `<div class="mm-uyari sari">${IK.tv}<div>Uygunsuz başlıklı ya da içerikli yayını tek dokunuşla kes; kanal ısrarla kural dışıysa kanalı kapat. Gerekçe kanal sahibine ve sunucuya imzanla gider, işlem denetim günlüğüne yazılır.</div></div>
      <div class="mm-alt" style="margin:14px 0 6px;font-weight:700">Canlı ve planlı programlar (${pr.length})</div>
      ${pr.map(progKart).join("") || bos("Şu an canlı ya da planlı yayın yok", "")}
      <div class="mm-alt" style="margin:18px 0 6px;font-weight:700">Açık kanallar (${kn.length})</div>
      ${kn.map(kanalSatir).join("") || bos("Açık kanal yok", "")}
      ${kp.length ? `<div class="mm-alt" style="margin:18px 0 6px;font-weight:700">Yönetimin kapattığı kanallar (${kp.length})</div>${kp.map(kapaliSatir).join("")}` : ""}`);
    document.querySelectorAll("[data-dosya]").forEach(b => b.onclick = () => mmDosyaAc(b.dataset.dosya));
    const gerekceSor = (baslik, aciklama, dugme, ekstra, gonder) => {
      const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">${esc(baslik)}</h3><p class="mm-alt" style="margin:4px 0 8px">${esc(aciklama)}</p>
        <label class="mm-alan" for="mmTvG">Gerekçe (kanal sahibi ve sunucu görür)</label><textarea class="mm-girdi" id="mmTvG" maxlength="300" placeholder="Örn. Hakaret ve kışkırtıcı içerikli yayın başlığı."></textarea>
        ${ekstra || ""}
        <button class="mm-btn kirmizi" style="margin-top:10px" id="mmTvOk">${esc(dugme)}</button><button class="mm-btn cizgi" style="margin-top:8px" id="mmTvVaz">Vazgeç</button>`);
      $("#mmTvVaz", md).onclick = modalKapat;
      $("#mmTvOk", md).onclick = async () => {
        const g = $("#mmTvG", md).value.trim();
        if (g.length < 5) { toast("Gerekçe en az 5 karakter olmalı.", true); return; }
        const btn = $("#mmTvOk", md); btn.disabled = true;
        try { const yeni = await gonder(g, md); modalKapat(); mmTv(yeni); } catch (err) { btn.disabled = false; hata(err); }
      };
    };
    document.querySelectorAll("[data-kes]").forEach(b => b.onclick = () => {
      const x = pr[+b.dataset.kes];
      gerekceSor(x.durum === "canli" ? "Yayını kes" : "Programı iptal et", `${x.kanal} · “${x.baslik}”`, x.durum === "canli" ? "Yayını kes" : "İptal et",
        `<label style="display:flex;gap:10px;align-items:center;margin-top:10px;font-size:15px"><input type="checkbox" id="mmTvBg" checked style="width:22px;height:22px"> Başlığı da kaldır (arşivde “Yayın yönetim kararıyla kesildi” görünür)</label>`,
        async (g, md) => { const r = await API.rpc("mod_tv_yayin_kes", { p_program: x.id, p_gerekce: g, p_baslik_gizle: $("#mmTvBg", md).checked }); toast("Yayın kesildi."); return r; });
    });
    document.querySelectorAll("[data-kkapat]").forEach(b => b.onclick = () => {
      const id = +b.dataset.kkapat, k = kn.find(z => z.id === id) || {};
      gerekceSor("Kanalı kapat", `${k.ad || "Kanal"} kapanır; canlı ve planlı bütün programları kesilir, yeni yayın açılamaz. Kasası ve geçmişi silinmez; gerekirse buradan yeniden açabilirsin.`, "Kanalı kapat", "",
        async g => { const r = await API.rpc("mod_tv_kanal_kapat", { p_kanal: id, p_gerekce: g }); toast("Kanal kapatıldı."); return r; });
    });
    document.querySelectorAll("[data-kac]").forEach(b => b.onclick = async () => {
      b.disabled = true;
      try { const r = await API.rpc("mod_tv_kanal_ac", { p_kanal: +b.dataset.kac }); toast("Kanal yeniden açıldı."); mmTv(r); } catch (err) { b.disabled = false; hata(err); }
    });
  }

  // 23.11.2026 · Medya ve yayın denetimi (sql/zz_20261123_medya_denetimi.sql + kurum denetimi çekirdeği)
  const MD_TUR = [["", "Tümü"], ["gazete_yazi", "Gazete yazısı"], ["kose_yorum", "Gazete yorumu"], ["dergi_sayi", "Karikatür"], ["kitap", "Kitap"],
    ["pano", "Pano reklamı"], ["tv_yorum", "TV yorumu"], ["dernek_eylem", "Dernek"], ["sendika_bildiri", "Sendika"], ["parti_aciklama", "Parti açıklaması"]];
  const MD_TUR_AD = Object.fromEntries(MD_TUR.filter(x => x[0]));
  const MD_KURUM = [["gazete", "Gazete"], ["dergi", "Karikatür dergisi"], ["tv", "TV kanalı"], ["sirket", "Yayınevi / şirket"], ["kitap", "Kitap adıyla ara"],
    ["dernek", "Dernek"], ["sendika", "Sendika"], ["parti", "Parti"]];
  const MD = { sekme: "akis", tur: "", ara: "", ktur: "gazete", kara: "" };
  const mdGerekce = (baslik, aciklama, dugme, enAz, ekstra, gonder) => {
    const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">${esc(baslik)}</h3><p class="mm-alt" style="margin:4px 0 8px;white-space:pre-wrap">${esc(aciklama)}</p>
      ${ekstra || ""}
      <label class="mm-alan" for="mdG">Gerekçe (ilgili oyuncu görür)</label><textarea class="mm-girdi" id="mdG" maxlength="500" placeholder="Örn. Bölücü ve hakaret içeren yayın."></textarea>
      <button class="mm-btn kirmizi" style="margin-top:10px" id="mdOk">${esc(dugme)}</button><button class="mm-btn cizgi" style="margin-top:8px" id="mdVaz">Vazgeç</button>`);
    $("#mdVaz", md).onclick = modalKapat;
    $("#mdOk", md).onclick = async () => {
      const g = $("#mdG", md).value.trim();
      if (g.length < enAz) { toast(`Gerekçe en az ${enAz} karakter olmalı.`, true); return; }
      const btn = $("#mdOk", md); btn.disabled = true;
      try { await gonder(g, md); modalKapat(); } catch (err) { btn.disabled = false; hata(err); }
    };
  };
  const mdIcerikKart = (x, i, ozel) => `<div class="mm-kart" style="--c:${x.kaldirildi ? "#6b7385" : "#5b8def"}">
      <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px;overflow-wrap:anywhere">${esc(x.baslik || "")}</b><span class="mm-etiket" style="--c:${x.kaldirildi ? "#6b7385" : "#5b8def"}">${esc(x.kaldirildi ? "Kaldırıldı" : (MD_TUR_AD[x.tur] || x.etiket || ""))}</span></div>
      <div class="mm-alt">${[x.kurum, x.yazar ? "yazan " + x.yazar : "", x.etiket && MD_TUR_AD[x.tur] ? ({ kose: "köşe yazısı", haber: "haber", propaganda: "propaganda", teklif: "yayınevi onayı bekliyor", yayinda: "satışta" }[x.etiket] || x.etiket) : "", x.zaman ? tsaat(x.zaman) : ""].filter(Boolean).map(esc).join(" · ")}</div>
      ${x.metin ? `<div class="mm-baloncuk" style="white-space:pre-wrap;max-height:180px;overflow:auto">${esc(x.metin)}</div>` : ""}
      <div class="mm-aksiyon">${!x.kaldirildi && !x.salt_okunur ? `<button data-mdk="${ozel || ""}${i}">Yayından kaldır</button>` : ""}${x.kurum_tur && x.kurum_id ? `<button class="y" data-mdkd="${x.kurum_tur}:${x.kurum_id}">Kurum dosyası</button>` : ""}${x.yazar ? `<button class="y" data-dosya="${esc(x.yazar)}">Oyuncu dosyası</button>` : ""}</div></div>`;
  function mdKaldirBagla(liste, ozel, sonra) {
    document.querySelectorAll(`[data-mdk^="${ozel || ""}"]`).forEach(b => {
      const kod = b.dataset.mdk; if (ozel && !kod.startsWith(ozel)) return; if (!ozel && /\D/.test(kod)) return;
      const x = liste[+kod.slice((ozel || "").length)]; if (!x) return;
      b.onclick = () => mdGerekce("Yayından kaldır", `${MD_TUR_AD[x.tur] || "İçerik"} · “${x.baslik}”${x.kurum ? "\n" + x.kurum : ""}\nİçerik arşive alınır, gerekirse geri yüklenir. Yazan oyuncu ve kurum sorumlusu bildirim alır.`,
        "Kaldır", 10, "", async g => { await API.rpc("mod_medya_kaldir", { p_tur: x.tur, p_id: x.id, p_gerekce: g }); toast("İçerik yayından kaldırıldı."); sonra(); });
    });
  }
  function mdOrtakBagla() {
    document.querySelectorAll("[data-dosya]").forEach(b => b.onclick = () => mmDosyaAc(b.dataset.dosya));
    document.querySelectorAll("[data-mdkd]").forEach(b => b.onclick = () => { const [t, id] = b.dataset.mdkd.split(":"); mdKurumDosya(t, +id); });
  }
  async function mmMedya() {
    const sekmeler = [["akis", "Son yayınlar"], ["durdurma", "Yayın durdurma"], ["kurum", "Kurum ara"], ["arsiv", "Kaldırılanlar"]];
    yukleniyor("Medya denetimi");
    let d;
    try {
      if (MD.sekme === "akis") d = await API.rpc("mod_medya_akis", { p_tur: MD.tur || null, p_ara: MD.ara || null });
      else if (MD.sekme === "kurum") d = MD.kara || MD.ktur ? await API.rpc("mod_kurum_ara", { p_tur: MD.ktur, p_ara: MD.kara || null }) : [];
      else d = await API.rpc("mod_kurum_durdurmalar");
    } catch (err) { hataSayfa("Medya denetimi", err); return; }
    let govde = "";
    if (MD.sekme === "akis") {
      const l = (d && d.liste) || [];
      govde = `<div class="mm-cipler" id="mdTur" style="margin-bottom:10px">${MD_TUR.map(([k, a]) => `<button class="mm-cip${MD.tur === k ? " on" : ""}" data-v="${k}" style="cursor:pointer${MD.tur === k ? ";background:var(--ink);color:#fff" : ""}">${esc(a)}</button>`).join("")}</div>
        <label class="mm-alan" for="mdAra">Ara (başlık, metin, kurum adı)</label><input class="mm-girdi" id="mdAra" value="${esc(MD.ara)}" placeholder="Örn. bir kelime ya da gazete adı" enterkeyhint="search">
        <button class="mm-btn" id="mdAraB" style="margin:8px 0 12px">Ara</button>
        <div class="mm-alt" style="margin:0 0 6px;font-weight:700">Son 14 gün · ${l.length} kayıt</div>
        ${l.map((x, i) => mdIcerikKart(x, i)).join("") || bos("Bu filtrede yayın yok", "")}`;
      sayfa("Medya denetimi", mdUst(sekmeler) + govde);
      cipSec($("#mdTur"), v => { MD.tur = v; mmMedya(); });
      $("#mdAraB").onclick = () => { MD.ara = $("#mdAra").value.trim(); mmMedya(); };
      $("#mdAra").onkeydown = e => { if (e.key === "Enter") $("#mdAraB").click(); };
      mdKaldirBagla(l, "", mmMedya);
    } else if (MD.sekme === "kurum") {
      const l = d || [];
      govde = `<label class="mm-alan" for="mdKt">Kurum türü</label><select class="mm-girdi" id="mdKt">${MD_KURUM.map(([k, a]) => `<option value="${k}"${MD.ktur === k ? " selected" : ""}>${esc(a)}</option>`).join("")}</select>
        <label class="mm-alan" for="mdKa" style="margin-top:8px">Ad</label><input class="mm-girdi" id="mdKa" value="${esc(MD.kara)}" placeholder="Boş bırakırsan son kurumlar listelenir">
        <button class="mm-btn" id="mdKaB" style="margin:8px 0 12px">Ara</button>
        ${l.map(x => `<div class="mm-kart" style="--c:${x.durdurma ? "#e0a43a" : x.aktif ? "#98a4c4" : "#6b7385"}">
          <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px;overflow-wrap:anywhere">${esc(x.ad)}</b>${x.durdurma ? `<span class="mm-etiket" style="--c:#e0a43a">Durduruldu</span>` : !x.aktif ? `<span class="mm-etiket" style="--c:#6b7385">Kapalı</span>` : ""}</div>
          <div class="mm-alt">${[x.sahip ? "sorumlu " + x.sahip : "", x.alt || ""].filter(Boolean).map(esc).join(" · ")}${x.durdurma ? " · " + tsaat(x.durdurma) + " tarihine kadar" : ""}</div>
          <div class="mm-aksiyon"><button data-mdkd="${x.tur}:${x.id}">Kurum dosyası</button></div></div>`).join("") || bos("Sonuç yok", "")}`;
      sayfa("Medya denetimi", mdUst(sekmeler) + govde);
      $("#mdKaB").onclick = () => { MD.ktur = $("#mdKt").value; MD.kara = $("#mdKa").value.trim(); mmMedya(); };
      $("#mdKt").onchange = () => { MD.ktur = $("#mdKt").value; mmMedya(); };
    } else if (MD.sekme === "durdurma") {
      const ak = d.aktif || [], bk = d.bekleyen || [];
      govde = `<div class="mm-uyari sari">${IK.kilit}<div>${(d.kurallar || []).map(esc).join("<br>")}</div></div>
        <div class="mm-alt" style="margin:14px 0 6px;font-weight:700">İkinci imza bekleyenler (${bk.length})</div>
        ${bk.map(x => mdDurdurmaKart(x, true)).join("") || bos("Bekleyen talep yok", "")}
        <div class="mm-alt" style="margin:18px 0 6px;font-weight:700">Yürürlükteki durdurmalar (${ak.length})</div>
        ${ak.map(x => mdDurdurmaKart(x, false)).join("") || bos("Yürürlükte durdurma yok", "Bir kurumu durdurmak için Kurum ara › Kurum dosyası.")}
        <div class="mm-alt" style="margin:18px 0 6px;font-weight:700">Süre ve yetkiler</div>
        ${(d.turler || []).map(x => `<div class="mm-kart" style="--c:${x.yetkim ? "#3fb67a" : "#6b7385"}"><b>${esc(x.ad)}</b><div class="mm-alt">Tek imza: ${esc(x.tek)} · İki imza: ${esc(x.cift)}${x.yetkim ? "" : " · senin masanın yetkisinde değil"}</div><div class="mm-alt">${esc(x.etki)}</div></div>`).join("")}`;
      sayfa("Medya denetimi", mdUst(sekmeler) + govde);
      mdDurdurmaBagla(mmMedya);
    } else {
      const l = d.kaldirilan || [];
      govde = `<div class="mm-alt" style="margin:0 0 8px">Yönetimin kaldırdığı son içerikler ve değiştirilen kurum adları. Yanlış karar geri yüklenebilir; kendi kaldırdığın içerik dışında kurum sorumlusu olduğun ya da partinden bir içeriği geri yükleyemezsin.</div>
        ${l.map(x => `<div class="mm-kart" style="--c:${x.geri_zaman ? "#3fb67a" : "#6b7385"}">
          <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px;overflow-wrap:anywhere">${esc(x.baslik || "")}</b><span class="mm-etiket" style="--c:${x.geri_zaman ? "#3fb67a" : "#6b7385"}">${x.geri_zaman ? "Geri yüklendi" : esc(x.tur_ad)}</span></div>
          <div class="mm-alt">${[x.sahip ? "sahibi " + x.sahip : "", "kaldıran " + (x.kaldiran || "—"), tsaat(x.zaman)].filter(Boolean).map(esc).join(" · ")}</div>
          <div class="mm-alt" style="white-space:pre-wrap">${esc(x.gerekce || "")}</div>
          <div class="mm-aksiyon">${!x.geri_zaman ? `<button class="y" data-mdg="${x.id}">Geri yükle</button>` : ""}${x.kurum_tur && x.kurum_id ? `<button class="y" data-mdkd="${x.kurum_tur}:${x.kurum_id}">Kurum dosyası</button>` : ""}</div></div>`).join("") || bos("Kaldırılan içerik yok", "")}`;
      sayfa("Medya denetimi", mdUst(sekmeler) + govde);
      mdGeriBagla(mmMedya);
    }
    document.querySelectorAll(".mm-sekme [data-s]").forEach(b => b.onclick = () => { MD.sekme = b.dataset.s; mmMedya(); });
    mdOrtakBagla();
  }
  function mdUst(sekmeler) {
    return `<div class="mm-uyari sari">${IK.gazete}<div>Gazete, karikatür, kitap, pano, TV yorumu, dernek, sendika ve parti açıklamaları tek yerde. Kural dışı içeriği kaldır; kurum ısrar ediyorsa yayınlarını süreli durdur. Her işlemde gerekçe zorunlu, imzanla bildirilir ve denetim günlüğüne yazılır. Canlı TV yayını için: TV yayınları ekranı.</div></div>
      <div class="mm-sekme">${sekmeler.map(s => `<button class="${MD.sekme === s[0] ? "on" : ""}" data-s="${s[0]}">${s[1]}</button>`).join("")}</div>`;
  }
  const mdDurdurmaKart = (x, bekleyen) => `<div class="mm-kart" style="--c:${bekleyen ? "#5b8def" : "#e0a43a"}">
      <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:16px;overflow-wrap:anywhere">${esc(x.kurum)} · ${esc(x.tur_ad)}</b><span class="mm-etiket" style="--c:${bekleyen ? "#5b8def" : "#e0a43a"}">${bekleyen ? "İmza bekliyor" : "Durduruldu"}</span></div>
      <div class="mm-alt">${x.bitis && !bekleyen ? esc(tsaat(x.bitis)) + " tarihine kadar · " : ""}${x.istenen ? "istenen " + esc(x.istenen) + " · " : ""}veren ${esc(x.veren || "—")}${x.onaylayan ? " · onaylayan " + esc(x.onaylayan) : ""}</div>
      <div class="mm-alt" style="white-space:pre-wrap">${esc(x.gerekce || "")}${x.kanit ? "\nKanıt: " + esc(x.kanit) : ""}</div>
      <div class="mm-aksiyon">${bekleyen && !x.benim ? `<button data-mdo="${x.id}">İkinci imzayı at</button><button class="y" data-mdr="${x.id}">Reddet</button>` : ""}${!bekleyen || x.benim ? `<button class="y" data-mdx="${x.id}" data-aktif="${x.aktif ? 1 : 0}">${x.aktif ? "Durdurmayı kaldır" : "Talebi geri çek"}</button>` : ""}<button class="y" data-mdkd="${x.tur}:${x.kurum_id}">Kurum dosyası</button></div></div>`;
  function mdDurdurmaBagla(sonra) {
    document.querySelectorAll("[data-mdo]").forEach(b => b.onclick = async () => {
      if (!await onayla("İkinci imza", "Durdurma talebini onaylıyorsun; istenen süre yürürlüğe girer ve kurum sorumlularına bildirilir.", "Onayla", true)) return;
      try { await API.rpc("mod_kurum_durdurma_karar", { p_id: +b.dataset.mdo, p_onay: true, p_not: null }); toast("Onaylandı."); sonra(); } catch (err) { hata(err); }
    });
    document.querySelectorAll("[data-mdr]").forEach(b => b.onclick = () => mdGerekce("Talebi reddet", "İkinci imza verilmez. Tek imzalı süre varsa aynen sürer.", "Reddet", 5, "",
      async g => { await API.rpc("mod_kurum_durdurma_karar", { p_id: +b.dataset.mdr, p_onay: false, p_not: g }); toast("Reddedildi."); sonra(); }));
    document.querySelectorAll("[data-mdx]").forEach(b => b.onclick = () => mdGerekce(b.dataset.aktif === "1" ? "Durdurmayı kaldır" : "Talebi geri çek",
      "Kurum yeniden yayın ve faaliyet yapabilir. Kurucunun koyduğu durdurmayı yalnız kurucu kaldırır.", "Kaldır", 5, "",
      async g => { await API.rpc("mod_kurum_durdurma_kaldir", { p_id: +b.dataset.mdx, p_not: g }); toast("Kaldırıldı."); sonra(); }));
  }
  function mdGeriBagla(sonra) {
    document.querySelectorAll("[data-mdg]").forEach(b => b.onclick = () => mdGerekce("Geri yükle", "İçerik yeniden yayına girer; sahibi ve kaldıran görevli bildirim alır.", "Geri yükle", 5, "",
      async g => { await API.rpc("mod_medya_geri_yukle", { p_arsiv: +b.dataset.mdg, p_not: g }); toast("Geri yüklendi."); sonra(); }));
  }
  async function mdKurumDosya(tur, id) {
    yukleniyor("Kurum dosyası");
    let d, kp = null; try { d = await API.rpc("mod_kurum_dosya", { p_tur: tur, p_id: id }); } catch (err) { hataSayfa("Kurum dosyası", err); return; }
    const kapanir = tur === "gazete" || tur === "dergi";
    if (kapanir && !d.aktif && d.yetki && d.yetki.icerik) { try { kp = await API.rpc("mod_kurum_kapatma_bilgi", { p_tur: tur, p_id: id }); } catch (err) { kp = null; } }
    const y = d.yetki || {}, ic = d.icerikler || [], pn = d.panolar || [], ar = d.arsiv || [];
    const tekrar = () => mdKurumDosya(tur, id);
    const icerik = ic.map(x => Object.assign({}, x, { kurum: "", kaldirildi: !!x.kaldirildi || ar.some(a => a.tur === x.tur && a.kayit_id === x.id && !a.geri_zaman) }));
    sayfa("Kurum dosyası", `<section class="mm-kart" style="--c:${d.durdurma ? "#e0a43a" : d.aktif ? "#5b8def" : "#6b7385"}">
        <div style="display:flex;gap:8px;align-items:center;justify-content:space-between"><b style="font-size:19px;overflow-wrap:anywhere">${esc(d.ad)}</b><span class="mm-etiket" style="--c:#98a4c4">${esc(d.tur_ad)}</span></div>
        ${d.slogan ? `<div class="mm-alt">${esc(d.slogan)}</div>` : ""}
        <div class="mm-alt">Sorumlu: ${esc((d.sorumlular || []).join(", ") || "—")}${d.aktif ? "" : " · kurum kapalı"}</div>
        ${d.durdurma ? `<div class="mm-uyari sari" style="margin-top:8px">${IK.kilit}<div><b>Yayınlar ${esc(tsaat(d.durdurma.bitis))} tarihine kadar durduruldu.</b><br>${esc(d.durdurma.gerekce || "")}<br>${esc(d.etki || "")}</div></div>` : ""}
        ${kp ? `<div class="mm-uyari sari" style="margin-top:8px">${IK.kilit}<div><b>Yönetim kararıyla kapatıldı</b> · ${esc(tsaat(kp.zaman))} · ${esc(kp.kapatan || "")}<br>${esc(kp.gerekce || "")}</div></div>` : ""}
        ${d.bekleyen ? `<div class="mm-alt" style="margin-top:6px">İkinci imza bekleyen talep var (${esc(d.bekleyen.istenen || "")}, ${esc(d.bekleyen.veren || "")}).</div>` : ""}
        <div class="mm-aksiyon" style="margin-top:8px">${y.durdur && d.aktif && !d.durdurma && !d.bekleyen ? `<button id="mdDur">Yayınları durdur</button>` : ""}${y.icerik && kapanir && d.aktif ? `<button id="mdKapat">Kurumu kapat</button>` : ""}${kp ? `<button class="y" id="mdAc">Yeniden aç</button>` : ""}${y.icerik ? `<button class="y" id="mdAd">Adını düzelt</button>` : ""}${(d.sorumlular || [])[0] ? `<button class="y" data-dosya="${esc(d.sorumlular[0])}">Sorumlu dosyası</button>` : ""}</div>
        ${y.tek_engel ? `<div class="mm-alt" style="margin-top:6px">${esc(y.tek_engel)}</div>` : ""}</section>
      <div class="mm-alt" style="margin:14px 0 6px;font-weight:700">Son içerikler (${icerik.length})</div>
      ${icerik.map((x, i) => mdIcerikKart(x, i, "k")).join("") || bos("İçerik yok", "")}
      ${pn.length ? `<div class="mm-alt" style="margin:18px 0 6px;font-weight:700">Yayındaki pano reklamları (${pn.length})</div>${pn.map((x, i) => `<div class="mm-kart" style="--c:#5b8def"><b>${esc(x.ad)}</b><div class="mm-alt">${x.kapsam === "ulke" ? "Ülke geneli" : "İl"} · ${esc(tsaat(x.bit))} tarihine kadar</div><div class="mm-aksiyon"><button data-mdp="${i}">Panodan kaldır</button></div></div>`).join("")}` : ""}
      ${ar.length ? `<div class="mm-alt" style="margin:18px 0 6px;font-weight:700">Bu kurumdan kaldırılanlar (${ar.length})</div>${ar.map(x => `<div class="mm-kart" style="--c:#6b7385"><b>${esc(x.baslik || "")}</b><div class="mm-alt">${esc(x.tur_ad)} · ${esc(x.kaldiran || "")} · ${esc(tsaat(x.zaman))}</div><div class="mm-alt" style="white-space:pre-wrap">${esc(x.gerekce || "")}</div>${!x.geri_zaman ? `<div class="mm-aksiyon"><button class="y" data-mdg="${x.id}">Geri yükle</button></div>` : `<div class="mm-alt">Geri yüklendi</div>`}</div>`).join("")}` : ""}`);
    mdOrtakBagla();
    mdKaldirBagla(icerik, "k", tekrar);
    mdGeriBagla(tekrar);
    document.querySelectorAll("[data-mdp]").forEach(b => b.onclick = () => { const x = pn[+b.dataset.mdp];
      mdGerekce("Panodan kaldır", `“${x.ad}” reklamı panodan iner. Ödeme iade edilmez.`, "Kaldır", 10, "",
        async g => { await API.rpc("mod_medya_kaldir", { p_tur: "pano", p_id: x.id, p_gerekce: g }); toast("Reklam kaldırıldı."); tekrar(); }); });
    const dr = $("#mdDur"); if (dr) dr.onclick = () => {
      const ust = Math.max(1, +y.cift_saat || 720), tek = +y.tek_saat || 0;
      const secenek = [[6, "6 saat"], [24, "1 gün"], [72, "3 gün"], [168, "7 gün"], [336, "14 gün"], [720, "30 gün"], [8760, "1 yıl"]].filter(s => s[0] <= ust);
      mdGerekce("Yayınları durdur", `${d.ad} (${d.tur_ad}) süre boyunca: ${d.etki}\nKurum kapanmaz, kasası ve üyeleri etkilenmez; süre bitince kendiliğinden açılır.\nTek imza: ${y.tek || "yok"} · İki imza: ${y.cift || ""}`, "Durdur", 10,
        `<label class="mm-alan" for="mdSure">Süre</label><select class="mm-girdi" id="mdSure">${secenek.map(([s, a]) => `<option value="${s}"${s === Math.min(24, ust) ? " selected" : ""}>${a}${tek && s > tek ? " (ikinci imza gerekir)" : ""}</option>`).join("")}</select>
         <label class="mm-alan" for="mdKanit" style="margin-top:8px">Kanıt (ikinci imza gerekiyorsa zorunlu: hangi yayın, hangi tarih, hangi ifade)</label><textarea class="mm-girdi" id="mdKanit" maxlength="600"></textarea>`,
        async (g, md) => {
          const r = await API.rpc("mod_kurum_durdur", { p_tur: tur, p_id: id, p_saat: +$("#mdSure", md).value, p_gerekce: g, p_kanit: $("#mdKanit", md).value.trim() || null });
          toast(r && r.durum === "bekliyor" ? "Talep açıldı; ikinci imza bekliyor." : r && r.ikinci_imza ? "Durduruldu; uzatma için ikinci imza bekliyor." : "Kurumun yayınları durduruldu.");
          tekrar();
        });
    };
    const kb = $("#mdKapat"); if (kb) kb.onclick = () => mdGerekce("Kurumu kapat", `${d.ad} (${d.tur_ad}) kapanır: listelerden düşer, yeni yayın yapamaz. Kasası ve geçmişi silinmez; sahibi 7 gün yenisini kuramaz. Yanlış karar buradan geri alınabilir.\nGeçici önlem yetiyorsa “Yayınları durdur”u kullan.`, "Kurumu kapat", 10, "",
      async g => { await API.rpc("mod_kurum_kapat", { p_tur: tur, p_id: id, p_gerekce: g }); toast("Kurum kapatıldı."); tekrar(); });
    const ac = $("#mdAc"); if (ac) ac.onclick = async () => {
      if (!await onayla("Yeniden aç", `${d.ad} yeniden açılır ve sahibine bildirilir.`, "Yeniden aç", false)) return;
      try { await API.rpc("mod_kurum_ac", { p_tur: tur, p_id: id }); toast("Kurum yeniden açıldı."); tekrar(); } catch (err) { hata(err); }
    };
    const ad = $("#mdAd"); if (ad) ad.onclick = () => mdGerekce("Adını düzelt", `Kurala aykırı kurum adı “${d.ad}” değiştirilir. Yeni ad boş bırakılırsa “${d.tur_ad} No. ${id}” olur. Eski ad arşivde kalır.`, "Adı değiştir", 10,
      `<label class="mm-alan" for="mdYad">Yeni ad (isteğe bağlı, 4-40 karakter)</label><input class="mm-girdi" id="mdYad" maxlength="40">`,
      async (g, md) => { await API.rpc("mod_kurum_ad_duzelt", { p_tur: tur, p_id: id, p_gerekce: g, p_yeni_ad: $("#mdYad", md).value.trim() || null }); toast("Kurum adı değiştirildi."); tekrar(); });
  }

  const KISIT_RENK = { sustur: "#e0a43a", engel: "#e5574f", mali: "#3fb67a", secim: "#5b8def" };
  function kisitSatir(k, yon) {
    const elle = k.kod === "mali" || k.kod === "secim";
    const uzat = elle && (yon || (!k.benim && !k.kurucu));
    const kaldir = elle && (yon || (!k.kurucu && k.kaynak !== "masak"));
    return `<div class="mm-satir" style="cursor:default;align-items:flex-start"><div class="orta">
        <b style="font-weight:650"><span class="mm-etiket" style="--c:${KISIT_RENK[k.kod] || "#98a4c4"}">${esc(k.ad)}</span> ${esc(k.hedef || "")}</b>
        <div class="kucuk">${k.bitis ? tsaat(k.bitis) + "'e kadar" : "süresiz"} · ${esc(k.veren || "sistem")}${k.onaylayan ? " + " + esc(k.onaylayan) + " (iki imza)" : " (tek imza)"}${k.kurucu ? " · kurucu" : ""}${k.kaynak === "masak" ? " · MASAK el koyma önerisi" : ""}</div>
        ${k.gerekce ? `<div class="kucuk" style="white-space:pre-wrap">${esc(k.gerekce)}</div>` : ""}
        ${uzat || kaldir ? `<div class="mm-aksiyon" style="margin-top:6px">${uzat ? `<button data-kuzat="${k.id}" data-kod="${esc(k.kod)}">Uzat (ikinci imza)</button>` : ""}${kaldir ? `<button class="y" data-kkaldir="${k.id}">Kaldır</button>` : ""}</div>` : ""}
      </div></div>`;
  }
  function kisitBagla(yenile) {
    document.querySelectorAll("[data-kuzat]").forEach(b => b.onclick = () => {
      const SEC = b.dataset.kod === "mali" ? [[72, "3 gün"], [168, "7 gün"], [336, "14 gün"], [696, "29 gün"]] : [[168, "7 gün"], [336, "14 gün"], [696, "29 gün"]];
      let v = SEC[1][0];
      const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">Kısıtı uzat</h3><p class="mm-alt" style="margin:4px 0 8px">İkinci imza: süre şu andan itibaren sayılır; başlangıçtan itibaren toplam 30 günü geçemez.</p>
        <div class="mm-filtre" id="mmKU">${SEC.map(s => `<button data-v="${s[0]}" class="${s[0] === v ? "on" : ""}">${s[1]}</button>`).join("")}</div>
        <label class="mm-alan" for="mmKUN">Not (isteğe bağlı)</label><textarea class="mm-girdi" id="mmKUN" maxlength="300"></textarea>
        <button class="mm-btn kirmizi" style="margin-top:10px" id="mmKUOk">Uzat</button><button class="mm-btn cizgi" style="margin-top:8px" id="mmKUVaz">Vazgeç</button>`);
      cipSec($("#mmKU", md), x => v = +x);
      $("#mmKUVaz", md).onclick = modalKapat;
      $("#mmKUOk", md).onclick = async () => {
        try { await API.rpc("mod_kisit_uzat", { p_id: +b.dataset.kuzat, p_saat: v, p_not: $("#mmKUN", md).value || null }); modalKapat(); toast("Kısıt uzatıldı."); yenile(); } catch (err) { hata(err); }
      };
    });
    document.querySelectorAll("[data-kkaldir]").forEach(b => b.onclick = () => {
      const n = prompt("Kaldırma gerekçesi (kayda geçer):", ""); if (n === null) return;
      (async () => { try { await API.rpc("mod_kisit_kaldir", { p_id: +b.dataset.kkaldir, p_not: n }); toast("Kısıt kaldırıldı."); yenile(); } catch (err) { hata(err); } })();
    });
  }
  function kisitUygula(kad, kod, sinir, yon, sonra) {
    const mali = kod === "mali";
    const tek = yon ? 87600 : ((sinir || {}).tek_saat || 0);
    const SEC = (mali ? [[24, "24 saat"], [48, "2 gün"], [72, "3 gün"], [168, "7 gün"], [720, "30 gün"]] : [[24, "24 saat"], [72, "3 gün"], [168, "7 gün"], [720, "30 gün"]]).filter(s => s[0] <= tek);
    if (!SEC.length) { toast("Bu yaptırım senin masanın yetkisinde değil.", true); return; }
    let v = SEC[SEC.length - 1][0];
    const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">${mali ? "Para çıkışını dondur" : "Seçim kısıtı"} · ${esc(kad)}</h3>
      <p class="mm-alt" style="margin:4px 0 8px">${mali ? "Oyuncu cüzdanından, banka hesaplarından ve yönettiği işletme kasalarından para çıkışı yapamaz. Gelen para ve otomatik tahsilatlar sürer; oyunun geri kalanını oynar." : "Oyuncu oy kullanamaz ve aday olamaz; oyunun geri kalanını oynar. Sahte ve çoklu hesap şüphesinde kullan."}</p>
      <div class="mm-filtre" id="mmKS">${SEC.map(s => `<button data-v="${s[0]}" class="${s[0] === v ? "on" : ""}">${s[1]}</button>`).join("")}</div>
      ${yon ? "" : `<p class="mm-alt" style="margin:6px 0 0">Tek imza sınırın ${esc((sinir || {}).tek || "")}. Daha uzunu için başka bir görevli "Uzat" ile ikinci imzayı atar (toplam ${esc((sinir || {}).cift || "30 gün")}).</p>`}
      <label class="mm-alan" for="mmKG">Gerekçe (oyuncu görür)</label><textarea class="mm-girdi" id="mmKG" maxlength="500" placeholder="${mali ? "Örn. Banka üzerinden şüpheli para döngüsü inceleniyor." : "Örn. Aynı kişiye ait birden çok hesapla oy kullanma şüphesi."}"></textarea>
      <label class="mm-alan" for="mmKK">Kanıt${mali ? " (isteğe bağlı)" : ""}</label><textarea class="mm-girdi" id="mmKK" maxlength="600" placeholder="Hangi hesaplar, hangi işlem, hangi işaret?"></textarea>
      <button class="mm-btn kirmizi" style="margin-top:10px" id="mmKOk">Uygula</button><button class="mm-btn cizgi" style="margin-top:8px" id="mmKVz">Vazgeç</button>`);
    cipSec($("#mmKS", md), x => v = +x);
    $("#mmKVz", md).onclick = modalKapat;
    $("#mmKOk", md).onclick = async () => {
      const g = $("#mmKG", md).value.trim();
      if (g.length < 10) { toast("Gerekçe en az 10 karakter olmalı.", true); return; }
      try { await API.rpc("mod_kisit_uygula", { p_kad: kad, p_kod: kod, p_saat: v, p_gerekce: g, p_kanit: $("#mmKK", md).value.trim() || null }); modalKapat(); toast(mali ? "Para çıkışı donduruldu." : "Seçim kısıtı uygulandı."); sonra && sonra(); }
      catch (err) { hata(err); }
    };
  }
  function topluGizle(kad, sonra) {
    let v = 24;
    const md = sheet(`<h3 style="font-size:19px;font-weight:800;margin:0">Son içeriklerini gizle · ${esc(kad)}</h3>
      <p class="mm-alt" style="margin:4px 0 8px">Oyuncunun seçtiğin süre içindeki bütün sohbet mesajları, Kürsü paylaşımları ve yayınları tek işlemle gizlenir. Spam ve toplu saldırı için.</p>
      <div class="mm-filtre" id="mmTGS">${[[1, "Son 1 saat"], [6, "6 saat"], [24, "24 saat"], [72, "3 gün"]].map(s => `<button data-v="${s[0]}" class="${s[0] === v ? "on" : ""}">${s[1]}</button>`).join("")}</div>
      <label class="mm-alan" for="mmTGG">Gerekçe (oyuncu görür)</label><textarea class="mm-girdi" id="mmTGG" maxlength="300" placeholder="Örn. Tekrarlanan spam paylaşımlar."></textarea>
      <button class="mm-btn kirmizi" style="margin-top:10px" id="mmTGOk">Gizle</button><button class="mm-btn cizgi" style="margin-top:8px" id="mmTGVz">Vazgeç</button>`);
    cipSec($("#mmTGS", md), x => v = +x);
    $("#mmTGVz", md).onclick = modalKapat;
    $("#mmTGOk", md).onclick = async () => {
      const g = $("#mmTGG", md).value.trim();
      if (g.length < 10) { toast("Gerekçe en az 10 karakter olmalı.", true); return; }
      try { const r = await API.rpc("mod_icerik_toplu_gizle", { p_kad: kad, p_saat: v, p_gerekce: g }); modalKapat(); toast(`${r.mesaj} mesaj, ${r.kursu} Kürsü paylaşımı, ${r.yayin} yayın gizlendi.`); sonra && sonra(); }
      catch (err) { hata(err); }
    };
  }
  async function mmKisitlar() {
    yukleniyor("Kısıtlar ve yetkilerim");
    let k, y; try { [k, y] = await Promise.all([API.rpc("mod_kisitlar", { p_kad: null }), API.rpc("mod_yetki_tablosu")]); } catch (err) { hataSayfa("Kısıtlar ve yetkilerim", err); return; }
    const ben = y.ben || {}, elle = (k.aktif || []).filter(x => x.kod === "mali" || x.kod === "secim"), diger = (k.aktif || []).filter(x => x.kod !== "mali" && x.kod !== "secim");
    sayfa("Kısıtlar ve yetkilerim", `
      <div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Masaların yaptırım yetkisi</h3></div>
        ${(y.birimler || []).map(b => `<div style="margin:8px 0 12px"><b style="color:${esc(b.renk)}">${esc(b.ad)}${b.kod === ben.birim ? " · senin masan" : ""}</b>
          ${(b.yaptirimlar || []).map(z => `<div class="mm-kv"><span>${esc(z.ad)}</span><span>tek imza ${esc(z.tek)} · iki imza ${esc(z.cift)}</span></div>`).join("")}</div>`).join("")}
        <div class="mm-alt">${(y.kurallar || []).map(x => "• " + esc(x)).join("<br>")}</div></div>
      <div class="mm-kart"><div class="mm-baslik" style="margin-top:0"><h3>Yürürlükteki dondurma ve seçim kısıtları (${elle.length})</h3></div>
        ${elle.map(x => kisitSatir(x, !!ben.yonetici)).join("") || `<div class="mm-alt">Yürürlükte kısıt yok. Yenisini oyuncu dosyasından uygularsın.</div>`}</div>
      ${diger.length ? `<details class="mm-kart"><summary style="font-weight:800;cursor:pointer">Yürürlükteki susturma ve engeller (${diger.length})</summary>${diger.map(x => kisitSatir(x, !!ben.yonetici)).join("")}</details>` : ""}`);
    kisitBagla(() => mmKisitlar());
  }

  /* ---------- Giriş noktası: eski panelin yerine Moderasyon Merkezi ---------- */
  if (typeof yoneticiEkrani === "function" && !window.yoneticiEkraniKlasik) {
    window.yoneticiEkraniKlasik = yoneticiEkrani;
    window.yoneticiEkrani = yoneticiEkrani = modMerkezi;
  }
  Object.assign(window, { modMerkezi, mmDosyaAc, mmKayit, mmSikayet, mmNobet, mmDestek, mmTalepler, mmEkip, mmGunluk, mmDuyuru, mmCoklu, mmTalepAc: talepAc, mmKutu, mmKursu, mmTv, mmMedya, mdKurumDosya, mmKisitlar, mmCihaz, mmOyuncuyaYaz: oyuncuyaYazAc });
})();
