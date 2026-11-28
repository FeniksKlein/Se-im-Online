/* =====================================================================
   ADAY BELİRLEME (16.11.2026)
   Parti, milletvekili ve belediye başkanı adaylarını iki yoldan belirler
   (2820 s. SPK md.37):
     • Ön seçim — partinin o ildeki üyeleri oy verir; MV listesi en çok
       oydan en aza sıralanır, belediyede en çok oyu alan aday olur.
     • Genel Başkan ataması (merkez yoklaması) — listeyi ve sırayı GB belirler.
   Sunucu: sql/zz_20261116_aday_belirleme_dhondt.sql
   (parti_aday_panel, parti_aday_yontem_ayarla, parti_aday_il, parti_aday_ata).
   Partiler ekranının üstüne kart ekler; GB için "Aday belirleme" ekranı.
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_ADAY_BELIRLEME_V1) return;
  window.SO_ADAY_BELIRLEME_V1 = true;

  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var zaman = function (t) { try { return typeof tarihSaat === 'function' ? tarihSaat(t) : new Date(t).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' }); } catch (_) { return ''; } };
  var YAD = { onsecim: 'Ön seçim', atama: 'Genel Başkan ataması' };
  var C = { panel: null, at: 0, yukleniyor: null };

  function css() {
    if (document.getElementById('ab-css')) return;
    var s = document.createElement('style'); s.id = 'ab-css';
    s.textContent =
      '.ab-kart{border-left:4px solid var(--altin,#d4a537)}' +
      '.ab-kart h3{font-size:17px;font-weight:800;margin:0 0 6px}' +
      '.ab-kart p,.ab-ekran p{font-size:14px;line-height:1.5}' +
      '.ab-satir{display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-bottom:1px solid var(--line2,#2a3045);font-size:15px;flex-wrap:wrap}' +
      '.ab-satir:last-child{border-bottom:0}' +
      '.ab-cip{display:inline-block;padding:3px 10px;border-radius:999px;font-size:13px;font-weight:700;background:var(--bg,#151a28);border:1px solid var(--line2,#2a3045)}' +
      '.ab-cip.atama{color:#f2c46d;border-color:#7a5d22}' +
      '.ab-uyari{padding:10px 12px;border-radius:10px;background:rgba(242,196,109,.12);border:1px solid #7a5d22;font-size:14px;margin:8px 0}' +
      '.ab-ekran .alan select{font-size:16px;min-height:48px;width:100%;min-width:0;box-sizing:border-box}' +
      '.ab-il{display:block;width:100%;text-align:left;min-height:48px;padding:10px 12px;margin:6px 0;border-radius:12px;background:var(--bg,#151a28);border:1px solid var(--line2,#2a3045);color:inherit;font:inherit}' +
      '.ab-il b{font-size:15px}.ab-il small{display:block;font-size:13px;opacity:.8;margin-top:2px}' +
      '.ab-liste li{display:flex;align-items:center;gap:8px;padding:8px 0;border-bottom:1px solid var(--line2,#2a3045);font-size:15px}' +
      '.ab-liste li span{flex:1;min-width:0;overflow-wrap:anywhere}' +
      '.ab-liste button,.ab-uye button{min-width:44px;min-height:44px;border-radius:10px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font-size:16px}' +
      '.ab-uye{display:flex;align-items:center;gap:8px;padding:6px 0;font-size:15px}.ab-uye span{flex:1;min-width:0;overflow-wrap:anywhere}' +
      '.ab-uye small{opacity:.75;font-size:13px}';
    document.head.appendChild(s);
  }

  function panelGetir(zorla) {
    if (!zorla && C.panel && Date.now() - C.at < 60000) return Promise.resolve(C.panel);
    if (C.yukleniyor) return C.yukleniyor;
    C.yukleniyor = API.rpc('parti_aday_panel', {}).then(function (p) { C.panel = p; C.at = Date.now(); C.yukleniyor = null; return p; },
      function (err) { C.yukleniyor = null; throw err; });
    return C.yukleniyor;
  }

  /* Liste tamamlama (28.11.2026): ön seçim/atama bitince boş sıralar genel seçime kadar doldurulur.
     Sunucu yetkiliye uyum için mv='atama' döndürür; gerçek yöntem gercek_mv'dedir. */
  var gmv = function (p) { return (p && p.gercek_mv) || (p && p.mv); };
  var tmAcik = function (p) { return !!(p && p.tamamlama_mv && p.tamamlama_mv.yetkili); };

  /* ------------------------------------------------ Partiler kartı */
  function kartHtml(p) {
    if (!p || !p.parti) return '';
    var ust = '<h3>Aday belirleme · ' + esc(p.parti.kisa) + '</h3>' +
      '<div class="ab-satir"><span>Milletvekili adayları</span><span class="ab-cip ' + (gmv(p) === 'atama' ? 'atama' : '') + '">' + YAD[gmv(p)] + '</span></div>' +
      '<div class="ab-satir"><span>Belediye başkanı adayları</span><span class="ab-cip ' + (p.bel === 'atama' ? 'atama' : '') + '">' + YAD[p.bel] + '</span></div>';
    if (p.gb_mi) {
      return '<div class="kart ab-kart">' + ust +
        (!p.belirlendi ? '<div class="ab-uyari">Genel Başkan olarak partinin aday belirleme yöntemini henüz seçmedin. Seçmezsen adaylar ön seçimle belirlenir.</div>' : '') +
        (tmAcik(p) ? '<div class="ab-uyari"><b>Liste tamamlama açık</b> · ' + esc(zaman(p.tamamlama_mv.son)) + "'e kadar. İllerde boş kalan milletvekili sıralarına parti üyelerini ekleyebilirsin.</div>" : '') +
        '<button class="btn altin" onclick="adayBelirlemeAc()">' + (tmAcik(p) ? 'Listeleri tamamla' : (p.belirlendi ? 'Aday belirleme ve listeler' : 'Yöntemi seç')) + '</button></div>';
    }
    return '<div class="kart ab-kart">' + ust +
      '<p class="alt">' + (p.mv === 'atama' || p.bel === 'atama'
        ? 'Genel Başkan ataması olan seçimde üye oylaması yapılmaz. Aday adaylığına başvurabilirsin; listeye alınıp alınmayacağını Genel Başkan belirler.'
        : 'Ön seçimde partinin ildeki üyeleri oy verir; milletvekili listesi en çok oydan en aza sıralanır.') + '</p></div>';
  }

  function partilerKartiEkle() {
    if (!D || !D.durum || !D.durum.profil || !(D.durum.profil.parti || {}).id) return;
    var ic = document.getElementById('icerik'); if (!ic) return;
    var yer = document.getElementById('abPartiKart');
    if (!yer) { ic.insertAdjacentHTML('afterbegin', '<div id="abPartiKart"></div>'); yer = document.getElementById('abPartiKart'); }
    if (C.panel) yer.innerHTML = kartHtml(C.panel);
    panelGetir(false).then(function (p) { var y = document.getElementById('abPartiKart'); if (y) y.innerHTML = kartHtml(p); }).catch(function () {});
  }

  if (typeof window.iskelet === 'function') {
    var eski = window.iskelet;
    window.iskelet = iskelet = function (baslik) {
      var sonuc = eski.apply(this, arguments);
      try { if (baslik === 'Partiler') { css(); partilerKartiEkle(); } } catch (_) {}
      return sonuc;
    };
  }

  /* ------------------------------------------------ GB ekranı */
  function donemHtml(s, ad) {
    if (!s) return '<div class="ab-satir"><span>' + ad + '</span><span>Takvimde yaklaşan ön seçim yok</span></div>';
    if (s.tamamlama) return '<div class="ab-satir"><span>' + ad + '</span><span><b>Liste tamamlama açık</b> · ' + esc(zaman(s.oy_bit)) + "'e kadar</span></div>";
    return '<div class="ab-satir"><span>' + ad + '</span><span>' + (s.acik ? '<b>Aday belirleme açık</b> · ' + esc(zaman(s.oy_bit)) + "'e kadar" : 'Başvuru ' + esc(zaman(s.basvuru_bas)) + "'de açılır") + '</span></div>';
  }

  function ekran() {
    css();
    iskelet('Aday belirleme', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    panelGetir(true).then(ciz).catch(function (err) {
      var ic = document.getElementById('icerik'); if (ic) ic.innerHTML = '<div class="kart"><div class="bos">' + esc(hata(err)) + '</div></div>';
    });
  }

  function ciz(p) {
    var ic = document.getElementById('icerik'); if (!ic) return;
    if (!p || !p.parti) { ic.innerHTML = '<div class="kart"><div class="bos">Bir partiye üye değilsin.</div></div>'; return; }
    if (!p.gb_mi) { ic.innerHTML = kartHtml(p); return; }
    var sec = function (id, deger, kilit) {
      return '<select id="' + id + '"' + (kilit ? ' disabled' : '') + '><option value="onsecim"' + (deger === 'onsecim' ? ' selected' : '') + '>Ön seçim (üyeler oy verir)</option><option value="atama"' + (deger === 'atama' ? ' selected' : '') + '>Genel Başkan ataması (sen belirlersin)</option></select>' +
        (kilit ? '<p class="kucuk">Adaylık süreci sürüyor; ' + esc(zaman(kilit)) + ' sonrasında değiştirebilirsin.</p>' : '');
    };
    var iller = (p.iller || []).map(function (i) {
      var alt = [];
      if (tmAcik(p)) alt.push('MV: ' + i.mv_atanan + '/' + i.mv + ' dolu' + (i.mv_bos ? ' · <b>' + i.mv_bos + ' boş sıra</b>' : ' · liste tam'));
      else if (p.mv === 'atama') alt.push('MV: ' + i.mv_atanan + '/' + i.mv + ' atandı' + (i.mv_basvuru ? ' · ' + i.mv_basvuru + ' başvuru' : ''));
      if (p.bel === 'atama') alt.push('Belediye: ' + (i.bel_atanan ? esc(i.bel_atanan) : 'aday yok'));
      return '<button class="ab-il" onclick="adayBelirlemeIl(' + i.il_id + ')"><b>' + esc(i.ad) + '</b> · ' + i.uye + ' üye<small>' + alt.join(' · ') + '</small></button>';
    }).join('');
    ic.innerHTML =
      '<div class="kart ab-ekran"><h3 style="font-size:17px;font-weight:800">Aday belirleme yöntemi</h3>' +
      '<p class="alt">' + esc(p.kural) + '</p>' +
      '<div class="alan"><label for="abMv">Milletvekili adayları</label>' + sec('abMv', gmv(p), p.kilit_mv) + '</div>' +
      '<div class="alan"><label for="abBel">Belediye başkanı adayları</label>' + sec('abBel', p.bel, p.kilit_bel) + '</div>' +
      '<div class="hata-metin" id="abHata"></div>' +
      '<button class="btn altin" id="abKaydet">Yöntemi kaydet</button></div>' +
      '<div class="kart"><h3 style="font-size:17px;font-weight:800">Takvim</h3>' + donemHtml(p.secim_mv, 'Milletvekili') + donemHtml(p.secim_bel, 'Belediye başkanlığı') +
      '<p class="kucuk" style="margin-top:8px">Sıra her zaman: önce adaylık başvurusu, sonra ön seçim (ya da Genel Başkan ataması), sonra genel seçim. Atama, başvurular açıldığı andan ön seçim süresi bitene kadar yapılır; süre bitince liste kesinleşir.</p></div>' +
      (tmAcik(p) ? '<div class="kart ab-kart"><h3>Liste tamamlama</h3><p>' + esc(p.tamamlama_mv.aciklama) + '</p><p class="kucuk">Son: ' + esc(zaman(p.tamamlama_mv.son)) + '. İl listesinde ön seçimle (ya da atamayla) kesinleşen sıralar kilitlidir; yeni adaylar onların arkasına eklenir. Belediye başkanı, vali, il teşkilatı görevlisi, oda/baro/sendika başkanı ve hâkim olan üyeler eklenemez.</p></div>' : '') +
      ((p.mv === 'atama' || p.bel === 'atama')
        ? '<div class="kart"><h3 style="font-size:17px;font-weight:800">İl il adaylar</h3><p class="alt">Milletvekili listesine partinin hangi ilde yaşarsa yaşasın bir üyesini koyabilirsin (ikamet şartı yok; bir kişi yalnız bir ilden aday olur). Belediye başkanı adayı yalnız o ilde kayıtlı üyelerden seçilir. Milletvekili listesi en fazla ilin sandalye sayısı kadar olur; sandalyeler seçimde D\'Hondt usulüyle bu sıraya göre dağıtılır.</p>' +
          (iller || '<div class="bos">Partinin üyesi olan il yok.</div>') + '</div>'
        : '');
    var b = document.getElementById('abKaydet');
    if (b) b.onclick = function () {
      b.disabled = true; document.getElementById('abHata').textContent = '';
      API.rpc('parti_aday_yontem_ayarla', { p_mv: document.getElementById('abMv').value, p_bel: document.getElementById('abBel').value })
        .then(function (np) { C.panel = np; C.at = Date.now(); toast('Aday belirleme yöntemi kaydedildi.'); ciz(np); })
        .catch(function (err) { document.getElementById('abHata').textContent = hata(err); b.disabled = false; });
    };
  }

  /* ------------------------------------------------ il listesi */
  function ilAc(ilId) {
    var p = C.panel || {};
    var turler = [];
    if (p.mv === 'atama') turler.push(['mv', 'Milletvekili listesi']);
    if (p.bel === 'atama') turler.push(['bel', 'Belediye başkanı adayı']);
    if (turler.length === 1) return listeAc(turler[0][0], ilId);
    var m = modal('<h3 style="font-size:19px;font-weight:800">Hangi adaylık?</h3>' +
      turler.map(function (t) { return '<button class="btn ikinci" data-t="' + t[0] + '">' + t[1] + '</button>'; }).join(''));
    m.querySelectorAll('button[data-t]').forEach(function (x) { x.onclick = function () { modalKapat(); listeAc(x.dataset.t, ilId); }; });
  }

  function listeAc(tur, ilId) {
    API.rpc('parti_aday_il', { p_tur: tur, p_il: ilId }).then(function (v) { listeCiz(v); }).catch(function (err) { toast(hata(err), true); });
  }

  function listeCiz(v) {
    if (v.tamamlama) return tamamlamaCiz(v);
    var secili = (v.uyeler || []).filter(function (u) { return u.atama_sira != null; })
      .sort(function (a, b) { return a.atama_sira - b.atama_sira; }).map(function (u) { return u.kad; });
    var baslik = (v.tur === 'mv' ? 'Milletvekili listesi' : 'Belediye başkanı adayı') + ' · ' + v.il_ad;
    var m = modal('<h3 style="font-size:19px;font-weight:800">' + esc(baslik) + '</h3>' +
      (v.secim ? '<p class="alt">Liste ' + esc(zaman(v.secim.oy_bit)) + "'de kesinleşir. " + (v.tur === 'mv' ? 'En çok ' + v.kontenjan + ' aday.' : 'Tek aday.') + '</p>'
               : '<div class="ab-uyari">Şu anda aday belirleme dönemi değil. Atama, adaylık başvurusu açılınca yapılır.</div>') +
      '<h4 style="margin:10px 0 4px">Liste</h4><ol class="ab-liste" id="abListe" style="padding-left:0;list-style:none;margin:0"></ol>' +
      '<h4 style="margin:12px 0 4px">Bu ildeki üyeler</h4><div id="abUyeler"></div>' +
      (v.tur === 'mv' && v.dis_il_serbest ? '<h4 style="margin:12px 0 4px">Başka ilden aday ekle</h4><p class="kucuk" style="margin:0 0 6px">Partinin başka ilde yaşayan bir üyesini bu ilin listesine koyabilirsin. Bir kişi yalnız bir ilden aday olur.</p>' +
        '<input id="abAra" type="search" autocomplete="off" placeholder="Ad soyad ya da kullanıcı adı" style="width:100%;min-width:0;box-sizing:border-box;font-size:16px;min-height:48px;padding:10px 12px;border-radius:12px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;color-scheme:dark"><div id="abAraSonuc"></div>' : '') +
      '<div class="hata-metin" id="abLHata"></div>' +
      '<button class="btn altin" id="abLKaydet"' + (v.secim ? '' : ' disabled') + '>Listeyi kaydet</button><button class="btn ikinci" id="abLKapat">Kapat</button>');
    var uyeBilgi = {}; (v.uyeler || []).forEach(function (u) { uyeBilgi[u.kad] = u; });
    var disEtiket = function (u) { return u && u.dis_il ? ' <small>(yaşadığı il: ' + esc(u.yasadigi_il || 'başka il') + ')</small>' : ''; };
    function yenile() {
      var ol = m.querySelector('#abListe');
      ol.innerHTML = secili.length ? secili.map(function (k, i) {
        return '<li><b style="min-width:26px">' + (i + 1) + '.</b><span>' + esc(k) + (uyeBilgi[k] && uyeBilgi[k].basvurdu ? ' <small>(başvurdu)</small>' : '') + disEtiket(uyeBilgi[k]) + '</span>' +
          (v.tur === 'mv' ? '<button data-y="' + i + '" aria-label="Yukarı">↑</button><button data-a="' + i + '" aria-label="Aşağı">↓</button>' : '') +
          '<button data-s="' + i + '" aria-label="Listeden çıkar">✕</button></li>';
      }).join('') : '<li><span class="kucuk">Henüz aday yok. Aşağıdan üyeye dokun.</span></li>';
      ol.querySelectorAll('button[data-y]').forEach(function (b) { b.onclick = function () { var i = +b.dataset.y; if (i > 0) { var t = secili[i - 1]; secili[i - 1] = secili[i]; secili[i] = t; yenile(); } }; });
      ol.querySelectorAll('button[data-a]').forEach(function (b) { b.onclick = function () { var i = +b.dataset.a; if (i < secili.length - 1) { var t = secili[i + 1]; secili[i + 1] = secili[i]; secili[i] = t; yenile(); } }; });
      ol.querySelectorAll('button[data-s]').forEach(function (b) { b.onclick = function () { secili.splice(+b.dataset.s, 1); yenile(); }; });
      var kalan = (v.uyeler || []).filter(function (u) { return secili.indexOf(u.kad) < 0 && !(v.tur === 'bel' && u.gb); });
      m.querySelector('#abUyeler').innerHTML = kalan.length ? kalan.map(function (u) {
        return '<div class="ab-uye"><span>' + esc(u.kad) + (u.basvurdu ? ' <small>· aday adaylığına başvurdu</small>' : '') + disEtiket(u) + '</span><button data-e="' + esc(u.kad) + '" aria-label="Listeye ekle">＋</button></div>';
      }).join('') : '<div class="kucuk">Eklenebilecek başka üye yok.</div>';
      m.querySelectorAll('button[data-e]').forEach(function (b) { b.onclick = function () {
        if (secili.length >= v.kontenjan) { m.querySelector('#abLHata').textContent = v.tur === 'mv' ? 'Bu ilde en çok ' + v.kontenjan + ' aday gösterebilirsin.' : 'Belediye başkanlığına tek aday gösterilir; önce mevcut adayı çıkar.'; return; }
        m.querySelector('#abLHata').textContent = ''; secili.push(b.dataset.e); yenile(); }; });
    }
    yenile();
    var ara = m.querySelector('#abAra'), zm = null;
    if (ara) ara.oninput = function () {
      clearTimeout(zm); var q = ara.value.trim(), out = m.querySelector('#abAraSonuc');
      if (q.length < 2) { out.innerHTML = ''; return; }
      zm = setTimeout(function () {
        API.rpc('parti_aday_uye_ara', { p_ara: q }).then(function (r) {
          if (ara.value.trim() !== q) return;
          var ls = (r || []).filter(function (u) { return secili.indexOf(u.kad) < 0; });
          out.innerHTML = ls.length ? ls.map(function (u) {
            var baska = u.atama_sira != null && u.aday_il_id !== v.il_id;
            var not = baska ? ' <small>· şu an ' + esc(u.aday_il) + ' listesinde (' + u.atama_sira + '. sıra)</small>' : (!u.uygun ? ' <small>· şu an aday olamaz</small>' : '');
            return '<div class="ab-uye"><span>' + esc(u.ad) + ' <small>(' + esc(u.kad) + ' · ' + esc(u.il) + ')</small>' + not + '</span>' +
              (baska || !u.uygun ? '' : '<button data-d="' + esc(u.kad) + '" aria-label="Listeye ekle">＋</button>') + '</div>';
          }).join('') : '<div class="kucuk">Eşleşen üye yok.</div>';
          out.querySelectorAll('button[data-d]').forEach(function (b) { b.onclick = function () {
            var u = (r || []).filter(function (x) { return x.kad === b.dataset.d; })[0];
            if (secili.length >= v.kontenjan) { m.querySelector('#abLHata').textContent = 'Bu ilde en çok ' + v.kontenjan + ' aday gösterebilirsin.'; return; }
            uyeBilgi[u.kad] = { kad: u.kad, ad: u.ad, basvurdu: u.basvurdu, dis_il: u.il_id !== v.il_id, yasadigi_il: u.il };
            m.querySelector('#abLHata').textContent = ''; secili.push(u.kad); ara.value = ''; out.innerHTML = ''; yenile();
          }; });
        }).catch(function (err) { out.innerHTML = '<div class="kucuk">' + esc(hata(err)) + '</div>'; });
      }, 350);
    };
    m.querySelector('#abLKapat').onclick = modalKapat;
    var k = m.querySelector('#abLKaydet');
    k.onclick = function () {
      k.disabled = true; m.querySelector('#abLHata').textContent = '';
      API.rpc('parti_aday_ata', { p_tur: v.tur, p_il: v.il_id, p_kadlar: secili }).then(function () {
        toast(secili.length ? 'Aday listesi kaydedildi.' : 'Liste boşaltıldı.'); modalKapat(); C.at = 0;
        if (typeof yenidenCiz === 'function') yenidenCiz();
      }).catch(function (err) { m.querySelector('#abLHata').textContent = hata(err); k.disabled = false; });
    };
  }

  /* ------------------------------------------------ liste tamamlama */
  function tamamlamaCiz(v) {
    var kilitli = (v.uyeler || []).filter(function (u) { return u.kilitli; }).sort(function (a, b) { return a.atama_sira - b.atama_sira; });
    var secili = (v.uyeler || []).filter(function (u) { return u.tamamlama && u.atama_sira != null; })
      .sort(function (a, b) { return a.atama_sira - b.atama_sira; }).map(function (u) { return u.kad; });
    var bos = Math.max(0, v.kontenjan - kilitli.length);
    var uyeBilgi = {}; (v.uyeler || []).forEach(function (u) { uyeBilgi[u.kad] = u; });
    var disEtiket = function (u) { return u && u.dis_il ? ' <small>(yaşadığı il: ' + esc(u.yasadigi_il || 'başka il') + ')</small>' : ''; };
    var m = modal('<h3 style="font-size:19px;font-weight:800">Liste tamamlama · ' + esc(v.il_ad) + '</h3>' +
      '<div class="ab-uyari">' + esc(v.aciklama || '') + '</div>' +
      '<h4 style="margin:10px 0 4px">Kesinleşen sıralar (' + kilitli.length + ')</h4><ol class="ab-liste" style="padding-left:0;list-style:none;margin:0">' +
        (kilitli.length ? kilitli.map(function (u) { return '<li><b style="min-width:26px">' + u.atama_sira + '.</b><span>' + esc(u.ad || u.kad) + ' <small>🔒' + (u.oy != null ? ' · ' + u.oy + ' oy' : '') + '</small>' + disEtiket(u) + '</span></li>'; }).join('')
                        : '<li><span class="kucuk">Bu ilde kesinleşmiş aday yok.</span></li>') + '</ol>' +
      '<h4 style="margin:12px 0 4px">Eklenenler (en çok ' + bos + ')</h4><ol class="ab-liste" id="abTListe" style="padding-left:0;list-style:none;margin:0"></ol>' +
      '<h4 style="margin:12px 0 4px">Bu ildeki üyeler</h4><div id="abTUyeler"></div>' +
      '<h4 style="margin:12px 0 4px">Başka ilden üye ekle</h4>' +
      '<input id="abTAra" type="search" autocomplete="off" placeholder="Ad soyad ya da kullanıcı adı" style="width:100%;min-width:0;box-sizing:border-box;font-size:16px;min-height:48px;padding:10px 12px;border-radius:12px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;color-scheme:dark"><div id="abTAraSonuc"></div>' +
      '<div class="hata-metin" id="abTHata"></div>' +
      '<button class="btn altin" id="abTKaydet"' + (bos ? '' : ' disabled') + '>Listeyi kaydet</button><button class="btn ikinci" id="abTKapat">Kapat</button>');
    function sinir() { if (secili.length >= bos) { m.querySelector('#abTHata').textContent = 'Bu ilde boş sıra kalmadı (kontenjan ' + v.kontenjan + ').'; return false; } m.querySelector('#abTHata').textContent = ''; return true; }
    function yenile() {
      var ol = m.querySelector('#abTListe');
      ol.innerHTML = secili.length ? secili.map(function (k, i) {
        var u = uyeBilgi[k] || {};
        return '<li><b style="min-width:26px">' + (kilitli.length + i + 1) + '.</b><span>' + esc(u.ad || k) + disEtiket(u) + '</span>' +
          '<button data-y="' + i + '" aria-label="Yukarı">↑</button><button data-a="' + i + '" aria-label="Aşağı">↓</button><button data-s="' + i + '" aria-label="Listeden çıkar">✕</button></li>';
      }).join('') : '<li><span class="kucuk">Henüz ekleme yok. Aşağıdan üyeye dokun.</span></li>';
      ol.querySelectorAll('button[data-y]').forEach(function (b) { b.onclick = function () { var i = +b.dataset.y; if (i > 0) { var t = secili[i - 1]; secili[i - 1] = secili[i]; secili[i] = t; yenile(); } }; });
      ol.querySelectorAll('button[data-a]').forEach(function (b) { b.onclick = function () { var i = +b.dataset.a; if (i < secili.length - 1) { var t = secili[i + 1]; secili[i + 1] = secili[i]; secili[i] = t; yenile(); } }; });
      ol.querySelectorAll('button[data-s]').forEach(function (b) { b.onclick = function () { secili.splice(+b.dataset.s, 1); yenile(); }; });
      var kalan = (v.uyeler || []).filter(function (u) { return !u.kilitli && secili.indexOf(u.kad) < 0; });
      m.querySelector('#abTUyeler').innerHTML = kalan.length ? kalan.map(function (u) {
        return '<div class="ab-uye"><span>' + esc(u.ad || u.kad) + ' <small>(' + esc(u.kad) + ')</small>' + disEtiket(u) + (u.engel ? ' <small>· eklenemez: ' + esc(u.engel) + '</small>' : '') + '</span>' +
          (u.engel ? '' : '<button data-e="' + esc(u.kad) + '" aria-label="Listeye ekle">＋</button>') + '</div>';
      }).join('') : '<div class="kucuk">Eklenebilecek başka üye yok.</div>';
      m.querySelectorAll('#abTUyeler button[data-e]').forEach(function (b) { b.onclick = function () { if (!sinir()) return; secili.push(b.dataset.e); yenile(); }; });
    }
    yenile();
    var ara = m.querySelector('#abTAra'), zm = null;
    ara.oninput = function () {
      clearTimeout(zm); var q = ara.value.trim(), out = m.querySelector('#abTAraSonuc');
      if (q.length < 2) { out.innerHTML = ''; return; }
      zm = setTimeout(function () {
        API.rpc('parti_aday_uye_ara', { p_ara: q }).then(function (r) {
          if (ara.value.trim() !== q) return;
          var ls = (r || []).filter(function (u) { return secili.indexOf(u.kad) < 0 && !(uyeBilgi[u.kad] && uyeBilgi[u.kad].kilitli); });
          out.innerHTML = ls.length ? ls.map(function (u) {
            var baska = u.atama_sira != null && u.aday_il_id !== v.il_id;
            var not = baska ? ' <small>· şu an ' + esc(u.aday_il) + ' listesinde</small>' : (!u.uygun ? ' <small>· şu an eklenemez</small>' : '');
            return '<div class="ab-uye"><span>' + esc(u.ad) + ' <small>(' + esc(u.kad) + ' · ' + esc(u.il) + ')</small>' + not + '</span>' +
              (baska || !u.uygun ? '' : '<button data-d="' + esc(u.kad) + '" aria-label="Listeye ekle">＋</button>') + '</div>';
          }).join('') : '<div class="kucuk">Eşleşen üye yok.</div>';
          out.querySelectorAll('button[data-d]').forEach(function (b) { b.onclick = function () {
            var u = (r || []).filter(function (x) { return x.kad === b.dataset.d; })[0];
            if (!sinir()) return;
            uyeBilgi[u.kad] = { kad: u.kad, ad: u.ad, dis_il: u.il_id !== v.il_id, yasadigi_il: u.il };
            secili.push(u.kad); ara.value = ''; out.innerHTML = ''; yenile();
          }; });
        }).catch(function (err) { out.innerHTML = '<div class="kucuk">' + esc(hata(err)) + '</div>'; });
      }, 350);
    };
    m.querySelector('#abTKapat').onclick = modalKapat;
    var k = m.querySelector('#abTKaydet');
    k.onclick = function () {
      k.disabled = true; m.querySelector('#abTHata').textContent = '';
      API.rpc('parti_aday_ata', { p_tur: 'mv', p_il: v.il_id, p_kadlar: secili }).then(function () {
        toast(secili.length ? 'Liste tamamlandı: ' + secili.length + ' aday eklendi.' : 'Eklenen adaylar çıkarıldı.'); modalKapat(); C.at = 0;
        if (typeof yenidenCiz === 'function') yenidenCiz();
      }).catch(function (err) { m.querySelector('#abTHata').textContent = hata(err); k.disabled = false; });
    };
  }

  window.adayBelirlemeEkrani = ekran;
  window.adayBelirlemeAc = function () { ekranAc(ekran); };
  window.adayBelirlemeIl = ilAc;
})();
