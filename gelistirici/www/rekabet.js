(function () {
  'use strict';
  var data = null, selected = 'oyuncu';
  var boards = {
    oyuncu: ['En zengin 10 oyuncu', 'Hesaplanan net varlık: nakit, mevduat, yatırımlar, mülklerin alış bedeli ve şirket payları; kredi ve kart borçları düşülür. Çekler, tahviller ve koleksiyonlar dahil değildir.', '₺'],
    sirket: ['En zengin 10 şirket', 'Defter değeri + NPC stoklarının maliyet değeri. Sermaye ayrıca eklenmez; banka müşteri mevduatı şirket serveti sayılmaz.', '₺'],
    kar: ['Haftanın kâr liderleri', 'Son 7 günün faaliyet gelirleri eksi faaliyet giderleri. Sermaye yatırma ve hisse satışı kâr sayılmaz.', '₺'],
    satis: ['NPC satış liderleri', 'Son 7 günde NPC müşterilere yapılan satışların cirosu.', '₺'],
    takipci: ['Kürsü’nün en çok takip edilenleri', 'Yasaklı hesaplar hariç toplam takipçi sayısı.', 'takipçi'],
    mulk: ['Gayrimenkul liderleri', 'Oyuncuya ait iki mülk sistemindeki toplam mülk sayısı.', 'mülk']
  };
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function(c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); };
  function draw() {
    var b = boards[selected], rows = data && data[selected] || [];
    var html = '<div class="rp"><header><small>TÜRKİYE’NİN İLK 10’U</small><h2>Rekabet Panosu</h2><p>Servet, ticaret ve sosyal etkinin liderleri.</p></header><nav aria-label="Sıralamalar">' + Object.keys(boards).map(function(k) { return '<button type="button" data-rp="'+k+'" aria-pressed="'+(k===selected)+'">'+esc(boards[k][0])+'</button>'; }).join('') + '</nav><h3>'+esc(b[0])+'</h3><p class="rp-note">'+esc(b[1])+'</p><ol>';
    html += rows.map(function(r,i) { return '<li><span class="rp-rank">'+(i<3?['🥇','🥈','🥉'][i]:i+1)+'</span><span class="rp-name">'+esc(r.ad)+'</span><strong>'+Number(r.deger).toLocaleString('tr-TR',{maximumFractionDigits:0})+' <small>'+b[2]+'</small></strong></li>'; }).join('');
    html += '</ol>' + (!rows.length?'<p>Bu sıralama için henüz kayıt yok.</p>':'') + '<footer>5 dakikada bir güncellenir · Son hesaplama: '+esc(new Date(data.zaman).toLocaleString('tr-TR'))+'<br>Yasaklı oyuncular ve onların yönettiği şirketler listelenmez. Eşitlikte ada göre sıralanır.</footer><button type="button" class="btn" id="rp-refresh">Yenile</button></div>';
    iskelet('Rekabet Panosu', html, {geri:true});
    document.querySelectorAll('[data-rp]').forEach(function(el) { el.onclick=function(){selected=el.dataset.rp;draw();}; });
    document.getElementById('rp-refresh').onclick=window.rekabetEkrani;
  }
  window.rekabetEkrani = async function () {
    iskelet('Rekabet Panosu', '<div id="rp-loading" class="kart">Sıralamalar yükleniyor…</div>', {geri:true});
    try {
      var result = await API.rpc('rekabet_paneli', {});
      if (!document.getElementById('rp-loading')) return;
      data = result; draw();
    } catch(e) {
      if (!document.getElementById('rp-loading')) return;
      iskelet('Rekabet Panosu','<div class="kart"><p>'+esc(e.message || 'Sıralamalar yüklenemedi.')+'</p><button type="button" class="btn" onclick="rekabetEkrani()">Tekrar dene</button></div>',{geri:true});
    }
  };
  var style=document.createElement('style');
  style.textContent='.rp header{background:linear-gradient(120deg,#31345a,#174953);border:1px solid #567482;border-radius:22px;padding:24px 20px}.rp header small{color:#f0cd78;letter-spacing:2px}.rp h2{margin:8px 0;font-size:30px}.rp nav{display:flex;overflow:auto;gap:8px;padding:16px 0}.rp nav button{flex:0 0 auto;border-radius:20px;padding:10px 14px;background:#232e4a;color:#ccd5e8}.rp nav button[aria-pressed=true]{background:#edce85;color:#182033}.rp ol{list-style:none;padding:0}.rp li{display:flex;align-items:center;gap:12px;padding:16px 12px;background:var(--panel,#1b2540);border-bottom:1px solid #ffffff14}.rp li:first-child{border-radius:16px 16px 0 0;background:#8d713129}.rp li:last-child{border-radius:0 0 16px 16px}.rp-rank{width:28px;flex-shrink:0;text-align:center}.rp-name{flex:1;min-width:0;overflow-wrap:anywhere}.rp strong{text-align:right;font-variant-numeric:tabular-nums}.rp strong small{font-size:11px}.rp-note,.rp footer{font-size:12px;line-height:1.6;color:var(--mut,#a8b5cd)}.rp footer{margin:18px 0}.rp button:focus-visible{outline:2px solid #edce85;outline-offset:3px}';
  document.head.appendChild(style);
})();
