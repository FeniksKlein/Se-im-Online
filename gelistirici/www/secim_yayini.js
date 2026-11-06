/* =====================================================================
   SEÇİM GECESİ CANLI YAYINI (sunucu modülü 165)
   Sandıklar kapanınca seçim ekranı canlı yayına dönüşür: açılan sandık,
   sayılan oy, adaylar/partiler, il il harita, son açılan sandıklar, stüdyo
   yorumu, son dakika bandı, sonuç kesinleşince kazanan anı. Sayım bitince
   gece hızlandırılmış olarak yeniden izlenebilir.
   Sunucuda secim_yayini yoksa eski seçim ekranı aynen çalışır.
   ===================================================================== */
(function () {
  "use strict";
  if (window.SO_SECIM_YAYINI_V1) return;
  window.SO_SECIM_YAYINI_V1 = true;

  /* ---------- Biçimler ---------- */
  const stil = document.createElement("style");
  stil.id = "yy-stil";
  stil.textContent = `
.yy{--yy-cizgi:rgba(164,184,255,.14);--yy-koyu:#0A1026;--yy-zemin:#101A3A;font-variant-numeric:tabular-nums}
.yy-ust{position:sticky;top:-14px;margin:-14px -16px 12px;z-index:4;box-shadow:0 8px 18px rgba(4,8,22,.45)}
.yy-bant{display:flex;align-items:center;gap:10px;padding:9px 14px;background:linear-gradient(90deg,#0B1230,#18224B 55%,#0B1230);border-bottom:1px solid var(--yy-cizgi)}
.yy-canli{display:inline-flex;align-items:center;gap:6px;padding:4px 8px 3px;border-radius:4px;background:var(--al);color:#fff;font-family:var(--disp);font-weight:700;font-size:14px;letter-spacing:.8px;line-height:1;flex:none}
.yy-canli::before{content:"";width:7px;height:7px;border-radius:50%;background:#fff;animation:nabiz 1.4s ease-in-out infinite}
.yy-canli.tekrar{background:var(--ink)}.yy-canli.tekrar::before{animation:none;border-radius:1px;width:0;height:0;border-left:7px solid #fff;border-top:4px solid transparent;border-bottom:4px solid transparent;background:none}
.yy-canli.bitti{background:var(--panel3)}.yy-canli.bitti::before{animation:none;background:var(--good)}
.yy-bant-ad{flex:1;min-width:0;line-height:1.1}
.yy-bant-ad b{display:block;font-family:var(--disp);font-size:18px;letter-spacing:.6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.yy-bant-ad span{display:block;font-size:11.5px;color:var(--mut);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.yy-saat{font-family:var(--disp);font-weight:700;font-size:21px;letter-spacing:.5px;flex:none}
.yy-ses{width:32px;height:32px;border-radius:8px;background:rgba(255,255,255,.06);display:grid;place-items:center;flex:none;color:var(--txt2)}
.yy-ses svg{width:18px;height:18px}
.yy-kayan{display:flex;align-items:stretch;background:#070C1F;border-bottom:1px solid var(--yy-cizgi);height:28px;overflow:hidden}
.yy-kayan b{display:flex;align-items:center;padding:0 9px;background:var(--al);color:#fff;font-family:var(--disp);font-size:13px;letter-spacing:.6px;flex:none;white-space:nowrap}
.yy-kayan-ic{position:relative;flex:1;overflow:hidden}
.yy-kayan-ic span{position:absolute;left:0;top:0;line-height:28px;white-space:nowrap;font-size:13px;font-weight:600;color:var(--txt);padding-left:100%;animation:yyKay var(--sure,40s) linear infinite}
.yy-kayan-ic i{font-style:normal;color:var(--al2);margin:0 10px}
@keyframes yyKay{to{transform:translateX(-100%)}}
.yy-sekmeler{display:grid;grid-template-columns:repeat(var(--n,2),minmax(0,1fr));gap:6px;margin:0 0 12px}
.yy-sekmeler button{padding:9px 8px;border-radius:10px;background:var(--panel);text-align:left;border:1px solid transparent;min-width:0}
.yy-sekmeler button b{display:block;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.yy-sekmeler button span{display:block;font-size:12px;color:var(--mut);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.yy-sekmeler button.aktif{border-color:var(--ink2);background:var(--inkbg)}
.yy-kart{background:var(--panel);border-radius:var(--r);padding:14px;margin-bottom:12px}
.yy-kb{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin-bottom:8px}
.yy-kb h3{font-family:var(--disp);font-size:20px;font-weight:700;line-height:1.1}
.yy-kb span{font-size:12px;color:var(--mut);text-align:right}
.yy-skor{background:radial-gradient(120% 140% at 0% 0%,#22306A 0%,var(--yy-zemin) 55%,var(--yy-koyu) 100%);border:1px solid var(--yy-cizgi);border-radius:var(--r);padding:14px;margin-bottom:12px}
.yy-skor-ust{display:flex;align-items:flex-start;justify-content:space-between;gap:10px}
.yy-etiket{display:block;font-size:11.5px;font-weight:700;letter-spacing:.7px;color:var(--ink2);text-transform:uppercase}
.yy-skor h2{font-family:var(--disp);font-size:23px;line-height:1.1;margin-top:2px}
.yy-skor-govde{display:flex;align-items:center;gap:14px;margin-top:12px}
.yy-halka{position:relative;width:112px;height:112px;flex:none}
.yy-halka svg{width:100%;height:100%;transform:rotate(-90deg)}
.yy-halka circle{fill:none;stroke-width:10}
.yy-halka .iz{stroke:rgba(164,184,255,.12)}
.yy-halka .dolu{stroke:var(--al);stroke-linecap:round;transition:stroke-dashoffset 1.1s cubic-bezier(.2,.8,.2,1),stroke .4s}
.yy-halka.bitti .dolu{stroke:var(--good)}
.yy-halka-ic{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center}
.yy-halka-ic b{font-family:var(--disp);font-size:27px;line-height:1}
.yy-halka-ic span{font-size:11px;color:var(--mut);margin-top:3px;line-height:1.15}
.yy-olcu{display:grid;grid-template-columns:1fr 1fr;gap:8px 10px;flex:1;min-width:0}
.yy-olcu div{min-width:0}
.yy-olcu dt{font-size:11.5px;color:var(--mut);white-space:nowrap}
.yy-olcu dd{font-size:13px;color:var(--txt2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.yy-olcu dd b{font-family:var(--disp);font-size:21px;color:var(--txt);font-weight:700}
.yy-kaynak{margin-top:10px;font-size:11.5px;color:var(--faint);display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap}
.yy-liste{position:relative}
.yy-satir{position:relative;display:grid;grid-template-columns:auto minmax(0,1fr) auto;align-items:center;gap:10px;padding:10px 0 12px;border-bottom:1px solid var(--line)}
.yy-satir:last-child{border-bottom:0}
.yy-satir .yy-yer{width:42px;height:42px;display:grid;place-items:center;flex:none}
.yy-satir .yy-yer .portre{width:42px;height:42px}
.yy-satir .yy-yer .amb{width:38px;height:38px}
.yy-ad{min-width:0}
.yy-ad>b{display:flex;align-items:center;gap:6px;min-width:0;font-size:15.5px}
.yy-ad>b .ad{min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.yy-cipler{flex:none;display:inline-flex;gap:4px}
.yy-ad>span{display:block;font-size:12.5px;color:var(--mut);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.yy-pay{text-align:right;line-height:1}
.yy-pay b{font-family:var(--disp);font-size:28px;font-weight:700}
.yy-pay>span{display:block;font-size:12px;color:var(--mut);margin-top:3px;white-space:nowrap}
.yy-cubuk{grid-column:1/-1;position:relative;height:8px;border-radius:5px;background:rgba(164,184,255,.1);overflow:visible;margin-top:-2px}
.yy-cubuk i{position:absolute;left:0;top:0;bottom:0;border-radius:5px;width:0;transition:width 1s cubic-bezier(.2,.8,.2,1)}
.yy-cubuk .esik{position:absolute;top:-4px;bottom:-4px;width:2px;background:rgba(255,255,255,.7);border-radius:1px}
.yy-cubuk .esik::after{content:attr(data-ad);position:absolute;top:13px;left:50%;transform:translateX(-50%);font-size:10px;color:var(--mut);white-space:nowrap;display:none}
.yy-satir:last-child .yy-cubuk .esik::after{display:block}
.yy-satir:last-child{padding-bottom:22px}
.yy-satir.lider .yy-pay b{color:#fff}
.yy-satir.lider::before{content:"";position:absolute;left:-14px;top:10px;bottom:12px;width:3px;border-radius:2px;background:var(--lr,var(--ink2))}
.yy-cip{display:inline-block;padding:1px 6px;border-radius:4px;font-size:10.5px;font-weight:800;letter-spacing:.4px;white-space:nowrap;line-height:1.5}
.yy-cip.onde{background:var(--al);color:#fff}.yy-cip.kaz{background:var(--good);color:#06291a}.yy-cip.tur{background:var(--warn);color:#2b1d02}.yy-cip.alt{background:var(--panel3);color:var(--txt2)}
.yy-artis{display:inline-block;margin-left:6px;font-size:11.5px;font-weight:800;color:var(--good);opacity:0}
.yy-artis.goster{animation:yyArtis 2.6s ease-out}
@keyframes yyArtis{0%{opacity:0;transform:translateY(4px)}12%{opacity:1;transform:none}75%{opacity:1}100%{opacity:0}}
.yy-satir.parla{animation:yyParla 1.6s ease-out}
@keyframes yyParla{0%{background:rgba(168,149,255,.16)}100%{background:transparent}}
.yy-fark{margin-top:8px;padding:10px 11px;border-radius:10px;background:var(--panel2);font-size:13.5px;color:var(--txt2)}
.yy-fark b{color:var(--txt)}
.yy-yorum-satir{display:flex;gap:10px;padding:8px 0;border-bottom:1px solid var(--line)}
.yy-yorum-satir:last-child{border-bottom:0}
.yy-yorum-satir time{font-size:12px;color:var(--mut);flex:none;width:42px;padding-top:2px}
.yy-yorum-satir p{font-size:14.5px;color:var(--txt2)}
.yy-yorum-satir:first-child p{color:var(--txt);font-weight:600;font-size:15.5px}
.yy-yorum-satir.yeni{animation:yyGir .5s ease-out}
@keyframes yyGir{from{opacity:0;transform:translateY(-6px)}to{opacity:1;transform:none}}
.yy-mik{width:30px;height:30px;border-radius:50%;background:var(--albg);color:var(--al2);display:grid;place-items:center;flex:none}
.yy-mik svg{width:16px;height:16px}
.yy-harita svg{width:100%;height:auto;display:block}
.yy-harita path{stroke:var(--yy-koyu);stroke-width:1.2;transition:fill .7s ease,fill-opacity .7s ease;cursor:pointer}
.yy-harita path.secili{stroke:#fff;stroke-width:2.2}
.yy-harita path.flas{animation:yyFlas 1.8s ease-out}
@keyframes yyFlas{0%{stroke:#fff;stroke-width:4}100%{stroke:var(--yy-koyu);stroke-width:1.2}}
.yy-lejant{display:flex;flex-wrap:wrap;gap:6px 12px;margin-top:8px;font-size:12px;color:var(--txt2)}
.yy-lejant span{display:inline-flex;align-items:center;gap:5px}
.yy-lejant i{width:10px;height:10px;border-radius:3px;display:inline-block}
.yy-il{margin-top:12px;padding:12px;border-radius:12px;background:var(--panel2)}
.yy-il-bas{display:flex;justify-content:space-between;align-items:baseline;gap:8px}
.yy-il-bas b{font-family:var(--disp);font-size:21px}
.yy-il-bas span{font-size:12px;color:var(--mut)}
.yy-ilerle{height:6px;border-radius:4px;background:rgba(164,184,255,.12);margin:8px 0 4px;overflow:hidden}
.yy-ilerle i{display:block;height:100%;background:var(--al);border-radius:4px;transition:width .9s}
.yy-ilerle.bitti i{background:var(--good)}
.yy-mini{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:2px 10px;align-items:center;padding:6px 0}
.yy-mini b{font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.yy-mini span{font-size:13px;color:var(--txt2);white-space:nowrap}
.yy-mini .yy-ilerle{grid-column:1/-1;margin:2px 0 0;height:5px}
.yy-mus{display:flex;flex-wrap:wrap;gap:5px;margin-top:8px;font-size:12px;color:var(--mut);align-items:center}
.yy-mus em{font-style:normal;padding:2px 7px;border-radius:10px;background:var(--panel3);color:var(--txt2);font-weight:700}
.yy-akis{list-style:none}
.yy-akis li{display:grid;grid-template-columns:62px minmax(0,1fr);gap:8px;padding:9px 0;border-bottom:1px solid var(--line);cursor:pointer}
.yy-akis li:last-child{border-bottom:0}
.yy-akis li.yeni{animation:yyGir .5s ease-out}
.yy-akis time{font-family:var(--disp);font-size:16px;color:var(--txt2)}
.yy-akis b{font-size:14.5px}
.yy-akis small{display:block;font-size:12.5px;color:var(--mut);margin-top:1px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.yy-nok{display:inline-block;width:8px;height:8px;border-radius:50%;margin:0 4px 0 2px;vertical-align:0}
.yy-iller summary{cursor:pointer;font-family:var(--disp);font-size:20px;font-weight:700;list-style:revert}
.yy-iller .yy-ilsatir{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:2px 10px;padding:8px 0;border-bottom:1px solid var(--line);cursor:pointer}
.yy-iller .yy-ilsatir:last-child{border-bottom:0}
.yy-iller .yy-ilsatir b{font-size:14px}
.yy-iller .yy-ilsatir span{font-size:12.5px;color:var(--txt2);text-align:right;white-space:nowrap}
.yy-iller .yy-ilsatir small{grid-column:1/-1;font-size:12px;color:var(--mut)}
.yy-evre{border-radius:var(--r);padding:16px 15px;margin-bottom:12px;background:linear-gradient(160deg,#1B2557,#121A3F 60%,#0E1534);border:1px solid var(--yy-cizgi);position:relative;overflow:hidden}
.yy-evre h2{font-family:var(--disp);font-size:26px;line-height:1.08;margin:6px 0 4px}
.yy-evre p{color:var(--txt2);font-size:14px}
.yy-evre .yy-buyuk-sayac{font-family:var(--disp);font-weight:700;font-size:38px;line-height:1;margin-top:10px}
.yy-adim{list-style:none;margin:12px 0 4px}
.yy-adim li{position:relative;padding:0 0 12px 26px;font-size:14px;color:var(--mut)}
.yy-adim li::before{content:"";position:absolute;left:4px;top:4px;width:10px;height:10px;border-radius:50%;border:2px solid var(--panel3);background:var(--bg)}
.yy-adim li::after{content:"";position:absolute;left:10px;top:18px;bottom:2px;width:2px;background:var(--panel3)}
.yy-adim li:last-child::after{display:none}
.yy-adim li.tamam{color:var(--txt2)}.yy-adim li.tamam::before{background:var(--good);border-color:var(--good)}
.yy-adim li.simdi{color:var(--txt);font-weight:700}.yy-adim li.simdi::before{background:var(--al);border-color:var(--al);animation:nabiz 1.2s infinite}
.yy-adim time{float:right;color:var(--mut);font-weight:400}
.yy-kazanan{text-align:center;padding:22px 15px 18px}
.yy-kazanan .yy-unvan{font-family:var(--disp);font-size:14px;letter-spacing:1.4px;color:var(--warn)}
.yy-kazanan .portre{width:86px;height:86px;margin:12px auto 8px;display:block;box-shadow:0 0 0 4px var(--kr,var(--ink2)),0 10px 30px rgba(0,0,0,.45)}
.yy-kazanan h2{font-size:31px;margin:4px 0}
.yy-kazanan .yy-ikili{display:flex;justify-content:center;align-items:center;gap:16px;margin:14px 0 6px}
.yy-kazanan .yy-ikili .portre{width:66px;height:66px;margin:0 auto 6px}
.yy-kazanan .yy-ikili div{min-width:0;flex:1;max-width:150px}
.yy-kazanan .yy-ikili b{display:block;font-size:15px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.yy-kazanan .yy-ikili span{font-size:12.5px;color:var(--mut)}
.yy-kazanan .yy-ikili em{font-style:normal;font-family:var(--disp);font-size:20px;color:var(--mut)}
.yy-konfeti{position:absolute;inset:0;pointer-events:none;overflow:hidden}
.yy-konfeti i{position:absolute;top:-12px;width:7px;height:12px;border-radius:2px;opacity:.9;animation:yyDus linear forwards}
@keyframes yyDus{to{transform:translateY(420px) rotate(540deg);opacity:0}}
.yy-alt{display:grid;gap:8px;margin:4px 0 12px}
.yy-alt .btn{margin:0}
.yy-tekrar-kontrol{display:flex;gap:8px;margin-top:12px}
.yy-tekrar-kontrol .btn{margin:0;flex:1;padding:10px}
.yy-gundem{border-left-color:var(--al);background:linear-gradient(180deg,var(--albg),var(--panel) 75%)}
.yy-gundem .yy-mini{padding:4px 0}
.yy-gbanner{display:block;width:100%;text-align:left;border-radius:var(--r);padding:13px 14px;margin-bottom:12px;background:linear-gradient(120deg,#2A0F24,#1B2557 55%,#121A3F);border:1px solid rgba(240,69,75,.45);cursor:pointer}
.yy-gbanner .ust{display:flex;align-items:center;gap:8px;margin-bottom:6px}
.yy-gbanner .ust b{font-family:var(--disp);font-size:19px;flex:1}
.yy-gbanner .git{display:block;margin-top:8px;font-weight:800;color:var(--al2);font-size:14px}
.yy-bos{padding:10px 0;color:var(--mut);font-size:14px}
@media(max-width:360px){.yy-halka{width:94px;height:94px}.yy-halka-ic b{font-size:22px}.yy-pay b{font-size:24px}.yy-olcu dd b{font-size:18px}.yy-saat{font-size:18px}.yy-bant-ad b{font-size:16px}}
@media(min-width:760px){.yy{max-width:720px;margin:0 auto}}
@media(prefers-reduced-motion:reduce){.yy *{animation:none!important;transition:none!important}}
`;
  document.head.appendChild(stil);

  /* ---------- Yardımcılar ---------- */
  const esc = (s) => (typeof e === "function" ? e(s) : String(s == null ? "" : s));
  const sayi = (n) => Number(n || 0).toLocaleString("tr-TR");
  const yz = (n, d) => Number(n || 0).toLocaleString("tr-TR", { minimumFractionDigits: d == null ? 1 : d, maximumFractionDigits: d == null ? 1 : d });
  const pay = (a, b) => (b > 0 ? (a * 100) / b : 0);
  const renkOk = (r) => (/^#[0-9a-fA-F]{3,8}$/.test(String(r || "")) ? r : "#8E97B5");
  const zaman = (ts) => new Date(ts).getTime();
  const saniyeli = (ms) => new Intl.DateTimeFormat("tr-TR", { timeZone: "Europe/Istanbul", hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23" }).format(new Date(ms));
  const dakikali = (ms) => new Intl.DateTimeFormat("tr-TR", { timeZone: "Europe/Istanbul", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date(ms));
  const gunAd = (ms) => new Intl.DateTimeFormat("tr-TR", { timeZone: "Europe/Istanbul", day: "numeric", month: "long", year: "numeric" }).format(new Date(ms));
  const suan = () => (typeof simdi === "function" ? simdi() : Date.now());
  function ek(ad, kalinEk, inceEk) {
    const k = String(ad || "").toLocaleLowerCase("tr-TR");
    const sesli = (k.match(/[aeıioöuüâîû]/g) || ["e"]).pop();
    const kalin = "aıouâû".includes(sesli);
    const sert = "çfhkpsşt".includes(k.slice(-1));
    return `${ad}'${sert ? "t" : "d"}${kalin ? kalinEk : inceEk}`;
  }
  const ekDen = (ad) => ek(ad, "an", "en");
  const ekDe = (ad) => ek(ad, "a", "e");
  function yarisAd(y, uzun) {
    const a = { cb: uzun ? "Cumhurbaşkanlığı Seçimi" : "Cumhurbaşkanlığı", mv: uzun ? "Milletvekili Genel Seçimi" : "Milletvekili", cb2: uzun ? "Cumhurbaşkanlığı 2. Tur" : "2. tur" }[y.tur] || "Seçim";
    return (y.ara && uzun ? "Olağanüstü " : "") + a;
  }
  const benimIl = () => +(typeof D !== "undefined" && D.durum && D.durum.profil && D.durum.profil.il_id) || 0;
  const IK = {
    sesAcik: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9v6h4l5 4V5L8 9H4z"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/></svg>',
    sesKapali: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9v6h4l5 4V5L8 9H4z"/><path d="m17 9 5 6M22 9l-5 6"/></svg>',
    mik: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>',
    oynat: '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M7 5v14l12-7z"/></svg>',
    durdur: '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M6 5h4v14H6zM14 5h4v14h-4z"/></svg>',
    ileri: '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M5 5v14l9-7zM14 5v14l9-7z"/></svg>'
  };

  /* ---------- Durum ---------- */
  const Y = {
    id: null, veri: null, sekme: null, ekranNo: null, zamanlayici: null, saat: null, hata: 0, ilk: true,
    onceki: {}, yorumlar: [], bant: [], secilenIl: null, sonTik: 0, tekrar: null, atla: null, aktif: [], kesinGoruldu: {}
  };
  window.SO_YAYIN = Y;

  /* ---------- Veriyi tek biçime getir ---------- */
  // Aynı renkli partiler/adaylar (ör. iki kırmızı parti) haritada ve çubuklarda ayırt edilsin
  const YEDEK_RENK = ["#F2B33D", "#3E7BFA", "#34C98A", "#B06CF0", "#FF7A45", "#2BC0D8", "#E85D9E", "#9CCC65", "#FFD54F", "#4DB6AC"];
  const renkOnbellek = {};
  function renkler(y) {
    const anahtar = y.secim_id + ":" + (y.secenekler || []).map((x) => x.k + x.renk).join(",");
    if (renkOnbellek[anahtar]) return renkOnbellek[anahtar];
    const m = {}, kullanilan = new Set(); let yi = 0;
    const benzer = (a, b) => { const h = (c) => [1, 3, 5].map((i) => parseInt(c.slice(i, i + 2), 16)); if (!/^#[0-9a-f]{6}$/i.test(a) || !/^#[0-9a-f]{6}$/i.test(b)) return a === b; const p = h(a), q = h(b); return Math.abs(p[0] - q[0]) + Math.abs(p[1] - q[1]) + Math.abs(p[2] - q[2]) < 70; };
    // sıra oya bağlı değil: sayım boyunca renkler yer değiştirmez
    [...(y.secenekler || [])].sort((a, b) => (+String(a.k).slice(1) || 0) - (+String(b.k).slice(1) || 0)).forEach((x) => {
      let r = renkOk(x.renk);
      if ([...kullanilan].some((u) => benzer(u, r))) {
        while (yi < YEDEK_RENK.length && [...kullanilan].some((u) => benzer(u, YEDEK_RENK[yi]))) yi++;
        r = YEDEK_RENK[yi % YEDEK_RENK.length]; yi++;
      }
      kullanilan.add(r); m[x.k] = r;
    });
    renkOnbellek[anahtar] = m;
    return m;
  }
  function secenekler(y) {
    const rk = renkler(y);
    const liste = (y.secenekler || []).map((x) => ({
      k: x.k, ad: y.tur === "mv" ? (x.kisa || x.ad) : x.kad, kisa: x.kisa, tam: x.ad || x.kisa, alt: y.tur === "mv" ? (x.ad && x.ad !== x.kisa ? x.ad : "") : (x.kisa ? (x.ad || x.kisa) : "Bağımsız"),
      renk: rk[x.k] || renkOk(x.renk), amblem: x.amblem, parti_id: x.parti_id, kad: x.kad, oy: +x.oy || 0, portre: y.tur !== "mv",
      sad: y.tur === "mv" ? (x.kisa || x.ad) : x.kad
    }));
    if (y.tur === "mv" && (y.bagimsizlar || []).length) {
      liste.push({ k: "bag", ad: "Bağımsızlar", sad: "Bağımsızlar", alt: `${y.bagimsizlar.length} bağımsız aday`, renk: "#8E97B5", oy: y.bagimsizlar.reduce((t, b) => t + (+b.oy || 0), 0), bagimsiz: true });
    }
    const top = +y.sayilan_oy || 0;
    liste.forEach((x) => { x.yuzde = pay(x.oy, top); });
    const kaz = y.kesin_sonuc && y.kesin_sonuc.kazanan && y.kesin_sonuc.kazanan.k;
    liste.sort((a, b) => (b.k === kaz) - (a.k === kaz) || b.oy - a.oy || (a.bagimsiz ? 1 : 0) - (b.bagimsiz ? 1 : 0) || String(a.ad).localeCompare(String(b.ad), "tr"));
    return liste;
  }
  // il dağılımı anahtarlarını adlandır (MV bağımsızları tek tek)
  function adlar(y) {
    const m = {}, rk = renkler(y);
    (y.secenekler || []).forEach((x) => { m[x.k] = { ad: y.tur === "mv" ? (x.kisa || x.ad) : x.kad, renk: rk[x.k] || renkOk(x.renk), kisa: x.kisa }; });
    (y.bagimsizlar || []).forEach((x) => { m[x.k] = { ad: `${x.kad} (Bağımsız)`, renk: "#8E97B5", grup: "bag" }; });
    return m;
  }
  function dagSirali(dag, ad) {
    return Object.entries(dag || {}).map(([k, n]) => ({ k, n: +n, ad: (ad[k] || {}).ad || "Diğer", renk: (ad[k] || {}).renk || "#8E97B5" }))
      .sort((a, b) => b.n - a.n || a.ad.localeCompare(b.ad, "tr"));
  }
  function ilLider(il, ad) {
    const l = dagSirali(il.dagilim, ad);
    if (!l.length || !l[0].n) return null;
    return { ...l[0], esit: l[1] && l[1].n === l[0].n, ikinci: l[1] || null };
  }

  /* ---------- Yeniden izleme: sandıklardan durum hesapla ---------- */
  function tekrarHesapla(y, gecen) {
    const sd = y.sandiklar || [], acik = sd.filter((s) => +s.sn <= gecen);
    const dag = {};
    acik.forEach((s) => Object.entries(s.dagilim || {}).forEach(([k, n]) => { dag[k] = (dag[k] || 0) + n; }));
    const ilMap = {};
    (y.iller_bilgi || []).forEach((i) => { ilMap[i.il_id] = { il_id: i.il_id, ad: i.ad, mv: i.mv, secmen: i.secmen, musahit: i.musahit || [], sandik: 0, acilan: 0, oy: 0, sayilan: 0, dagilim: {} }; });
    sd.forEach((s) => {
      const i = ilMap[s.il_id]; if (!i) return;
      i.sandik++; i.oy += s.oy;
      if (+s.sn <= gecen) { i.acilan++; i.sayilan += s.oy; Object.entries(s.dagilim || {}).forEach(([k, n]) => { i.dagilim[k] = (i.dagilim[k] || 0) + n; }); }
    });
    const bas = zaman(y.baslangic);
    const son = acik.slice(-15).reverse().map((s) => ({ ...s, il: (ilMap[s.il_id] || {}).ad, an: new Date(bas + s.sn * 1000).toISOString() }));
    const sec = (y.secenekler || []).map((x) => ({ ...x, oy: dag[x.k] || 0 }));
    const bag = (y.bagimsizlar || []).map((x) => ({ ...x, oy: dag[x.k] || 0 }));
    const kisaK = {}; (y.secenekler || []).forEach((x) => { if (x.kisa) kisaK[x.kisa] = x.k; });
    const itt = (y.ittifaklar || []).map((i) => ({ ...i, oy: (i.partiler || []).reduce((t, p) => t + (dag[kisaK[p]] || 0), 0) }));
    const bitti = gecen >= +y.sure_sn;
    return {
      ...y, secenekler: sec, bagimsizlar: bag, ittifaklar: itt, dagilim: dag, son,
      iller: Object.values(ilMap).sort((a, b) => a.ad.localeCompare(b.ad, "tr")),
      acilan_sandik: acik.length, toplam_sandik: sd.length, sayilan_oy: acik.reduce((t, s) => t + s.oy, 0),
      toplam_oy: sd.reduce((t, s) => t + s.oy, 0), secmen: Object.values(ilMap).reduce((t, i) => t + (+i.secmen || 0), 0) || y.secmen,
      durum: gecen < 0 ? "once" : bitti ? "kesin" : "sayim", kesin_sonuc: bitti ? y.kesin_sonuc : null, gecen_sn: gecen
    };
  }

  /* ---------- Stüdyo yorumu ---------- */
  function yorumUret(y, p, ana) {
    const out = [];
    const ad = adlar(y), sl = secenekler(y), L = sl[0], S = sl[1];
    const acPct = pay(y.acilan_sandik, y.toplam_sandik), pAc = p ? pay(p.acilan_sandik, p.toplam_sandik) : -1;
    const ilad = (id) => ((y.iller || []).find((i) => i.il_id === id) || {}).ad || "";
    const baslik = yarisAd(y);
    if (y.durum === "kesin" && (!p || p.durum !== "kesin")) {
      const k = y.kesin_sonuc || {};
      if (y.tur === "mv") {
        const u = [...(k.ulusal || [])].sort((a, b) => (b.sandalye || 0) - (a.sandalye || 0));
        if (u[0]) out.push({ m: `Resmî sonuç açıklandı: ${u[0].ad || u[0].kisa} ${u[0].sandalye} sandalyeyle birinci parti. Meclis'te ${k.dolu || 0} sandalye doldu.`, o: 10 });
      } else if (k.kazanan) out.push({ m: `Resmî sonuç açıklandı: Türkiye'nin yeni Cumhurbaşkanı ${k.kazanan.kad}.`, o: 10 });
      else if (k.ikinci_tur && L && S) out.push({ m: `Resmî sonuç: hiçbir aday %50'yi geçemedi. ${L.sad} ile ${S.sad} ikinci turda yarışacak.`, o: 10 });
      return out;
    }
    if (y.durum === "once" && (!p || p.durum !== "once") && ana) {
      out.push({ m: `${baslik}: sandıklar kapandı. Sandık kurulları oyları sayıyor; ilk sonuçlar birkaç dakika içinde.`, o: 5 });
      return out;
    }
    if (!p || !L) return out;
    if (y.acilan_sandik === p.acilan_sandik && y.durum === p.durum) return out;
    const pl = secenekler(p), pL = pl[0];
    const yeni = (y.son || []).filter((s) => !(p.son || []).some((q) => q.il_id === s.il_id && q.no === s.no));
    if (y.durum === "tamam" && p.durum !== "tamam") {
      if (y.tur === "mv") out.push({ m: `Sandıkların tamamı açıldı. Kesin olmayan sonuçlara göre ${L.sad} %${yz(L.yuzde)} ile birinci parti.`, o: 9 });
      else if (L.yuzde > 50) out.push({ m: `Sandıkların tamamı açıldı. Kesin olmayan sonuçlara göre ${L.sad} %${yz(L.yuzde)} ile ilk turda seçilmiş görünüyor.`, o: 9 });
      else if (S) out.push({ m: `Sandıkların tamamı açıldı. Kesin olmayan sonuçlara göre ${L.sad} ile ${S.sad} ikinci tura kalıyor.`, o: 9 });
      return out;
    }
    if (p.acilan_sandik === 0 && y.acilan_sandik > 0) {
      const ilk = yeni[yeni.length - 1];
      out.push({ m: `İlk sandık ${ekDen(ilk ? ilk.il : ilad((y.son[0] || {}).il_id))} geldi. İlk sonuçlarda ${L.sad} önde.`, o: 8 });
      return out;
    }
    if (pL && pL.k !== L.k && p.sayilan_oy > 0 && L.oy > (S ? S.oy : 0)) {
      out.push({ m: `Sıralama değişti! ${L.sad} öne geçti; ${pL.sad} ikinci sıraya geriledi.`, o: 9 });
    }
    // eşikler
    [[25, "dörtte biri"], [50, "yarısı"], [75, "dörtte üçü"]].forEach(([e2, ad2]) => {
      if (pAc < e2 && acPct >= e2 && acPct < 100) out.push({ m: `Sandıkların ${ad2} açıldı. ${L.sad} %${yz(L.yuzde)}${S ? `, ${S.sad} %${yz(S.yuzde)}` : ""}.`, o: 7 });
    });
    if (y.tur !== "mv" && S) {
      if (L.yuzde > 50 && !(pL && pL.k === L.k && pL.yuzde > 50) && y.sayilan_oy >= 3) out.push({ m: `${L.sad} şu an %50 sınırının üzerinde. Bu tablo korunursa seçim ilk turda bitiyor.`, o: 6 });
      if (pL && pL.k === L.k && pL.yuzde > 50 && L.yuzde <= 50) out.push({ m: `${L.sad} %50'nin altına indi; ikinci tur ihtimali yeniden masada.`, o: 6 });
    }
    // il tamamlandı
    const biten = (y.iller || []).filter((i) => i.acilan === i.sandik && i.sandik > 0 && ((p.iller || []).find((q) => q.il_id === i.il_id) || {}).acilan < i.sandik)
      .sort((a, b) => (b.il_id === benimIl()) - (a.il_id === benimIl()) || b.oy - a.oy);
    if (biten[0]) {
      const i = biten[0], l = ilLider(i, ad);
      out.push({ m: `${ekDe(i.ad)} sayım tamamlandı${i.il_id === benimIl() ? " (senin ilin)" : ""}: ${l ? (l.esit ? `${l.ad} ile ${l.ikinci.ad} eşit` : `${l.ad} %${yz(pay(l.n, i.sayilan))} ile önde`) : "oy yok"}.`, o: i.il_id === benimIl() ? 8 : 4 });
    }
    if (S && y.sayilan_oy >= 3 && L.oy - S.oy <= 1 && !Y.yorumlar.slice(0, 3).some((x) => x.m.startsWith("Başa baş"))) {
      out.push({ m: L.oy === S.oy ? `Başa baş yarış: ${L.sad} ile ${S.sad} eşit oyda.` : `Başa baş yarış: ${L.sad} ile ${S.sad} arasında yalnızca 1 oy var.`, o: 5 });
    }
    if (y.tur === "mv" && y.baraj) {
      sl.filter((x) => !x.bagimsiz && x.oy > 0).forEach((x) => {
        const o = (pl.find((q) => q.k === x.k) || {}).yuzde;
        if (o != null && o < y.baraj && x.yuzde >= y.baraj && y.sayilan_oy >= 4) out.push({ m: `${x.sad} şu an barajın üzerinde: %${yz(x.yuzde)}.`, o: 5 });
        if (o != null && o >= y.baraj && x.yuzde < y.baraj && y.sayilan_oy >= 4) out.push({ m: `${x.sad} %${yz(x.yuzde)} ile baraj altına düştü; sandalye için %${yz(y.baraj, 0)} gerekiyor.`, o: 5 });
      });
    }
    if (!out.length) {
      const bek = (y.iller || []).filter((i) => i.acilan < i.sandik).sort((a, b) => (b.oy - b.sayilan) - (a.oy - a.sayilan))[0];
      if (bek && bek.oy - bek.sayilan >= 2 && !Y.yorumlar.slice(0, 4).some((x) => x.m.startsWith("Gözler"))) {
        out.push({ m: `Gözler ${ekDe(bek.ad)}: açılmayı bekleyen ${bek.sandik - bek.acilan} sandıkta ${bek.oy - bek.sayilan} oy var.`, o: 3 });
      } else if (yeni[0]) {
        const s = yeni[0], dl = dagSirali(s.dagilim, ad)[0];
        out.push({ m: `${s.il} ${s.no} No'lu sandık açıldı${dl ? `: ${dl.ad} ${dl.n} oy` : ""}. ${L.sad} %${yz(L.yuzde)} ile önde.`, o: 2 });
      }
    }
    return out.sort((a, b) => b.o - a.o).slice(0, 2);
  }

  /* ---------- Ekran iskeleti ---------- */
  function iskeletHtml() {
    return `<div id="yayinKok" class="yy">
      <div class="yy-ust">
        <div class="yy-bant"><span class="yy-canli" id="yyCanli">CANLI</span>
          <div class="yy-bant-ad"><b id="yyBantBas">SEÇİM GECESİ</b><span id="yyBantAlt">Kesin olmayan sonuçlar</span></div>
          <time class="yy-saat" id="yySaat">--:--:--</time>
          <button class="yy-ses" id="yySes" aria-label="Sesi aç / kapat"></button></div>
        <div class="yy-kayan" aria-hidden="true"><b>SON DAKİKA</b><div class="yy-kayan-ic"><span id="yyKayan"></span></div></div>
      </div>
      <div class="yy-sekmeler" id="yySekmeler" hidden></div>
      <div id="yyEvre"></div>
      <section class="yy-skor" id="yySkor"></section>
      <section class="yy-kart"><div class="yy-kb"><h3 id="yyListeBas">Adaylar</h3><span id="yyListeNot"></span></div>
        <div class="yy-liste" id="yyListe"></div><div class="yy-fark" id="yyFark" hidden></div></section>
      <div id="yyMeclis"></div>
      <div id="yyIttifak"></div>
      <section class="yy-kart"><div class="yy-kb" style="justify-content:flex-start;gap:10px"><span class="yy-mik">${IK.mik}</span><h3 style="flex:1">Stüdyo</h3><span>Canlı yorum</span></div>
        <div id="yyYorum" aria-live="polite"></div></section>
      <section class="yy-kart"><div class="yy-kb"><h3>Türkiye haritası</h3><span id="yyHaritaNot">İle dokun</span></div>
        <div class="yy-harita" id="yyHarita"></div><div class="yy-lejant" id="yyLejant"></div><div class="yy-il" id="yyIl" hidden></div></section>
      <section class="yy-kart"><div class="yy-kb"><h3>Son açılan sandıklar</h3><span id="yyAkisNot"></span></div><ol class="yy-akis" id="yyAkis"></ol></section>
      <details class="yy-kart yy-iller" id="yyIllerKutu"><summary id="yyIllerBas">İl il sayım</summary><div id="yyIller" style="margin-top:8px"></div></details>
      <div class="yy-alt" id="yyAlt"></div>
    </div>`;
  }
  function kok() { const k = document.getElementById("yayinKok"); return k && k.isConnected ? k : null; }
  function yaris() {
    const v = Y.veri; if (!v || !v.yarislar || !v.yarislar.length) return null;
    return v.yarislar.find((x) => x.secim_id === Y.sekme) || v.yarislar[0];
  }

  /* ---------- Bölümler ---------- */
  function bantCiz(v, y) {
    const c = document.getElementById("yyCanli"), alt = document.getElementById("yyBantAlt");
    if (Y.tekrar) { c.className = "yy-canli tekrar"; c.textContent = "TEKRAR"; }
    else if (y.durum === "kesin") { c.className = "yy-canli bitti"; c.textContent = "SONUÇ"; }
    else { c.className = "yy-canli"; c.textContent = "CANLI"; }
    document.getElementById("yyBantBas").textContent = "SEÇİM " + new Intl.DateTimeFormat("tr-TR", { timeZone: "Europe/Istanbul", year: "numeric" }).format(new Date(zaman(y.oy_bit)));
    alt.textContent = `${gunAd(zaman(y.oy_bit))} · ${y.durum === "kesin" ? "Resmî sonuç" : Y.tekrar ? "Seçim gecesi yeniden" : "Kesin olmayan sonuçlar"}`;
    const ses = document.getElementById("yySes");
    const kapali = typeof SES !== "undefined" && SES.kapali();
    ses.innerHTML = kapali ? IK.sesKapali : IK.sesAcik;
    ses.setAttribute("aria-pressed", kapali ? "false" : "true");
  }
  function sekmeCiz(v) {
    const k = document.getElementById("yySekmeler");
    if (!v.yarislar || v.yarislar.length < 2) { k.hidden = true; return; }
    k.hidden = false; k.style.setProperty("--n", v.yarislar.length);
    k.innerHTML = v.yarislar.map((y) => {
      const l = secenekler(y)[0];
      const alt = y.durum === "kesin" ? "Resmî sonuç" : y.toplam_sandik ? `%${yz(pay(y.acilan_sandik, y.toplam_sandik))} sandık${l && l.oy ? " · " + esc(l.kisa || l.ad) : ""}` : "Sayım bekleniyor";
      return `<button class="${y.secim_id === (yaris() || {}).secim_id ? "aktif" : ""}" data-sid="${y.secim_id}"><b>${esc(yarisAd(y))}</b><span>${alt}</span></button>`;
    }).join("");
    k.querySelectorAll("button").forEach((b) => b.onclick = () => { Y.sekme = +b.dataset.sid; Y.yeniSekme = true; ciz(); });
  }
  function skorCiz(y) {
    const k = document.getElementById("yySkor");
    if (!k.querySelector(".yy-halka") || Y.yeniSekme) {
      k.innerHTML = `<div class="yy-skor-ust"><div><span class="yy-etiket" id="yySkorEt"></span><h2 id="yySkorBas"></h2></div><span id="yySkorRozet"></span></div>
        <div class="yy-skor-govde"><div class="yy-halka" id="yyHalka"><svg viewBox="0 0 120 120"><circle class="iz" cx="60" cy="60" r="52"/><circle class="dolu" cx="60" cy="60" r="52" stroke-dasharray="326.73" stroke-dashoffset="326.73"/></svg>
          <div class="yy-halka-ic"><b id="yyHalkaY" data-v="0">%0</b><span>açılan<br>sandık</span></div></div>
          <dl class="yy-olcu"><div><dt>Açılan sandık</dt><dd id="yyOlcuS"></dd></div><div><dt>Sayılan oy</dt><dd id="yyOlcuO"></dd></div>
            <div><dt>Katılım</dt><dd id="yyOlcuK"></dd></div><div><dt>Son sandık</dt><dd id="yyOlcuSon"></dd></div></dl></div>
        <div class="yy-kaynak"><span id="yyKaynak"></span><span id="yyGuncel"></span></div>`;
    }
    const acPct = pay(y.acilan_sandik, y.toplam_sandik);
    document.getElementById("yySkorEt").textContent = yarisAd(y, true);
    document.getElementById("yySkorBas").textContent = y.durum === "kesin" ? "Resmî sonuçlar" : y.durum === "once" ? "Sayım bekleniyor" : y.durum === "tamam" ? "Tüm sandıklar açıldı" : "Kesin olmayan sonuçlar";
    document.getElementById("yySkorRozet").innerHTML = y.durum === "kesin" ? `<span class="rozet yesil">Kesinleşti</span>` : y.durum === "tamam" ? `<span class="rozet sari">YSK bekleniyor</span>` : `<span class="rozet kirmizi">${y.durum === "once" ? "Sayım başlıyor" : "Sayım sürüyor"}</span>`;
    const halka = document.getElementById("yyHalka");
    halka.classList.toggle("bitti", acPct >= 100);
    halka.querySelector(".dolu").setAttribute("stroke-dashoffset", (326.73 * (1 - Math.min(100, acPct) / 100)).toFixed(2));
    sayiAnim(document.getElementById("yyHalkaY"), acPct, (n) => "%" + yz(n));
    document.getElementById("yyOlcuS").innerHTML = `<b>${sayi(y.acilan_sandik)}</b> / ${sayi(y.toplam_sandik)}`;
    document.getElementById("yyOlcuO").innerHTML = `<b>${sayi(y.sayilan_oy)}</b> / ${sayi(y.toplam_oy)}`;
    document.getElementById("yyOlcuK").innerHTML = y.secmen ? `<b>%${yz(Math.min(100, pay(y.toplam_oy, y.secmen)))}</b>` : `<b>${sayi(y.toplam_oy)}</b> oy`;
    const s0 = (y.son || [])[0];
    document.getElementById("yyOlcuSon").textContent = s0 ? `${saniyeli(zaman(s0.an)).slice(0, 5)} · ${s0.il}` : "Henüz yok";
    document.getElementById("yyKaynak").textContent = y.durum === "kesin" ? "Kaynak: Yüksek Seçim Kurulu resmî sonuçları" : "Kaynak: sandık kurulu tutanakları";
    document.getElementById("yyGuncel").textContent = Y.tekrar ? "Hızlandırılmış tekrar" : `Güncelleme ${saniyeli(zaman(Y.veri.simdi))}`;
  }
  function sayiAnim(el, hedef, bicim) {
    const bas = +el.dataset.v || 0; el.dataset.v = hedef;
    if (Math.abs(hedef - bas) < 0.05 || Y.ilk) { el.textContent = bicim(hedef); return; }
    const t0 = performance.now(), sure = 900;
    const adim = (t) => { const r = Math.min(1, (t - t0) / sure), q = 1 - Math.pow(1 - r, 3); el.textContent = bicim(bas + (hedef - bas) * q); if (r < 1 && el.isConnected) requestAnimationFrame(adim); };
    requestAnimationFrame(adim);
  }
  function listeCiz(y, p) {
    const kutu = document.getElementById("yyListe");
    if (Y.yeniSekme) kutu.innerHTML = "";
    const sl = secenekler(y), pl = p ? secenekler(p) : null;
    const kesin = y.kesin_sonuc || null;
    document.getElementById("yyListeBas").textContent = y.tur === "mv" ? "Partiler" : "Adaylar";
    const baraj = y.tur === "mv" && kesin && kesin.baraj != null ? +kesin.baraj : y.baraj;
    document.getElementById("yyListeNot").textContent = y.tur === "mv" ? (baraj ? `Baraj %${yz(baraj, 0)}` : "Baraj yok") : (y.tur === "cb" ? "İlk turda kazanmak için %50'den fazla" : "Çok oy alan kazanır");
    if (!sl.length) { kutu.innerHTML = `<div class="yy-bos">Bu seçimde aday yok.</div>`; return; }
    // FLIP: eski konumlar
    const eski = {};
    kutu.querySelectorAll(".yy-satir").forEach((el) => { eski[el.dataset.k] = el.getBoundingClientRect().top; });
    const yeniPortre = [];
    sl.forEach((x, i) => {
      let el = kutu.querySelector(`.yy-satir[data-k="${CSS.escape(x.k)}"]`);
      if (!el) {
        el = document.createElement("div"); el.className = "yy-satir"; el.dataset.k = x.k;
        const yer = x.portre && typeof portre === "function" ? portre(x.kad, x.renk, 42) : x.bagimsiz ? `<div class="amb" style="background:var(--panel2)"></div>` : (typeof amblemKutu === "function" ? amblemKutu({ renk: x.renk, amblem: x.amblem }, 38) : "");
        const esik = y.tur === "mv" && y.baraj && !x.bagimsiz ? `<span class="esik" data-ad="baraj" style="left:${Math.min(100, y.baraj)}%"></span>` : y.tur === "cb" ? `<span class="esik" data-ad="%50" style="left:50%"></span>` : "";
        el.innerHTML = `<span class="yy-yer">${yer}</span><div class="yy-ad"><b><span class="ad">${esc(x.ad)}</span><span class="yy-cipler"></span></b><span>${esc(x.alt || "")}</span></div>
          <div class="yy-pay"><b data-v="0">%0,0</b><span><span class="oy">0 oy</span><span class="yy-artis"></span></span></div>
          <div class="yy-cubuk"><i style="background:${esc(x.renk)}"></i>${esik}</div>`;
        el.style.setProperty("--lr", x.renk);
        if (x.portre) yeniPortre.push(el);
      }
      kutu.appendChild(el);   // sıraya göre yerleştir
      const o = pl && pl.find((q) => q.k === x.k);
      const fark = o ? x.oy - o.oy : 0;
      sayiAnim(el.querySelector(".yy-pay b"), x.yuzde, (n) => "%" + yz(n));
      el.querySelector(".oy").textContent = `${sayi(x.oy)} oy`;
      const ar = el.querySelector(".yy-artis");
      if (fark > 0 && !Y.ilk) { ar.textContent = `+${sayi(fark)}`; ar.classList.remove("goster"); void ar.offsetWidth; ar.classList.add("goster"); }
      el.querySelector(".yy-cubuk i").style.width = Math.min(100, x.yuzde) + "%";
      const lider = i === 0 && x.oy > 0 && !(sl[1] && sl[1].oy === x.oy);
      el.classList.toggle("lider", lider);
      let cip = "";
      if (kesin && y.tur !== "mv") {
        if (kesin.kazanan && kesin.kazanan.k === x.k) cip = `<span class="yy-cip kaz">KAZANDI</span>`;
        else if (kesin.ikinci_tur && i < 2) cip = `<span class="yy-cip tur">2. TUR</span>`;
      } else if (lider) cip = `<span class="yy-cip onde">ÖNDE</span>`;
      const resmi = y.tur === "mv" && kesin ? (kesin.ulusal || []).find((q) => "p" + q.parti_id === x.k) : null;
      if (y.tur === "mv" && !x.bagimsiz && (kesin ? resmi && resmi.gecti === false : y.baraj && y.sayilan_oy > 0 && x.yuzde < y.baraj)) cip += `<span class="yy-cip alt">baraj altı</span>`;
      if (y.tur === "mv" && kesin) {
        const u = (kesin.ulusal || []).find((q) => "p" + q.parti_id === x.k);
        if (u && u.sandalye) cip = `<span class="yy-cip kaz">${u.sandalye} sandalye</span>`;
      }
      el.querySelector(".yy-cipler").innerHTML = cip;
      if (o && pl.indexOf(o) !== i && !Y.ilk) { el.classList.remove("parla"); void el.offsetWidth; el.classList.add("parla"); }
    });
    // FLIP: yeni konumdan eskiye, sonra serbest bırak
    kutu.querySelectorAll(".yy-satir").forEach((el) => {
      const once = eski[el.dataset.k]; if (once == null || Y.ilk) return;
      const dy = once - el.getBoundingClientRect().top; if (!dy) return;
      el.style.transition = "none"; el.style.transform = `translateY(${dy}px)`;
      requestAnimationFrame(() => { el.style.transition = "transform .7s cubic-bezier(.2,.8,.2,1)"; el.style.transform = ""; });
    });
    if (yeniPortre.length && typeof portreleriTazele === "function") portreleriTazele(kutu);
    // fark ve eşik notu
    const f = document.getElementById("yyFark"), L = sl[0], S = sl[1];
    if (!L || !y.sayilan_oy) { f.hidden = true; return; }
    f.hidden = false;
    if (y.tur === "mv") {
      f.innerHTML = `Birinci parti <b>${esc(L.ad)}</b> %${yz(L.yuzde)}${S ? ` · ikinci <b>${esc(S.ad)}</b> %${yz(S.yuzde)} · fark ${sayi(L.oy - S.oy)} oy` : ""}`;
    } else if (S) {
      const d = L.oy - S.oy;
      const durum = y.tur === "cb2" ? (d === 0 ? "Şu an eşitlik var." : `Bu tabloyla kazanan ${esc(L.ad)}.`)
        : L.yuzde > 50 ? `Bu tabloyla <b>${esc(L.ad)}</b> ilk turda seçiliyor.` : `Bu tabloyla seçim <b>ikinci tura</b> kalıyor: ${esc(L.ad)} ve ${esc(S.ad)}.`;
      f.innerHTML = `${d === 0 ? "İlk iki aday <b>eşit</b>" : `Fark: <b>${sayi(d)} oy</b> · ${yz(L.yuzde - S.yuzde)} puan`}. ${kesin ? "" : durum}`;
    } else f.innerHTML = `Tek aday: <b>${esc(L.ad)}</b>`;
  }
  function meclisCiz(y) {
    const k = document.getElementById("yyMeclis");
    if (y.tur !== "mv") { k.innerHTML = ""; return; }
    const ks = y.kesin_sonuc;
    if (!ks) {
      const svg = typeof meclisSvg === "function" ? meclisSvg([], +y.sandalye_toplam || 600) : "";
      k.innerHTML = `<section class="yy-kart"><div class="yy-kb"><h3>Meclis aritmetiği</h3><span>Resmî sonuçla</span></div>
        <div style="opacity:.55">${svg}</div><p class="kucuk" style="margin-top:6px">Sandalyeler il il D'Hondt usulüyle dağıtılır; Meclis'in yeni dağılımı saat ${dakikali(zaman(y.sonuc_at))}'te resmî sonuçla burada belirir.</p></section>`;
      return;
    }
    const u = [...(ks.ulusal || [])].filter((p) => p.sandalye > 0).sort((a, b) => b.sandalye - a.sandalye);
    const koltuk = [...u.map((p) => ({ renk: renkOk(p.renk), n: p.sandalye })), ...(ks.bagimsiz_sandalye ? [{ renk: "#8E97B5", n: +ks.bagimsiz_sandalye }] : [])];
    const dolu = +ks.dolu || 0, cog = Math.floor(dolu / 2) + 1;
    const svg = typeof meclisSvg === "function" ? meclisSvg(koltuk, dolu + (+ks.bos || 0)) : "";
    const b = u[0];
    k.innerHTML = `<section class="yy-kart"><div class="yy-kb"><h3>TBMM'nin yeni aritmetiği</h3><span>${sayi(dolu)} sandalye doldu</span></div>${svg}
      ${b ? `<div class="yy-fark" style="margin-top:8px"><b>${esc(b.ad || b.kisa)}</b> ${b.sandalye} sandalye · ${b.sandalye >= cog ? "tek başına çoğunluk" : `çoğunluk için ${cog} gerekli`}</div>` : ""}
      ${u.map((p) => `<div class="yy-mini"><b><span class="yy-nok" style="background:${esc(renkOk(p.renk))}"></span>${esc(p.ad || p.kisa)}</b><span>${p.sandalye} sandalye</span></div>`).join("")}
      ${ks.bagimsiz_sandalye ? `<div class="yy-mini"><b><span class="yy-nok" style="background:#8E97B5"></span>Bağımsızlar</b><span>${ks.bagimsiz_sandalye} sandalye</span></div>` : ""}</section>`;
  }
  function ittifakCiz(y) {
    const k = document.getElementById("yyIttifak");
    const it = (y.ittifaklar || []).filter((i) => (i.partiler || []).length);
    if (y.tur !== "mv" || !it.length) { k.innerHTML = ""; return; }
    k.innerHTML = `<section class="yy-kart"><div class="yy-kb"><h3>İttifaklar</h3><span>Üye partilerin oyları</span></div>
      ${[...it].sort((a, b) => b.oy - a.oy).map((i) => `<div class="yy-mini"><b>${esc(i.ad)}</b><span>%${yz(pay(i.oy, y.sayilan_oy))} · ${sayi(i.oy)} oy</span>
        <div class="yy-ilerle"><i style="width:${Math.min(100, pay(i.oy, y.sayilan_oy))}%;background:var(--ink2)"></i></div><small class="kucuk" style="grid-column:1/-1">${esc((i.partiler || []).join(" + "))}</small></div>`).join("")}</section>`;
  }
  function yorumCiz() {
    const k = document.getElementById("yyYorum");
    if (!Y.yorumlar.length) { k.innerHTML = `<div class="yy-bos">Stüdyo yayına hazır. Sayım başlayınca yorumlar burada.</div>`; return; }
    k.innerHTML = Y.yorumlar.slice(0, 5).map((x, i) => `<div class="yy-yorum-satir ${i === 0 && x.yeni ? "yeni" : ""}"><time>${saniyeli(x.t).slice(0, 5)}</time><p>${esc(x.m)}</p></div>`).join("");
    Y.yorumlar.forEach((x) => { x.yeni = false; });
  }
  function kayanCiz(v) {
    const k = document.getElementById("yyKayan");
    const parca = [];
    (v.yarislar || []).forEach((y) => {
      const l = secenekler(y), L = l[0];
      if (y.durum === "kesin" && y.kesin_sonuc) {
        const ks = y.kesin_sonuc;
        if (y.tur === "mv") { const b = [...(ks.ulusal || [])].sort((a, b2) => b2.sandalye - a.sandalye)[0]; if (b) parca.push(`MECLİS: ${b.kisa || b.ad} ${b.sandalye} sandalye`); }
        else if (ks.kazanan) parca.push(`CUMHURBAŞKANI SEÇİLDİ: ${ks.kazanan.kad}`);
        else if (ks.ikinci_tur && l[1]) parca.push(`İKİNCİ TUR: ${L.sad} — ${l[1].sad}`);
      } else if (y.toplam_sandik) {
        parca.push(`${yarisAd(y).toLocaleUpperCase("tr-TR")}: açılan sandık %${yz(pay(y.acilan_sandik, y.toplam_sandik))}${L && L.oy ? ` · ${L.sad} %${yz(L.yuzde)}` : ""}`);
      }
    });
    Y.yorumlar.slice(0, 3).forEach((x) => parca.push(x.m));
    const metin = parca.map(esc).join("<i>•</i>") || "Seçim gecesi canlı yayını";
    const durumImza = (v.yarislar || []).map((y) => y.durum).join("|") + (Y.tekrar ? "|t" : "");
    if (k.dataset.durum !== durumImza) { k.dataset.durum = durumImza; delete k.dataset.m; delete k.dataset.bekleyen; k.style.animation = "none"; void k.offsetWidth; k.style.animation = ""; }
    if (k.dataset.m === metin || k.dataset.bekleyen === metin) return;
    const koy = (m) => { k.dataset.m = m; k.innerHTML = m; k.style.setProperty("--sure", Math.max(22, Math.min(110, m.replace(/<[^>]+>/g, "").length / 6)) + "s"); };
    if (!k.dataset.m) { koy(metin); k.onanimationiteration = () => { if (k.dataset.bekleyen) { koy(k.dataset.bekleyen); delete k.dataset.bekleyen; } }; }
    else k.dataset.bekleyen = metin;
  }
  function haritaCiz(y) {
    const k = document.getElementById("yyHarita"); const H = window.VERI && VERI.harita;
    if (!H) { k.innerHTML = ""; return; }
    if (!k.querySelector("svg")) {
      k.innerHTML = `<svg viewBox="0 0 ${H.w} ${H.h}" role="img" aria-label="İllere göre sayım durumu">${Object.entries(H.il).map(([id, p]) => `<path data-il="${id}" d="${p.d}" fill="#1A2347"></path>`).join("")}</svg>`;
      k.querySelector("svg").addEventListener("click", (ev) => { const p = ev.target.closest("path"); if (p) ilSec(+p.dataset.il, true); });
    }
    const ad = adlar(y), iller = {}; (y.iller || []).forEach((i) => { iller[i.il_id] = i; });
    const onceki = Y.haritaOnceki || {}; const simdiki = {}; const lej = {};
    k.querySelectorAll("path").forEach((p) => {
      const id = +p.dataset.il, i = iller[id];
      let f = "#1A2347", o = 1;
      if (i) {
        const l = ilLider(i, ad);
        if (!i.acilan) { f = "#34416F"; }
        else if (l) { f = l.esit ? "#B9C2DC" : l.renk; o = i.acilan >= i.sandik ? 1 : 0.42 + 0.4 * (i.acilan / i.sandik); if (!l.esit) lej[l.ad] = l.renk; }
        else f = "#34416F";
        simdiki[id] = i.acilan;
        if (onceki[id] != null && onceki[id] !== i.acilan && Y.haritaSecim === y.secim_id) { p.classList.remove("flas"); void p.getBoundingClientRect(); p.classList.add("flas"); }
      }
      p.setAttribute("fill", f); p.setAttribute("fill-opacity", o.toFixed(2));
      p.classList.toggle("secili", id === Y.secilenIl);
    });
    Y.haritaOnceki = simdiki; Y.haritaSecim = y.secim_id;
    const varSayim = (y.iller || []).some((i) => i.acilan > 0 && i.acilan < i.sandik), bekleyen = (y.iller || []).some((i) => !i.acilan);
    document.getElementById("yyLejant").innerHTML = Object.entries(lej).map(([a, r]) => `<span><i style="background:${esc(r)}"></i>${esc(a)} önde</span>`).join("")
      + (varSayim ? `<span><i style="background:#8E97B5;opacity:.55"></i>Açık renk: sayım sürüyor</span>` : "")
      + (bekleyen ? `<span><i style="background:#34416F"></i>Sandık bekleniyor</span>` : "") + `<span><i style="background:#1A2347;outline:1px solid var(--line2)"></i>Oy yok</span>`;
  }
  function ilSec(id, kaydir) {
    Y.secilenIl = id; const y = yaris(); if (!y) return;
    ilCiz(y); haritaCiz(y);
    if (kaydir) { const k = document.getElementById("yyIl"); if (k && !k.hidden) k.scrollIntoView({ behavior: "smooth", block: "nearest" }); }
  }
  window.yayinIlSec = ilSec;
  function ilCiz(y) {
    const k = document.getElementById("yyIl"); const iller = y.iller || [];
    if (!Y.secilenIl || !iller.some((i) => i.il_id === Y.secilenIl) && !(VERI.harita && VERI.harita.il[Y.secilenIl])) {
      const b = iller.find((i) => i.il_id === benimIl()) || [...iller].sort((a, c) => c.oy - a.oy)[0];
      Y.secilenIl = b ? b.il_id : null;
    }
    if (!Y.secilenIl) { k.hidden = true; return; }
    k.hidden = false;
    const i = iller.find((x) => x.il_id === Y.secilenIl);
    const adi = i ? i.ad : (typeof ilAd === "function" ? ilAd(Y.secilenIl) : "");
    const ben = Y.secilenIl === benimIl() ? ` <span class="yy-cip onde" style="background:var(--ink)">SENİN İLİN</span>` : "";
    if (!i) { k.innerHTML = `<div class="yy-il-bas"><b>${esc(adi)}${ben}</b><span>Bu yarışta oy yok</span></div><p class="kucuk" style="margin-top:6px">Bu ilde ${esc(yarisAd(y))} oyu kullanılmadı.</p>`; return; }
    const ad = adlar(y), dl = dagSirali(i.dagilim, ad), ac = pay(i.acilan, i.sandik);
    k.innerHTML = `<div class="yy-il-bas"><b>${esc(adi)}${ben}</b><span>${y.tur === "mv" && i.mv ? `${i.mv} milletvekili · ` : ""}${i.sandik} sandık</span></div>
      <div class="yy-ilerle ${ac >= 100 ? "bitti" : ""}"><i style="width:${ac}%"></i></div>
      <div class="kucuk">${ac >= 100 ? "Sayım tamamlandı" : `Açılan sandık ${i.acilan}/${i.sandik} (%${yz(ac)})`} · ${sayi(i.sayilan)}/${sayi(i.oy)} oy sayıldı${i.secmen ? ` · katılım %${yz(Math.min(100, pay(i.oy, i.secmen)))}` : ""}</div>
      ${dl.length ? dl.map((x) => `<div class="yy-mini"><b><span class="yy-nok" style="background:${esc(x.renk)}"></span>${esc(x.ad)}</b><span>%${yz(pay(x.n, i.sayilan))} (${sayi(x.n)})</span>
        <div class="yy-ilerle"><i style="width:${pay(x.n, i.sayilan)}%;background:${esc(x.renk)}"></i></div></div>`).join("") : `<div class="yy-bos">Bu ilde henüz sandık açılmadı.</div>`}
      ${(i.musahit || []).length ? `<div class="yy-mus">Sandık başındaki müşahitler: ${i.musahit.map((m) => `<em style="color:${esc(renkOk(m.renk))}">${esc(m.kisa)}</em>`).join("")}</div>` : ""}`;
  }
  function akisCiz(y, p) {
    const k = document.getElementById("yyAkis"); const ad = adlar(y);
    const son = y.son || [];
    document.getElementById("yyAkisNot").textContent = y.toplam_sandik ? `${sayi(y.toplam_sandik - y.acilan_sandik)} sandık kaldı` : "";
    if (!son.length) { k.innerHTML = `<li style="display:block;cursor:default"><div class="yy-bos">${y.durum === "once" ? "İlk sandıkların açılması bekleniyor." : "Henüz açılan sandık yok."}</div></li>`; return; }
    const eski = new Set(((p && p.son) || []).map((s) => s.il_id + ":" + s.no));
    k.innerHTML = son.slice(0, 10).map((s) => {
      const dl = dagSirali(s.dagilim, ad).slice(0, 2);
      return `<li class="${!eski.has(s.il_id + ":" + s.no) && p && !Y.ilk ? "yeni" : ""}" onclick="yayinIlSec(${+s.il_id}, true)"><time>${saniyeli(zaman(s.an)).slice(0, 5)}</time>
        <div><b>${esc(s.il)}</b> · ${s.no} No'lu sandık<small>${sayi(s.oy)} oy${dl.map((x) => ` · <span class="yy-nok" style="background:${esc(x.renk)}"></span>${esc(x.ad)} ${sayi(x.n)}`).join("")}</small></div></li>`;
    }).join("");
  }
  function illerCiz(y) {
    const k = document.getElementById("yyIller"), ad = adlar(y), iller = [...(y.iller || [])];
    document.getElementById("yyIllerBas").textContent = `İl il sayım (${iller.length} il)`;
    if (!iller.length) { k.innerHTML = `<div class="yy-bos">İl bilgisi sayım başlayınca gelir.</div>`; return; }
    iller.sort((a, b) => b.oy - a.oy || a.ad.localeCompare(b.ad, "tr"));
    k.innerHTML = iller.map((i) => {
      const l = ilLider(i, ad), ac = pay(i.acilan, i.sandik);
      return `<div class="yy-ilsatir" onclick="yayinIlSec(${+i.il_id}, true)"><b>${esc(i.ad)}${i.il_id === benimIl() ? " · senin ilin" : ""}</b>
        <span>${l ? (l.esit ? "Eşit" : `<span class="yy-nok" style="background:${esc(l.renk)}"></span>${esc(l.ad)} %${yz(pay(l.n, i.sayilan))}`) : "—"}</span>
        <small>${ac >= 100 ? "Sayım tamamlandı" : `Açılan sandık ${i.acilan}/${i.sandik}`} · ${sayi(i.sayilan)}/${sayi(i.oy)} oy</small></div>`;
    }).join("");
  }
  function evreCiz(y) {
    const k = document.getElementById("yyEvre");
    const sl = secenekler(y), L = sl[0], S = sl[1];
    if (Y.tekrar) {
      const T = Y.tekrar, ilerleme = Math.max(0, Math.min(100, pay(T.gecen - T.bas, T.son - T.bas)));
      k.innerHTML = `<div class="yy-evre" style="padding:13px 14px"><div class="yy-kb" style="margin:0"><h3>Seçim gecesi yeniden</h3><span>${saniyeli(zaman(y.baslangic) + T.gecen * 1000).slice(0, 5)} · hızlandırılmış</span></div>
        <div class="yy-ilerle" style="margin-top:10px"><i style="width:${ilerleme}%;background:var(--ink2)"></i></div>
        <div class="yy-tekrar-kontrol"><button class="btn ikinci" onclick="yayinTekrarKontrol('dur')">${T.dur ? IK.oynat + " Devam" : IK.durdur + " Duraklat"}</button>
        <button class="btn ikinci" onclick="yayinTekrarKontrol('son')">${IK.ileri} Sona geç</button><button class="btn ikinci" onclick="yayinTekrarKontrol('bas')">Baştan</button></div></div>
        ${y.durum === "kesin" ? kazananHtml(y, sl) : ""}`;
      return;
    }
    if (y.durum === "kesin") { k.innerHTML = kazananHtml(y, sl); return; }
    if (y.durum === "once") {
      const ilk = y.baslangic ? zaman(y.baslangic) : zaman(y.oy_bit) + 120000;
      const hedef = Math.max(ilk, suan() + (Y.veri.sonraki_sn || 0) * 1000);
      k.innerHTML = `<div class="yy-evre"><span class="yy-etiket">${esc(yarisAd(y, true))}</span><h2>Sandıklar kapandı, oylar sayılıyor</h2>
        <ol class="yy-adim"><li class="tamam">Sandıklar kapandı<time>${dakikali(zaman(y.oy_bit))}</time></li>
          <li class="simdi">Sandık kurulları oyları sayıyor, tutanaklar imzalanıyor</li>
          <li>Sayım ve ilk sandıklar<time>${dakikali(hedef)}</time></li><li>Resmî sonuç<time>${dakikali(zaman(y.sonuc_at))}</time></li></ol>
        <div class="yy-buyuk-sayac" data-yy-an="${hedef}">${kalanYaz(hedef - suan())}</div><p class="kucuk">Sayımın başlamasına kalan</p>
        <p style="margin-top:10px">Bu gece <b>${sayi(y.toplam_oy)}</b> seçmen sandığa gitti${y.toplam_sandik ? `; oylar ${sayi((y.iller || []).length)} ilde <b>${sayi(y.toplam_sandik)}</b> sandıkta` : ""}.</p></div>`;
      return;
    }
    if (y.durum === "tamam") {
      const h = zaman(y.sonuc_at);
      k.innerHTML = `<div class="yy-evre"><span class="yy-etiket">Kesin olmayan sonuçlar</span><h2>Sandıkların tamamı açıldı</h2>
        <p>${L ? (y.tur === "mv" ? `${esc(L.ad)} %${yz(L.yuzde)} ile birinci parti.` : L.yuzde > 50 || y.tur === "cb2" ? `${esc(L.ad)} %${yz(L.yuzde)} ile önde.` : S ? `${esc(L.ad)} ile ${esc(S.ad)} ikinci tura kalıyor görünüyor.` : "") : ""} Yüksek Seçim Kurulu resmî sonucu saat ${dakikali(h)}'te ilan edecek.</p>
        <div class="yy-buyuk-sayac" data-yy-an="${h}">${kalanYaz(h - suan())}</div></div>`;
      return;
    }
    if (y.durum === "sayim" && !y.acilan_sandik) {
      k.innerHTML = `<div class="yy-evre" style="padding:13px 14px"><span class="yy-etiket">Sayım başladı</span><h2 style="font-size:21px">İlk sandıklar yolda</h2>
        <p>Sandık kurulu tutanakları ilçe seçim kurullarına ulaştıkça sonuçlar burada sandık sandık açılacak.</p></div>`;
      return;
    }
    k.innerHTML = "";
  }
  function kazananHtml(y, sl) {
    const ks = y.kesin_sonuc; if (!ks) return "";
    const ilkGorus = !Y.kesinGoruldu[y.secim_id];
    const konfeti = (renk) => ilkGorus && !Y.ilk ? `<div class="yy-konfeti">${Array.from({ length: 34 }, (_, i) => `<i style="left:${(i * 37) % 100}%;background:${i % 3 ? esc(renk) : (i % 2 ? "#fff" : "#F2B33D")};animation-duration:${(2.2 + (i % 7) * 0.35).toFixed(2)}s;animation-delay:${((i % 9) * 0.12).toFixed(2)}s"></i>`).join("")}</div>` : "";
    if (y.tur === "mv") {
      const u = [...(ks.ulusal || [])].sort((a, b) => (b.sandalye || 0) - (a.sandalye || 0)), b = u[0];
      if (!b) return "";
      const cog = Math.floor((+ks.dolu || 0) / 2) + 1;
      return `<div class="yy-evre yy-kazanan">${konfeti(renkOk(b.renk))}<div class="yy-unvan">MİLLETVEKİLİ GENEL SEÇİMİ · RESMÎ SONUÇ</div>
        <div style="margin:12px auto 6px;width:72px">${typeof amblemKutu === "function" ? amblemKutu({ renk: renkOk(b.renk), amblem: ((sl.find((x) => x.k === "p" + b.parti_id) || {}).amblem) }, 72) : ""}</div>
        <h2>${esc(b.ad || b.kisa)}</h2><p>${b.sandalye} sandalye · %${yz(b.yuzde)} · ${b.sandalye >= cog ? "tek başına iktidar" : `çoğunluk için ${cog} sandalye gerekiyor`}</p></div>`;
    }
    if (ks.kazanan) {
      const x = sl.find((q) => q.k === ks.kazanan.k) || {};
      return `<div class="yy-evre yy-kazanan" style="--kr:${esc(renkOk(ks.kazanan.renk))}">${konfeti(renkOk(ks.kazanan.renk))}<div class="yy-unvan">TÜRKİYE CUMHURİYETİ CUMHURBAŞKANI</div>
        ${typeof portre === "function" ? portre(ks.kazanan.kad, renkOk(ks.kazanan.renk), 86) : ""}<h2>${esc(ks.kazanan.kad)}</h2>
        <p>${esc(ks.kazanan.kisa || "Bağımsız")} · %${yz(x.yuzde || 0)} (${sayi(x.oy || 0)} oy)${y.tur === "cb" ? " · ilk turda seçildi" : " · ikinci turda seçildi"}</p>
        ${y.goreve_bas ? `<p class="kucuk" style="margin-top:6px">Yemin ve göreve başlama: ${typeof tarihSaat === "function" ? tarihSaat(y.goreve_bas) : ""}</p>` : ""}</div>`;
    }
    if (ks.ikinci_tur && sl[1]) {
      const a = sl[0], b = sl[1];
      const kisi = (x) => `<div>${typeof portre === "function" ? portre(x.kad, x.renk, 66) : ""}<b>${esc(x.ad)}</b><span>%${yz(x.yuzde)} · ${esc(x.kisa || "Bağımsız")}</span></div>`;
      return `<div class="yy-evre yy-kazanan"><div class="yy-unvan">CUMHURBAŞKANLIĞI · RESMÎ SONUÇ</div><h2>Seçim ikinci tura kaldı</h2>
        <div class="yy-ikili">${kisi(a)}<em>—</em>${kisi(b)}</div><p>Hiçbir aday %50'yi geçemedi. İki aday ertesi gün yeniden sandıkta.</p></div>`;
    }
    return `<div class="yy-evre"><h2>Sonuç açıklandı</h2></div>`;
  }
  function altCiz(y) {
    const k = document.getElementById("yyAlt");
    const btn = [];
    if (y.durum === "kesin" && !Y.tekrar) {
      btn.push(`<button class="btn altin" onclick="yayinTekrarAc(${Y.id})">${IK.oynat} Seçim gecesini baştan izle</button>`);
      btn.push(`<button class="btn ikinci" onclick="yayinAyrinti(${y.secim_id})">Ayrıntılı resmî sonuçlar</button>`);
      if (y.kesin_sonuc && y.kesin_sonuc.ikinci_tur_id) btn.push(`<button class="btn ikinci" onclick="ekranAc(()=>secimEkrani(${+y.kesin_sonuc.ikinci_tur_id}))">İkinci tur sandığı</button>`);
    }
    if (Y.tekrar) btn.push(`<button class="btn ikinci" onclick="yayinTekrarKontrol('cik')">Tekrarı kapat</button>`);
    k.innerHTML = btn.join("");
  }
  function kalanYaz(ms) { return typeof kalan === "function" ? kalan(ms) : Math.max(0, Math.round(ms / 1000)) + " sn"; }

  /* ---------- Hepsini çiz ---------- */
  function ciz() {
    if (!kok() || !Y.veri) return;
    const v = Y.veri, y = yaris(); if (!y) return;
    const p = Y.oncekiYaris && Y.oncekiYaris[y.secim_id];
    bantCiz(v, y); sekmeCiz(v); evreCiz(y); skorCiz(y); listeCiz(y, Y.yeniSekme ? null : p); meclisCiz(y); ittifakCiz(y);
    yorumCiz(); kayanCiz(v); haritaCiz(y); ilCiz(y); akisCiz(y, Y.yeniSekme ? null : p); illerCiz(y); altCiz(y);
    if (y.durum === "kesin") Y.kesinGoruldu[y.secim_id] = true;
    Y.yeniSekme = false; Y.ilk = false;
  }
  // yeni veri geldi: yorum üret, ses/titreşim, çiz
  function veriAl(v) {
    const eski = Y.veri;
    Y.oncekiYaris = {};
    if (eski) (eski.yarislar || []).forEach((y) => { Y.oncekiYaris[y.secim_id] = y; });
    Y.veri = v;
    if (!Y.sekme || !(v.yarislar || []).some((y) => y.secim_id === Y.sekme)) {
      const ana = (v.yarislar || []).find((y) => y.secim_id === Y.id) || (v.yarislar || [])[0];
      Y.sekme = ana ? ana.secim_id : null;
    }
    let yeniSandik = false, onemli = false, kesinOldu = false;
    (v.yarislar || []).forEach((y) => {
      const p = Y.oncekiYaris[y.secim_id];
      if (p && y.acilan_sandik > p.acilan_sandik) yeniSandik = true;
      if (p && y.durum === "kesin" && p.durum !== "kesin") kesinOldu = true;
      const yeni = yorumUret(y, p || null, y.secim_id === Y.sekme);
      const t = Y.tekrar ? zaman(y.baslangic) + (Y.tekrar.gecen || 0) * 1000 : zaman(v.simdi);
      yeni.forEach((x) => {
        if (Y.yorumlar.length && Y.yorumlar[0].m === x.m) return;
        if (x.o >= 8) onemli = true;
        Y.yorumlar.unshift({ m: (v.yarislar.length > 1 && x.o < 10 && !x.m.startsWith(yarisAd(y)) ? yarisAd(y) + " · " : "") + x.m, t, yeni: true, o: x.o });
      });
    });
    if (Y.ilk && !Y.yorumlar.length) {
      const y = yaris();
      if (y && y.durum === "sayim") {
        const L = secenekler(y)[0];
        Y.yorumlar.unshift({ m: `Canlı yayındayız. ${yarisAd(y)}: açılan sandık %${yz(pay(y.acilan_sandik, y.toplam_sandik))}${L && L.oy ? `; ${L.sad} %${yz(L.yuzde)} ile önde` : ""}.`, t: zaman(v.simdi), yeni: true });
      }
    }
    Y.yorumlar = Y.yorumlar.slice(0, 12);
    if (!Y.ilk) {
      const sesVar = typeof SES !== "undefined";
      if (kesinOldu) { if (sesVar) SES.fanfar(); if (typeof HAPTIK !== "undefined") HAPTIK.guclu(); }
      else if (yeniSandik && Date.now() - Y.sonTik > (Y.tekrar ? 1500 : 6000)) {
        Y.sonTik = Date.now(); if (sesVar) SES.tik(); if (onemli && typeof HAPTIK !== "undefined") HAPTIK.hafif();
      }
    }
    ciz();
  }

  /* ---------- Canlı veri döngüsü ---------- */
  function durdur() {
    if (Y.zamanlayici) { clearTimeout(Y.zamanlayici); Y.zamanlayici = null; }
    if (Y.saat) { clearInterval(Y.saat); Y.saat = null; }
    if (Y.tekrar && Y.tekrar.dongu) { clearInterval(Y.tekrar.dongu); }
  }
  function canliMi() { return kok() && Y.ekranNo === D._ekranNo; }
  function saatBaslat() {
    if (Y.saat) clearInterval(Y.saat);
    Y.saat = setInterval(() => {
      if (!canliMi()) { durdur(); return; }
      const s = document.getElementById("yySaat");
      const y = yaris();
      const t = Y.tekrar && y ? zaman(y.baslangic) + Y.tekrar.gecen * 1000 : suan();
      if (s) s.textContent = saniyeli(t);
      document.querySelectorAll("#yayinKok [data-yy-an]").forEach((el) => { el.textContent = kalanYaz(+el.dataset.yyAn - suan()); });
    }, 1000);
    const s = document.getElementById("yySaat"); if (s) s.textContent = saniyeli(suan());
  }
  function sonrakiPlan(v) {
    if (Y.zamanlayici) clearTimeout(Y.zamanlayici);
    const durumlar = (v.yarislar || []).map((y) => y.durum);
    if (durumlar.length && durumlar.every((d) => d === "kesin")) return;   // her şey kesinleşti
    const sayimda = durumlar.some((d) => d === "sayim");
    let ms = (v.sonraki_sn != null ? v.sonraki_sn * 1000 : 20000) + 400 + Math.floor(Math.random() * 2600);
    ms = Math.max(sayimda ? 5000 : 4000, Math.min(ms, sayimda ? 30000 : durumlar.includes("oy") ? 60000 : 20000));
    Y.zamanlayici = setTimeout(getir, ms);
  }
  async function getir() {
    if (!canliMi() || Y.tekrar) return;
    if (document.hidden || (window.YUK && YUK.otomatik && !YUK.otomatik())) { Y.zamanlayici = setTimeout(getir, 5000); return; }
    try {
      const v = await API.rpc("secim_yayini", { p_secim: Y.id });
      if (!canliMi() || Y.tekrar) return;
      Y.hata = 0; veriAl(v); sonrakiPlan(v);
    } catch (err) {
      Y.hata++;
      if (Y.hata === 2 && typeof toast === "function") toast("Canlı yayın bağlantısı zayıf; yeniden deneniyor.", true);
      Y.zamanlayici = setTimeout(getir, Math.min(60000, 5000 * Math.pow(2, Y.hata - 1)));
    }
  }
  Y.yenile = () => getir();   // testler ve elle tazeleme için
  document.addEventListener("visibilitychange", () => { if (!document.hidden && canliMi() && !Y.tekrar) { clearTimeout(Y.zamanlayici); getir(); } });

  async function yayinEkrani(sid) {
    durdur();
    Object.assign(Y, { id: sid, veri: null, sekme: sid, ilk: true, onceki: {}, oncekiYaris: {}, yorumlar: [], secilenIl: null, tekrar: null, haritaOnceki: null, hata: 0, yeniSekme: true });
    if (typeof yukleniyor === "function") yukleniyor("Seçim gecesi");
    let v;
    try { v = await API.rpc("secim_yayini", { p_secim: sid }); }
    catch (err) { Y.id = null; return eskiSecimEkrani(sid); }     // sunucu eskiyse eski ekran
    iskelet("Seçim gecesi", iskeletHtml(), { geri: true });
    Y.ekranNo = D._ekranNo;
    document.getElementById("yySes").onclick = () => { if (typeof SES === "undefined") return; SES.ayarla(!SES.kapali()); if (!SES.kapali()) SES.tik(); bantCiz(Y.veri, yaris()); };
    veriAl(v); saatBaslat(); sonrakiPlan(v);
  }
  window.secimYayiniEkrani = yayinEkrani;

  /* ---------- Yeniden izleme ---------- */
  window.yayinTekrarAc = async function (sid) {
    let t;
    try { t = await API.rpc("secim_yayini_tekrar", { p_secim: sid }); }
    catch (err) { if (typeof toast === "function") toast(typeof hataCevir === "function" ? hataCevir(err.message) : "Yeniden izleme açılamadı.", true); return; }
    if (!t || !(t.yarislar || []).length) { if (typeof toast === "function") toast("Bu seçimin gece kaydı yok.", true); return; }
    if (!kok() || Y.id !== sid) {
      ekranAc(() => yayinTekrarBaslat(sid, t));
      return;
    }
    yayinTekrarBaslat(sid, t);
  };
  function yayinTekrarBaslat(sid, t) {
    durdur();
    if (!kok() || Y.id !== sid) {
      Object.assign(Y, { id: sid, veri: null, sekme: sid, ilk: true, yorumlar: [], secilenIl: null, haritaOnceki: null, yeniSekme: true });
      iskelet("Seçim gecesi", iskeletHtml(), { geri: true });
      Y.ekranNo = D._ekranNo;
      document.getElementById("yySes").onclick = () => { if (typeof SES === "undefined") return; SES.ayarla(!SES.kapali()); bantCiz(Y.veri, yaris()); };
      saatBaslat();
    }
    const sureMax = Math.max(...t.yarislar.map((y) => +y.sure_sn || 0));
    const ilkSn = Math.min(...t.yarislar.map((y) => Math.min(...(y.sandiklar || [{ sn: 0 }]).map((s) => +s.sn))));
    const bas = Math.max(-3, ilkSn - 4);
    Y.tekrar = { veri: t, bas, son: sureMax, gecen: bas, hiz: Math.max(1, (sureMax - bas) / 75), dur: false, sonCiz: -1, dongu: null };
    Y.yorumlar = []; Y.veri = null; Y.ilk = true; Y.yeniSekme = true; Y.haritaOnceki = null;
    tekrarAdim(true);
    let onceki = performance.now();
    Y.tekrar.dongu = setInterval(() => {
      if (!canliMi() || !Y.tekrar) { durdur(); return; }
      const now = performance.now(), dt = (now - onceki) / 1000; onceki = now;
      if (!Y.tekrar.dur) Y.tekrar.gecen = Math.min(Y.tekrar.son, Y.tekrar.gecen + dt * Y.tekrar.hiz);
      tekrarAdim(false);
      if (Y.tekrar.gecen >= Y.tekrar.son && !Y.tekrar.dur) { Y.tekrar.dur = true; tekrarAdim(true); }
    }, 250);
  }
  function tekrarAdim(zorla) {
    const T = Y.tekrar; if (!T) return;
    const yarislar = T.veri.yarislar.map((y) => tekrarHesapla(y, T.gecen));
    const imza = yarislar.map((y) => y.acilan_sandik + y.durum).join("|");
    if (!zorla && imza === T.sonCiz) { evreCiz(yaris() || yarislar[0]); return; }
    T.sonCiz = imza;
    veriAl({ simdi: new Date(zaman(T.veri.yarislar[0].baslangic) + T.gecen * 1000).toISOString(), secim_id: Y.id, yarislar, sonraki_sn: null });
  }
  window.yayinTekrarKontrol = function (k) {
    const T = Y.tekrar; if (!T) return;
    if (k === "dur") { if (T.gecen >= T.son) { T.gecen = T.bas; Y.yorumlar = []; Y.veri = null; Y.ilk = true; } T.dur = !T.dur; tekrarAdim(true); }
    else if (k === "son") { T.gecen = T.son; T.dur = true; tekrarAdim(true); }
    else if (k === "bas") { T.gecen = T.bas; T.dur = false; Y.yorumlar = []; Y.veri = null; Y.ilk = true; Y.haritaOnceki = null; tekrarAdim(true); }
    else if (k === "cik") { if (T.dongu) clearInterval(T.dongu); Y.tekrar = null; yayinEkrani(Y.id); }
  };
  window.yayinAyrinti = function (sid) { ekranAc(() => { Y.atla = sid; return secimEkrani(sid); }); };

  /* ---------- Yönlendirme: sayım ve son 3 saat canlı yayında ---------- */
  const eskiSecimEkrani = window.secimEkrani;
  function yayinUygun(sid) {
    const t = ((typeof D !== "undefined" && D.durum && D.durum.takvim) || []).find((x) => x.id === sid);
    if (!t || !["mv", "cb", "cb2"].includes(t.tur)) return false;
    if (t.asama === "sayim") return true;
    if (t.asama === "bitti") return suan() - zaman(t.sonuc_at) < 3 * 3600e3;
    return false;
  }
  if (typeof eskiSecimEkrani === "function") {
    window.secimEkrani = async function (sid, sessiz) {
      if (Y.atla === sid) { Y.atla = null; await eskiSecimEkrani(sid, sessiz); return yeniIzleDugmesi(sid); }
      if (!sessiz && yayinUygun(sid)) return yayinEkrani(sid);
      const r = await eskiSecimEkrani(sid, sessiz);
      if (!sessiz) yeniIzleDugmesi(sid);
      return r;
    };
  }
  // Kesin sonuç ekranına "Seçim gecesini yeniden izle"
  function yeniIzleDugmesi(sid) {
    const ic = document.getElementById("icerik");
    if (!ic || ic.querySelector("#yyTekrarKart") || !ic.querySelector(".sonuc-sahne")) return;
    const t = ((D.durum && D.durum.takvim) || []).find((x) => x.id === sid);
    if (t && !["mv", "cb", "cb2"].includes(t.tur)) return;
    const k = document.createElement("div");
    k.id = "yyTekrarKart"; k.className = "kart";
    k.innerHTML = `<div class="yy-kb" style="margin:0"><h3>Seçim gecesi</h3><span>Sandık sandık, hızlandırılmış</span></div>
      <button class="btn altin" onclick="yayinTekrarAc(${+sid})">${IK.oynat} Seçim gecesini baştan izle</button>`;
    ic.insertAdjacentElement("afterbegin", k);
  }

  /* ---------- Gündem ve takvim kartları ---------- */
  const eskiOlayKarti = window.olayKarti;
  if (typeof eskiOlayKarti === "function") {
    window.olayKarti = function (s) {
      if (s && ["mv", "cb", "cb2"].includes(s.tur) && s.asama === "sayim") {
        const a = (Y.aktif || []).find((x) => x.secim_id === s.id);
        const ad = typeof secimTakvimAdi === "function" ? secimTakvimAdi(s) : esc(s.tur);
        const pct = a ? +a.yuzde || 0 : 0;
        const hedef = zaman(s.sonuc_at);
        return `<div class="olay yy-gundem" style="cursor:pointer" onclick="ekranAc(()=>secimEkrani(${+s.id}))"><div class="baslik"><b>${ad}</b><span class="rozet kirmizi">Canlı sayım</span></div>
          ${a ? `<div class="yy-mini"><span style="color:var(--txt)">Açılan sandık <b>%${yz(pct)}</b>${a.toplam_sandik ? ` · ${sayi(a.acilan_sandik)}/${sayi(a.toplam_sandik)}` : ""}</span><span>${a.onde ? (a.onde === "başa baş" ? "Başa baş" : "Önde: " + esc(a.onde)) : ""}</span>
            <div class="yy-ilerle"><i style="width:${Math.min(100, pct)}%"></i></div></div>`
            : `<div class="alt" style="margin-top:6px">Sandıklar kapandı. Sayım sandık sandık canlı yayında.</div>`}
          <div class="kucuk" style="margin-top:4px">Resmî sonuç ${typeof saatYaz === "function" ? saatYaz(s.sonuc_at) : ""} · <span class="sayac" style="font-size:13px;display:inline" data-an="${hedef}">${kalanYaz(hedef - suan())}</span></div>
          <button class="btn canli" onclick="event.stopPropagation();ekranAc(()=>secimEkrani(${+s.id}))">Canlı yayını izle</button></div>`;
      }
      return eskiOlayKarti(s);
    };
  }
  const eskiEkVeri = window.gundemEkVeri;
  if (typeof eskiEkVeri === "function") {
    window.gundemEkVeri = async function (iste) { const r = await eskiEkVeri(iste); Y.aktif = (r && r.canli) || []; return r; };
  }
  const eskiEkUst = window.gundemEkUst;
  if (typeof eskiEkUst === "function") {
    window.gundemEkUst = function (ek) {
      const canli = (ek && ek.canli) || [];
      if (!canli.length) return eskiEkUst(ek);
      const ilk = canli[0];
      return `<div class="yy-gbanner" role="button" tabindex="0" onclick="ekranAc(()=>secimEkrani(${+ilk.secim_id}))"><div class="ust"><span class="yy-canli">CANLI</span><b>Seçim gecesi</b><span class="kucuk">Sandıklar açılıyor</span></div>
        ${canli.map((c) => `<div class="yy-mini"><b>${c.tur === "mv" ? "Milletvekili" : c.tur === "cb2" ? "Cumhurbaşkanlığı 2. tur" : "Cumhurbaşkanlığı"}</b><span>%${yz(+c.yuzde || 0)} sandık${c.onde ? " · " + (c.onde === "başa baş" ? "başa baş" : esc(c.onde)) : ""}</span>
          <div class="yy-ilerle"><i style="width:${Math.min(100, +c.yuzde || 0)}%"></i></div></div>`).join("")}
        <span class="git">Canlı yayını izle ›</span></div>`;
    };
  }
})();
