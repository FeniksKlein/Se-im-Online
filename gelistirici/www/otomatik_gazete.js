/* Türkiye Gündem: doğrulanmış kayıtları aktaran ücretsiz, otomatik gazete. */
const TG_KAT={siyaset:"Siyaset",secim:"Seçimler",adaylar:"Adaylar",ittifak:"İttifak",ekonomi:"Ekonomi",meclis:"Meclis",yerel:"Yerel",gundem:"Gündem",bulten:"Bülten"};
const TG_RENK={siyaset:"",secim:"",adaylar:"",ittifak:"",ekonomi:"",meclis:"",yerel:"",gundem:"",bulten:""};
let tgCache={};
function tgTarih(t){return t?new Date(t).toLocaleString("tr-TR",{dateStyle:"long",timeStyle:"short"}):"—"}
async function otomatikGazeteEkrani(kategori=null,offset=0){
 yukleniyor("Türkiye Gündem");
 try{
  const d=await API.rpc("ajans_haberler",{p_limit:30,p_kategori:kategori,p_offset:offset});
  const bas=d.manset||d.haberler[0],items=(d.haberler||[]).filter(x=>!bas||x.id!==bas.id);
  if(offset===0)tgCache={};(d.haberler||[]).forEach(x=>tgCache[x.id]=x);
  if(bas)tgCache[bas.id]=bas;
  const tabs=[[null,"Tümü"],...Object.entries(TG_KAT).map(([k,v])=>[k,v])];
  const tab=`<div class="tg-secimler">${tabs.map(([k,v])=>`<button class="tg-filtre ${k===kategori?"secili":""}" onclick="otomatikGazeteEkrani(${k?`'${k}'`:"null"},0)">${e(v)}</button>`).join("")}</div>`;
  const lead=bas?`<article class="tg-manset" onclick="tgHaberOku(${bas.id})" tabindex="0" role="button" onkeydown="if(event.key==='Enter')tgHaberOku(${bas.id})">
    <span class="tg-ust">Son dakika · Günün manşeti</span>
    <span class="tg-kategori">${TG_RENK[bas.kategori]||""} ${e(TG_KAT[bas.kategori]||bas.kategori)}</span>
    <h2>${e(bas.baslik)}</h2><p>${e(bas.ozet)}</p>
    <div class="tg-meta">${tgTarih(bas.zaman)} · Haberin tamamını oku →</div>
  </article>`:"";
  const cards=items.map(h=>`<article class="tg-haber">
    <div class="tg-gorev">${TG_RENK[h.kategori]||""} ${e(TG_KAT[h.kategori]||h.kategori)}${h.parti?" · "+e(h.parti):""}${h.il?" · "+e(h.il):""}</div>
    <h3>${e(h.baslik)}</h3><p>${e(h.ozet)}</p>
    <div class="tg-meta">${tgTarih(h.zaman)}</div>
    <button class="tg-oku" onclick="tgHaberOku(${h.id})">Haberin devamı →</button>
  </article>`).join("");
  iskelet("Türkiye Gündem",`
    <section class="tg-kapak"><div class="tg-saat">Oyuncu gazetesi değil · otomatik haber merkezi</div>
      <h1>TÜRKİYE <span>GÜNDEM</span></h1>
      <div class="tg-slogan">Siyasetin nabzı burada atıyor.</div>
      <div class="tg-baslik-alt"><span>Ücretsiz</span><span>5 dakikada bir güncellenir</span><span>${tgTarih(d.yayin_tarihi)}</span></div>
    </section>
    <section class="tg-tanitim"><span>Canlı oyun haberleri</span>
      <p>Haberler gerçek oyuncuların parti, seçim, adaylık ve ekonomi kayıtlarından üretilir. Gerçek olmayan olay veya sonuç uydurulmaz. Parti tanıtımları siyasi açıklama olarak belirtilir.</p>
    </section>
    ${tab}
    ${offset===0?lead:""}
    <div class="tg-govde"><div class="tg-bolum-bas"><h2>Son gelişmeler</h2><span>${fmt(d.toplam,0)} haber</span></div>
    <div class="tg-liste">${cards||"<div class='kart'>Bu kategoride henüz yayımlanmış haber bulunmuyor.</div>"}</div></div>
    <div class="satir"><button class="btn ikinci yarim" onclick="otomatikGazeteEkrani(${kategori?`'${kategori}'`:"null"},Math.max(0,${offset}-30))" ${offset===0?"disabled":""}>← Önceki</button>
    <button class="btn altin yarim" onclick="otomatikGazeteEkrani(${kategori?`'${kategori}'`:"null"},${offset}+30)" ${offset+30>=d.toplam?"disabled":""}>Daha fazla →</button></div>
    <button class="btn ikinci" onclick="basinEkrani()">Oyuncuların gazetelerine dön</button>
  `,{geri:true});
 }catch(err){iskelet("Türkiye Gündem",`<div class="kart"><h2>Gazete geçici olarak okunamıyor</h2>
    <p class="alt">${e(hataCevir(err.message))}</p>
    <button class="btn ikinci" onclick="otomatikGazeteEkrani()">Tekrar dene</button></div>`,{geri:true});}
}
function tgHaberOku(id){
 const h=tgCache[id];if(!h){otomatikGazeteEkrani();return;}
 iskelet("Türkiye Gündem",`
  <section class="tg-kapak"><div class="tg-saat">Türkiye Gündem · haber arşivi</div><h1>TÜRKİYE <span>GÜNDEM</span></h1>
   <div class="tg-slogan">Otomatik ve ücretsiz haber merkezi</div></section>
  <article class="tg-detay"><div class="tg-gorev">${TG_RENK[h.kategori]||""} ${e(TG_KAT[h.kategori]||h.kategori)}</div>
    <h1>${e(h.baslik)}</h1><div class="tg-meta">Yayımlanma: ${tgTarih(h.zaman)} · Kaynak: gerçek oyun kayıtları</div>
    <div class="tg-ozet">${e(h.ozet)}</div><div class="tg-tam">${e(h.metin)}</div>
    <div class="tg-dipnot">Haberler oyun içindeki kayıtlı olaylara dayanır. Gazete hiçbir adayın destekçisi değildir.</div>
  </article><button class="btn altin" onclick="otomatikGazeteEkrani()">← Gazete ana sayfasına dön</button>
 `,{geri:true});
}

/** Bağışlar alıcının kendi sayfasında gösterilir. */
function aliciBagisModal(tur, id, ad){
  const kabulEdilen=["oyuncu","parti","sirket","gazete","il","devlet"];
  if(!kabulEdilen.includes(tur)||id==null||String(id).trim()===""){
    toast("Bağış yapılacak alıcı bulunamadı.",true);return;
  }
  const hedef=String(id),isim=String(ad||(tur==="oyuncu"?id:
    tur==="devlet"?"Türkiye Cumhuriyeti Hazinesi":
    tur==="parti"?"Siyasi parti":tur==="sirket"?"Şirket":
    tur==="gazete"?"Gazete":"Belediye / il"));
  const turAd={oyuncu:"Oyuncuya para hediye et",parti:"Partiye bağış yap",
    sirket:"Şirkete bağış yap",gazete:"Gazeteye bağış yap",
    il:"Şehre bağış yap",devlet:"Devlet hazinesine bağış yap"};
  const m=modal(`<h3>${e(turAd[tur])}</h3>
    <div class="kart" style="background:var(--panel2);margin:10px 0">
      <span class="kucuk">Bağışın alıcısı</span><h3 style="margin-top:5px">${e(isim)}</h3>
      <p class="alt">Bağış doğrudan ${tur==="oyuncu"?"oyuncunun cüzdanına":"ilgili kurumun kasasına"} aktarılır. ${["oyuncu","sirket","gazete"].includes(tur)?"Oyunculara, şirketlere ve gazetelere aktarılan para (hediye ve havale birlikte) günlük sınıra tabidir.":"Partiye, şehre ve hazineye bağışın sınırı yoktur; bağış günde bir kıdem puanına kadar kazandırır."}</p>
      <div class="kucuk" id="ah_hak"></div>
    </div>
    <div class="alan"><label>Tutar (₺)</label><input id="ah_tutar" type="number" min="1" step="1" value="1000" inputmode="numeric"></div>
    <div class="alan"><label>Not (isteğe bağlı)</label><input id="ah_not" maxlength="150" placeholder="Bağış açıklaması"></div>
    <p class="kucuk">Bağış geri alınamaz; şirket bağışı hisse satın alma anlamına gelmez.</p>
    <button class="btn" id="ah_gonder">${e(isim)} için bağışla</button>
    <button class="btn ikinci" id="ah_vazgec">Vazgeç</button>`);
  $("#ah_vazgec",m).onclick=()=>modalKapat();
  if(["oyuncu","sirket","gazete"].includes(tur)) API.rpc("aktarim_hakki").then(h=>{const el=$("#ah_hak",m);if(el)el.textContent=h.engel?h.engel:"Bugün kalan aktarma hakkın: "+tlYaz(h.kalan)+" / "+tlYaz(h.tavan);}).catch(()=>{});
  $("#ah_gonder",m).onclick=async()=>{
    const miktar=Number($("#ah_tutar",m).value),aciklama=$("#ah_not",m).value.trim();
    if(!Number.isSafeInteger(miktar)||miktar<1){toast("En az 1 ₺ tutarında, tam sayı bağış gir.",true);return;}
    if(aciklama.length>150){toast("Bağış notu en fazla 150 karakter olmalı.",true);return;}
    const evet=await onayla("Bağışı onayla",
      "<b>"+e(isim)+"</b> alıcısına <b>"+tlYaz(miktar)+"</b> göndereceksin. İşlem geri alınamaz.",
      "Evet, bağışla");
    if(!evet)return;
    try{
      const result=await API.rpc("serbest_bagis",{
        p_tur:tur,p_id:hedef,p_tutar:miktar,p_aciklama:aciklama||null});
      D._hayat=null;
      toast(tlYaz(miktar)+" "+result.hedef+" hesabına gönderildi.");
      try {await durumYenile();}catch(_){}
      if(tur==="parti")partiDetay(+hedef);
      else if(tur==="gazete")gazeteEkrani(+hedef);
      else if(tur==="sirket")sirketEkrani();
      else if(tur==="il")ilDetay(+hedef);
      else if(tur==="devlet")devletEkrani();
      else if(tur==="oyuncu")oyuncuKart(hedef);
    }catch(err){toast(hataCevir(err.message),true);}
  };
}
