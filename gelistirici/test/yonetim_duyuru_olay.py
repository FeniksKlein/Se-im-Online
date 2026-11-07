"""Süper yönetici portalı · Aşama 5 (173): duyuru, olay ve destek merkezi kabul testleri.
Çalıştır: ../kur_yerel.sh && python3 yonetim_duyuru_olay.py
(Yerelde ulusal/ülke kriz tabloları canlıdan kopya bir ek dosyayla kurulur.)"""
import json
from db import q, rpc, kullanici_ekle, hata_bekle

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def J(o): return json.dumps(o, ensure_ascii=False)

Y = kullanici_ekle("sahip@duyuru.com"); rpc(Y, "profil_olustur", "DuyuruSahibi", 34)
q(f"update oyun.profiller set yonetici = true where id = '{Y}'")
U = {}
for ad, il in (("Ist1", 34), ("Ank1", 6), ("Izm1", 35)):
    u = kullanici_ekle(f"{ad}@duyuru.com"); rpc(u, "profil_olustur", ad, il); U[ad] = u

def onizle(islem, p): return rpc(Y, "yp_onizle", islem, J(p))
def uygula(o, onay=None): return rpc(Y, "yp_uygula", o["anahtar"], onay)
def geri(islem_id):
    g = onizle("geri_al", {"islem_id": islem_id}); assert g.get("engel") is None, g
    return uygula(g, "ONAYLIYORUM")
def kutu(u): return J(rpc(u, "bildirim_kutusu", 60))

for f in ("yp_duyurular", "yp_olaylar", "yp_destek"):
    hata_bekle(rpc, U["Ist1"], f, icerir="YP_YETKI")
ok("Oyuncu duyuru, olay ve destek panolarını göremez")

# --- Duyuru: hemen, il hedefli, iki kanal
o = onizle("duyuru_yayinla", {"metin": "İstanbul için bakım duyurusu", "kanallar": ["kutu", "haber"], "hedef_il": 34})
assert o.get("engel") is None and not o["kritik"] and o["sayi"] == 2, o
assert any("push" in u for u in o["uyarilar"]), o["uyarilar"]
s = uygula(o)
assert s["basarili"] and s["dogrulama"]["tutarli"], s
yid = s["sonra"]["yayin_id"]; oid = s["sonra"]["olay_id"]
assert q(f"select tur || '|' || hedef_il || '|' || unvan from oyun.yayinlar where id = {yid}") == "sistem|34|Oyun Yönetimi"
assert "İstanbul için bakım" in kutu(U["Ist1"]) and "İstanbul için bakım" not in kutu(U["Ank1"])
assert q(f"select metin from oyun.olaylar where id = {oid}") == "Oyun Yönetimi: İstanbul için bakım duyurusu"
D = rpc(Y, "yp_duyurular")
assert D["arsiv"][0]["id"] == yid and D["arsiv"][0]["islem_id"] == s["islem_id"] and D["push"]["cihaz"] == 0, D["arsiv"][0]
geri(s["islem_id"])
assert q(f"select gizli from oyun.yayinlar where id = {yid}") == "t" and q(f"select count(*) from oyun.olaylar where id = {oid}") == "0"
assert "İstanbul için bakım" not in kutu(U["Ist1"])
ok("İl hedefli duyuru yalnız o ildekilerin kutusuna düştü, haber akışına yazıldı; geri alınınca gizlendi ve haber kaldırıldı")

# --- Duyuru: engeller
assert "3-600" in onizle("duyuru_yayinla", {"metin": "a"})["engel"]
assert "kanal" in onizle("duyuru_yayinla", {"metin": "Deneme duyuru", "kanallar": []})["engel"]
assert "2 dakika" in onizle("duyuru_yayinla", {"metin": "Deneme duyuru", "zaman": q("select (now() + interval '30 seconds')::text")})["engel"]
assert "30 gün" in onizle("duyuru_yayinla", {"metin": "Deneme duyuru", "zaman": q("select (now() + interval '40 days')::text")})["engel"]
ok("Boş metin, kanalsız, çok yakın ve çok uzak planlama reddedildi")

# --- Planlı duyuru: zamanı gelince gönderilir
n0 = int(q("select count(*) from oyun.yayinlar where tur = 'sistem'"))
o = onizle("duyuru_yayinla", {"metin": "Yarın seçim var, unutmayın", "zaman": q("select (now() + interval '10 minutes')::text")})
s = uygula(o); assert s["basarili"] and s["sonra"]["plan_id"], s
pid = s["sonra"]["plan_id"]
assert int(q("select count(*) from oyun.yayinlar where tur = 'sistem'")) == n0
assert q("select oyun.yp_duyuru_plan_isle()") == "0"
q(f"update oyun.yp_duyuru_plan set zaman = now() - interval '1 second' where id = {pid}")
assert q("select oyun.yp_duyuru_plan_isle()") == "1"
assert q(f"select durum from oyun.yp_duyuru_plan where id = {pid}") == "gonderildi"
assert "Yarın seçim var" in kutu(U["Ank1"]) and "Yarın seçim var" in kutu(U["Izm1"])
assert q("select count(*) from oyun.mod_kayit where islem = 'yp_duyuru_plan'") == "1"
geri(s["islem_id"])
assert "Yarın seçim var" not in kutu(U["Ank1"])
ok("Planlı duyuru zamanından önce gönderilmedi, zamanında gönderildi (kayıt düştü); geri alınınca gizlendi")

# --- Planlı duyuru: göndermeden iptal
o = onizle("duyuru_yayinla", {"metin": "İptal edilecek duyuru", "zaman": q("select (now() + interval '1 hour')::text")})
s = uygula(o); pid = s["sonra"]["plan_id"]
assert rpc(Y, "yp_duyurular")["planlar"][0]["durum"] == "bekliyor"
geri(s["islem_id"])
q(f"update oyun.yp_duyuru_plan set zaman = now() - interval '1 second' where id = {pid}")
assert q("select oyun.yp_duyuru_plan_isle()") == "0" and q(f"select durum from oyun.yp_duyuru_plan where id = {pid}") == "iptal"
assert "İptal edilecek" not in kutu(U["Ank1"])
ok("Planlı duyuru gönderilmeden geri alınınca iptal oldu ve hiç gönderilmedi")

# --- Olay: ulusal kriz
o = onizle("olay_baslat", {"tur": "ulusal", "kod": "deprem"})
assert "il seçmelisin" in o["engel"], o
o = onizle("olay_baslat", {"tur": "ulusal", "kod": "deprem", "il_id": 35})
assert o.get("engel") is None and o["kritik"] and any("geri alınamaz" in u for u in o["uyarilar"]), o
hata_bekle(rpc, Y, "yp_uygula", o["anahtar"], None, icerir="YP_ONAY")
s = uygula(o, "ONAYLIYORUM")
assert s["basarili"] and s["dogrulama"]["tutarli"], s
assert q("select sablon_kod || '|' || il_id from oyun.uk_olay where durum = 'aktif'") == "deprem|35"
assert "Zaten süren" in onizle("olay_baslat", {"tur": "ulusal", "kod": "salgin"})["engel"]
assert "geri alınamaz" in onizle("geri_al", {"islem_id": s["islem_id"]})["engel"]
ok("Ulusal kriz ikinci onayla başladı (İzmir depremi); ikinci kriz engellendi; geri alınamaz")

# --- Olay: ülke krizi
o = onizle("olay_baslat", {"tur": "ulke", "kod": "elektrik"})
s = uygula(o, "ONAYLIYORUM"); assert s["basarili"] and s["dogrulama"]["tutarli"], s
assert q("select count(*) from oyun.olaylar where tur = 'ulke_krizi'") == "1"
assert "Karar bekleyen" in onizle("olay_baslat", {"tur": "ulke", "kod": "doviz"})["engel"]
ok("Ülke krizi kriz motorunun kaydıyla açıldı (4 saat karar süresi, haber akışı)")

# --- Olay: belediye krizi
assert "belediye başkanı yok" in onizle("olay_baslat", {"tur": "belediye", "kod": "su", "il_id": 6})["engel"]
q(f"insert into oyun.makamlar(tur, user_id, il_id, kaynak, bas) values ('bel', '{U['Ank1']}', 6, 'atama', now())")
b0 = int(q(f"select count(*) from oyun.bildirimler where user_id = '{U['Ank1']}'"))
o = onizle("olay_baslat", {"tur": "belediye", "kod": "su", "il_id": 6})
assert o.get("engel") is None, o
s = uygula(o, "ONAYLIYORUM"); assert s["basarili"] and s["dogrulama"]["tutarli"], s
assert int(q(f"select count(*) from oyun.bildirimler where user_id = '{U['Ank1']}'")) == b0 + 1
assert "açık bir belediye krizi" in onizle("olay_baslat", {"tur": "belediye", "kod": "cop", "il_id": 6})["engel"]
OL = rpc(Y, "yp_olaylar")
assert len(OL["aktif"]["ulusal"]) == 1 and len(OL["aktif"]["ulke"]) == 1 and len(OL["aktif"]["belediye"]) == 1, OL["aktif"]
assert len(OL["belediye_sablon"]) >= 10 and any(i["id"] == 6 and i["acik_kriz"] for i in OL["iller"])
ok("Belediye krizi yalnız başkanı olan ilde açıldı, başkana bildirim gitti; olay panosu üç aktif krizi gösteriyor")

# --- Şikâyet kararı
q(f"insert into oyun.mesajlar(kanal, user_id, metin, zaman) values ('genel', '{U['Ist1']}', 'Kaba bir mesaj', now())")
mid = q("select id from oyun.mesajlar where metin = 'Kaba bir mesaj'")
for u in ("Ank1", "Izm1"):
    q(f"insert into oyun.sikayetler(sikayetci, hedef_user, tur, kayit_id, neden) values ('{U[u]}', '{U['Ist1']}', 'mesaj', {mid}, 'hakaret')")
DS = rpc(Y, "yp_destek")
sk = next(x for x in DS["sikayetler"] if x["kayit_id"] == int(mid))
assert sk["sayi"] == 2 and sk["durum"] == "yeni" and sk["icerik"]["metin"] == "Kaba bir mesaj" and DS["sayac"]["sikayet"] >= 1, sk
o = onizle("sikayet_karar", {"tur": "mesaj", "kayit_id": mid, "hedef": U["Ist1"], "karar": "gizle_sustur1"})
assert o.get("engel") is None and len(o["degisen"]) == 3, o
s = uygula(o); assert s["basarili"] and s["dogrulama"]["tutarli"], s
assert q(f"select gizli from oyun.mesajlar where id = {mid}") == "t"
assert q(f"select susturma_bitis > now() + interval '23 hours' from oyun.profiller where id = '{U['Ist1']}'") == "t"
assert q(f"select count(*) from oyun.sikayetler where kayit_id = {mid} and durum = 'incelendi'") == "2"
assert "bekleyen şikâyet yok" in onizle("sikayet_karar", {"tur": "mesaj", "kayit_id": mid, "hedef": U["Ist1"], "karar": "gizle"})["engel"]
geri(s["islem_id"])
assert q(f"select gizli from oyun.mesajlar where id = {mid}") == "f"
assert q(f"select susturma_bitis is null or susturma_bitis < now() from oyun.profiller where id = '{U['Ist1']}'") == "t"
assert q(f"select count(*) from oyun.sikayetler where kayit_id = {mid} and durum = 'yeni'") == "2"
q(f"insert into oyun.sikayetler(sikayetci, hedef_user, tur, kayit_id, neden) values ('{U['Ank1']}', '{Y}', 'oyuncu', 0, 'diger')")
assert "Yönetici hesabı" in onizle("sikayet_karar", {"tur": "oyuncu", "kayit_id": 0, "hedef": Y, "karar": "gizle_sustur7"})["engel"]
ok("Şikâyet: mesaj gizlendi, 1 gün susturuldu, şikâyetler incelendi; geri alınınca hepsi eski hâline döndü")

# --- Destek talebi (oyuncu tarafı)
hata_bekle(rpc, U["Izm1"], "destek_gonder", "hata", "kısa", icerir="10 karakter")
hata_bekle(rpc, U["Izm1"], "destek_gonder", "bilinmeyen", "Bu yeterince uzun bir metin", icerir="Konu")
r = rpc(U["Izm1"], "destek_gonder", "hata", "Seçim ekranı açılmıyor, beyaz kalıyor.", "2026.11.07", "android")
tid = r["id"]
for i in range(2): rpc(U["Izm1"], "destek_gonder", "oneri", f"Öneri numarası {i} için uzun metin")
hata_bekle(rpc, U["Izm1"], "destek_gonder", "diger", "Dördüncü açık talep metni", icerir="3 talebin")
DS = rpc(Y, "yp_destek")
assert any(t["id"] == tid and t["kad"] == "Izm1" and t["platform"] == "android" for t in DS["talepler"]) and DS["sayac"]["talep"] == 3
o = onizle("destek_yanitla", {"kaynak": "talep", "id": tid, "metin": "Uygulamayı güncelleyince düzelecek."})
assert o.get("engel") is None and not o["kritik"], o
s = uygula(o); assert s["basarili"] and s["dogrulama"]["tutarli"], s
assert "Destek yanıtı (talep #" in kutu(U["Izm1"])
L = rpc(U["Izm1"], "destek_taleplerim")
assert next(t for t in L if t["id"] == tid)["yeni_yanit"] is True
assert next(t for t in rpc(U["Izm1"], "destek_taleplerim") if t["id"] == tid)["yeni_yanit"] is False
o = onizle("destek_yanitla", {"kaynak": "talep", "id": tid, "kapat": True}); uygula(o)
assert q(f"select durum from oyun.destek_talep where id = {tid}") == "kapali"
assert "kapatılmış" in onizle("destek_yanitla", {"kaynak": "talep", "id": tid, "metin": "tekrar"})["engel"]
assert not any(t["id"] == tid for t in rpc(Y, "yp_destek")["talepler"])
assert any(t["id"] == tid for t in rpc(Y, "yp_destek", "tum")["talepler"])
ok("Oyuncu destek talebi gönderdi (kısa/çok talep engelli); yanıt bildirimle ulaştı, talep kapatıldı")

# --- Yönetime gelen özel mesaj ve yanıt
q(f"insert into oyun.ozel(gonderen, alici, metin, zaman) values ('{U['Ank1']}', '{Y}', 'Hesabım kilitlendi yardım', now())")
DS = rpc(Y, "yp_destek")
kon = next(m for m in DS["mesajlar"] if m["kad"] == "Ank1")
assert kon["okunmamis"] == 1 and kon["mesajlar"][-1]["gelen"] is True and DS["sayac"]["mesaj"] == 1, kon
o = onizle("destek_yanitla", {"kaynak": "ozel", "id": kon["son_gelen"], "metin": "Kilidi açtık, tekrar dene."})
s = uygula(o); assert s["basarili"], s
assert q(f"select count(*) from oyun.ozel where gonderen = '{Y}' and alici = '{U['Ank1']}' and metin = 'Kilidi açtık, tekrar dene.'") == "1"
assert q(f"select count(*) from oyun.ozel where alici = '{Y}' and not okundu") == "0"
diger = q(f"select id from oyun.ozel where gonderen = '{Y}' limit 1")
assert "bulunamadı" in onizle("destek_yanitla", {"kaynak": "ozel", "id": diger, "metin": "olmaz"})["engel"]
ok("Yönetime gelen özel mesaj destek merkezinde göründü; yanıt oyuncunun özel kutusuna gitti, mesaj okundu sayıldı")

print(f"{len(TAMAM)} kontrol geçti")
