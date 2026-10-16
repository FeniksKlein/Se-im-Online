// gorunum_onizleme.js için örnek veri (kurgusal).
module.exports = {
  profil: { il_id: 35, il_ad: 'İzmir', kad: 'Ada', ad: 'Ada Yılmaz', parti: { id: 3, ad: 'Örnek Parti', kisa: 'ÖP', renk: '#3E7BFA' }, gb: false, gby: false,
    cuzdan: { para: 25079 }, kidem: 12, makamlar: [] },
  durum: {},
  rpc: {
    hayat: { para: 25079, bugun_toplandi: true, il_ad: 'İzmir', banka: { vadesiz: 0, vadeli: 0 },
      kumbara: { dolu: false, birikmis: 120, saat: 3, kapasite: 16, dolma_an: new Date(Date.now() + 36e6).toISOString(), seri: 1, seri_bonus: 0, reklam_odul: 500, vekil_kesinti: 0,
        gunluk_destek: { devlet: 0, belediye: 0 }, saatlik: { net: 40, maas: 50, brut: 50, vergi: 5, kent: 2, gecim: 3, makam: 0 },
        asgari: 17002, statu_carpan: 1, il_carpan: 1, ucret_bonus: 0, vergi_oran: 15, kent_oran: 2, gecim_indirim: 0 },
      statu: { ad: 'Vatandaş', puan: 5, bu_esik: 0, sonraki_esik: 50, sonraki_ad: 'Tanınan' },
      reklam: { kalan: 5, hazir: null }, etkiler: [], hareketler: [], mulkler: [],
      ulke: { asgari: 17002, vergi: 15, destek: 0, enflasyon: 30, tasinma_destek: 0 }, fiyat: { endeks: 1, tasinma: 1000 } },
    cimer: { basvurularim: [], gelen: [], kurumlar: { bakanliklar: [], il_id: 35 }, bugun_kalan: 3 },
  }
};
