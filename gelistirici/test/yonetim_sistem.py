"""Süper yönetici portalı · Aşama 6 (174): sistem durumu, tutarlılık kontrolleri, yedek, asistan kaydı.
Çalıştır: ../kur_yerel.sh && python3 yonetim_sistem.py"""
import json, random
from db import q, rpc, kullanici_ekle, hata_bekle

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def J(o): return json.dumps(o, ensure_ascii=False)
ek = str(random.randint(100, 999))
Y = kullanici_ekle(f"sahip{ek}@sistem.com"); rpc(Y, "profil_olustur", "SistemSahibi" + ek, 34)
q(f"update oyun.profiller set yonetici = true where id = '{Y}'")
A = kullanici_ekle(f"a{ek}@sistem.com"); rpc(A, "profil_olustur", "SisA" + ek, 6)
B = kullanici_ekle(f"b{ek}@sistem.com"); rpc(B, "profil_olustur", "SisB" + ek, 6)

for f in ("yp_sistem", "yp_tutarlilik", "yp_asistan_gecmis"):
    hata_bekle(rpc, A, f, icerir="YP_YETKI")
hata_bekle(rpc, A, "yp_asistan_kaydet", "soru", "yanit", icerir="YP_YETKI")
ok("Oyuncu sistem, tutarlılık ve asistan kaydına erişemez")

S = rpc(Y, "yp_sistem")
for k in ("surum", "oyuncu", "veritabani", "yedekler", "zamanlayici", "motor_hatalari", "push", "portal"):
    assert k in S, k
assert S["veritabani"]["boyut"] > 0 and S["oyuncu"]["toplam"] >= 3
ok("Sistem durumu okunuyor (sürüm, oyuncu, veritabanı, yedek, zamanlayıcı, motor hataları)")

def kontrol(kod): return next(k for k in rpc(Y, "yp_tutarlilik")["kontroller"] if k["kod"] == kod)
c0 = kontrol("negatif_kasa")["sayi"]; m0 = kontrol("cift_makam")["sayi"]
k0 = q("select kasa from oyun.partiler where id = 1"); q("update oyun.partiler set kasa = -500 where id = 1")
q(f"insert into oyun.makamlar(tur, user_id, il_id, kaynak, bas) values ('bel', '{A}', 6, 'atama', now()), ('bel', '{B}', 6, 'atama', now())")
n = kontrol("negatif_kasa"); m = kontrol("cift_makam")
assert n["sayi"] == c0 + 1 and "Parti" in n["ornekler"][0]["metin"], n
assert m["sayi"] == m0 + 1 and "Ankara" in json.dumps(m["ornekler"], ensure_ascii=False), m
T = rpc(Y, "yp_tutarlilik"); assert T["sorunlu"] >= 2 and len(T["kontroller"]) >= 14
assert "secmen" not in json.dumps(kontrol("oy_pencere_disi"), ensure_ascii=False)
q(f"update oyun.partiler set kasa = {k0} where id = 1"); q("update oyun.makamlar set bit = now() where il_id = 6 and tur = 'bel' and bit is null")
assert kontrol("negatif_kasa")["sayi"] == c0
ok("Tutarlılık: eksi parti kasası ve aynı koltukta iki başkan yakalandı (oyuncu bağlantısıyla); düzeltilince temizlendi")

o = rpc(Y, "yp_onizle", "yedek_al", J({"aciklama": "a"}))
assert "açıklama" in o["engel"].lower(), o
o = rpc(Y, "yp_onizle", "yedek_al", J({"aciklama": "Test yedeği"}))
assert o.get("engel") is None and not o["kritik"], o
s = rpc(Y, "yp_uygula", o["anahtar"], None)
assert s["basarili"] and s["dogrulama"]["tutarli"] and s["dogrulama"]["tablo"] > 100, s
assert any(y["sema"] == s["sonra"]["sema"] and "Portal: Test yedeği" in (y["aciklama"] or "") for y in rpc(Y, "yp_sistem")["yedekler"])
assert "geri alınamaz" in rpc(Y, "yp_onizle", "geri_al", J({"islem_id": s["islem_id"]}))["engel"]
ok("Portaldan yedek alındı (oyunun kendi yedek fonksiyonu, tüm tablolar); listede açıklamasıyla görünüyor")

kid = rpc(Y, "yp_asistan_kaydet", "Kaç oyuncu var?", "3 oyuncu var.", J([{"ad": "pano"}]), J([]), "deneme", 100, 10, None)
G = rpc(Y, "yp_asistan_gecmis", 10)
assert G[0]["id"] == kid and G[0]["soru"] == "Kaç oyuncu var?" and G[0]["araclar"][0]["ad"] == "pano"
assert rpc(Y, "yp_sistem")["portal"]["asistan_7g"] >= 1
ok("Asistan konuşması kayda geçti ve geçmişte görünüyor")
print(f"{len(TAMAM)} kontrol geçti")
