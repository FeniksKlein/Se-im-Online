/* =====================================================================
   İL BAŞKANLIĞI MASASI + İL BAŞKANLIKLARI (genel merkez) — 27.11.2026
   İstek (Ercan): "İl başkanlığı masası kur: yapabileceği şeyler ekle, oradaki oyuncuya yetkiler ver; ille ilgili yönetim
   kurabilsin, kararlar alabilsin, miting vs yapabilsin, iliyle ilgili açıklamalar olsun; il başkanı kendini önemli biri
   hissetsin. Genel başkan isterse kendi atasın, isterse il başkanlığı seçimi olsun; seçimler genel başkanlık seçiminden önce."
   Sunucu: sql/zz_20261127_il_baskanligi_masasi.sql
     il_masa, il_masa_genel, il_masa_benim, il_kasa_odenek, il_kasa_iade, il_kasa_bagis, il_miting_duzenle, il_miting_iptal,
     il_stant_ac, il_aciklama_yap, il_aciklamalari, il_aciklama_sil, il_karar_oner, il_karar_oy, il_karar_geri_cek,
     il_gm_yazi_gonder, il_gm_yazi_cevap, il_yk_yetki, il_baskan_yontem_ayarla, il_baskan_ata, il_baskan_gorevden_al
     (+ mevcut il_yk_ekle, il_yk_cikar, il_teskilat_detay; kongre işlemleri teskilat_kongre.js'deki ilTeskilatEkrani'nda)
   Ekranlar: ilMasasiAc(parti, il) — il örgütünün masası (sekmeler: Özet · Etkinlik · Açıklama · Kurul · Kasa · Genel merkez)
             ilBaskanliklariAc() — genel merkez: yöntem (seçim/atama), kongre haftası, gelen yazılar, 81 il karnesi
             ilBaskanligiGiris() — kişiye göre doğru ekranı açar (menü karosu, arama, bildirim)
   Girişler: Partiler ekranı kartı, teşkilat kartı, Menü › Siyaset karosu ve menü araması, bildirim rotası.
   Eski sunucuda RPC yoksa giriş kartları eklenmez.
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_IL_MASASI_V1) return;
  window.SO_IL_MASASI_V1 = true;

  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var simdiMs = function () { try { return typeof simdi === 'function' ? simdi() : Date.now(); } catch (_) { return Date.now(); } };
  var zaman = function (t) { if (!t) return ''; try { return typeof tarihSaat === 'function' ? tarihSaat(t) : new Date(t).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }); } catch (_) { return ''; } };
  var gunAy = function (t) { try { return new Date(t).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: 'numeric', month: 'long', weekday: 'long' }); } catch (_) { return ''; } };
  var saat = function (t) { try { return new Date(t).toLocaleTimeString('tr-TR', { timeZone: 'Europe/Istanbul', hour: '2-digit', minute: '2-digit' }); } catch (_) { return ''; } };
  var kisaGun = function (t) { try { return new Date(t).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: 'numeric', month: 'long' }); } catch (_) { return ''; } };
  var kisaTl = function (n) { n = Number(n || 0); var a = Math.abs(n); return a >= 1e9 ? (n / 1e9).toFixed(1).replace('.', ',') + ' Mr ₺' : a >= 1e6 ? (n / 1e6).toFixed(1).replace('.', ',') + ' Mn ₺' : a >= 1e4 ? Math.round(n / 1e3) + ' B ₺' : Math.round(n).toLocaleString('tr-TR') + ' ₺'; };
  var tl = function (n) { return Number(n || 0).toLocaleString('tr-TR', { maximumFractionDigits: 0 }) + ' ₺'; };
  var rpc = (ad, a) => API.rpc(ad, a || {});
  var ac = function (fn) { if (typeof ekranAc === 'function') ekranAc(fn); else fn(); };
  var bildir = function (m, h) { try { toast(m, h); } catch (_) {} };
  var ic = function () { return document.getElementById('icerik'); };
  var amb = function (p, boy) { try { if (typeof amblemKutu === 'function' && p) return amblemKutu(p, boy || 40); } catch (_) {} return '<span class="im-nok" style="background:' + esc((p && p.renk) || '#666') + '"></span>'; };
  var kartAc = function (kad) { try { if (kad && typeof oyuncuKart === 'function') oyuncuKart(kad); } catch (_) {} };
  var profil = function () { try { return (typeof D !== 'undefined' && D && D.durum && D.durum.profil) || null; } catch (_) { return null; } };

  var STATU = { secilmis: 'Kongrede seçildi', gecici: 'Geçici görevli', atanmis: 'Genel merkez ataması' };
  var ROL = { baskan: 'İl Başkanısın', yk: 'Yönetim kurulu üyesisin', gm: 'Genel merkez', uye: 'Partili üye' };
  var YETKI = { etkinlik: 'Miting ve stant', aciklama: 'Açıklama ve duyuru', yazisma: 'Genel merkeze yazı' };
  var KARAR = { oylama: 'Oylamada', kabul: 'Kabul edildi', ret: 'Reddedildi', dustu: 'Düştü (yeter sayı yok)', iptal: 'Geri çekildi' };
  var YAZI_TUR = { rapor: 'Rapor', oneri: 'Öneri', talep: 'Ödenek talebi', aday: 'Aday önerisi', karar: 'Yönetim kurulu kararı' };
  var YAZI_DURUM = { bekliyor: 'Yanıt bekliyor', goruldu: 'Görüldü', kabul: 'Kabul edildi', ret: 'Reddedildi' };
  var KASA_TUR = { odenek: 'Genel merkez ödeneği', bagis: 'Bağış', miting: 'Miting', stant: 'Seçim standı', iade: 'Genel merkeze aktarım' };
  var GOREVLER = ['İl Başkan Yardımcısı', 'Teşkilattan Sorumlu', 'Seçim İşleri', 'Tanıtım ve Medya', 'Mali İşler (Sayman)', 'Sekreter', 'Gençlik Kolları', 'Kadın Kolları', 'Halkla İlişkiler ve STK'];

  var S = { m: null, pid: null, il: null, sekme: 'ozet', g: null, benim: null, benimAt: 0 };

  function css() {
    if (document.getElementById('im-css')) return;
    var s = document.createElement('style'); s.id = 'im-css';
    s.textContent = [
      '.im-ust{position:relative;overflow:hidden;border-radius:18px;padding:16px;color:#fff;background:linear-gradient(135deg,var(--pr,#334) 0%,#1b2036 70%);border:1px solid rgba(255,255,255,.14)}',
      '.im-ust:after{content:"";position:absolute;inset:0;background:radial-gradient(120% 90% at 100% 0%,rgba(255,255,255,.16),transparent 55%);pointer-events:none}',
      '.im-ust>*{position:relative;z-index:1}',
      '.im-bas{display:flex;align-items:center;gap:12px}.im-bas .orta{flex:1;min-width:0}',
      '.im-bas h2{font-size:20px;font-weight:900;line-height:1.25;margin:0;overflow-wrap:anywhere}',
      '.im-bas small{display:block;font-size:13.5px;opacity:.9;margin-top:3px;line-height:1.4}',
      '.im-cipler{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}',
      '.im-cip{display:inline-flex;align-items:center;gap:5px;padding:4px 10px;border-radius:999px;font-size:13px;font-weight:800;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.2);line-height:1.3}',
      '.im-cip.altin{background:#f2c46d;color:#2a1d05;border-color:#f2c46d}.im-cip.yesil{color:#a9f0c6;border-color:#2c6e4a;background:rgba(127,224,166,.12)}',
      '.im-cip.kirmizi{color:#ffb4b4;border-color:#7a2e2e;background:rgba(230,80,80,.14)}.im-cip.gri{opacity:.8}',
      '.im-cip.canli{background:#d93a3a;border-color:#ff7a7a;color:#fff}',
      '.im-istat{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin-top:12px}',
      '.im-istat div{background:rgba(0,0,0,.25);border-radius:12px;padding:8px 4px;text-align:center;min-width:0}',
      '.im-istat b{display:block;font-size:18px;line-height:1.2}.im-istat small{display:block;font-size:11.5px;opacity:.85;line-height:1.25;margin-top:2px}',
      '.im-karne{display:flex;align-items:center;gap:10px;margin-top:12px;background:rgba(0,0,0,.22);border-radius:12px;padding:10px}',
      '.im-karne .puan{flex:none;width:52px;height:52px;border-radius:50%;display:grid;place-items:center;font-size:19px;font-weight:900;background:conic-gradient(#f2c46d calc(var(--p)*1%),rgba(255,255,255,.12) 0)}',
      '.im-karne .puan span{width:42px;height:42px;border-radius:50%;display:grid;place-items:center;background:#1b2036}',
      '.im-karne .orta{flex:1;min-width:0;font-size:13.5px;line-height:1.45}',
      '.im-seg{display:flex;gap:6px;overflow-x:auto;padding:10px 0 4px;-webkit-overflow-scrolling:touch;scrollbar-width:none}.im-seg::-webkit-scrollbar{display:none}',
      '.im-seg button{flex:none;min-height:42px;padding:6px 14px;border-radius:999px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font:inherit;font-size:14.5px;font-weight:700;display:inline-flex;align-items:center;gap:6px}',
      '.im-seg button.aktif{background:#f2c46d;color:#2a1d05;border-color:#f2c46d}',
      '.im-seg .sayi{min-width:20px;height:20px;border-radius:10px;background:#d93a3a;color:#fff;font-size:12px;display:inline-grid;place-items:center;padding:0 5px}',
      '.im-izgara{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}',
      '.im-eylem{display:flex;flex-direction:column;align-items:flex-start;gap:4px;min-height:84px;padding:12px;border-radius:14px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font:inherit;text-align:left;min-width:0}',
      '.im-eylem b{font-size:15px;line-height:1.3;overflow-wrap:anywhere}.im-eylem small{font-size:12.5px;opacity:.78;line-height:1.35;overflow-wrap:anywhere}',
      '.im-eylem .ik{font-size:20px;line-height:1}',
      '.im-eylem:disabled{opacity:.45}',
      '.im-satir{display:flex;align-items:flex-start;gap:10px;width:100%;text-align:left;padding:10px 2px;border:0;border-bottom:1px solid var(--line2,#2a3045);background:none;color:inherit;font:inherit}',
      '.im-satir:last-child{border-bottom:0}.im-satir .orta{flex:1;min-width:0}',
      '.im-satir b{font-size:15px;overflow-wrap:anywhere;line-height:1.35}.im-satir small{display:block;font-size:13px;opacity:.8;margin-top:3px;line-height:1.45;overflow-wrap:anywhere}',
      '.im-satir .sag{flex:none;text-align:right;font-size:13px}',
      '.im-metin{font-size:14.5px;line-height:1.55;white-space:pre-wrap;overflow-wrap:anywhere;margin-top:6px}',
      '.im-form label{display:block;font-size:15px;font-weight:700;margin:12px 0 6px}',
      '.im-form input,.im-form select,.im-form textarea{display:block;width:100%;min-width:0;box-sizing:border-box;font-size:16px;min-height:48px;padding:10px 12px;border-radius:12px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;color-scheme:dark;font-family:inherit}',
      '.im-form textarea{min-height:120px;line-height:1.5;resize:vertical}.im-form option{background:#151a28;color:#eef1f8}',
      '.im-form .sayac{font-size:13px;opacity:.75;text-align:right;margin-top:3px}',
      '.im-form .btn{width:100%;margin-top:12px}',
      '.im-onay{display:flex;align-items:center;gap:10px;min-height:48px;padding:8px 10px;margin:6px 0;border-radius:12px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);font-size:15px}',
      '.im-onay input{width:22px;height:22px;flex:none;margin:0}',
      '.im-hizli{display:flex;flex-wrap:wrap;gap:6px;margin-top:6px}.im-hizli button{min-height:40px;padding:6px 12px;border-radius:999px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font:inherit;font-size:14px}',
      '.im-oy{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;margin-top:8px}',
      '.im-oy button{min-height:44px;border-radius:12px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font:inherit;font-weight:800;font-size:14px}',
      '.im-oy .kabul{border-color:#2c6e4a;color:#a9f0c6}.im-oy .ret{border-color:#7a2e2e;color:#ffb4b4}',
      '.im-bar{display:flex;height:8px;border-radius:5px;overflow:hidden;background:rgba(255,255,255,.08);margin-top:6px}.im-bar i{display:block;height:100%}',
      '.im-uyari{padding:10px 12px;border-radius:12px;background:rgba(242,196,109,.12);border:1px solid #7a5d22;font-size:14px;line-height:1.5;margin:8px 0}',
      '.im-bilgi{padding:10px 12px;border-radius:12px;background:rgba(93,140,230,.1);border:1px solid rgba(93,140,230,.35);font-size:14px;line-height:1.5;margin:8px 0}',
      '.im-ozet{display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-bottom:1px solid var(--line2,#2a3045);font-size:15px;flex-wrap:wrap}.im-ozet:last-child{border-bottom:0}',
      '.im-kasa{font-size:30px;font-weight:900;margin:2px 0 4px}',
      '.im-yontem{display:grid;gap:8px;margin-top:8px}',
      '.im-yontem button{display:block;width:100%;text-align:left;padding:12px 14px;border-radius:14px;border:2px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font:inherit;min-height:64px}',
      '.im-yontem button.secili{border-color:#f2c46d;background:rgba(242,196,109,.1)}',
      '.im-yontem b{display:block;font-size:16px}.im-yontem small{display:block;font-size:13.5px;opacity:.85;line-height:1.45;margin-top:3px}',
      '.im-takvim{display:grid;gap:6px;margin-top:10px}',
      '.im-takvim>div{display:flex;align-items:center;gap:10px;border-radius:12px;padding:8px 10px;background:rgba(255,255,255,.05);border:1px solid var(--line2,#2a3045);font-size:13.5px;line-height:1.4;min-width:0}',
      '.im-takvim>div>i{flex:none;width:26px;height:26px;border-radius:50%;display:grid;place-items:center;font-style:normal;font-weight:900;font-size:13px;background:rgba(255,255,255,.1)}',
      '.im-takvim>div>span{flex:1;min-width:0}.im-takvim b{display:block;font-size:14.5px}',
      '.im-takvim>div.su{background:rgba(242,196,109,.14);border-color:#f2c46d}.im-takvim>div.su>i{background:#f2c46d;color:#2a1d05}',
      '.im-takvim>div.bitti{opacity:.6}',
      '.im-giris{display:flex;align-items:center;gap:12px;width:100%;text-align:left;min-height:60px;padding:12px 14px;border-radius:16px;border:1px solid rgba(242,196,109,.35);background:linear-gradient(135deg,rgba(242,196,109,.14),rgba(47,158,143,.16));color:inherit;font:inherit;margin:10px 0}',
      '.im-giris .orta{flex:1;min-width:0}.im-giris b{font-size:16px;display:block;overflow-wrap:anywhere}.im-giris small{display:block;font-size:13px;opacity:.85;line-height:1.4;margin-top:2px}.im-giris .ok{font-size:22px;opacity:.7}',
      '.im-ik{flex:none;width:42px;height:42px;border-radius:12px;display:grid;place-items:center;background:#f2c46d;color:#2a1d05}.im-ik svg{width:24px;height:24px}',
      '.im-nok{display:inline-block;width:12px;height:12px;border-radius:50%;flex:none}',
      '.im-ara{width:100%;min-width:0;box-sizing:border-box;font-size:16px;min-height:48px;padding:10px 14px;border-radius:12px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;color-scheme:dark;margin-bottom:6px}',
      '.im-ad-btn{background:none;border:0;color:inherit;font:inherit;padding:0;text-align:left;font-weight:800;overflow-wrap:anywhere}'
    ].join('');
    document.head.appendChild(s);
  }

  var IKON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 21h18"/><path d="M5 21V9l7-5 7 5v12"/><path d="M9 21v-5h6v5"/><path d="M12 4V2"/><path d="M12 2l3 1-3 1"/></svg>';

  /* ------------------------------------------------ küçük yardımcılar */
  function kartlariBagla(kok) { kok.querySelectorAll('[data-kart]').forEach(function (b) { b.onclick = function (ev) { ev.stopPropagation(); kartAc(b.dataset.kart); }; }); }
  function yerelDeger(d) { var p = function (n) { return String(n).padStart(2, '0'); }; return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) + 'T' + p(d.getHours()) + ':' + p(d.getMinutes()); }
  function takvimCiz(h) {
    var t = simdiMs(), a = new Date(h.acilis).getTime(), ab = new Date(h.aday_bit).getTime(), ob = new Date(h.oy_bit).getTime(), kb = new Date(h.kurultay_basvuru).getTime();
    var su = t < ab ? 0 : t < ob ? 1 : 2;
    var adim = function (i, bas, alt, bit) { return '<div class="' + (i === su ? 'su' : bit ? 'bitti' : '') + '"><i>' + (bit ? '✓' : i + 1) + '</i><span><b>' + bas + '</b>' + alt + '</span></div>'; };
    return '<div class="im-takvim">' +
      adim(0, 'Aday başvurusu', esc(kisaGun(h.acilis)) + ' ' + esc(saat(h.acilis)) + ' – ' + esc(kisaGun(h.aday_bit)) + ' ' + esc(saat(h.aday_bit)), t >= ab) +
      adim(1, 'İl kongresi oylaması', esc(gunAy(h.aday_bit)) + ' · ' + esc(saat(h.aday_bit)) + '–' + esc(saat(h.oy_bit)), t >= ob) +
      adim(2, 'Genel başkanlık seçimi (kurultay)', 'Başvurular ' + esc(gunAy(h.kurultay_basvuru)), t >= kb) + '</div>' +
      (t < a ? '<p class="kucuk" style="margin:6px 0 0">Kongre haftasının açılmasına ' + Math.max(1, Math.ceil((a - t) / 86400000)) + ' gün var.</p>' : '');
  }
  function yetkim(m, y) { return ((m && m.yetkiler) || []).indexOf(y) >= 0; }
  function adBtn(kad, ad) { return kad ? '<button type="button" class="im-ad-btn" data-kart="' + esc(kad) + '">' + esc(ad || kad) + '</button>' : esc(ad || '—'); }
  function sayacBagla(kok, id, max) { var el = kok.querySelector('#' + id), s = kok.querySelector('#' + id + 'Say'); if (el && s) { var f = function () { s.textContent = el.value.length + ' / ' + max; }; el.oninput = f; f(); } }
  function islemYap(dugme, fn, basari, sonra) {
    if (dugme) dugme.disabled = true;
    return Promise.resolve().then(fn).then(function (r) { if (basari) bildir(basari); if (sonra) sonra(r); return r; })
      .catch(function (err) { bildir(hata(err), true); })
      .then(function () { if (dugme && document.body.contains(dugme)) dugme.disabled = false; });
  }
  function kapat() { try { if (typeof modalKapat === 'function') modalKapat(); } catch (_) {} }
  function pencere(html) { css(); return typeof modal === 'function' ? modal('<div class="im-form">' + html + '</div>') : null; }

  function masaGetir(pid, il) {
    return rpc('il_masa', { p_parti: pid == null ? null : +pid, p_il: il == null ? null : +il }).then(function (m) { S.m = m; S.pid = m.parti.id; S.il = m.il.id; return m; });
  }
  function benimGetir(zorla) {
    if (!zorla && S.benim && Date.now() - S.benimAt < 60000) return Promise.resolve(S.benim);
    return rpc('il_masa_benim', {}).then(function (b) { S.benim = b; S.benimAt = Date.now(); return b; });
  }

  /* ------------------------------------------------ İL BAŞKANLIĞI MASASI */
  function masaEkrani(pid, il) {
    css();
    if (typeof iskelet === 'function') iskelet('İl Başkanlığı', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    masaGetir(pid, il).then(ciz).catch(function (err) { var x = ic(); if (x) x.innerHTML = '<div class="kart"><div class="bos">' + esc(hata(err)) + '</div></div>'; });
  }

  function ustKart(m) {
    var d = m.detay || {}, b = d.baskan, k = m.karne || {}, st = m.istatistik || {};
    var cip = [];
    if (m.rol && ROL[m.rol]) cip.push('<span class="im-cip altin">' + esc(ROL[m.rol]) + '</span>');
    cip.push('<span class="im-cip">' + (m.yontem === 'atama' ? 'İl başkanını genel merkez atar' : 'İl başkanını il kongresi seçer') + '</span>');
    if (!m.teskilat) cip.push('<span class="im-cip kirmizi">Teşkilat açılmadı</span>');
    if (st.belediye) cip.push('<span class="im-cip yesil">Belediye bizde: ' + esc(st.belediye) + '</span>');
    var puan = Math.max(0, Math.min(100, +k.puan || 0));
    return '<section class="im-ust" style="--pr:' + esc(m.parti.renk || '#445') + '">' +
      '<div class="im-bas">' + amb(m.parti, 46) + '<div class="orta"><h2>' + esc(m.parti.kisa) + ' ' + esc(m.il.ad) + ' İl Başkanlığı</h2>' +
      '<small>İl Başkanı: <b>' + (b ? adBtn(b.kad, b.ad) : 'Boş') + '</b>' + (b ? ' · ' + esc(STATU[b.statu] || b.statu) + (b.statu === 'secilmis' && b.donem_bit ? ' (dönem sonu ' + esc(zaman(b.donem_bit)) + ')' : '') : '') + '</small></div></div>' +
      '<div class="im-cipler">' + cip.join('') + '</div>' +
      '<div class="im-istat"><div><b>' + (+st.uye || 0) + '</b><small>üye</small></div><div><b>' + (+st.aktif_24s || 0) + '</b><small>son 24 saat aktif</small></div>' +
      '<div><b>+' + (+st.yeni_7g || 0) + '</b><small>bu hafta katılan</small></div><div><b>' + (+st.mv || 0) + '/' + (+m.il.mv || 0) + '</b><small>milletvekili</small></div></div>' +
      (m.teskilat ? '<div class="im-karne"><div class="puan" style="--p:' + puan + '"><span>' + puan + '</span></div><div class="orta"><b>İl karnesi: ' + puan + '/100</b><br>' +
        'Partinin ' + (+k.toplam || 0) + ' il örgütü içinde <b>' + (+k.sira || 0) + '.</b> sırada. Son 14 gün: ' + (+k.miting || 0) + ' miting, ' + (+k.stant || 0) + ' stant, ' + (+k.aciklama || 0) + ' açıklama, ' + (+k.karar || 0) + ' karar.</div></div>' : '') +
      '</section>';
  }

  function kongreKart(m) {
    var d = m.detay || {}, h = d.kongre_haftasi, k = d.kongre;
    if (m.yontem === 'atama') return '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 6px">İl başkanının belirlenmesi</h3><p class="alt" style="margin:0">' + esc(m.parti.kisa) + ' il başkanlarını <b>genel merkez ataması</b> ile belirliyor. Genel başkan ya da teşkilattan sorumlu genel başkan yardımcısı il başkanını atar ve değiştirir; il kongresi yapılmaz.</p></div>';
    var t = simdiMs(), adim = '';
    if (h) {
      adim = takvimCiz(h) +
        '<p class="alt" style="margin:8px 0 0">' + (h.bu_ilde ? 'Bu kongre haftasında <b>' + esc(m.il.ad) + '</b> il kongresi yapılacak: partinin bu ilde kayıtlı üyeleri il başkanlığına aday olur ve oy verir.' :
          'Seçilmiş il başkanının dönemi sürdüğü için bu kongre haftasında ' + esc(m.il.ad) + ' kongresi yok.') + '</p>';
    }
    var sur = k && (k.durum === 'aday' || k.durum === 'oy');
    var kd = sur ? '<div class="im-uyari"><b>' + (k.kongre_haftasi ? 'Kongre haftası' : 'İl kongresi') + ' sürüyor</b> · ' + (k.durum === 'aday' ? 'aday başvurusu ' + esc(zaman(k.aday_bit)) + '’e kadar' : 'oylama ' + esc(zaman(k.oy_bit)) + '’e kadar') +
        ' · ' + (k.adaylar || []).length + ' aday, ' + (+k.oy_sayisi || 0) + ' oy</div>' : (k && k.durum === 'tamam' ? '<p class="alt" style="margin:6px 0 0">Son kongre: ' + esc(k.kazanan_ad || k.kazanan || '') + ' seçildi.</p>' : '');
    return '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 6px">İl kongresi ve kongre haftası</h3>' +
      '<p class="alt" style="margin:0">Olağan il kongreleri her genel başkanlık seçiminden (kurultay) önce, kongre haftasında yapılır.</p>' + adim + kd +
      (typeof window.ilTeskilatEkrani === 'function' ? '<button type="button" class="btn ' + (sur ? 'altin' : 'ikinci') + '" style="margin-top:10px" id="imKongre">' + (sur ? 'Kongreye git: aday ol, oy ver' : 'Kongre ve il yönetim kurulu ayrıntısı') + '</button>' : '') + '</div>';
  }

  function sekmeler(m) {
    var bekleyen = (m.kararlar || []).filter(function (k) { return k.durum === 'oylama' && !k.oyum; }).length;
    var ls = [['ozet', 'Özet'], ['etkinlik', 'Etkinlik'], ['aciklama', 'Açıklamalar']];
    if (m.ozel) ls.push(['kurul', 'Kurul ve kararlar', bekleyen], ['kasa', 'Kasa'], ['gm', 'Genel merkez']);
    else ls.push(['kasa', 'Bağış']);
    if (!ls.some(function (x) { return x[0] === S.sekme; })) S.sekme = 'ozet';
    return '<div class="im-seg">' + ls.map(function (x) { return '<button type="button" data-sk="' + x[0] + '" class="' + (S.sekme === x[0] ? 'aktif' : '') + '">' + esc(x[1]) + (x[2] ? '<span class="sayi">' + x[2] + '</span>' : '') + '</button>'; }).join('') + '</div>';
  }

  function ciz(m) {
    var x = ic(); if (!x) return;
    m = m || S.m;
    var govde = ustKart(m) + kongreKart(m) + sekmeler(m) + '<div id="imGovde"></div>';
    if (m.gm) govde += gmIslemleri(m);
    x.innerHTML = govde;
    var kb = document.getElementById('imKongre'); if (kb) kb.onclick = function () { window.ilTeskilatEkrani(m.parti.id, m.il.id); };
    x.querySelectorAll('[data-sk]').forEach(function (b) { b.onclick = function () { S.sekme = b.dataset.sk; ciz(S.m); }; });
    var seg = x.querySelector('.im-seg'), akt = seg && seg.querySelector('.aktif');
    if (seg && akt) seg.scrollLeft = Math.max(0, akt.offsetLeft - seg.offsetLeft - (seg.clientWidth - akt.offsetWidth) / 2);
    var g = document.getElementById('imGovde');
    ({ ozet: ozetCiz, etkinlik: etkinlikCiz, aciklama: aciklamaCiz, kurul: kurulCiz, kasa: kasaCiz, gm: gmCiz }[S.sekme] || ozetCiz)(g, m);
    if (m.gm) gmBagla(x, m);
    kartlariBagla(x);
  }
  function yenile() { return masaGetir(S.pid, S.il).then(ciz); }
  function sonuc(r) { if (r && r.parti && r.il && r.detay) { S.m = r; ciz(r); } else return yenile(); }

  /* ---- Özet */
  function ozetCiz(g, m) {
    var h = m.haklar || {};
    var e = function (id, ik, ad, alt, ok) { return '<button type="button" class="im-eylem" data-e="' + id + '"' + (ok ? '' : ' disabled') + '><span class="ik">' + ik + '</span><b>' + esc(ad) + '</b><small>' + esc(alt) + '</small></button>'; };
    var eylemler = '';
    if (m.rol === 'baskan' || m.rol === 'yk') {
      eylemler = '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 10px">Masadaki işler</h3><div class="im-izgara">' +
        e('miting', '📣', 'Miting düzenle', 'İl mitingi · ' + tl(h.miting_bedel), yetkim(m, 'etkinlik') && m.teskilat) +
        e('stant', '⛺', 'Seçim standı aç', h.stant_bugun ? 'Bugün stant açıldı' : '3 saat · ' + tl(h.stant_bedel), yetkim(m, 'etkinlik') && m.teskilat && !h.stant_bugun) +
        e('aciklama', '📢', 'Açıklama yap', 'Bugün ' + (+h.aciklama_bugun || 0) + '/' + (+h.aciklama_sinir || 6), yetkim(m, 'aciklama')) +
        e('duyuru', '📌', 'Teşkilata duyuru', 'Üyelere bildirim · ' + (+h.duyuru_bugun || 0) + '/' + (+h.duyuru_sinir || 3), yetkim(m, 'aciklama')) +
        e('karar', '📒', 'Karar önergesi', 'Yönetim kurulu oylar', yetkim(m, 'karar')) +
        e('yazi', '📨', 'Genel merkeze yaz', 'Rapor, öneri, ödenek talebi', yetkim(m, 'yazisma')) +
        '</div>' + (m.rol === 'yk' ? '<p class="kucuk" style="margin:10px 0 0">Yetkilerin: ' + (((m.yetkiler || []).map(function (y) { return YETKI[y] || y; }).join(', ')) || 'yalnız karar oyu') + '. Yetkileri il başkanı verir.</p>' : '') + '</div>';
    } else {
      eylemler = '<div class="kart"><p class="alt" style="margin:0">' + (m.rol === 'gm' ? 'Genel merkez olarak bu il örgütünü izliyorsun. Masadaki işleri il başkanı ve yetki verdiği yönetim kurulu üyeleri yürütür; aşağıda genel merkez işlemleri var.' :
        'Bu il örgütünün masasını il başkanı ve yönetim kurulu yürütür. Açıklamaları ve etkinlikleri izleyebilir, il örgütüne bağış yapabilirsin.') + '</p></div>';
    }
    var son = (m.mitingler || []).slice(0, 2).map(mitingSatir).join('') + (m.stantlar || []).slice(0, 1).map(stantSatir).join('') + (m.aciklamalar || []).slice(0, 2).map(function (a) { return aciklamaSatir(a, false); }).join('');
    var yk = (m.detay && m.detay.yonetim_kurulu) || [];
    g.innerHTML = eylemler +
      '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 4px">İl yönetim kurulu</h3>' +
      (yk.length ? yk.map(function (u) { return '<div class="im-satir"><div class="orta"><b>' + adBtn(u.kad, u.ad) + '</b><small>' + esc(u.gorev || 'Üye') + '</small></div></div>'; }).join('') : '<p class="alt" style="margin:4px 0 0">Henüz yönetim kurulu kurulmadı.</p>') +
      (m.istatistik && (m.istatistik.mv_adlar || []).length ? '<p class="kucuk" style="margin:10px 0 0">İlin partili milletvekilleri: ' + esc(m.istatistik.mv_adlar.join(', ')) + '</p>' : '') + '</div>' +
      '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 4px">Son hareketler</h3>' + (son || '<p class="alt" style="margin:4px 0 0">Son günlerde il örgütünden bir hareket yok.</p>') + '</div>';
    g.querySelectorAll('[data-e]').forEach(function (b) { b.onclick = function () { ({ miting: mitingPencere, stant: stantPencere, aciklama: function () { aciklamaPencere(true); }, duyuru: function () { aciklamaPencere(false); }, karar: kararPencere, yazi: yaziPencere }[b.dataset.e])(); }; });
  }

  /* ---- Etkinlik */
  function mitingSatir(mt) {
    var t = simdiMs(), canli = mt.canli, gecti = new Date(mt.bit).getTime() < t;
    return '<div class="im-satir"><div class="orta"><b>📣 ' + esc(mt.baslik) + '</b><small>' + esc(zaman(mt.bas)) + ' · ' + (mt.il_orgut ? 'İl örgütü mitingi' : 'Genel merkez mitingi') + ' · ' + esc(mt.ad || mt.kad) +
      (mt.il_orgut ? ' · ' + (mt.odeyen === 'il' ? 'il kasasından' : 'kendi cebinden') + ' ' + tl(mt.bedel) : '') + '</small></div><div class="sag">' +
      (canli ? '<span class="im-cip canli">CANLI</span>' : gecti ? '<span class="im-cip gri">Bitti</span>' : '<span class="im-cip altin">Yakında</span>') +
      (mt.iptal_edebilir ? '<br><button type="button" class="btn ikinci" style="margin-top:6px;min-height:40px;padding:4px 10px;font-size:13px;width:auto" data-iptal="' + (+mt.id) + '">İptal</button>' : '') + '</div></div>';
  }
  function stantSatir(s) {
    return '<div class="im-satir"><div class="orta"><b>⛺ ' + esc(s.baslik) + '</b><small>' + esc(zaman(s.bas)) + '–' + esc(saat(s.bit)) + ' · ' + esc(s.ad || '') + '</small></div><div class="sag">' +
      (s.canli ? '<span class="im-cip canli">AÇIK</span>' : '<span class="im-cip gri">Kapandı</span>') + '</div></div>';
  }
  function etkinlikCiz(g, m) {
    var yet = (m.rol === 'baskan' || m.rol === 'yk') && yetkim(m, 'etkinlik') && m.teskilat, h = m.haklar || {};
    g.innerHTML = (yet ? '<div class="kart"><div class="im-izgara"><button type="button" class="im-eylem" id="imMiting"><span class="ik">📣</span><b>Miting düzenle</b><small>' + tl(h.miting_bedel) + ' · 1 saat</small></button>' +
        '<button type="button" class="im-eylem" id="imStant"' + (h.stant_bugun ? ' disabled' : '') + '><span class="ik">⛺</span><b>Seçim standı aç</b><small>' + (h.stant_bugun ? 'Bugün açıldı' : tl(h.stant_bedel) + ' · 3 saat') + '</small></button></div>' +
        '<p class="kucuk" style="margin:10px 0 0">Partinin bu ildeki iki mitingi arasında en az 3 gün olmalı (genel merkez mitingi önceliklidir). Günde ilde 1 stant. Etkinliklerde partinin bu ildeki üyelerine bildirim gider.</p></div>' : '') +
      '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 4px">Mitingler</h3>' + ((m.mitingler || []).map(mitingSatir).join('') || '<p class="alt" style="margin:4px 0 0">Son bir haftada bu ilde parti mitingi yok.</p>') + '</div>' +
      '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 4px">Seçim standları</h3>' + ((m.stantlar || []).map(stantSatir).join('') || '<p class="alt" style="margin:4px 0 0">Son bir haftada stant açılmadı.</p>') + '</div>';
    var b1 = document.getElementById('imMiting'); if (b1) b1.onclick = mitingPencere;
    var b2 = document.getElementById('imStant'); if (b2) b2.onclick = stantPencere;
    g.querySelectorAll('[data-iptal]').forEach(function (b) { b.onclick = function () {
      if (!window.confirm('Mitingi iptal etmek istiyor musun? Bedel ödendiği yere iade edilir.')) return;
      islemYap(b, function () { return rpc('il_miting_iptal', { p_miting: +b.dataset.iptal }); }, 'Miting iptal edildi, bedel iade edildi.', sonuc);
    }; });
  }
  function kaynakSecici(m, bedel) {
    var k = m.kasa || {}, cz = (m.haklar || {}).cuzdan;
    return '<label for="imKaynak">Bedeli kim ödesin? (' + tl(bedel) + ')</label><select id="imKaynak"><option value="il">İl örgütü kasası · ' + tl(k.bakiye) + '</option><option value="kendi">Kendi cüzdanım' + (cz != null ? ' · ' + tl(cz) : '') + '</option></select>';
  }
  function mitingPencere() {
    var m = S.m, h = m.haklar || {}, t = simdiMs();
    var enErken = new Date(t + 16 * 60000), enGec = new Date(t + 3 * 86400000), oner = new Date(t + 3 * 3600000); oner.setMinutes(0, 0, 0);
    var p = pencere('<h3 style="font-size:19px;font-weight:800;margin:0">' + esc(m.il.ad) + ' il mitingi</h3><p class="alt" style="margin:6px 0 0">Miting 1 saat sürer; partililer meydana gelir, konuşmalara tepki verir.</p>' +
      '<label for="imMBas">Başlık</label><input id="imMBas" maxlength="80" placeholder="Örn. ' + esc(m.il.ad) + ' büyük buluşma"><div class="sayac" id="imMBasSay"></div>' +
      '<label for="imMZaman">Başlangıç (Türkiye saati)</label><input id="imMZaman" type="datetime-local" min="' + yerelDeger(enErken) + '" max="' + yerelDeger(enGec) + '" value="' + yerelDeger(oner) + '">' +
      '<div class="im-hizli"><button type="button" data-z="60">1 saat sonra</button><button type="button" data-z="aksam">Bu akşam 20:00</button><button type="button" data-z="yarin">Yarın 20:00</button></div>' +
      kaynakSecici(m, h.miting_bedel) + '<div class="hata-metin" id="imMHata"></div>' +
      '<button type="button" class="btn altin" id="imMOk">Mitingi duyur</button><button type="button" class="btn ikinci" id="imMVaz">Vazgeç</button>');
    if (!p) return;
    sayacBagla(p, 'imMBas', 80);
    p.querySelectorAll('[data-z]').forEach(function (b) { b.onclick = function () {
      var z = new Date(simdiMs()), k = b.dataset.z;
      if (k === 'aksam') { z.setHours(20, 0, 0, 0); if (z.getTime() < simdiMs() + 16 * 60000) z.setDate(z.getDate() + 1); }
      else if (k === 'yarin') { z.setDate(z.getDate() + 1); z.setHours(20, 0, 0, 0); }
      else { z = new Date(simdiMs() + 60 * 60000); z.setSeconds(0, 0); }
      p.querySelector('#imMZaman').value = yerelDeger(z);
    }; });
    p.querySelector('#imMVaz').onclick = kapat;
    var ok = p.querySelector('#imMOk');
    ok.onclick = function () {
      var he = p.querySelector('#imMHata'), bas = p.querySelector('#imMBas').value.trim(), z = new Date(p.querySelector('#imMZaman').value);
      he.textContent = '';
      if (bas.length < 3) { he.textContent = 'Başlık en az 3 karakter olmalı.'; return; }
      if (isNaN(z.getTime())) { he.textContent = 'Başlangıç zamanını seç.'; return; }
      islemYap(ok, function () { return rpc('il_miting_duzenle', { p_bas: z.toISOString(), p_baslik: bas, p_kaynak: p.querySelector('#imKaynak').value }); },
        'Miting duyuruldu. Partinin ' + m.il.ad + ' üyelerine haber verildi.', function () { kapat(); S.sekme = 'etkinlik'; yenile(); });
    };
  }
  function stantPencere() {
    var m = S.m, h = m.haklar || {};
    var p = pencere('<h3 style="font-size:19px;font-weight:800;margin:0">Seçim standı aç</h3><p class="alt" style="margin:6px 0 0">Stant hemen açılır ve 3 saat kalır. Partililer gönüllü olarak katılır, vatandaşlar uğrayıp soru sorar.</p>' +
      '<label for="imSBas">Stant başlığı</label><input id="imSBas" maxlength="80" placeholder="Örn. Kadıköy iskele meydanı standı"><div class="sayac" id="imSBasSay"></div>' +
      kaynakSecici(m, h.stant_bedel) + '<div class="hata-metin" id="imSHata"></div>' +
      '<button type="button" class="btn altin" id="imSOk">Standı aç</button><button type="button" class="btn ikinci" id="imSVaz">Vazgeç</button>');
    if (!p) return;
    sayacBagla(p, 'imSBas', 80);
    p.querySelector('#imSVaz').onclick = kapat;
    var ok = p.querySelector('#imSOk');
    ok.onclick = function () {
      var bas = p.querySelector('#imSBas').value.trim();
      if (bas.length < 3) { p.querySelector('#imSHata').textContent = 'Başlık en az 3 karakter olmalı.'; return; }
      islemYap(ok, function () { return rpc('il_stant_ac', { p_baslik: bas, p_kaynak: p.querySelector('#imKaynak').value }); }, 'Stant açıldı.', function () { kapat(); S.sekme = 'etkinlik'; yenile(); });
    };
  }

  /* ---- Açıklamalar */
  function aciklamaSatir(a, tam) {
    return '<div class="im-satir" style="display:block"><div style="display:flex;gap:8px;align-items:flex-start"><div style="flex:1;min-width:0"><b>' + (a.kamu ? '📢 ' : '📌 ') + esc(a.baslik) + '</b>' +
      '<small>' + esc(zaman(a.zaman)) + ' · ' + (a.kamu ? 'Kamuya açık açıklama' : 'Teşkilat içi duyuru') + ' · ' + esc(a.ad || a.kad) + (a.rol === 'baskan' ? ' (İl Başkanı)' : ' (Yönetim kurulu)') + '</small></div>' +
      (tam && a.silebilir ? '<button type="button" class="btn ikinci" style="width:auto;min-height:40px;padding:4px 10px;font-size:13px;margin:0" data-sil="' + (+a.id) + '">Kaldır</button>' : '') + '</div>' +
      '<div class="im-metin">' + esc(tam ? a.metin : String(a.metin || '').slice(0, 180) + (String(a.metin || '').length > 180 ? '…' : '')) + '</div></div>';
  }
  function aciklamaCiz(g, m) {
    var yet = (m.rol === 'baskan' || m.rol === 'yk') && yetkim(m, 'aciklama'), h = m.haklar || {};
    var bekle = h.sonraki_aciklama && new Date(h.sonraki_aciklama).getTime() > simdiMs();
    g.innerHTML = (yet ? '<div class="kart"><div class="im-izgara"><button type="button" class="im-eylem" id="imAc"' + (bekle ? ' disabled' : '') + '><span class="ik">📢</span><b>Kamuya açıklama</b><small>Kürsü’de il başkanlığı adıyla · bugün ' + (+h.aciklama_bugun || 0) + '/' + (+h.aciklama_sinir || 6) + '</small></button>' +
        '<button type="button" class="im-eylem" id="imDy"' + (bekle ? ' disabled' : '') + '><span class="ik">📌</span><b>Teşkilata duyuru</b><small>İldeki partililere bildirim · bugün ' + (+h.duyuru_bugun || 0) + '/' + (+h.duyuru_sinir || 3) + '</small></button></div>' +
        (bekle ? '<p class="kucuk" style="margin:10px 0 0">Sonraki açıklama ' + esc(saat(h.sonraki_aciklama)) + '’den sonra yapılabilir (iki açıklama arasında 20 dakika).</p>' : '') + '</div>' : '') +
      '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 4px">İl başkanlığı açıklamaları</h3>' + ((m.aciklamalar || []).map(function (a) { return aciklamaSatir(a, true); }).join('') || '<p class="alt" style="margin:4px 0 0">Henüz açıklama yapılmadı.</p>') +
      ((m.aciklamalar || []).length >= 20 && !m.aciklama_son ? '<button type="button" class="btn ikinci" id="imAcDaha" style="margin-top:8px">Daha eski açıklamalar</button>' : '') + '</div>';
    var a1 = document.getElementById('imAc'); if (a1) a1.onclick = function () { aciklamaPencere(true); };
    var a2 = document.getElementById('imDy'); if (a2) a2.onclick = function () { aciklamaPencere(false); };
    var dh = document.getElementById('imAcDaha'); if (dh) dh.onclick = function () {
      var ls = m.aciklamalar || [], once = Math.min.apply(null, ls.map(function (a) { return +a.id; }));
      islemYap(dh, function () { return rpc('il_aciklamalari', { p_parti: m.parti.id, p_il: m.il.id, p_once: once }); }, null, function (r) {
        r = r || []; m.aciklamalar = ls.concat(r); if (r.length < 20) m.aciklama_son = true; aciklamaCiz(g, m);
      });
    };
    g.querySelectorAll('[data-sil]').forEach(function (b) { b.onclick = function () {
      if (!window.confirm('Bu açıklamayı kaldırmak istiyor musun?')) return;
      islemYap(b, function () { return rpc('il_aciklama_sil', { p_id: +b.dataset.sil }); }, 'Açıklama kaldırıldı.', function () { yenile(); });
    }; });
  }
  function aciklamaPencere(kamu) {
    var m = S.m;
    var p = pencere('<h3 style="font-size:19px;font-weight:800;margin:0">' + (kamu ? esc(m.il.ad) + ' İl Başkanlığı açıklaması' : 'Teşkilat içi duyuru') + '</h3>' +
      '<p class="alt" style="margin:6px 0 0">' + (kamu ? 'Açıklama Kürsü’de “' + esc(m.parti.ad) + ' ' + esc(m.il.ad) + ' İl Başkanlığı” adıyla yayımlanır ve il gündemine düşer.' : 'Duyuru partinin ' + esc(m.il.ad) + ' ilindeki bütün üyelerine bildirim olarak gider.') + ' Bölücü, hakaret ve küfür içeren metinler yayımlanmaz.</p>' +
      '<label for="imABas">Başlık</label><input id="imABas" maxlength="120"><div class="sayac" id="imABasSay"></div>' +
      '<label for="imAMet">Metin</label><textarea id="imAMet" maxlength="3000" placeholder="' + (kamu ? 'İlimizle ilgili tutumumuzu, çağrımızı ya da tepkimizi yaz.' : 'Toplantı, saha çalışması, görev dağılımı…') + '"></textarea><div class="sayac" id="imAMetSay"></div>' +
      '<div class="hata-metin" id="imAHata"></div><button type="button" class="btn altin" id="imAOk">' + (kamu ? 'Açıklamayı yayımla' : 'Duyuruyu gönder') + '</button><button type="button" class="btn ikinci" id="imAVaz">Vazgeç</button>');
    if (!p) return;
    sayacBagla(p, 'imABas', 120); sayacBagla(p, 'imAMet', 3000);
    p.querySelector('#imAVaz').onclick = kapat;
    var ok = p.querySelector('#imAOk');
    ok.onclick = function () {
      var he = p.querySelector('#imAHata'), b = p.querySelector('#imABas').value.trim(), t = p.querySelector('#imAMet').value.trim();
      if (b.length < 3) { he.textContent = 'Başlık en az 3 karakter olmalı.'; return; }
      if (t.length < 10) { he.textContent = 'Metin en az 10 karakter olmalı.'; return; }
      islemYap(ok, function () { return rpc('il_aciklama_yap', { p_baslik: b, p_metin: t, p_kamu: kamu }); }, kamu ? 'Açıklama yayımlandı.' : 'Duyuru gönderildi.', function (r) { kapat(); S.sekme = 'aciklama'; sonuc(r); });
    };
  }

  /* ---- Kurul ve kararlar */
  function kurulCiz(g, m) {
    var yk = (m.detay && m.detay.yonetim_kurulu) || [], baskan = m.rol === 'baskan', yonet = baskan || m.gm;
    var kurulSayi = yk.length + ((m.detay && m.detay.baskan) ? 1 : 0);
    var ykHtml = yk.map(function (u) {
      return '<div class="im-satir"><div class="orta"><b>' + adBtn(u.kad, u.ad) + '</b><small>' + esc(u.gorev || 'Üye') + ' · ' + (((u.yetkiler || []).map(function (y) { return YETKI[y] || y; }).join(', ')) || 'yalnız karar oyu') + '</small></div>' +
        (yonet ? '<div class="sag"><button type="button" class="btn ikinci" style="width:auto;min-height:40px;padding:4px 10px;font-size:13px;margin:0 0 4px" data-ytk="' + esc(u.kad) + '">Yetki</button><br><button type="button" class="btn ikinci" style="width:auto;min-height:40px;padding:4px 10px;font-size:13px;margin:0" data-cikar="' + esc(u.kad) + '">Çıkar</button></div>' : '') + '</div>';
    }).join('');
    var kararlar = (m.kararlar || []).map(function (k) {
      var kurulda = m.rol === 'baskan' || m.rol === 'yk';
      return '<div class="im-satir" style="display:block"><b>📒 ' + esc(k.no) + ' · ' + esc(k.baslik) + '</b><small>' + (k.tur === 'oneri' ? 'Genel merkeze öneri' : 'Genel karar') + ' · ' + esc(k.oneren || '') + ' · ' +
        (k.olur ? 'İl Başkanı oluru' : esc(KARAR[k.durum] || k.durum) + (k.durum === 'oylama' ? ' · ' + esc(zaman(k.bitis)) + '’e kadar' : '')) +
        (k.olur ? '' : ' · kabul ' + (+k.kabul || 0) + ', ret ' + (+k.ret || 0) + ', çekimser ' + (+k.cekimser || 0) + ' (kurul ' + (+k.kurul || 0) + ')') + '</small>' +
        '<div class="im-metin">' + esc(k.metin) + '</div>' +
        (k.durum === 'oylama' && kurulda && !k.oyum ? '<div class="im-oy"><button type="button" class="kabul" data-oy="kabul" data-k="' + (+k.id) + '">Kabul</button><button type="button" class="ret" data-oy="ret" data-k="' + (+k.id) + '">Ret</button><button type="button" data-oy="cekimser" data-k="' + (+k.id) + '">Çekimser</button></div>' : '') +
        (k.oyum ? '<p class="kucuk" style="margin:6px 0 0">Oyun: ' + esc({ kabul: 'Kabul', ret: 'Ret', cekimser: 'Çekimser' }[k.oyum] || k.oyum) + '</p>' : '') +
        (k.durum === 'oylama' && baskan ? '<button type="button" class="btn ikinci" style="margin-top:6px" data-geri="' + (+k.id) + '">Önergeyi geri çek</button>' : '') + '</div>';
    }).join('');
    g.innerHTML = '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 4px">İl yönetim kurulu (' + yk.length + '/' + (+m.yk_azami || 7) + ')</h3>' +
      '<p class="alt" style="margin:0 0 4px">Kurul il başkanı ile birlikte kararları oylar. İl başkanı üyelere miting/stant, açıklama ve genel merkeze yazı yetkisi verebilir.</p>' +
      (ykHtml || '<p class="alt" style="margin:4px 0 0">Kurulda henüz üye yok.</p>') +
      (yonet && m.detay && m.detay.baskan && yk.length < (+m.yk_azami || 7) ? '<button type="button" class="btn altin" id="imYkEkle" style="margin-top:10px">Kurula üye ekle</button>' : '') + '</div>' +
      '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 4px">Karar defteri</h3>' +
      '<p class="alt" style="margin:0 0 4px">' + (kurulSayi >= 3 ? 'Önergeler 24 saat oylanır; kurulun yarıdan fazlası oy vermezse önerge düşer, oy verenlerin çoğunluğuyla karar alınır.' : 'Kurul (il başkanı + en az 2 üye) kurulana kadar kararlar il başkanının oluruyla alınır.') + '</p>' +
      (baskan ? '<button type="button" class="btn altin" id="imKarar" style="margin:6px 0">Karar önergesi getir</button>' : '') + (kararlar || '<p class="alt" style="margin:4px 0 0">Henüz karar yok.</p>') + '</div>';
    var ek = document.getElementById('imYkEkle'); if (ek) ek.onclick = ykEklePencere;
    var kb = document.getElementById('imKarar'); if (kb) kb.onclick = kararPencere;
    g.querySelectorAll('[data-oy]').forEach(function (b) { b.onclick = function () {
      islemYap(b, function () { return rpc('il_karar_oy', { p_karar: +b.dataset.k, p_oy: b.dataset.oy }); }, 'Oyun kaydedildi.', sonuc);
    }; });
    g.querySelectorAll('[data-geri]').forEach(function (b) { b.onclick = function () {
      if (!window.confirm('Önergeyi geri çekmek istiyor musun?')) return;
      islemYap(b, function () { return rpc('il_karar_geri_cek', { p_karar: +b.dataset.geri }); }, 'Önerge geri çekildi.', sonuc);
    }; });
    g.querySelectorAll('[data-cikar]').forEach(function (b) { b.onclick = function () {
      if (!window.confirm('Bu üyeyi il yönetim kurulundan çıkarmak istiyor musun?')) return;
      islemYap(b, function () { return rpc('il_yk_cikar', { p_il: m.il.id, p_kad: b.dataset.cikar }); }, 'Üye kuruldan çıkarıldı.', function () { yenile(); });
    }; });
    g.querySelectorAll('[data-ytk]').forEach(function (b) { b.onclick = function () { yetkiPencere(b.dataset.ytk); }; });
  }
  function ykEklePencere() {
    var m = S.m, aday = (m.uyeler || []).filter(function (u) { return !u.yk && !u.baskan; });
    var p = pencere('<h3 style="font-size:19px;font-weight:800;margin:0">İl yönetim kuruluna üye ekle</h3><p class="alt" style="margin:6px 0 0">Kurula yalnız partinin ' + esc(m.il.ad) + ' ilinde kayıtlı üyeleri girer.</p>' +
      '<label for="imYkAra">Üye ara</label><input id="imYkAra" class="im-ara" type="search" placeholder="Ad soyad ya da kullanıcı adı" autocomplete="off">' +
      '<label for="imYkKad">Üye</label><select id="imYkKad"></select>' +
      '<label for="imYkGorev">Görevi</label><select id="imYkGorev">' + GOREVLER.map(function (x) { return '<option>' + esc(x) + '</option>'; }).join('') + '<option value="">Görevsiz üye</option></select>' +
      '<div class="hata-metin" id="imYkHata"></div><button type="button" class="btn altin" id="imYkOk">Kurula ekle</button><button type="button" class="btn ikinci" id="imYkVaz">Vazgeç</button>');
    if (!p) return;
    var sec = p.querySelector('#imYkKad'), ara = p.querySelector('#imYkAra');
    var doldur = function () {
      var q = (ara.value || '').toLocaleLowerCase('tr-TR').trim();
      var ls = aday.filter(function (u) { return !q || String(u.ad + ' ' + u.kad).toLocaleLowerCase('tr-TR').indexOf(q) >= 0; }).slice(0, 200);
      sec.innerHTML = ls.length ? ls.map(function (u) { return '<option value="' + esc(u.kad) + '">' + esc(u.ad) + (u.ad !== u.kad ? ' (' + esc(u.kad) + ')' : '') + '</option>'; }).join('') : '<option value="">Uygun üye yok</option>';
    };
    ara.oninput = doldur; doldur();
    p.querySelector('#imYkVaz').onclick = kapat;
    var ok = p.querySelector('#imYkOk');
    ok.onclick = function () {
      if (!sec.value) { p.querySelector('#imYkHata').textContent = 'Önce üyeyi seç.'; return; }
      islemYap(ok, function () { return rpc('il_yk_ekle', { p_il: m.il.id, p_kad: sec.value, p_gorev: p.querySelector('#imYkGorev').value }); }, 'Üye il yönetim kuruluna alındı.', function () { kapat(); S.sekme = 'kurul'; yenile(); });
    };
  }
  function yetkiPencere(kad) {
    var m = S.m, u = ((m.detay && m.detay.yonetim_kurulu) || []).filter(function (x) { return x.kad === kad; })[0] || { yetkiler: [] };
    var p = pencere('<h3 style="font-size:19px;font-weight:800;margin:0">' + esc(u.ad || kad) + ' · yetkiler</h3><p class="alt" style="margin:6px 0 0">Yetki verdiğin üye il başkanlığı adına işlem yapar; işlemler masada adıyla görünür.</p>' +
      Object.keys(YETKI).map(function (y) { return '<label class="im-onay"><input type="checkbox" value="' + y + '"' + ((u.yetkiler || []).indexOf(y) >= 0 ? ' checked' : '') + '> ' + esc(YETKI[y]) + '</label>'; }).join('') +
      '<button type="button" class="btn altin" id="imYtOk">Kaydet</button><button type="button" class="btn ikinci" id="imYtVaz">Vazgeç</button>');
    if (!p) return;
    p.querySelector('#imYtVaz').onclick = kapat;
    var ok = p.querySelector('#imYtOk');
    ok.onclick = function () {
      var ls = [].slice.call(p.querySelectorAll('input[type=checkbox]:checked')).map(function (c) { return c.value; });
      islemYap(ok, function () { return rpc('il_yk_yetki', { p_il: m.il.id, p_kad: kad, p_yetkiler: ls }); }, 'Yetkiler güncellendi.', function (r) { kapat(); sonuc(r); });
    };
  }
  function kararPencere() {
    var m = S.m;
    var p = pencere('<h3 style="font-size:19px;font-weight:800;margin:0">Karar önergesi</h3>' +
      '<label for="imKTur">Türü</label><select id="imKTur"><option value="genel">Genel karar (il gündemine yazılır)</option><option value="oneri">Genel merkeze öneri (kabul edilirse genel merkeze iletilir)</option></select>' +
      '<label for="imKBas">Başlık</label><input id="imKBas" maxlength="120" placeholder="Örn. Kongre hazırlık komisyonu kurulması"><div class="sayac" id="imKBasSay"></div>' +
      '<label for="imKMet">Karar metni</label><textarea id="imKMet" maxlength="2000" placeholder="Ne karara bağlanıyor? Kim, ne zaman, nasıl?"></textarea><div class="sayac" id="imKMetSay"></div>' +
      '<div class="hata-metin" id="imKHata"></div><button type="button" class="btn altin" id="imKOk">Önergeyi kurula getir</button><button type="button" class="btn ikinci" id="imKVaz">Vazgeç</button>');
    if (!p) return;
    sayacBagla(p, 'imKBas', 120); sayacBagla(p, 'imKMet', 2000);
    p.querySelector('#imKVaz').onclick = kapat;
    var ok = p.querySelector('#imKOk');
    ok.onclick = function () {
      var he = p.querySelector('#imKHata'), b = p.querySelector('#imKBas').value.trim(), t = p.querySelector('#imKMet').value.trim();
      if (b.length < 5) { he.textContent = 'Başlık en az 5 karakter olmalı.'; return; }
      if (t.length < 20) { he.textContent = 'Karar metni en az 20 karakter olmalı.'; return; }
      islemYap(ok, function () { return rpc('il_karar_oner', { p_tur: p.querySelector('#imKTur').value, p_baslik: b, p_metin: t }); }, 'Önerge kurula getirildi.', function (r) { kapat(); S.sekme = 'kurul'; sonuc(r); });
    };
  }

  /* ---- Kasa */
  function kasaCiz(g, m) {
    var k = m.kasa;
    var hareket = k ? (k.hareket || []).map(function (h) {
      return '<div class="im-satir"><div class="orta"><b>' + esc(KASA_TUR[h.tur] || h.tur) + '</b><small>' + esc(h.aciklama || '') + ' · ' + esc(zaman(h.zaman)) + '</small></div><div class="sag" style="font-weight:800;color:' + (+h.tutar >= 0 ? '#7fe0a6' : '#ffb4b4') + '">' + (+h.tutar >= 0 ? '+' : '') + tl(h.tutar) + '</div></div>';
    }).join('') : '';
    g.innerHTML = (k ? '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0">İl örgütü kasası</h3><div class="im-kasa">' + tl(k.bakiye) + '</div>' +
        '<p class="alt" style="margin:0">Kasa genel merkez ödeneği ve bağışlarla dolar; yalnız il etkinliklerine (miting, stant) harcanır, kişilere para çıkmaz. Ödenek için Genel merkez sekmesinden talep yazabilirsin.</p></div>' +
        '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 4px">Kasa hareketleri</h3>' + (hareket || '<p class="alt" style="margin:4px 0 0">Henüz hareket yok.</p>') + '</div>' : '') +
      '<div class="kart im-form"><h3 style="font-size:17px;font-weight:800;margin:0">İl örgütüne bağış</h3><p class="alt" style="margin:6px 0 0">' + esc(m.parti.kisa) + ' ' + esc(m.il.ad) + ' il örgütünün mitinglerine ve standlarına katkı ver. Bağış cüzdanından düşer.</p>' +
      '<label for="imBTut">Tutar (₺)</label><input id="imBTut" type="number" inputmode="numeric" min="100" max="10000000" step="100" placeholder="Örn. 5000">' +
      '<div class="hata-metin" id="imBHata"></div><button type="button" class="btn altin" id="imBOk"' + (m.teskilat ? '' : ' disabled') + '>Bağış yap</button></div>';
    var ok = document.getElementById('imBOk');
    if (ok) ok.onclick = function () {
      var v = Math.round(+document.getElementById('imBTut').value || 0);
      if (v < 100) { document.getElementById('imBHata').textContent = 'En az 100 ₺ bağışlayabilirsin.'; return; }
      if (!window.confirm(tl(v) + ' bağışlamak istiyor musun?')) return;
      islemYap(ok, function () { return rpc('il_kasa_bagis', { p_parti: m.parti.id, p_il: m.il.id, p_tutar: v }); }, 'Bağışın için teşekkürler!', function () { yenile(); });
    };
  }

  /* ---- Genel merkez yazışmaları (il tarafı) */
  function gmCiz(g, m) {
    var yet = (m.rol === 'baskan' || m.rol === 'yk') && yetkim(m, 'yazisma'), h = m.haklar || {};
    var ls = (m.yazilar || []).map(function (y) {
      return '<div class="im-satir" style="display:block"><b>📨 ' + esc(YAZI_TUR[y.tur] || y.tur) + ': ' + esc(y.baslik) + '</b>' +
        '<small>' + esc(zaman(y.zaman)) + ' · ' + esc(y.gonderen || '') + (y.tutar ? ' · ' + tl(y.tutar) : '') + (y.ilgili ? ' · önerilen: ' + esc(y.ilgili) : '') + '</small>' +
        '<div class="im-cipler"><span class="im-cip ' + (y.durum === 'kabul' ? 'yesil' : y.durum === 'ret' ? 'kirmizi' : 'gri') + '">' + esc(YAZI_DURUM[y.durum] || y.durum) + '</span></div>' +
        '<div class="im-metin">' + esc(y.metin) + '</div>' + (y.cevap ? '<div class="im-bilgi"><b>Genel merkezin yanıtı' + (y.cevaplayan ? ' (' + esc(y.cevaplayan) + ')' : '') + ':</b> ' + esc(y.cevap) + '</div>' : '') + '</div>';
    }).join('');
    g.innerHTML = (yet ? '<div class="kart"><button type="button" class="btn altin" id="imYaz">Genel merkeze yaz</button><p class="kucuk" style="margin:8px 0 0">24 saatte en çok ' + (+h.yazi_sinir || 3) + ' yazı (' + (+h.yazi_24s || 0) + ' gönderildi). Ödenek talebi kabul edilirse para il kasasına aktarılır.</p></div>' : '') +
      '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 4px">Genel merkezle yazışmalar</h3>' + (ls || '<p class="alt" style="margin:4px 0 0">Henüz yazı yok.</p>') + '</div>';
    var b = document.getElementById('imYaz'); if (b) b.onclick = yaziPencere;
  }
  function yaziPencere() {
    var m = S.m, uyeler = m.uyeler || [];
    var p = pencere('<h3 style="font-size:19px;font-weight:800;margin:0">Genel merkeze yazı</h3>' +
      '<label for="imYTur">Yazının türü</label><select id="imYTur"><option value="rapor">Rapor (ildeki durum)</option><option value="oneri">Öneri</option><option value="talep">Ödenek talebi</option><option value="aday">Aday önerisi (MV ya da belediye)</option></select>' +
      '<div id="imYTutarK" hidden><label for="imYTutar">Talep edilen ödenek (₺)</label><input id="imYTutar" type="number" inputmode="numeric" min="1000" step="1000" placeholder="Örn. 50000"></div>' +
      '<div id="imYAdayK" hidden><label for="imYAday">Önerilen üye</label><select id="imYAday">' + uyeler.map(function (u) { return '<option value="' + esc(u.kad) + '">' + esc(u.ad) + (u.ad !== u.kad ? ' (' + esc(u.kad) + ')' : '') + '</option>'; }).join('') + '</select></div>' +
      '<label for="imYBas">Başlık</label><input id="imYBas" maxlength="120"><div class="sayac" id="imYBasSay"></div>' +
      '<label for="imYMet">Yazı</label><textarea id="imYMet" maxlength="3000" placeholder="Durumu, gerekçeyi ve isteğini açıkça yaz."></textarea><div class="sayac" id="imYMetSay"></div>' +
      '<div class="hata-metin" id="imYHata"></div><button type="button" class="btn altin" id="imYOk">Gönder</button><button type="button" class="btn ikinci" id="imYVaz">Vazgeç</button>');
    if (!p) return;
    sayacBagla(p, 'imYBas', 120); sayacBagla(p, 'imYMet', 3000);
    var tur = p.querySelector('#imYTur');
    tur.onchange = function () { p.querySelector('#imYTutarK').hidden = tur.value !== 'talep'; p.querySelector('#imYAdayK').hidden = tur.value !== 'aday'; };
    p.querySelector('#imYVaz').onclick = kapat;
    var ok = p.querySelector('#imYOk');
    ok.onclick = function () {
      var he = p.querySelector('#imYHata'), b = p.querySelector('#imYBas').value.trim(), t = p.querySelector('#imYMet').value.trim(), tu = tur.value;
      var tutar = tu === 'talep' ? Math.round(+p.querySelector('#imYTutar').value || 0) : null, ilg = tu === 'aday' ? p.querySelector('#imYAday').value : null;
      if (b.length < 5) { he.textContent = 'Başlık en az 5 karakter olmalı.'; return; }
      if (t.length < 20) { he.textContent = 'Yazı en az 20 karakter olmalı.'; return; }
      if (tu === 'talep' && tutar < 1000) { he.textContent = 'Ödenek talebi en az 1.000 ₺ olmalı.'; return; }
      if (tu === 'aday' && !ilg) { he.textContent = 'Önerdiğin üyeyi seç.'; return; }
      islemYap(ok, function () { return rpc('il_gm_yazi_gonder', { p_tur: tu, p_baslik: b, p_metin: t, p_tutar: tutar, p_ilgili: ilg }); }, 'Yazı genel merkeze gönderildi.', function (r) { kapat(); S.sekme = 'gm'; sonuc(r); });
    };
  }

  /* ---- Genel merkez işlemleri (masa altında, yalnız genel merkeze) */
  function gmIslemleri(m) {
    var d = m.detay || {}, b = d.baskan, k = m.kasa || {};
    var secilmisKilit = m.yontem === 'secim' && b && b.statu === 'secilmis';
    return '<div class="kart im-form" id="imGm"><h3 style="font-size:17px;font-weight:800;margin:0">Genel merkez işlemleri · ' + esc(m.il.ad) + '</h3>' +
      '<p class="alt" style="margin:6px 0 0">' + (m.yontem === 'atama' ? 'Partin atama yönteminde: il başkanını doğrudan atayabilir, değiştirebilir ya da görevden alabilirsin.' :
        'Partin seçim yönteminde: il başkanlığı boşsa ya da geçiciyse geçici il başkanı görevlendirebilirsin; seçilmiş başkan ancak gerekçeli görevden almayla (olağanüstü kongre) değişir.') + '</p>' +
      (!secilmisKilit && (m.uyeler || []).length ? '<label for="imGmAta">' + (m.yontem === 'atama' ? 'İl başkanı ata' : 'Geçici il başkanı görevlendir') + '</label><select id="imGmAta">' +
        (m.uyeler || []).filter(function (u) { return !u.baskan; }).map(function (u) { return '<option value="' + esc(u.kad) + '">' + esc(u.ad) + (u.ad !== u.kad ? ' (' + esc(u.kad) + ')' : '') + '</option>'; }).join('') + '</select>' +
        '<button type="button" class="btn altin" id="imGmAtaOk">' + (m.yontem === 'atama' ? 'İl başkanı olarak ata' : 'Geçici il başkanı yap') + '</button>' : '') +
      (b ? '<label for="imGmGer">Görevden alma gerekçesi</label><textarea id="imGmGer" maxlength="300" style="min-height:80px" placeholder="En az ' + (m.yontem === 'atama' ? 10 : 20) + ' karakter"></textarea>' +
        '<button type="button" class="btn ikinci" id="imGmAl">' + esc(b.ad || b.kad) + ' görevden al' + (m.yontem === 'secim' ? ' (olağanüstü kongre açılır)' : '') + '</button>' : '') +
      (m.mali && m.teskilat ? '<label for="imGmOd">İl kasasına ödenek (parti kasası: ' + tl(k.parti_kasa) + ')</label><input id="imGmOd" type="number" inputmode="numeric" min="1000" step="1000" placeholder="Örn. 25000">' +
        '<button type="button" class="btn altin" id="imGmOdOk">Ödenek gönder</button>' +
        '<label for="imGmIa">İl kasasından genel merkeze aktar (kasada ' + tl(k.bakiye) + ')</label><input id="imGmIa" type="number" inputmode="numeric" min="100" step="100">' +
        '<button type="button" class="btn ikinci" id="imGmIaOk">Genel merkeze aktar</button>' : '') + '</div>';
  }
  function gmBagla(x, m) {
    var q = function (id) { return x.querySelector('#' + id); };
    var ata = q('imGmAtaOk'); if (ata) ata.onclick = function () {
      var kad = q('imGmAta').value; if (!kad) return;
      if (!window.confirm(m.il.ad + ' il başkanlığına bu üyeyi ' + (m.yontem === 'atama' ? 'atamak' : 'geçici olarak görevlendirmek') + ' istiyor musun? Mevcut il yönetim kurulu dağılır.')) return;
      islemYap(ata, function () { return rpc('il_baskan_ata', { p_il: m.il.id, p_kad: kad }); }, 'İl başkanı görevlendirildi.', sonuc);
    };
    var al = q('imGmAl'); if (al) al.onclick = function () {
      var g = q('imGmGer').value.trim(), en = m.yontem === 'atama' ? 10 : 20;
      if (g.length < en) { bildir('Gerekçe en az ' + en + ' karakter olmalı.', true); return; }
      if (!window.confirm('İl başkanını görevden almak istiyor musun?')) return;
      islemYap(al, function () { return rpc('il_baskan_gorevden_al', { p_il: m.il.id, p_gerekce: g }); }, 'İl başkanı görevden alındı.', function () { yenile(); });
    };
    var od = q('imGmOdOk'); if (od) od.onclick = function () {
      var v = Math.round(+q('imGmOd').value || 0); if (v < 1000) { bildir('Ödenek en az 1.000 ₺ olmalı.', true); return; }
      islemYap(od, function () { return rpc('il_kasa_odenek', { p_il: m.il.id, p_tutar: v }); }, tl(v) + ' il kasasına gönderildi.', sonuc);
    };
    var ia = q('imGmIaOk'); if (ia) ia.onclick = function () {
      var v = Math.round(+q('imGmIa').value || 0); if (v < 100) { bildir('Geçersiz tutar.', true); return; }
      islemYap(ia, function () { return rpc('il_kasa_iade', { p_il: m.il.id, p_tutar: v }); }, tl(v) + ' parti kasasına aktarıldı.', sonuc);
    };
  }

  /* ------------------------------------------------ İL BAŞKANLIKLARI (genel merkez) */
  function genelEkrani() {
    css();
    if (typeof iskelet === 'function') iskelet('İl Başkanlıkları', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    rpc('il_masa_genel', {}).then(genelCiz).catch(function (err) { var x = ic(); if (x) x.innerHTML = '<div class="kart"><div class="bos">' + esc(hata(err)) + '</div></div>'; });
  }
  function genelCiz(v) {
    S.g = v; var x = ic(); if (!x) return;
    var h = v.kongre_haftasi, iller = v.iller || [], tes = iller.filter(function (i) { return i.teskilat; });
    var bsk = tes.filter(function (i) { return i.baskan; }).length, sec = tes.filter(function (i) { return i.baskan && i.baskan.statu === 'secilmis'; }).length;
    var gelen = v.gelen || [], bekleyen = gelen.filter(function (y) { return y.durum === 'bekliyor' || y.durum === 'goruldu'; });
    var yon = '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0">İl başkanları nasıl belirlenir?</h3>' +
      '<div class="im-yontem"><button type="button" data-yon="secim" class="' + (v.yontem === 'secim' ? 'secili' : '') + '"' + (v.gb ? '' : ' disabled') + '><b>🗳️ İl kongresi (seçim)</b><small>Partinin o ilde kayıtlı üyeleri il başkanlığına aday olur ve oy verir. Olağan il kongreleri her genel başkanlık seçiminden önce, kongre haftasında yapılır. Başkanlık boşsa genel merkez geçici başkan görevlendirir.</small></button>' +
      '<button type="button" data-yon="atama" class="' + (v.yontem === 'atama' ? 'secili' : '') + '"' + (v.gb ? '' : ' disabled') + '><b>🏛️ Genel merkez ataması</b><small>Genel başkan ya da teşkilattan sorumlu genel başkan yardımcısı il başkanlarını doğrudan atar ve dilediğinde değiştirir. İl kongresi yapılmaz.</small></button></div>' +
      '<p class="kucuk" style="margin:8px 0 0">' + (v.gb ? 'Yöntemi yalnız genel başkan değiştirir; 7 günde bir, kongre haftası dışında.' : 'Yöntemi genel başkan belirler.') + (v.yontem_sonraki ? ' Sonraki değişiklik: ' + esc(zaman(v.yontem_sonraki)) + '.' : '') + '</p></div>';
    var hafta = h && v.yontem === 'secim' ? '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0">Kongre haftası</h3><p class="alt" style="margin:4px 0 0">Kongre haftasında il başkanı olmayan, geçici ya da atanmış başkanla yönetilen ve seçilmiş başkanının dönemi kurultaydan önce biten bütün illerde il kongresi kendiliğinden açılır.</p>' + takvimCiz(h) +
      (+h.acik_kongre ? '<p class="alt" style="margin:8px 0 0"><b>' + (+h.acik_kongre) + '</b> il kongresi sürüyor.</p>' : '') + '</div>' : '';
    var gelenHtml = gelen.slice(0, 20).map(function (y) {
      var acik = y.durum === 'bekliyor' || y.durum === 'goruldu';
      return '<div class="im-satir" style="display:block"><b>' + esc(y.il) + ' · ' + esc(YAZI_TUR[y.tur] || y.tur) + (y.karar ? ' (' + esc(y.karar) + ')' : '') + ': ' + esc(y.baslik) + '</b>' +
        '<small>' + esc(zaman(y.zaman)) + ' · ' + esc(y.gonderen || '') + (y.tutar ? ' · ' + tl(y.tutar) : '') + (y.ilgili ? ' · önerilen: ' : '') + '</small>' + (y.ilgili ? adBtn(y.ilgili_kad, y.ilgili) : '') +
        '<div class="im-cipler"><span class="im-cip ' + (y.durum === 'kabul' ? 'yesil' : y.durum === 'ret' ? 'kirmizi' : 'altin') + '">' + esc(YAZI_DURUM[y.durum] || y.durum) + '</span></div>' +
        '<div class="im-metin">' + esc(y.metin) + '</div>' + (y.cevap ? '<div class="im-bilgi"><b>Yanıt:</b> ' + esc(y.cevap) + '</div>' : '') +
        (acik ? '<div class="im-oy"><button type="button" class="kabul" data-cv="kabul" data-y="' + (+y.id) + '">' + (y.tur === 'talep' ? 'Kabul et, öde' : 'Kabul') + '</button><button type="button" class="ret" data-cv="ret" data-y="' + (+y.id) + '">Ret</button>' +
          (y.durum === 'bekliyor' ? '<button type="button" data-cv="goruldu" data-y="' + (+y.id) + '">Gördüm</button>' : '<button type="button" disabled>Görüldü</button>') + '</div>' : '') + '</div>';
    }).join('');
    x.innerHTML = '<section class="im-ust" style="--pr:' + esc(v.parti.renk || '#445') + '"><div class="im-bas">' + amb(v.parti, 46) + '<div class="orta"><h2>' + esc(v.parti.kisa) + ' İl Başkanlıkları</h2><small>' + tes.length + ' il teşkilatı · ' + bsk + ' il başkanı · ' + sec + ' kongrede seçilmiş</small></div></div>' +
        '<div class="im-istat"><div><b>' + tes.length + '</b><small>teşkilat</small></div><div><b>' + bsk + '</b><small>il başkanı</small></div><div><b>' + bekleyen.length + '</b><small>bekleyen yazı</small></div><div><b>' + (v.parti.kasa != null ? esc(kisaTl(v.parti.kasa)) : '—') + '</b><small>parti kasası</small></div></div></section>' +
      yon + hafta +
      '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 4px">Gelen yazılar' + (bekleyen.length ? ' (' + bekleyen.length + ' bekliyor)' : '') + '</h3>' + (gelenHtml || '<p class="alt" style="margin:4px 0 0">İl başkanlıklarından gelen yazı yok.</p>') + '</div>' +
      '<div class="kart"><h3 style="font-size:17px;font-weight:800;margin:0 0 6px">81 il · il karnesi</h3><input id="imGAra" class="im-ara" type="search" placeholder="İl ya da il başkanı ara" autocomplete="off"><div id="imGListe"></div></div>';
    var liste = function () {
      var q = (document.getElementById('imGAra').value || '').toLocaleLowerCase('tr-TR').trim();
      document.getElementById('imGListe').innerHTML = iller.filter(function (i) { return !q || String(i.il + ' ' + (i.baskan ? i.baskan.ad + ' ' + i.baskan.kad : '')).toLocaleLowerCase('tr-TR').indexOf(q) >= 0; }).map(function (i) {
        return '<button type="button" class="im-satir" data-il="' + (+i.il_id) + '"><div class="orta"><b>' + esc(i.il) + (i.kongre ? ' <span class="im-cip altin">Kongre</span>' : '') + (i.bekleyen ? ' <span class="im-cip kirmizi">' + (+i.bekleyen) + ' yazı</span>' : '') + '</b>' +
          '<small>' + (!i.teskilat ? 'Teşkilat yok' : i.baskan ? esc(i.baskan.ad) + ' · ' + esc(STATU[i.baskan.statu] || i.baskan.statu) : 'İl başkanı yok') + (i.teskilat ? ' · ' + (+i.uye) + ' üye · kurul ' + (+i.yk) + ' · kasa ' + tl(i.kasa) : '') + '</small>' +
          (i.teskilat ? '<div class="im-bar"><i style="width:' + Math.max(2, Math.min(100, +i.puan || 0)) + '%;background:' + esc(v.parti.renk || '#f2c46d') + '"></i></div>' : '') + '</div><div class="sag"><b>' + (i.teskilat ? (+i.puan || 0) : '—') + '</b><br><small>karne</small></div></button>';
      }).join('') || '<p class="alt">Sonuç yok.</p>';
      cevapListeBagla();
    };
    document.getElementById('imGAra').oninput = liste; liste();
    kartlariBagla(x);
    x.querySelectorAll('[data-yon]').forEach(function (yb) { yb.onclick = function () {
      if (yb.disabled || yb.dataset.yon === v.yontem) return;
      var hedef = yb.dataset.yon;
      if (!window.confirm(hedef === 'atama' ? 'İl başkanlarını genel merkez ataması ile belirlemeye geçilsin mi? Süren il kongreleri iptal edilir, yöntem 7 gün değiştirilemez.' : 'İl başkanlarını il kongresinde üyelerin oyuyla seçmeye geçilsin mi? Atanmış başkanlar ilk kongreye kadar geçici sayılır, yöntem 7 gün değiştirilemez.')) return;
      islemYap(yb, function () { return rpc('il_baskan_yontem_ayarla', { p_yontem: hedef }); }, 'Yöntem güncellendi.', genelCiz);
    }; });
    x.querySelectorAll('[data-cv]').forEach(function (cv) { cv.onclick = function () {
      if (cv.disabled) return;
      var drm = cv.dataset.cv, y = gelen.filter(function (z) { return +z.id === +cv.dataset.y; })[0] || {};
      if (drm === 'goruldu') { islemYap(cv, function () { return rpc('il_gm_yazi_cevap', { p_id: +cv.dataset.y, p_durum: drm, p_cevap: null }); }, 'Yazı görüldü olarak işaretlendi.', genelCiz); return; }
      cevapPencere(y, drm);
    }; });
  }
  function cevapListeBagla() {
    var x = ic(); if (!x) return;
    x.querySelectorAll('[data-il]').forEach(function (b) { b.onclick = function () { S.sekme = 'ozet'; var pid = S.g && S.g.parti.id; ac(function () { masaEkrani(pid, +b.dataset.il); }); }; });
  }
  function cevapPencere(y, drm) {
    var p = pencere('<h3 style="font-size:19px;font-weight:800;margin:0">' + esc(y.il || '') + ' · ' + (drm === 'kabul' ? 'Kabul' : 'Ret') + '</h3>' +
      '<p class="alt" style="margin:6px 0 0">' + esc(YAZI_TUR[y.tur] || '') + ': ' + esc(y.baslik || '') + (drm === 'kabul' && y.tur === 'talep' ? '<br><b>' + tl(y.tutar) + ' parti kasasından il kasasına aktarılacak.</b>' : '') + '</p>' +
      '<label for="imCvMet">İl başkanlığına yanıt (isteğe bağlı)</label><textarea id="imCvMet" maxlength="600" style="min-height:90px"></textarea><div class="sayac" id="imCvMetSay"></div>' +
      '<button type="button" class="btn ' + (drm === 'kabul' ? 'altin' : 'tehlike') + '" id="imCvOk">' + (drm === 'kabul' ? 'Kabul et' : 'Reddet') + '</button><button type="button" class="btn ikinci" id="imCvVaz">Vazgeç</button>');
    if (!p) return;
    sayacBagla(p, 'imCvMet', 600);
    p.querySelector('#imCvVaz').onclick = kapat;
    var ok = p.querySelector('#imCvOk');
    ok.onclick = function () {
      var c = p.querySelector('#imCvMet').value.trim();
      islemYap(ok, function () { return rpc('il_gm_yazi_cevap', { p_id: +y.id, p_durum: drm, p_cevap: c || null }); }, 'Yanıt gönderildi.', function (r) { kapat(); genelCiz(r); });
    };
  }

  /* ------------------------------------------------ girişler */
  function giris() {
    benimGetir(true).then(function (b) {
      if (b && b.rol) ac(function () { masaEkrani(b.parti_id, b.il_id); });
      else if (b && b.gm) ac(genelEkrani);
      else if (b && b.parti_id) ac(function () { masaEkrani(b.parti_id, null); });
      else bildir('İl başkanlığı masası için bir partiye üye olmalısın.', true);
    }).catch(function (err) { bildir(hata(err), true); });
  }
  function girisKart(b) {
    var h = '';
    if (b && b.rol) h += '<button type="button" class="im-giris" onclick="ilMasasiAc(' + (+b.parti_id) + ',' + (+b.il_id) + ')"><span class="im-ik">' + IKON + '</span><span class="orta"><b>' + esc(b.parti) + ' ' + esc(b.il) + ' İl Başkanlığı Masası</b><small>' +
      (b.rol === 'baskan' ? 'İl başkanısın: kurul, miting, stant, açıklama, karar, kasa' : 'Yönetim kurulu üyesisin') + (b.oy_bekleyen ? ' · ' + (+b.oy_bekleyen) + ' önerge oyunu bekliyor' : '') + '</small></span><span class="ok" aria-hidden="true">›</span></button>';
    if (b && b.gm) h += '<button type="button" class="im-giris" onclick="ilBaskanliklariAc()"><span class="im-ik">' + IKON + '</span><span class="orta"><b>İl Başkanlıkları (81 il)</b><small>' +
      (b.yontem === 'atama' ? 'Atama yöntemi' : 'Kongre yöntemi') + ' · il karneleri, atama' + (b.gelen_bekleyen ? ' · ' + (+b.gelen_bekleyen) + ' yazı yanıt bekliyor' : ' · gelen yazılar') + '</small></span><span class="ok" aria-hidden="true">›</span></button>';
    return h;
  }
  function ekle(id, html, yer) {
    if (!yer || !html || document.getElementById(id)) return;
    var d = document.createElement('div'); d.id = id; d.innerHTML = html; yer.insertBefore(d, yer.firstChild);
  }
  if (typeof window.iskelet === 'function') {
    var eski = window.iskelet;
    window.iskelet = iskelet = function (baslik) {
      var sonuc = eski.apply(this, arguments);
      try {
        if (baslik === 'Partiler') {
          var x = ic();
          benimGetir(false).then(function (b) { if (ic() === x && x) { css(); ekle('imParti', girisKart(b), x); } }).catch(function () {});
        }
      } catch (_) {}
      return sonuc;
    };
  }
  // Teşkilat kartına "İl Başkanlığı Masası" ve genel merkeze "İl Başkanlıkları" düğmeleri
  var eskiKart = window.teskilatKartCiz;
  if (typeof eskiKart === 'function') {
    window.teskilatKartCiz = async function (pid) {
      await eskiKart.apply(this, arguments);
      try {
        var el = document.getElementById('teskilatKart'); if (!el) return;
        var kart = el.querySelector('.kart'); if (!kart || kart.querySelector('#imTesk')) return;
        var b = await benimGetir(false);
        var d = document.createElement('div'); d.id = 'imTesk';
        d.innerHTML = '<button type="button" class="btn ikinci" id="imTeskMasa">İl Başkanlığı Masası</button>' + (b && b.gm && +b.parti_id === +pid ? '<button type="button" class="btn altin" id="imTeskGenel">İl Başkanlıkları (81 il)</button>' : '');
        kart.appendChild(d);
        d.querySelector('#imTeskMasa').onclick = function () {
          var sec = kart.querySelector('#ikSec'), il = sec ? +sec.value : null;
          S.sekme = 'ozet'; ac(function () { masaEkrani(pid, il); });
        };
        var gn = d.querySelector('#imTeskGenel'); if (gn) gn.onclick = function () { ac(genelEkrani); };
      } catch (_) {}
    };
  }

  window.ilMasasiEkrani = masaEkrani;
  window.ilMasasiAc = function (pid, il) { S.sekme = 'ozet'; ac(function () { masaEkrani(pid, il); }); };
  window.ilBaskanliklariAc = function () { ac(genelEkrani); };
  window.ilBaskanligiGiris = giris;
})();
