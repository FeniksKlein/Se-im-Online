"""Modül 86: reklam ve anket ajansları."""
from db import q, qj, rpc, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
para = lambda u: float(q(f"select para from oyun.cuzdan where user_id='{u}'"))
kasa = lambda sid: float(q(f"select kasa from oyun.sirketler where id={sid}"))
def zaman(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}+03'")

zaman("2030-03-01 10:00")
def oyuncu(kad, il="İzmir", p=3000000):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.cuzdan set para={p} where user_id='{u}'"); return u
SAHIP, GB, ADAY = oyuncu("Reklamci"), oyuncu("GenelBaskan"), oyuncu("Aday")
SECMEN = [oyuncu(f"Secmen{i}", "İzmir" if i < 5 else "Ankara", 10000) for i in range(7)]
q("update oyun.ulke set asgari=30000 where id=1")
IZMIR = IL("İzmir")
partiler = [int(x) for x in q("select id from oyun.partiler where not kapali order by id limit 3").split("\n")]
P1, P2, P3 = partiler
q(f"update oyun.partiler set gb='{GB}', kasa=500000 where id={P1}")
zaman("2030-03-03 10:00")

# ---------------- ajans kur ve ayarla
hata_bekle(rpc, SAHIP, "ajans_kur", "Ab", 200000, icerir="3-50")
hata_bekle(rpc, SAHIP, "ajans_kur", "Ege Medya", 100000, icerir="en az 150.000")
aj = rpc(SAHIP, "ajans_kur", "Ege Medya Ajans", 300000)["id"]
hata_bekle(rpc, SAHIP, "ajans_kur", "Ikinci Ajans", 300000, icerir="Zaten")
y = rpc(SAHIP, "ajans_yonetim", aj)
assert y["kapasite"] == 3 and y["reklam_saat"] == 20 and y["fiyatlar"]["turkiye"]["anket"] > y["fiyatlar"]["kucuk"]["anket"]
rpc(SAHIP, "ajans_ayarla", aj, 2, 2)
y = rpc(SAHIP, "ajans_yonetim", aj)
assert y["kalite"] == 2 and y["reklam_saat"] == 28 and y["kapasite"] == 4
hata_bekle(rpc, GB, "ajans_ayarla", aj, 1, 1, icerir="en büyük ortak")
ok(f"Ajans kuruldu (300.000 ₺), kalite 2: reklam 28 saat, kapasite 4, haftalık gider {float(y['haftalik_gider']):,.0f} ₺")

# ---------------- reklam siparişi (parti kasasından)
l = rpc(GB, "ajans_liste", IZMIR)
a0 = l["ajanslar"][0]; ucret = float(a0["reklam_ucret"])
assert l["parti"]["id"] == P1 and l["reklam_sinir"] == 2
hata_bekle(rpc, SAHIP, "ajans_siparis", aj, "reklam", IZMIR, "kisi", "Kendi reklamım deneme", icerir="Kendi ajansından")
hata_bekle(rpc, ADAY, "ajans_siparis", aj, "reklam", IZMIR, "parti", "Partimize oy verin lütfen", icerir="genel başkan")
hata_bekle(rpc, GB, "ajans_siparis", aj, "reklam", IZMIR, "parti", "kısa", icerir="10-200")
pk0, k0 = float(q(f"select kasa from oyun.partiler where id={P1}")), kasa(aj)
j = rpc(GB, "ajans_siparis", aj, "reklam", IZMIR, "parti", "İzmir için güçlü belediye, temiz şehir! Partimize destek ver.")
assert float(q(f"select kasa from oyun.partiler where id={P1}")) == pk0 - ucret and kasa(aj) == k0 + ucret
hata_bekle(rpc, GB, "ajans_siparis", aj, "anket", IZMIR, "parti", None, icerir="Saatte en fazla")
assert int(q(f"select count(*) from oyun.bildirimler where metin like 'Sponsorlu%' and user_id='{SECMEN[0]}'")) == 1
assert int(q(f"select count(*) from oyun.bildirimler where metin like 'Sponsorlu%' and user_id='{SECMEN[6]}'")) == 0   # Ankara'ya gitmez
ok(f"Reklam siparişi: parti kasasından {ucret:,.0f} ₺ ajansa geçti, İzmir'deki oyunculara bildirim gitti, Ankara'ya gitmedi")

# kişisel reklam + alan sınırı
rpc(ADAY, "ajans_siparis", aj, "reklam", IZMIR, "kisi", "Aday adayınız Aday, İzmir için çalışacak!")
zaman("2030-03-03 11:30")
hata_bekle(rpc, ADAY, "ajans_siparis", aj, "reklam", IZMIR, "kisi", "Bir reklam daha veriyorum İzmir", icerir="reklam alanı dolu")
# gösterim: Gündem'de sponsorlu kart, bir oyuncu bir kez sayılır
g = rpc(SECMEN[0], "ajans_gundem"); assert g["reklam"] and g["reklam"]["metin"]
rpc(SECMEN[0], "ajans_gundem"); rpc(SECMEN[1], "ajans_gundem")
assert rpc(SECMEN[6], "ajans_gundem")["reklam"] is None
toplam = int(q("select sum(gosterim) from oyun.ajans_is where tur='reklam'"))
assert 2 <= toplam <= 3, toplam
ok(f"Gündem'de sponsorlu kart: İzmir'de görünüyor, Ankara'da yok; tekil gösterim sayımı ({toplam})")

# ---------------- anket
zaman("2030-03-03 13:00")
an = rpc(GB, "ajans_siparis", aj, "anket", IZMIR, "parti", None)
assert int(q(f"select count(*) from oyun.bildirimler where metin like '%kamuoyu araştırması%' and user_id='{SECMEN[2]}'")) == 1
hata_bekle(rpc, ADAY, "ajans_siparis", aj, "anket", IZMIR, "kisi", None, icerir="sürmekte olan")
gk = rpc(SECMEN[0], "ajans_gundem")["anket"]
assert gk and gk["id"] == an["id"] and float(gk["odul"]) == 800 and len(gk["partiler"]) >= 3
odul0 = para(SECMEN[0])
for i, s in enumerate(SECMEN[:5]):
    rpc(s, "ajans_anket_cevap", an["id"], [P1, P1, P2, None, P3][i])
assert para(SECMEN[0]) == odul0 + 800
hata_bekle(rpc, SECMEN[0], "ajans_anket_cevap", an["id"], P2, icerir="zaten katıldın")
hata_bekle(rpc, SECMEN[6], "ajans_anket_cevap", an["id"], P2, icerir="başka bir ilde")
hata_bekle(rpc, GB, "ajans_anket_cevap", an["id"], P2, icerir="Kendi yaptırdığın")
assert rpc(SECMEN[0], "ajans_gundem")["anket"] is None
hata_bekle(rpc, GB, "ajans_anket_yayimla", an["id"], icerir="henüz bitmedi")
ok("Anket: İzmir'deki 5 oyuncu cevapladı, her biri 800 ₺ ödül aldı; tekrar, başka il ve sipariş veren engelli")

# yeni hesaba ödül yok
yeni = oyuncu("YeniHesap")
rpc(yeni, "ajans_anket_cevap", an["id"], P1)
assert float(q(f"select odul from oyun.ajans_cevap where user_id='{yeni}'")) == 0

zaman("2030-03-04 13:30"); q("select oyun.pazar_tick()")
x = qj(f"select row_to_json(j) from oyun.ajans_is j where id={an['id']}")
s = x["sonuc"]
assert x["durum"] == "bitti" and s["n"] == 6 and s["kararsiz"] == 1 and s["partiler"][0]["id"] == P1 and s["partiler"][0]["oy"] == 3
assert s["partiler"][0]["yuzde"] == 60.0 and s["hata"] == round(98 / 6 ** 0.5, 1)
# sonuç yalnız sipariş veren (ya da parti GB'si) görür
assert rpc(SECMEN[0], "ajans_liste", IZMIR)["islerim"] == []
gl = [i for i in rpc(GB, "ajans_liste", IZMIR)["islerim"] if i["id"] == an["id"]][0]
assert gl["sonuc"]["n"] == 6
ok(f"Anket sonucu: 6 katılımcı, {s['partiler'][0]['kisa']} %60, kararsız %{s['kararsiz_yuzde']}, hata payı ±{s['hata']}; yalnız sipariş verene görünür")

# yayın yasağı ve yayımlama
yasak_sec = None
try:
    q("select 1 from oyun.secimler limit 1")
    yasak_sec = q("""update oyun.secimler set oy_bas='2030-03-05 08:00+03', oy_bit='2030-03-05 17:00+03' where id=(select id from oyun.secimler where durum='bekliyor' order by id limit 1) returning id""")
except Exception:
    pass
if yasak_sec:
    hata_bekle(rpc, GB, "ajans_anket_yayimla", an["id"], icerir="Seçim yasağı")
    q(f"update oyun.secimler set oy_bas='2030-06-05 08:00+03', oy_bit='2030-06-05 17:00+03' where id={yasak_sec.split()[0]}")
    ok("Seçim yasağı: oy gününe 24 saatten az kala anket sonucu yayımlanamıyor")
rpc(GB, "ajans_anket_yayimla", an["id"])
assert "anketi" in q("select metin from oyun.olaylar where tur='anket' order by id desc limit 1")
assert rpc(SECMEN[0], "ajans_liste", IZMIR)["islerim"] == []
hata_bekle(rpc, GB, "ajans_anket_yayimla", an["id"], icerir="zaten")
ok("Anket yayımlandı: Gündem akışına düştü, marka arttı")

# puan: siparişi veren puanlar
hata_bekle(rpc, SECMEN[0], "ajans_puanla", an["id"], 5, icerir="kendi siparişini")
rpc(GB, "ajans_puanla", an["id"], 5)
hata_bekle(rpc, GB, "ajans_puanla", an["id"], 4, icerir="zaten")
assert float(rpc(GB, "ajans_liste", None)["ajanslar"][0]["puan"]) == 5

# ---------------- haftalık hesap: gelir - ödül - gider - vergi, ortağa kâr
pS = para(SAHIP); h0 = float(q("select hazine from oyun.ulke where id=1"))
gelir = float(q(f"select hafta_gelir from oyun.ajans where sirket_id={aj}")); odul = float(q(f"select hafta_odul from oyun.ajans where sirket_id={aj}"))
zaman("2030-03-10 10:05"); q("select oyun.pazar_tick()")
h = qj(f"select row_to_json(h) from oyun.sirket_hareket h where sirket_id={aj} order by id desc limit 1")
assert float(h["faaliyet_gelir"]) == gelir and "ajans" in h["aciklama"]
assert float(q(f"select hafta_gelir from oyun.ajans where sirket_id={aj}")) == 0
if float(h["tutar"]) > 0: assert para(SAHIP) > pS and float(q("select hazine from oyun.ulke where id=1")) > h0
ok(f"Haftalık hesap: gelir {gelir:,.0f} ₺, ödül {odul:,.0f} ₺, net {float(h['tutar']):,.0f} ₺ (ortağa dağıtıldı, vergi hazineye)")

# reklam bitince bildirim
assert q(f"select count(*) from oyun.ajans_is where tur='reklam' and durum='bitti'") == "2"
assert "Reklamın sona erdi" in q(f"select metin from oyun.bildirimler where user_id='{GB}' and metin like 'Reklam%' order by id desc limit 1")
print("TAMAM: reklam ve anket ajansları")
