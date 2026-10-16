/* =====================================================================
   GÖRÜNÜM CİLASI (2026-10-16) — yalnız arayüz, sunucu değişikliği yok.
   "Seçim gecesi stüdyosu" kimliği korunur; derinlik, ışık ve düzen eklenir:
   · stüdyo ışığı zemini, cam üst çubuk, katmanlı kartlar
   · yeniden tasarlanmış alt menü (kaydırılabilir, hap göstergeli, etkin sekme ortalanır)
   · düğme ailesi (ana / yumuşak / çizgili), daha okunaklı yazı hiyerarşisi
   · karşılama ekranında özellik şeritleri, giriş/kayıtta sade "Geri"
   · başlık, düğme ve menü satırlarındaki emojilerin temizlenmesi (kullanıcı içeriğine dokunmaz)
   · İngilizce teknik hata metinleri yerine Türkçe, anlaşılır mesaj
   En son yüklenir. Hiçbir oyun verisine, RPC'ye ya da kurala dokunmaz.
   ===================================================================== */
(function () {
  if (window.__gorunumCila) return; window.__gorunumCila = true;

  const CSS = `
:root{
  --panelUst:#1A2449; --kenar:rgba(164,184,255,.09); --kenar2:rgba(164,184,255,.16);
  --golge:0 1px 0 rgba(255,255,255,.035) inset,0 10px 28px -18px rgba(0,0,0,.75);
  --r:16px; --rBtn:12px;
}
/* ---- Zemin: stüdyo ışığı ---- */
#app{background:
  radial-gradient(120% 60% at 50% -12%,rgba(123,97,255,.16),transparent 60%),
  radial-gradient(90% 40% at 100% 0%,rgba(240,69,75,.06),transparent 55%),
  var(--bg)}
body{letter-spacing:.05px;text-rendering:optimizeLegibility}
.alt{color:var(--mut);line-height:1.5}
.kucuk{line-height:1.45}

/* ---- Üst çubuk: cam ---- */
.ust{background:rgba(14,21,48,.72);-webkit-backdrop-filter:saturate(160%) blur(16px);backdrop-filter:saturate(160%) blur(16px);
  border-bottom:1px solid var(--kenar);padding-bottom:11px}
.ust h1{font-size:27px;letter-spacing:-.1px}
.ust .ikon,.ust .geri{border-radius:12px;background:rgba(29,40,80,.7);box-shadow:inset 0 0 0 1px var(--kenar)}
.ust .ikon.portre-ikon{box-shadow:none;background:none}
.ust .para-cip{background:linear-gradient(180deg,rgba(123,97,255,.20),rgba(123,97,255,.08));box-shadow:inset 0 0 0 1px rgba(168,149,255,.28);color:#fff}
.ust .geri{font-size:20px}

/* ---- Kartlar ---- */
.kart,.olay{background:linear-gradient(180deg,var(--panelUst),var(--panel) 70%);box-shadow:var(--golge),inset 0 0 0 1px var(--kenar)}
.kart.duz{background:none;box-shadow:none}
.kart h2{font-size:21px;letter-spacing:-.05px}
.olay{border-left-width:3px}
.olay.oy{background:linear-gradient(90deg,rgba(240,69,75,.13),var(--panel) 60%)}
.kart.cizgili{border-left-width:3px}
.bolum-bas{margin:24px 2px 10px}
.bolum-bas h2{font-size:23px;letter-spacing:-.1px;display:flex;align-items:center;gap:9px;white-space:nowrap;flex:none}
.bolum-bas h2::before{content:"";width:4px;height:18px;border-radius:2px;background:linear-gradient(180deg,var(--ink2),var(--ink));flex:none}
.bolum-bas > :not(h2){color:var(--faint);font-size:12.5px;text-align:right;min-width:0}
.kv{padding:10px 0}
.kv .v{font-variant-numeric:tabular-nums}

/* ---- Düğmeler ---- */
.btn{background:linear-gradient(180deg,#8A73FF,var(--ink));box-shadow:0 1px 0 rgba(255,255,255,.18) inset,0 8px 20px -10px rgba(123,97,255,.9);letter-spacing:.1px;min-height:48px}
.btn.ikinci{background:rgba(40,53,99,.75);box-shadow:inset 0 0 0 1px var(--kenar2);color:var(--txt)}
.btn.altin{background:var(--inkbg);color:#C9BDFF;box-shadow:inset 0 0 0 1px rgba(168,149,255,.30)}
.btn.altin:active{background:rgba(123,97,255,.26)}
.btn.tehlike{background:var(--albg);box-shadow:inset 0 0 0 1px rgba(240,69,75,.35)}
.btn.canli{background:linear-gradient(180deg,#FF5C62,var(--al));box-shadow:0 1px 0 rgba(255,255,255,.18) inset,0 8px 20px -10px rgba(240,69,75,.9)}
.btn:disabled{opacity:.38;box-shadow:none}
.bolum-bas a,.bolum-bas button{color:var(--ink2)}

/* ---- Rozetler, segment, giriş alanları ---- */
.rozet{border-radius:7px;padding:3px 8px;letter-spacing:.1px}
.segment{background:rgba(10,16,38,.65);box-shadow:inset 0 0 0 1px var(--kenar);border-radius:12px;padding:4px}
.segment button{border-radius:9px;transition:background .15s,color .15s}
.segment button.aktif{background:linear-gradient(180deg,var(--panel3),var(--panel2));box-shadow:0 4px 12px -6px rgba(0,0,0,.7),inset 0 0 0 1px var(--kenar2)}
.alan label{color:var(--txt2);font-size:13px}
.alan input,.alan select,textarea{background:rgba(10,16,38,.7);border:1px solid var(--kenar2);border-radius:12px;transition:border-color .15s,box-shadow .15s}
.alan input:focus,.alan select:focus,textarea:focus{border-color:var(--ink2);box-shadow:0 0 0 4px rgba(123,97,255,.18)}

/* ---- Menü satırları (Ekonomi, Devlet vb.) ---- */
.giris-satir{padding:13px 2px;transition:background .12s}
.giris-satir:active{background:rgba(123,97,255,.07)}
.giris-satir .yik,.ms-yik{background:linear-gradient(180deg,rgba(123,97,255,.22),rgba(123,97,255,.08))!important;box-shadow:inset 0 0 0 1px rgba(168,149,255,.20);border-radius:11px!important;color:#C9BDFF}
.giris-satir .orta b{font-weight:700;font-size:15px;letter-spacing:.05px}
.giris-satir .ok{color:var(--faint);transition:transform .15s}
.giris-satir:active .ok{transform:translateX(2px)}
.liste-satir{padding:12px 0}

/* ---- Alt menü: kaydırılabilir, hap göstergeli ---- */
.sekmeler{background:rgba(10,16,38,.86);-webkit-backdrop-filter:saturate(160%) blur(18px);backdrop-filter:saturate(160%) blur(18px);
  border-top:1px solid var(--kenar);padding:6px 6px var(--safeB);gap:2px;scroll-snap-type:x proximity;scroll-behavior:smooth;
  -webkit-mask-image:linear-gradient(90deg,transparent 0,#000 14px,#000 calc(100% - 22px),transparent);mask-image:linear-gradient(90deg,transparent 0,#000 14px,#000 calc(100% - 22px),transparent)}
.sekmeler::-webkit-scrollbar{display:none}
.sekmeler button{flex:0 0 auto;min-width:58px;padding:4px 4px 4px;gap:4px;font-size:11px!important;letter-spacing:0!important;font-weight:600;color:var(--faint);scroll-snap-align:center;border-radius:12px}
.sekmeler button svg{width:22px!important;height:22px!important;padding:0;box-sizing:content-box}
.sekmeler button > svg{padding:4px 14px;border-radius:999px;transition:background .2s,color .2s}
.sekmeler button.aktif{color:var(--txt)}
.sekmeler button.aktif::before{display:none}
.sekmeler button.aktif > svg{background:linear-gradient(180deg,rgba(123,97,255,.34),rgba(123,97,255,.18));color:#D6CCFF;box-shadow:inset 0 0 0 1px rgba(168,149,255,.30)}
.sekmeler button:active > svg{background:rgba(123,97,255,.12)}
.sekmeler .sayi{top:0;right:calc(50% - 26px)}
.sekmeler .nokta{top:3px;right:calc(50% - 20px)}
.icerik{padding-bottom:calc(var(--safeB) + 96px)}

/* ---- Yükleniyor ---- */
.yukleniyor{color:var(--faint);font-size:13px;gap:2px}
.yukleniyor::before{width:26px;height:26px;border:2.5px solid rgba(164,184,255,.14);border-top-color:var(--ink2);border-right-color:var(--ink)}
.bos{color:var(--mut);line-height:1.5}

/* ---- Modal, bildirim ---- */
.modal{background:linear-gradient(180deg,var(--panelUst),var(--panel) 40%);box-shadow:0 -1px 0 var(--kenar2),0 -20px 50px -20px rgba(0,0,0,.8);border-radius:22px 22px 0 0}
.modal-arka{background:rgba(6,10,26,.62);-webkit-backdrop-filter:blur(3px);backdrop-filter:blur(3px)}
.toast{background:rgba(40,53,99,.92);-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);border-radius:14px;box-shadow:0 16px 36px -12px rgba(0,0,0,.7),inset 0 0 0 1px var(--kenar2)}

/* ---- Karşılama, giriş, kayıt ---- */
.karsila{background:radial-gradient(120% 55% at 50% 0%,rgba(123,97,255,.20),transparent 62%)}
.karsila h1{font-size:46px;letter-spacing:-.4px;background:linear-gradient(180deg,#fff 30%,#C9BDFF);-webkit-background-clip:text;background-clip:text;color:transparent}
.karsila .cila-ust{display:inline-flex;align-items:center;gap:8px;font-size:12px;font-weight:700;letter-spacing:.3px;color:var(--al2);margin-bottom:10px}
.karsila .cila-ust::before{content:"";width:7px;height:7px;border-radius:50%;background:var(--al);box-shadow:0 0 0 4px var(--albg);animation:nabiz 1.6s ease-in-out infinite}
.karsila .cila-seritler{display:flex;gap:8px;margin:-6px 0 22px}
.karsila .cila-seritler span{flex:1 1 0;min-width:0;padding:10px 6px;border-radius:12px;text-align:center;background:rgba(29,40,80,.6);box-shadow:inset 0 0 0 1px var(--kenar)}
.karsila .cila-seritler b{display:block;font-family:var(--disp);font-size:22px;line-height:1.05;color:#fff}
.karsila .cila-seritler small{font-size:11.5px;color:var(--mut)}
.karsila .logo{box-shadow:0 0 0 8px rgba(123,97,255,.08),0 0 40px rgba(123,97,255,.35);background:rgba(123,97,255,.08)}
.karsila .btn.cila-sade{background:none;box-shadow:none;color:var(--mut);min-height:40px;margin-top:4px}
.karsila .btn.cila-sade:active{color:var(--txt)}
@media (max-width:360px){.karsila h1{font-size:38px}.karsila .cila-seritler b{font-size:19px}.ust h1{font-size:23px}.ust .para-cip{font-size:15px;padding:0 8px}.ust{gap:6px;padding-left:14px;padding-right:12px}}
`;
  const st = document.createElement('style'); st.id = 'gorunumCila'; st.textContent = CSS;
  (document.head || document.documentElement).appendChild(st);

  /* ---- Anlaşılır hata metinleri ---- */
  try {
    if (typeof HATA_CEVIRI !== 'undefined' && Array.isArray(HATA_CEVIRI)) {
      HATA_CEVIRI.push(
        [/cannot read propert|undefined is not|null is not|is not a function|is not iterable|is not defined|invalid time value|unexpected token/i,
          'Bu bölüm şu an yüklenemedi. Biraz sonra tekrar dene.'],
        [/could not find the function|function .* does not exist|schema cache/i, 'Bu özellik sunucuda henüz açılmadı.'],
        [/permission denied|not authorized|row-level security/i, 'Bu işlem için yetkin yok.'],
        [/timeout|timed out/i, 'Sunucu geç yanıt verdi. Tekrar dene.']
      );
    }
  } catch (e) {}
  const TEKNIK = /^(TypeError|ReferenceError|SyntaxError|RangeError)?:?\s*(Cannot read propert|undefined is not|null is not|.* is not a function|.* is not iterable|.* is not defined|Invalid time value)/i;
  const DOSTCA = 'Bu bölüm şu an yüklenemedi. Biraz sonra tekrar dene.';

  /* ---- Emoji temizliği: yalnız arayüz başlıkları, düğmeler ve menü satırları ---- */
  let EMOJI;
  try { EMOJI = new RegExp('(?:\\p{Extended_Pictographic}|\\p{Regional_Indicator})(?:\\uFE0F|\\u200D(?:\\p{Extended_Pictographic})\\uFE0F?|[\\u{1F3FB}-\\u{1F3FF}])*\\s?', 'gu'); } catch (e) { EMOJI = null; }
  const HEDEF = '.ust h1, .kart h2, .kart h3, .bolum-bas h2, .olay .baslik b, .btn, .segment button, .giris-satir .orta > b, .ms-grup b, .modal h3, .modal h2, .yik + .orta b';
  const DOKUNMA = '.balon, .akis, .sohbet, input, textarea, [contenteditable], .kullanici-icerik, .parti, .portre';
  function temizle(el) {
    if (!EMOJI || !el || el.closest(DOKUNMA)) return;
    const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    const d = [];
    while (w.nextNode()) d.push(w.currentNode);
    for (const t of d) {
      if (t.parentElement && t.parentElement.closest(DOKUNMA)) continue;
      const v = t.nodeValue; EMOJI.lastIndex = 0;
      if (!EMOJI.test(v)) continue;
      EMOJI.lastIndex = 0;
      const y = v.replace(EMOJI, '');
      if (y !== v) t.nodeValue = /\S/.test(y) ? y.replace(/^\s+/, (m) => (t.previousSibling ? m : '')) : y;
    }
  }
  function hataYumusat(kok) {
    kok.querySelectorAll('.bos, .hata-metin, #icerik > p, .kart > p.alt').forEach((el) => {
      if (el.children.length === 0 && TEKNIK.test(el.textContent.trim())) el.textContent = DOSTCA;
    });
  }
  function ortala() {
    const n = document.querySelector('nav.sekmeler'); if (!n) return;
    const a = n.querySelector('button.aktif'); if (!a) return;
    const hedef = a.offsetLeft - (n.clientWidth - a.offsetWidth) / 2;
    const eski = n.style.scrollBehavior; n.style.scrollBehavior = 'auto';
    n.scrollLeft = Math.max(0, hedef);
    n.style.scrollBehavior = eski;
  }
  function karsilamaSus(kok) {
    const k = kok.querySelector('.karsila'); if (!k || k.dataset.cila) return; k.dataset.cila = '1';
    const h1 = k.querySelector('h1'), p = k.querySelector('p.giris');
    if (h1 && /Seçim Simülasyonu/.test(h1.textContent) && p) {
      const u = document.createElement('div'); u.className = 'cila-ust'; u.textContent = 'Çok oyunculu siyaset oyunu';
      h1.parentNode.insertBefore(u, h1);
      const s = document.createElement('div'); s.className = 'cila-seritler';
      s.innerHTML = '<span><b>81</b><small>il</small></span><span><b>600</b><small>milletvekili</small></span><span><b>Her ay</b><small>seçim</small></span>';
      p.after(s);
    }
    k.querySelectorAll('.btn.ikinci').forEach((b) => { if (/^\s*(Geri|Vazgeç)\s*$/.test(b.textContent)) b.classList.add('cila-sade'); });
  }
  let bekliyor = false; const kuyruk = new Set();
  function isle() {
    bekliyor = false;
    const app = document.getElementById('app') || document.body;
    const els = [...kuyruk]; kuyruk.clear();
    for (const k of els) {
      if (!k.isConnected) continue;
      if (k.matches && k.matches(HEDEF)) temizle(k);
      k.querySelectorAll && k.querySelectorAll(HEDEF).forEach(temizle);
    }
    hataYumusat(app); karsilamaSus(app); ortala();
  }
  function planla(n) { if (n.nodeType === 1) kuyruk.add(n); else if (n.parentElement) kuyruk.add(n.parentElement); if (!bekliyor) { bekliyor = true; requestAnimationFrame(isle); } }
  function baslat() {
    const kok = document.body; if (!kok) return;
    planla(kok);
    new MutationObserver((ms) => { for (const m of ms) m.addedNodes.forEach(planla); })
      .observe(kok, { childList: true, subtree: true });
  }
  if (document.body) baslat(); else document.addEventListener('DOMContentLoaded', baslat);
})();
