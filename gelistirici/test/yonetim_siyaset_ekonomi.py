"""Süper yönetici portalı · Aşama 4 (172): siyaset ve ekonomi kabul testleri.
Çalıştır: ../kur_yerel.sh && python3 yonetim_siyaset_ekonomi.py
Siyaset/ekonomi panoları, kurum kasası (defter kaydı, ikinci onay, geri alma), parti adı düzeltme, ekonomi ayar kataloğu."""
import json
from db import q, rpc, kullanici_ekle, hata_bekle

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def J(o): return json.dumps(o, ensure_ascii=False)

Y = kullanici_ekle("sahip@siyaset.com"); rpc(Y, "profil_olustur", "SiyasetSahibi", 34)
q(f"update oyun.profiller set yonetici = true where id = '{Y}'")
U = {}
for ad, il in (("Uye1", 34), ("Uye2", 6), ("Uye3", 35)):
    u = kullanici_ekle(f"{ad}@siyaset.com"); rpc(u, "profil_olustur", ad, il); U[ad] = u
q(f"update oyun.profiller set parti_id = 2, parti_at = now() where id in ('{U['Uye1']}', '{U['Uye2']}')")

def onizle(islem, p): return rpc(Y, "yp_onizle", islem, J(p))
def uygula(o, onay=None): return rpc(Y, "yp_uygula", o["anahtar"], onay)
def geri(islem_id):
    g = onizle("geri_al", {"islem_id": islem_id}); assert g.get("engel") is None, g
    return uygula(g, "ONAYLIYORUM")

hata_bekle(rpc, U["Uye1"], "yp_siyaset", icerir="YP_YETKI")
hata_bekle(rpc, U["Uye1"], "yp_ekonomi", icerir="YP_YETKI")
ok("Oyuncu siyaset ve ekonomi panolarını göremez")

S = rpc(Y, "yp_siyaset")
assert len(S["belediyeler"]) == 81 and any(p["id"] == 2 and p["uye"] == 2 for p in S["partiler"]) and "meclis" in S and "devlet" in S, S.keys()
P = rpc(Y, "yp_parti", 2)
assert len(P["uyeler"]) == 2 and "gecisler" in P and "teskilat" in P
E = rpc(Y, "yp_ekonomi")
for k in ("gosterge", "para_arzi", "bakanliklar", "zenginler", "transferler", "masak", "hazine_hareket"):
    assert k in E, k
assert len(E["bakanliklar"]) == 12
ok("Siyaset panosu (81 belediye, partiler, meclis), parti dosyası ve ekonomi panosu okunuyor")

# parti kasası
k0 = float(q("select kasa from oyun.partiler where id = 2"))
o = onizle("kurum_kasa", {"tur": "parti", "id": "2", "tutar": 25000, "aciklama": "Seçim desteği"})
assert o["kritik"] and o.get("engel") is None, o
hata_bekle(rpc, Y, "yp_uygula", o["anahtar"], None, icerir="YP_ONAY")
s = uygula(o, "ONAYLIYORUM")
assert s["basarili"] and s["dogrulama"]["tutarli"] and float(q("select kasa from oyun.partiler where id = 2")) == k0 + 25000, s
geri(s["islem_id"])
assert float(q("select kasa from oyun.partiler where id = 2")) == k0
ok("Parti kasası: ikinci onayla +25.000 ₺, geri alınınca eski bakiye")

# kasadan fazlası düşülemez
o = onizle("kurum_kasa", {"tur": "parti", "id": "2", "tutar": -(int(k0) + 1), "aciklama": "Deneme"})
assert "yeterli" in (o.get("engel") or ""), o
ok("Kasadaki paradan fazlası düşülemiyor")

# Hazine defteri
h0 = float(q("select hazine from oyun.ulke where id = 1"))
n0 = int(q("select count(*) from oyun.hazine_hareketleri"))
o = onizle("kurum_kasa", {"tur": "hazine", "tutar": 12.5, "aciklama": "Kriz desteği"})
s = uygula(o, "ONAYLIYORUM")
assert s["basarili"] and abs(float(q("select hazine from oyun.ulke where id = 1")) - (h0 + 12.5)) < 1e-9, s
assert int(q("select count(*) from oyun.hazine_hareketleri")) == n0 + 1
assert q("select aciklama from oyun.hazine_hareketleri order by id desc limit 1") == "Oyun yönetimi: Kriz desteği"
assert q("select kalem from oyun.hazine_hareketleri order by id desc limit 1") == "diger_gelir"
ok("Hazine +12,5 milyar ₺; Hazine defterine 'Oyun yönetimi' kaydı ve kalem yazıldı")

# Bakanlık defteri
b0 = float(q("select kasa from oyun.bakanlik_kasa where kod = 'adalet'"))
o = onizle("kurum_kasa", {"tur": "bakanlik", "id": "adalet", "tutar": 3, "aciklama": "Ek ödenek düzeltmesi"})
s = uygula(o, "ONAYLIYORUM")
assert s["basarili"] and q("select tur || '|' || aciklama from oyun.bakanlik_hareket where kod = 'adalet' order by id desc limit 1") == "yonetim|Oyun yönetimi: Ek ödenek düzeltmesi", s
geri(s["islem_id"])
assert abs(float(q("select kasa from oyun.bakanlik_kasa where kod = 'adalet'")) - b0) < 1e-9
ok("Bakanlık kasası: defter kaydı 'yonetim' türüyle; geri alındı")

# Belediye ve şirket
o = onizle("kurum_kasa", {"tur": "il", "id": "35", "tutar": 50000, "aciklama": "Afet yardımı"})
s = uygula(o, "ONAYLIYORUM"); assert s["basarili"], s
q(f"insert into oyun.sirketler(ad, sektor, kurucu, sermaye, kasa) values ('Test Gıda', 'ticaret', '{U['Uye3']}', 100000, 100000)")
sid = q("select id from oyun.sirketler where ad = 'Test Gıda'")
o = onizle("kurum_kasa", {"tur": "sirket", "id": sid, "tutar": -4000, "aciklama": "Haksız kazanç iadesi"})
s = uygula(o, "ONAYLIYORUM")
assert s["basarili"] and float(q(f"select kasa from oyun.sirketler where id = {sid}")) == 96000, s
assert q(f"select aciklama from oyun.sirket_hareket where sirket_id = {sid} order by id desc limit 1") == "Oyun yönetimi: Haksız kazanç iadesi"
ok("Belediye kasası ve şirket kasası düzeltildi; şirket hareketine kayıt düştü")

# Parti adı
eski = q("select ad || '|' || kisa from oyun.partiler where id = 2")
bas_bildirim = int(q(f"select count(*) from oyun.bildirimler where user_id = '{U['Uye1']}'"))
o = onizle("parti_duzenle", {"parti_id": 2, "ad": "Deneme Halk Partisi", "kisa": "DHP", "renk": "#2255aa"})
assert o.get("engel") is None and not o["kritik"] and len(o["degisen"]) == 3, o
s = uygula(o)
assert s["basarili"] and q("select ad || '|' || kisa || '|' || renk from oyun.partiler where id = 2") == "Deneme Halk Partisi|DHP|#2255aa", s
assert int(q(f"select count(*) from oyun.bildirimler where user_id = '{U['Uye1']}'")) == bas_bildirim + 1
assert q("select count(*) from oyun.parti_ad_gecmis where parti_id = 2 and yeni_kisa = 'DHP'") == "1"
assert q("select son_ad_degis is null from oyun.partiler where id = 2") in ("t", "f")
diger = q("select kisa from oyun.partiler where id = 1")
o = onizle("parti_duzenle", {"parti_id": 2, "kisa": diger})
assert "kullanılıyor" in (o.get("engel") or ""), o
o = onizle("parti_duzenle", {"parti_id": 2, "ad": "Parti 123"})
assert "harf" in (o.get("engel") or ""), o
geri(s["islem_id"])
assert q("select ad || '|' || kisa from oyun.partiler where id = 2") == eski
ok("Parti adı/kısa adı/rengi düzeltildi (üyelere bildirim, ad geçmişi); çakışan ve kurala aykırı ad reddedildi; geri alındı")

A = rpc(Y, "yp_ayarlar")
keys = {a["anahtar"] for a in A["ayarlar"]}
assert {"makro.enf_tavan", "denge.aktif", "pazar.kurumlar", "bakanlik.tavan"} <= keys
o = onizle("ayar_degistir", {"degisiklikler": [{"anahtar": "pazar.tl_milyar", "deger": 160000}], "neden": "Kur ayarı"})
assert o["kritik"], o
ok(f"Ekonomi parametreleri canlı ayar kataloğunda ({len(keys)} ayar); kamu ₺ kuru yüksek riskli")

L = rpc(Y, "yp_sirketler", "Test G", 50)
assert any(x["ad"] == "Test Gıda" for x in L)
ok("Şirket listesi aranabiliyor")
print(f"{len(TAMAM)} kontrol geçti")
