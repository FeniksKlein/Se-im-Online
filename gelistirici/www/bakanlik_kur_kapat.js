/* Bakanlık Kur / Kapat — 17.11.2026.
   Yetki denetimi Supabase RPC'lerinde yapılır: yalnız görevdeki Cumhurbaşkanı.
   Bakanlık silinmez, kapatılınca arşivlenir; eski kayıtlar korunur. */
(function () {
  "use strict";
  if (window.SO_BAKANLIK_KUR_KAPAT_V1) return;
  window.SO_BAKANLIK_KUR_KAPAT_V1 = true;

  function htmlKac(x) {
    return String(x == null ? "" : x).replace(/[&<>"']/g, function(c) {
      return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];
    });
  }
  function cumhurbaskaniMi() {
    var p = typeof D !== "undefined" && D.durum && D.durum.profil;
    return !!(p && Array.isArray(p.makamlar) && p.makamlar.some(function(m) { return m.tur === "cb"; }));
  }
  function bilgi(m, hata) {
    if (typeof toast === "function") toast(String(m), !!hata);
    else if (hata) window.alert(String(m));
  }
  function hata(err) {
    return typeof hataCevir === "function" ? hataCevir(err && err.message || String(err)) :
      String(err && err.message || err);
  }
  function butce(x) {
    return (Number(x) || 0).toLocaleString("tr-TR", {maximumFractionDigits:2}) + " milyar ₺";
  }
  function cbKarti() {
    return '<div class="kart" id="bakanlik-kur-kapat-bag">' +
      '<h2>🏛️ Bakanlık Kur / Kapat</h2>' +
      '<p class="alt">Yeni bakanlık oluşturabilir, açık bakanlıkları kapatabilir veya kapalı bir bakanlığı yeniden açabilirsin.</p>' +
      '<button type="button" class="btn altin" onclick="ekranAc(bakanlikKurKapatEkrani)">Bakanlık Kur / Kapat</button></div>';
  }

  window.bakanlikKurKapatEkrani = async function() {
    if (!cumhurbaskaniMi()) {
      bilgi("Bu ekran yalnızca görevdeki Cumhurbaşkanına açıktır.", true);
      return;
    }
    if (typeof yukleniyor === "function") yukleniyor("Bakanlık yönetimi");
    try {
      var sonuc = await API.rpc("bakanlik_yonetimi");
      var liste = Array.isArray(sonuc && sonuc.bakanliklar) ? sonuc.bakanliklar : [];
      var acik = liste.filter(function(x) { return !!x.aktif; }).length;
      var alanlar = Array.isArray(sonuc && sonuc.alanlar) ? sonuc.alanlar : [];
      var alanIsimleri = {};
      alanlar.forEach(function(a) { alanIsimleri[a.kod] = a.ad; });
      var h = '<div class="kart">' +
        '<h2>🏛️ Bakanlık Kur / Kapat</h2>' +
        '<p class="alt">Bakanlık açma ve kapatma yetkisi Cumhurbaşkanına aittir. Mevcut atamalar, geçmiş mali kayıtlar ve kararlar silinmez.</p>' +
        '<p><b>Açık bakanlık:</b> '+acik+' · <b>Kurulmuş toplam:</b> '+liste.length+' / '+Number(sonuc.sinir || 30)+'</p>' +
        '<label for="bk-yeni-ad">Yeni bakanlığın adı</label>' +
        '<input id="bk-yeni-ad" type="text" maxlength="80" placeholder="Örn. Enerji ve Tabii Kaynaklar Bakanlığı" style="display:block;width:100%;box-sizing:border-box;margin:8px 0 12px;padding:12px;border-radius:10px">' +
        '<label for="bk-yeni-alan">Bakanlığın faaliyet alanı</label>' +
        '<select id="bk-yeni-alan" style="display:block;width:100%;box-sizing:border-box;margin:8px 0 12px;padding:12px;border-radius:10px">' +
        '<option value="genel">Otomatik: Bakanlık adına göre</option>' + alanlar.filter(function(a) { return a.kod !== 'genel'; }).map(function(a) { return '<option value="'+htmlKac(a.kod)+'">'+htmlKac(a.ad)+'</option>'; }).join('') +
        '</select>' +
        '<button type="button" class="btn altin" onclick="bakanlikYonKur()">+ Yeni bakanlık kur</button>' +
        '<p class="alt">Kuruluşta Hazine kaynaklı 5 milyar ₺ kasa ödeneği, %2 merkezi bütçe payı, 4 alanına özel icraat ve 2 katılımlı etkinlik verilir. Diğer bütçe payları dengelenerek toplam %100 korunur. Bakan ataması Kabine üzerinden yapılır.</p></div>';
      h += '<div class="kart"><h2>Mevcut bakanlıklar</h2><p class="alt">Kapatılan bakanlıklar arşivlenir ve tekrar açılabilir. Görevli bakan varsa önce Kabine bölümünden görevden alınmalıdır.</p></div>';
      liste.forEach(function(b) {
        var kod = String(b.kod || "");
        if (!/^[a-z0-9_]+$/.test(kod)) return;
        var durum = b.aktif ? "Açık" : "Kapalı";
        h += '<div class="kart" style="margin-bottom:10px">' +
          '<div style="display:flex;align-items:center;justify-content:space-between;gap:8px;flex-wrap:wrap">' +
          '<h3 style="margin:0">'+htmlKac(b.ad)+'</h3><b>'+durum+'</b></div>' +
          '<p class="alt" style="margin:8px 0">Alan: '+htmlKac(alanIsimleri[b.alan] || (b.sistem ? 'Mevcut bakanlık' : 'Genel kamu hizmetleri'))+
          ' · Kasa: '+htmlKac(butce(b.kasa))+' · Bütçe payı: %'+htmlKac(Number(b.pay || 0).toLocaleString('tr-TR',{maximumFractionDigits:4}))+
          (b.bakan ? ' · Bakan: '+htmlKac(b.bakan) : ' · Bakan atanmamış') + '</p>';
        if (b.aktif) {
          h += '<button type="button" class="btn ikinci" onclick="bakanlikYonKapatForm(\''+kod+'\')">Bakanlığı kapat</button>' +
            '<div id="bk-kap-form-'+kod+'" hidden style="margin-top:12px">' +
            '<label for="bk-gerekce-'+kod+'">Resmî kapatma gerekçesi</label>' +
            '<textarea id="bk-gerekce-'+kod+'" rows="2" maxlength="350" style="display:block;width:100%;box-sizing:border-box;padding:10px;margin:8px 0" placeholder="En az 10 karakter gerekçe yaz"></textarea>' +
            '<button type="button" class="btn ikinci" onclick="bakanlikYonKapat(\''+kod+'\')">Kapatmayı onayla</button></div>';
        } else {
          h += b.kapanis_gerekce ? '<p class="alt">Kapatma gerekçesi: '+htmlKac(b.kapanis_gerekce)+'</p>' : '';
          h += '<button type="button" class="btn altin" onclick="bakanlikYonYenidenAc(\''+kod+'\')">Yeniden aç</button>';
        }
        h += '</div>';
      });
      iskelet("Bakanlık Kur / Kapat", h, {geri:true});
    } catch (err) {
      iskelet("Bakanlık Kur / Kapat",
        '<div class="kart"><h2>İşlem açılamadı</h2><p>'+htmlKac(hata(err))+'</p></div>',{geri:true});
    }
  };
  window.bakanlikYonKur = async function() {
    var el = document.getElementById("bk-yeni-ad");
    var ad = el && el.value && el.value.trim();
    var secim = document.getElementById("bk-yeni-alan");
    var alan = secim && secim.value || "genel";
    if (!ad || ad.length < 5) { bilgi("Bakanlığın adını en az 5 karakter olarak yaz.", true); return; }
    try {
      var r = await API.rpc("bakanlik_kur_alan", {p_ad:ad,p_alan:alan});
      bilgi((r && r.ad || ad) + " kuruldu. 5 milyar ₺ bütçe, 4 icraat ve 2 etkinlik hazır.");
      return window.bakanlikKurKapatEkrani();
    } catch (err) { bilgi(hata(err), true); }
  };
  window.bakanlikYonKapatForm = function(kod) {
    var el = document.getElementById("bk-kap-form-"+kod);
    if (el) el.hidden = !el.hidden;
  };
  window.bakanlikYonKapat = async function(kod) {
    var el = document.getElementById("bk-gerekce-"+kod);
    var gerekce = el && el.value && el.value.trim();
    if (!gerekce || gerekce.length < 10) { bilgi("Kapatma gerekçesi en az 10 karakter olmalı.",true); return; }
    try {
      await API.rpc("bakanlik_kapat", {p_kod:kod,p_gerekce:gerekce});
      bilgi("Bakanlık kapatıldı, kayıtları korundu.");
      return window.bakanlikKurKapatEkrani();
    } catch (err) { bilgi(hata(err),true); }
  };
  window.bakanlikYonYenidenAc = async function(kod) {
    try {
      await API.rpc("bakanlik_yeniden_ac", {p_kod:kod});
      bilgi("Bakanlık yeniden açıldı.");
      return window.bakanlikKurKapatEkrani();
    } catch (err) { bilgi(hata(err),true); }
  };

  // Cumhurbaşkanının Devlet › Hükümet ve Yönetim sayfalarında tek giriş kartı.
  // Mevcut ekran bileşenlerine dokunmadan çalışan ek güvenli bağlantı.
  if (typeof iskelet === "function") {
    var eskiIskelet = iskelet;
    iskelet = function(baslik, govde, secenek) {
      if (cumhurbaskaniMi() &&
          (baslik === "Yönetim" ||
           ((baslik === "Devlet" || baslik === "Devlet yönetimi") &&
            typeof D !== "undefined" && D.devletSekme === "hukumet")) &&
          typeof govde === "string" && govde.indexOf('id="bakanlik-kur-kapat-bag"') === -1) {
        govde = cbKarti() + govde;
      }
      return eskiIskelet.call(this,baslik,govde,secenek);
    };
  }
})();
