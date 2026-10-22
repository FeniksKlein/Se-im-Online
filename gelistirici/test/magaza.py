"""Mağaza (modül 115): RevenueCat olaylarıyla ₺ paketi, Siyaset Kartı, Başlangıç Paketi ve kalıcı haklar;
günlük Kart ödülü, iade, hesap taşıma, rozetler ve yönetici satış özeti."""
import json, uuid
from db import q, qj, rpc, kullanici_ekle, hata_bekle, saat

def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
q("update oyun.ayarlar set test_simdi = '2026-12-10 12:00+03'")

def oyuncu(kad):
    u = kullanici_ekle(f"{kad.lower()}_{uuid.uuid4().hex[:6]}@t.com"); rpc(u, "profil_olustur", kad, IL("İzmir")); return u
def para(u): return float(q(f"select para from oyun.cuzdan where user_id='{u}'"))
def olay(u, urun, tur="NON_RENEWING_PURCHASE", islem=None, **ek):
    e = {"type": tur, "app_user_id": u, "product_id": urun, "transaction_id": islem or uuid.uuid4().hex,
         "price_in_purchased_currency": 49.99, "currency": "TRY", "price": 1.25}
    e.update(ek)
    return qj(f"select public.odeme_isle($j${json.dumps({'event': e})}$j$::jsonb)")

ek = uuid.uuid4().hex[:4]
a = oyuncu("Alici" + ek); b = oyuncu("Diger" + ek)
d = rpc(a, "magaza_durum")
urunler = [p["urun_id"] for p in d["paketler"]]
assert urunler[:2] == ["baslangic_paketi", "siyaset_karti"] and "para_servet" in urunler and "tl_10000" not in urunler, urunler
assert d["kart"]["aktif"] is False and d["reklamsiz"] is False and d["haklar"] == []
ok("Vitrin: 8 ürün, eski deneme paketleri gizli")

once = para(a)
r = olay(a, "para_kampanya", islem=ek+"t1"); assert r["durum"] == "eklendi", r
assert para(a) == once + 125000
assert olay(a, "para_kampanya", islem=ek+"t1")["durum"] == "zaten_islendi" and para(a) == once + 125000
ok("₺ paketi bir kez işleniyor (aynı işlem ikinci kez gelirse para eklenmiyor)")

once = para(a)
assert olay(a, "baslangic_paketi", islem=ek+"t2")["durum"] == "eklendi"
d = rpc(a, "magaza_durum")
assert para(a) == once + 100000 and d["kart"]["aktif"] and d["reklamsiz"]
assert [p for p in d["paketler"] if p["urun_id"] == "baslangic_paketi"][0]["alinabilir"] is False
bit1 = q(f"select kart_bitis from oyun.magaza_hesap where user_id='{a}'")
assert olay(a, "siyaset_karti", islem=ek+"t3")["durum"] == "eklendi"
gun = float(q(f"select extract(epoch from kart_bitis - (select test_simdi from oyun.ayarlar))/86400 from oyun.magaza_hesap where user_id='{a}'"))
assert 36.9 < gun < 37.1, gun
ok("Başlangıç Paketi: 100.000 ₺ + 7 gün Kart, bir kez; Kart süresi üst üste ekleniyor (7 + 30 gün)")

once = para(a)
r = rpc(a, "kart_odul_al"); assert r["sonuc"]["odul"] == 7500 and para(a) == once + 7500
hata_bekle(rpc, a, "kart_odul_al", icerir="Bugünkü Kart ödülünü aldın")
q("update oyun.ayarlar set test_simdi = '2026-12-11 09:00+03'")
rpc(a, "kart_odul_al"); assert para(a) == once + 15000
hata_bekle(rpc, b, "kart_odul_al", icerir="aktif değil")
ok("Kart günlük ödülü: günde bir kez 7.500 ₺; Kartı olmayan alamıyor")

assert olay(a, "destekci_rozeti", islem=ek+"t4")["durum"] == "eklendi"
d = rpc(a, "magaza_durum")
assert "destekci" in d["haklar"] and [p for p in d["paketler"] if p["urun_id"] == "destekci_rozeti"][0]["sahip"]
roz = rpc(b, "magaza_rozetler"); kad_a = q(f"select kad from oyun.profiller where id='{a}'")
assert roz.get(kad_a) == "destekci,kart", roz
ok("Kalıcı hak ve rozetler (Destekçi + Kart) herkese görünüyor")

# İade: para geri alınır (cüzdanda kalan kadar), Kart günleri düşer, kalıcı hak kapanır
once = para(a)
assert olay(a, "para_kampanya", tur="CANCELLATION", islem=ek+"t1", cancel_reason="CUSTOMER_SUPPORT")["durum"] == "iade"
assert para(a) == once - 125000
olay(a, "siyaset_karti", tur="CANCELLATION", islem=ek+"t3", cancel_reason="CUSTOMER_SUPPORT")
gun2 = float(q(f"select extract(epoch from kart_bitis - (select test_simdi from oyun.ayarlar))/86400 from oyun.magaza_hesap where user_id='{a}'"))
assert 5 < gun2 < 7, gun2
olay(a, "destekci_rozeti", tur="CANCELLATION", islem=ek+"t4", cancel_reason="CUSTOMER_SUPPORT")
assert "destekci" not in rpc(a, "magaza_durum")["haklar"]
assert olay(a, "para_cep", tur="CANCELLATION", islem="yok")["durum"] == "yok_say"
ok("İade: para, Kart günleri ve kalıcı hak geri alınıyor; bilinmeyen işlem yok sayılıyor")

# Hesap taşıma (aynı Apple/Google hesabı başka oyun hesabında geri yükledi)
olay(a, "reklamsiz_odul", islem=ek+"t5")
r = olay(None, None, tur="TRANSFER", transferred_from=[a], transferred_to=[b])
assert r["durum"] == "transfer", r
assert rpc(b, "magaza_durum")["reklamsiz"] is True and "reklamsiz" not in rpc(a, "magaza_durum")["haklar"]
ok("Kalıcı haklar mağaza hesabıyla birlikte yeni oyun hesabına taşınıyor")

assert olay(a, "olmayan_urun")["durum"] == "urun_yok"
assert olay(str(uuid.uuid4()), "para_cep")["durum"] == "kullanici_yok"
assert qj("select public.odeme_isle('{\"event\":{\"type\":\"TEST\"}}'::jsonb)")["durum"] == "test"
ok("Bilinmeyen ürün / oyuncu ve test olayı güvenle yanıtlanıyor")

# Yetkiler: oyuncu odeme_isle'yi çağıramaz, satış özetini yalnız yönetici görür
hata_bekle(q, "set role authenticated; select public.odeme_isle('{}'::jsonb);", icerir="permission denied")
hata_bekle(rpc, b, "yk_satislar", 30)
y = oyuncu("Yonetici" + ek); q(f"update oyun.profiller set yonetici=true where id='{y}'")
s = rpc(y, "yk_satislar", 30)
assert s["toplam"]["adet"] >= 2 and s["toplam"]["iade"] >= 3 and s["toplam"]["brut_try"] > 0, s["toplam"]
ok("Satış özeti yalnız yöneticiye açık; odeme_isle oyunculara kapalı")
print("magaza: hepsi geçti")
