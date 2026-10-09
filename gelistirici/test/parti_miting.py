"""Modül 50: il dışı parti mitingi (GB + yetkili GBY) ve bağımsız adayın partiye katılması."""
from db import q, rpc, saat, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
saat("2026-10-12 10:00")
def oyuncu(kad, il, para=200000):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.cuzdan set para={para} where user_id='{u}'"); return u

PARTI = 1
gb = oyuncu("Lider", "Ankara")
y1 = oyuncu("Yardimci1", "İzmir")
y2 = oyuncu("Yardimci2", "Bursa")
uye_uzak = oyuncu("UyeAntalya", "Antalya")
erzurumlu = oyuncu("Erzurumlu", "Erzurum")
siradan = oyuncu("Siradan", "Ankara")
for u in (gb, y1, y2, uye_uzak, siradan): rpc(u, "partiye_katil", PARTI)
q(f"update oyun.partiler set gb='{gb}', kasa=100000 where id={PARTI}")
q(f"insert into oyun.parti_gby(parti_id,sira,user_id) values ({PARTI},1,'{y1}'),({PARTI},2,'{y2}')")

# --- Yetki
assert rpc(gb, "parti_miting_bilgi")["yetki"] == "gb"
assert rpc(y1, "parti_miting_bilgi")["yetki"] is None
hata_bekle(rpc, y1, "parti_miting_duzenle", IL("Erzurum"), "2026-10-12 12:00+03", "Erzurum buluşması", "true", icerir="yalnız genel başkan")
hata_bekle(rpc, siradan, "parti_miting_duzenle", IL("Ankara"), "2026-10-12 12:00+03", "Ankara buluşması", "true", icerir="yalnız genel başkan")
hata_bekle(rpc, y1, "gby_miting_yetkisi", "Yardimci2", "true", icerir="yalnız genel başkan")
ok("Miting yetkisi yalnız GB'de; yetkisiz yardımcı ve sıradan üye düzenleyemiyor")

# --- GB başka ilde, parti kasasından
bedel = float(q(f"select oyun.miting_bedel({IL('Erzurum')}::smallint)"))
r = rpc(gb, "parti_miting_duzenle", IL("Erzurum"), "2026-10-12 12:00+03", "Erzurum buluşması", "true")
assert r["odeyen"] == "parti" and float(r["bedel"]) == bedel
assert float(q(f"select kasa from oyun.partiler where id={PARTI}")) == 100000 - bedel
assert q(f"select count(*) from oyun.parti_hareket where parti_id={PARTI} and tur='miting'") == "1"
hata_bekle(rpc, gb, "parti_miting_duzenle", IL("Van"), "2026-10-12 18:00+03", "Van buluşması", "true", icerir="Günde en fazla 1")
ok(f"GB Ankara'dan Erzurum'a miting koydu; {bedel:.0f} ₺ parti kasasından düştü; aynı gün ikinci miting yok")

# --- GBY'ye yetki ver; aynı ilde 3 gün kuralı; kendi cebinden
b = rpc(gb, "gby_miting_yetkisi", "Yardimci1", "true")
assert [y["yetki"] for y in b["yardimcilar"]] == [True, False]
assert rpc(y1, "parti_miting_bilgi")["yetki"] == "gby"
hata_bekle(rpc, y1, "parti_miting_duzenle", IL("Erzurum"), "2026-10-14 12:00+03", "Yine Erzurum", "true", icerir="3 gün")
para0 = float(q(f"select para from oyun.cuzdan where user_id='{y1}'"))
r = rpc(y1, "parti_miting_duzenle", IL("Van"), "2026-10-13 12:00+03", "Van buluşması", "false")
assert r["odeyen"] == "kisi"
assert float(q(f"select para from oyun.cuzdan where user_id='{y1}'")) == para0 - float(r["bedel"])
ok("Yetki verilen yardımcı Van'a kendi cebinden miting koydu; aynı ilde 3 gün kuralı çalışıyor")

# --- Yetki geri alınınca başlamamış miting iptal + iade
rpc(gb, "gby_miting_yetkisi", "Yardimci1", "false")
assert q("select count(*) from oyun.mitingler where tur='parti' and il_id=%d" % IL("Van")) == "0"
assert float(q(f"select para from oyun.cuzdan where user_id='{y1}'")) == para0
hata_bekle(rpc, y1, "parti_miting_duzenle", IL("Van"), "2026-10-13 12:00+03", "Van buluşması", "false", icerir="yalnız genel başkan")
ok("Yetki geri alındı: Van mitingi iptal, bedel iade edildi")

# --- Canlı: Erzurum'daki herkese + partinin başka illerdeki üyelerine bildirim; tepkiyi yalnız Erzurumlu verir
saat("2026-10-12 12:01")
assert q(f"select count(*) from oyun.bildirimler where user_id='{erzurumlu}' and metin like '%Erzurum meydanında%'") == "1"
assert q(f"select count(*) from oyun.bildirimler where user_id='{uye_uzak}' and metin like '%mitingi başladı%Erzurum%'") == "1"
mid = int(q(f"select id from oyun.mitingler where tur='parti' and il_id={IL('Erzurum')}"))
d = rpc(gb, "miting_konus", mid, "Erzurum, Türkiye'nin kalesi!")
rpc(erzurumlu, "miting_katil", mid)
rpc(erzurumlu, "miting_tepki", d["konusmalar"][0]["id"], "tezahurat")
hata_bekle(rpc, uye_uzak, "miting_katil", mid, icerir="Yalnızca bu ilde")
liste = rpc(uye_uzak, "mitingler")
assert any(m["id"] == mid and m["tur"] == "parti" and m["partim"] for m in liste)
ok("Parti mitingi canlı: Erzurum'a ve Antalya'daki üyeye haber gitti, kürsü ve tepki çalışıyor")

# --- GB görevden düşerse başlamamış mitingi iptal olur
r = rpc(gb, "parti_miting_duzenle", IL("Trabzon"), "2026-10-13 15:00+03", "Trabzon buluşması", "true")
kasa = float(q(f"select kasa from oyun.partiler where id={PARTI}"))
q(f"update oyun.partiler set gb=null where id={PARTI}")
saat("2026-10-12 12:05")
assert q(f"select count(*) from oyun.mitingler where id={r['id']}") == "0"
assert float(q(f"select kasa from oyun.partiler where id={PARTI}")) == kasa + float(r["bedel"])
ok("Genel başkanlığı biten oyuncunun başlamamış mitingi iptal edildi, kasa iade aldı")

# --- Bağımsız aday partiye katılır
bag = oyuncu("BagimsizAday", "Konya")
bag2 = oyuncu("BagimsizIki", "Konya")
saat("2026-10-25 10:00")
rpc(bag, "bagimsiz_aday_ol", 2); rpc(bag2, "bagimsiz_aday_ol", 2)
para_once = q(f"select para from oyun.cuzdan where user_id='{bag}'")
assert q(f"select count(*) from oyun.adaylar where user_id='{bag}' and parti_id is null") == "1"
rpc(bag, "partiye_katil", PARTI)
assert q(f"select count(*) from oyun.adaylar where user_id='{bag}'") == "0"
assert q(f"select parti_id from oyun.profiller where id='{bag}'") == str(PARTI)
assert q(f"select para from oyun.cuzdan where user_id='{bag}'") == para_once
assert q(f"select count(*) from oyun.bildirimler where user_id='{bag}' and metin like '%bağımsız milletvekili adaylığın düştü%'") == "1"
ok("Bağımsız aday partiye katıldı: adaylığı düştü, harç iade edilmedi, bildirim gitti")

saat("2026-11-01 10:00")
hata_bekle(rpc, bag2, "partiye_katil", PARTI, icerir="Oy verme sürüyor")
assert q(f"select count(*) from oyun.adaylar where user_id='{bag2}' and parti_id is null") == "1"
ok("Oy verme sürerken bağımsız aday partiye katılamıyor; pusula korunuyor")

# --- Seçim yasağı (1 Kasım genel seçim oy saatleri)
saat("2026-10-31 10:00")
q(f"update oyun.profiller set son_gorulme='2026-10-31 10:00+03' where id='{gb}'")   # görev ihmali kuralına takılmasın
q(f"update oyun.partiler set gb='{gb}' where id={PARTI}")
hata_bekle(rpc, gb, "parti_miting_duzenle", IL("İzmir"), "2026-11-01 12:00+03", "Seçim günü", "true", icerir="Seçim yasağı")
rpc(gb, "parti_miting_duzenle", IL("İzmir"), "2026-11-01 22:30+03", "Sandık sonrası", "true")
ok("Genel seçimin oy verme saatlerinde miting reddedildi; sandık kapanınca serbest")
print("parti_miting: tamam")
