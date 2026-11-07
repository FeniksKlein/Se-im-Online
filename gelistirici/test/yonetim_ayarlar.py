"""Süper yönetici portalı · Aşama 3 (171): canlı ayarlar kabul testleri.
Çalıştır: ../kur_yerel.sh && python3 yonetim_ayarlar.py
Katalog, doğrulama, yüksek riskte ikinci onay, geçmiş, geri alma, süreli ve ileri tarihli değişiklik, canlı sinyal."""
import json
from db import q, rpc, kullanici_ekle, hata_bekle

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def J(o): return json.dumps(o, ensure_ascii=False)

Y = kullanici_ekle("sahip@ayar.com"); rpc(Y, "profil_olustur", "AyarSahibi", 34)
q(f"update oyun.profiller set yonetici = true where id = '{Y}'")
O = kullanici_ekle("oyuncu@ayar.com"); rpc(O, "profil_olustur", "AyarOyuncu", 6)

def onizle(p): return rpc(Y, "yp_onizle", "ayar_degistir", J(p))
def uygula(o, onay=None): return rpc(Y, "yp_uygula", o["anahtar"], onay)
def deger(sql): return q(sql)
def rev(): return int(q("select rev from public.oyun_kontrol_sinyali where id = 1") or 0)

hata_bekle(rpc, O, "yp_ayarlar", icerir="YP_YETKI")
ok("Oyuncu ayar listesini göremez")

A = rpc(Y, "yp_ayarlar")
anahtarlar = {a["anahtar"]: a for a in A["ayarlar"]}
assert "ayarlar.mentor_odul" in anahtarlar and "ayarlar.maas_hizi" in anahtarlar and len(A["gruplar"]) == 6, A["gruplar"]
ok(f"Katalog: {len(anahtarlar)} etkin ayar, 6 grup, güncel değerleriyle")

# düşük risk: tek onaylı
m0 = deger("select mentor_odul from oyun.ayarlar")
r0 = rev()
o = onizle({"degisiklikler": [{"anahtar": "ayarlar.mentor_odul", "deger": 2500}], "neden": "Mentorluğu teşvik"})
assert o.get("engel") is None and not o["kritik"], o
s = uygula(o)
assert s["basarili"] and s["dogrulama"]["tutarli"], s
assert float(deger("select mentor_odul from oyun.ayarlar")) == 2500
assert deger("select count(*) from oyun.yp_ayar_gecmis where anahtar = 'ayarlar.mentor_odul' and kaynak = 'portal'") == "1"
assert rev() > r0
ok("Düşük riskli ayar tek onayla değişti; geçmişe yazıldı; canlı sinyal yayıldı")

# sınır dışı / aynı değer / neden yok
o = onizle({"degisiklikler": [{"anahtar": "ayarlar.cihaz_max_hesap", "deger": 9}], "neden": "deneme"})
assert "En çok 5" in o["engel"], o
o = onizle({"degisiklikler": [{"anahtar": "ayarlar.mentor_odul", "deger": 2500}], "neden": "deneme"})
assert "zaten" in o["engel"], o
o = onizle({"degisiklikler": [{"anahtar": "ayarlar.mentor_odul", "deger": 3000}]})
assert "neden" in o["engel"], o
o = onizle({"degisiklikler": [{"anahtar": "ayarlar.iz_tuz", "deger": "x"}], "neden": "deneme"})
assert "Tanımsız" in o["engel"], o
ok("Sınır dışı değer, aynı değer, nedensiz değişiklik ve katalog dışı ayar reddedildi")

# yüksek risk: ikinci onay
o = onizle({"degisiklikler": [{"anahtar": "ayarlar.maas_hizi", "deger": 2}], "neden": "Enflasyonu yavaşlat"})
assert o["kritik"] and o.get("engel") is None, o
hata_bekle(rpc, Y, "yp_uygula", o["anahtar"], None, icerir="YP_ONAY")
s = uygula(o, "ONAYLIYORUM")
assert s["basarili"] and float(deger("select maas_hizi from oyun.ayarlar")) == 2, s
ok("Yüksek riskli ayar (gelir hızı) ikinci onay olmadan uygulanmadı, onayla uygulandı")

# metin + uygulama ayarı (jsonb)
o = onizle({"degisiklikler": [{"anahtar": "uygulama.duyuru_bandi", "deger": "Bu akşam 21:00'de seçim gecesi!"},
                              {"anahtar": "ayarlar.stant_bedel", "deger": "3.000".replace(".", "")}], "neden": "Etkinlik duyurusu"})
s = uygula(o)
assert s["basarili"], s
assert deger("select deger #>> '{}' from oyun.uygulama_ayar where anahtar = 'duyuru_bandi'") == "Bu akşam 21:00'de seçim gecesi!"
ok("Duyuru bandı (uygulama ayarı) ve seçim standı bedeli birlikte değişti")

# ön izlemeden sonra değer değişirse uygulanmaz
o = onizle({"degisiklikler": [{"anahtar": "ayarlar.stant_bedel", "deger": 4000}], "neden": "Deneme"})
q("update oyun.ayarlar set stant_bedel = 3500")
s = uygula(o)
assert not s["basarili"] and s.get("degisti"), s
ok("Ön izlemeden sonra ayar başka yerden değişince işlem durdu")

# geri al
mo = int(q("select id from oyun.yp_islem where islem='ayar_degistir' and durum='uygulandi' and parametre::text like '%mentor_odul%' order by id limit 1"))
g = rpc(Y, "yp_onizle", "geri_al", J({"islem_id": mo}))
assert g.get("engel") is None, g
s = rpc(Y, "yp_uygula", g["anahtar"], "ONAYLIYORUM")
assert s["basarili"] and float(deger("select mentor_odul from oyun.ayarlar")) == float(m0), s
ok(f"Mentorluk ödülü geri alındı ({m0} ₺)")

# başkası değiştirdikten sonra geri alma dokunmaz
mid = int(q("select id from oyun.yp_islem where islem='ayar_degistir' and durum='uygulandi' and parametre::text like '%maas_hizi%' order by id limit 1"))
q("update oyun.ayarlar set maas_hizi = 5")
g = rpc(Y, "yp_onizle", "geri_al", J({"islem_id": mid}))
assert g.get("engel"), g
ok("Ayar bu arada başka değere çekildiyse geri alma dokunmuyor")

# süreli değişiklik: şimdi uygula, süre bitince eski değere dön
k0 = deger("select deger #>> '{}' from oyun.uygulama_ayar where anahtar = 'kart_gunluk'")
o = onizle({"degisiklikler": [{"anahtar": "uygulama.kart_gunluk", "deger": 15000}], "neden": "Hafta sonu çift ödül",
            "bitis": "2099-01-01T00:00:00+03:00"})
assert "bitiş" not in (o.get("engel") or "").lower() and "90 gün" in (o.get("engel") or ""), o
o = onizle({"degisiklikler": [{"anahtar": "uygulama.kart_gunluk", "deger": 15000}], "neden": "Hafta sonu çift ödül",
            "bitis": q("select to_char(now() + interval '2 days', 'YYYY-MM-DD\"T\"HH24:MI:SSOF')")})
s = uygula(o)
assert s["basarili"] and len(s["planlar"]) == 1 and deger("select deger #>> '{}' from oyun.uygulama_ayar where anahtar = 'kart_gunluk'") == "15000", s
assert len(rpc(Y, "yp_ayarlar")["planlar"]) == 1
q("update oyun.yp_ayar_plan set zaman = now() - interval '1 minute' where durum = 'bekliyor'")
assert q("select oyun.yp_ayar_plan_isle()") == "1"
assert deger("select deger #>> '{}' from oyun.uygulama_ayar where anahtar = 'kart_gunluk'") == k0
assert deger("select count(*) from oyun.yp_ayar_gecmis where anahtar = 'uygulama.kart_gunluk' and kaynak = 'plan_bitis'") == "1"
ok(f"Süreli değişiklik: Siyaset Kartı ödülü 15.000 ₺ oldu, süre bitince zamanlayıcı {k0} ₺'ye döndürdü")

# ileri tarihli + süreli
b0 = deger("select baraj from oyun.ayarlar")
o = onizle({"degisiklikler": [{"anahtar": "ayarlar.baraj", "deger": 10}], "neden": "Seçim öncesi baraj",
            "baslangic": q("select to_char(now() + interval '1 day', 'YYYY-MM-DD\"T\"HH24:MI:SSOF')"),
            "bitis": q("select to_char(now() + interval '3 days', 'YYYY-MM-DD\"T\"HH24:MI:SSOF')")})
assert o["kritik"], o
s = uygula(o, "ONAYLIYORUM")
assert s["basarili"] and len(s["planlar"]) == 2 and float(deger("select baraj from oyun.ayarlar")) == float(b0), s
ileri = int(s["islem_id"])
q(f"update oyun.yp_ayar_plan set zaman = now() - interval '1 minute' where islem_id = {ileri} and tur = 'uygula'")
q("select oyun.yp_ayar_plan_isle()")
assert float(deger("select baraj from oyun.ayarlar")) == 10
assert deger(f"select jsonb_array_length(degisiklikler) from oyun.yp_ayar_plan where islem_id = {ileri} and tur = 'geri_don'") == "1"
q(f"update oyun.yp_ayar_plan set zaman = now() - interval '1 minute' where islem_id = {ileri} and tur = 'geri_don'")
q("select oyun.yp_ayar_plan_isle()")
assert float(deger("select baraj from oyun.ayarlar")) == float(b0)
ok(f"İleri tarihli değişiklik: baraj zamanı gelince %10 oldu, süre bitince %{b0}'a döndü")

# bekleyen planı geri al = iptal
o = onizle({"degisiklikler": [{"anahtar": "ayarlar.teskilat_ucret", "deger": 20000}], "neden": "Plan iptal deneme",
            "baslangic": q("select to_char(now() + interval '1 day', 'YYYY-MM-DD\"T\"HH24:MI:SSOF')")})
s = uygula(o)
g = rpc(Y, "yp_onizle", "geri_al", J({"islem_id": s["islem_id"]}))
gs = rpc(Y, "yp_uygula", g["anahtar"], "ONAYLIYORUM")
assert gs["basarili"] and deger(f"select durum from oyun.yp_ayar_plan where islem_id = {s['islem_id']}") == "iptal", gs
ok("Henüz uygulanmamış planlı değişiklik geri alınınca iptal edildi")

G = rpc(Y, "yp_ayar_gecmis", None, 50)
assert len(G) >= 8 and all("eski" in x and "yeni" in x for x in G), G[:2]
ok(f"Ayar geçmişi: {len(G)} kayıt, önceki/yeni değerleriyle")
print(f"{len(TAMAM)} kontrol geçti")
