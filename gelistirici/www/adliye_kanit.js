/* Seçim Online · Dava dosyasına güvenli ekran görüntüsü ekleme. */
(function () {
  if (window.ADL_KANIT_MODUL) return;
  window.ADL_KANIT_MODUL = true;
  if (typeof adliyeDosya !== 'function') return;

  var orijinalDosya = adliyeDosya;
  var depo = null;
  function depoyaBaglan() {
    if (!depo) {
      if (!window.supabase || typeof AYAR === 'undefined') throw new Error('Görsel yükleme servisi kullanılamıyor.');
      depo = window.supabase.createClient(AYAR.SUPABASE_URL, AYAR.SUPABASE_ANON, {
        auth: { persistSession: true, autoRefreshToken: false, detectSessionInUrl: false }
      });
    }
    return depo;
  }
  function kanitKart(k, url) {
    var goruntu = url
      ? '<a href="' + e(url) + '" target="_blank" rel="noopener noreferrer" aria-label="Kanıt görselini büyüt"><img alt="Dava ekran görüntüsü" src="' + e(url) + '" loading="lazy" style="display:block;width:100%;max-width:260px;max-height:220px;object-fit:contain;border-radius:9px;margin-top:8px"></a>'
      : '<p class="kucuk">Görsel şu anda açılamıyor.</p>';
    return '<div class="liste-satir" style="display:block"><b>' + e(k.yukleyen) + '</b>' +
      '<p class="kucuk">' + tarihSaat(k.zaman) + '</p>' +
      (k.aciklama ? '<p style="white-space:pre-wrap">' + e(k.aciklama) + '</p>' : '') + goruntu + '</div>';
  }

  async function kanitlariGoster(id) {
    var r = await API.rpc('adliye_kanit_listele', { p_dava: id });
    var istemci = depoyaBaglan();
    var kanitlar = Array.isArray(r.kanitlar) ? r.kanitlar : [];
    var urller = await Promise.all(kanitlar.map(async function (k) {
      var sonuc = await istemci.storage.from('adliye-kanitlar').createSignedUrl(k.yol, 3600);
      return sonuc.error ? null : sonuc.data.signedUrl;
    }));
    var ana = document.getElementById('icerik');
    var ilk = ana && ana.querySelector('.kart .baslik b');
    if (!ana || !ilk || !ilk.textContent.trim().startsWith('#' + id + ' ·')) return;
    var onceki = ana.querySelector('#adliyeKanitKarti');
    if (onceki) onceki.remove();
    var html = '<div class="kart" id="adliyeKanitKarti"><h3>📸 Ekran görüntüsü kanıtları (' + kanitlar.length + ')</h3>' +
      '<p class="alt">Dava dosyasına eklenen ekran resimleri duruşmadaki herkes tarafından incelenebilir. Görseller otomatik olarak suçun kanıtlandığı anlamına gelmez.</p>' +
      (r.ekleyebilirim ? '<button type="button" class="btn altin" onclick="adlKanitYukleModal(' + id + ')">Ekran resmi / kanıt yükle</button>' : '') +
      (kanitlar.length ? kanitlar.map(function (k, i) { return kanitKart(k, urller[i]); }).join('') : '<p class="alt">Henüz görsel kanıt eklenmedi.</p>') + '</div>';
    ana.querySelector('.kart').insertAdjacentHTML('afterend', html);
  }

  window.adlKanitYukleModal = function (id) {
    var m = modal('<p class="alt">PNG, JPG veya WebP ekran görüntüsü seç. En fazla 5 MB ve kişi başına her dava için 5 görsel. Yalnız açık davanın tarafları, yetkili temsilcileri ve yargıçlar yükleyebilir.</p>' +
      '<div class="alan"><label>Dosya seç</label><input id="akDosya" type="file" accept="image/png,image/jpeg,image/webp"></div>' +
      '<div class="alan"><label>Görselin neyi kanıtladığı (isteğe bağlı)</label><textarea id="akAciklama" maxlength="300" rows="3" placeholder="Örn. 20 Ekim tarihli dernek kasa işlemi"></textarea></div>' +
      '<p class="hata-metin" id="akHata" role="alert"></p><button class="btn altin" id="akYukle">Kanıtı dosyaya ekle</button>');
    m.querySelector('#akYukle').onclick = async function () {
      var btn = m.querySelector('#akYukle');
      var hata = m.querySelector('#akHata');
      var file = m.querySelector('#akDosya').files[0];
      hata.textContent = '';
      if (!file) { hata.textContent = 'Önce bir ekran resmi seç.'; return; }
      var uzanti = ({ 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp' })[file.type];
      if (!uzanti) { hata.textContent = 'Yalnız PNG, JPG veya WebP görsel yüklenebilir.'; return; }
      if (file.size > 5 * 1024 * 1024 || file.size < 1) { hata.textContent = 'Görsel boyutu 5 MB sınırını aşamaz.'; return; }
      btn.disabled = true;
      btn.textContent = 'Kanıt yükleniyor…';
      var yuklenenYol = null;
      try {
        var sb = depoyaBaglan();
        var oturum = await sb.auth.getSession();
        if (oturum.error || !oturum.data.session) throw new Error('Yükleme için oyuncu hesabına giriş yap.');
        var userId = oturum.data.session.user.id;
        yuklenenYol = String(id) + '/' + userId + '/' + crypto.randomUUID() + '.' + uzanti;
        var sonuc = await sb.storage.from('adliye-kanitlar').upload(yuklenenYol, file, { contentType: file.type, upsert: false });
        if (sonuc.error) throw sonuc.error;
        await API.rpc('adliye_kanit_kaydet', { p_dava: id, p_yol: yuklenenYol, p_aciklama: m.querySelector('#akAciklama').value });
        yuklenenYol = null;
        modalKapat();
        toast('Ekran resmi dava dosyasına eklendi.');
        await adliyeDosya(id);
      } catch (err) {
        if (yuklenenYol) {
          try { await depoyaBaglan().storage.from('adliye-kanitlar').remove([yuklenenYol]); } catch (_) {}
        }
        hata.textContent = hataCevir(err.message || String(err));
        btn.disabled = false;
        btn.textContent = 'Kanıtı dosyaya ekle';
      }
    };
  };

  window.adliyeDosya = adliyeDosya = async function (id) {
    await orijinalDosya.apply(this, arguments);
    try { await kanitlariGoster(id); }
    catch (err) {
      var ana = document.getElementById('icerik');
      var ilk = ana && ana.querySelector('.kart .baslik b');
      if (ilk && ilk.textContent.trim().startsWith('#' + id + ' ·')) {
        ana.querySelector('.kart').insertAdjacentHTML('afterend', '<div class="kart"><p class="alt">Görsel kanıtlar alınamadı: ' + e(hataCevir(err.message)) + '</p></div>');
      }
    }
  };
})();
