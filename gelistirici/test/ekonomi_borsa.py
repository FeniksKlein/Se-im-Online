"""Modül 85: danışman/otopilot, paravan kuralı, borsa, Rekabet Kurumu, şirket bağışı, yerel fiyat → geçim, piyasa raporu."""
from db import q, qj, rpc, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
para = lambda u: float(q(f"select para from oyun.cuzdan where user_id='{u}'"))
kasa = lambda sid: float(q(f"select kasa from oyun.sirketler where id={sid}"))
pay = lambda sid, u: float(q(f"select coalesce((select pay from oyun.sirket_ortaklari where sirket_id={sid} and user_id='{u}'),0)"))
def zaman(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}+03'")

zaman("2030-03-03 10:00")
def oyuncu(kad, il="İzmir", p=8000000):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.cuzdan set para={p} where user_id='{u}'"); return u
A, B, C, TIC = oyuncu("Ayse"), oyuncu("Burak"), oyuncu("Cem"), oyuncu("TicaretBakani")
q("update oyun.ulke set asgari=30000, buyume=3, memnuniyet=50 where id=1")
q("update oyun.il_durum set gelisim=50, memnuniyet=50; update oyun.bakanlik_kasa set kasa=30")
IZMIR, ADANA, ANKARA = IL("İzmir"), IL("Adana"), IL("Ankara")

# ---------------- paravan kuralı
m1 = rpc(A, "pazar_sirket_kur", "Ayse Market", "market", 400000, ADANA, None)["id"]
hata_bekle(rpc, A, "pazar_sirket_kur", "Ayse Market 2", "market", 400000, ADANA, None, icerir="Paravan")
m_iz = rpc(A, "pazar_sirket_kur", "Ayse Izmir", "market", 400000, IZMIR, None)["id"]          # başka ilde serbest
o1 = rpc(A, "pazar_sirket_kur", "Ayse Okul", "ozel_okul", 300000, ADANA, None)["id"]           # başka türde serbest
hata_bekle(rpc, A, "pazar_tasi", m_iz, ADANA, icerir="Paravan")
ok("Paravan kuralı: aynı ilde aynı türde ikinci çoğunluk şirketi kurulamaz, taşınamaz")

# ---------------- danışman ve otopilot
m2 = rpc(B, "pazar_sirket_kur", "Burak Market", "market", 400000, ADANA, None)["id"]
rpc(B, "pazar_ayarla", m2, 3, 0, None)                # kötü ayar: premium + asgari kalite
d = rpc(B, "pazar_danisman", m2)
assert d["oneri"] and d["oneri_farkli"] and d["oneri"]["net"] > d["mevcut_net"], d
assert d["saglik"] in ("zararda", "basabas", "karda")
ok(f"Danışman: mevcut net {d['mevcut_net']:,} ₺ → önerilen fiyat {d['oneri']['fiyat']}, kalite {d['oneri']['kalite']}: {d['oneri']['net']:,} ₺ ({d['saglik']})")
hata_bekle(rpc, A, "pazar_otopilot", m2, True, icerir="en büyük ortak")
r = rpc(B, "pazar_otopilot", m2, True)
st = q(f"select fiyat||'|'||kalite||'|'||otopilot from oyun.pazar_sirket where sirket_id={m2}")
assert st == f"{d['oneri']['fiyat']}|{d['oneri']['kalite']}|true", st
zaman("2030-03-10 10:05"); q("select setseed(0.2)"); q("select oyun.pazar_tick()")
h = q(f"select aciklama from oyun.sirket_hareket where sirket_id={m2} order by id desc limit 1")
rap = qj(f"select row_to_json(r) from oyun.pazar_rapor r where sirket_id={m2} order by id desc limit 1")
th = rpc(B, "pazar_detay", m2)["tahmin"]
assert "otopilot" in h and float(rap["gider"]) > th["gider"], (h, rap["gider"], th["gider"])   # yönetici ücreti gidere eklendi
ok(f"Otopilot en iyi ayarı uyguladı, haftalık hesapta %4 yönetici ücreti gidere eklendi (gider {float(rap['gider']):,.0f} ₺)")

# ---------------- borsa
q(f"update oyun.sirketler set halka_acik=true where id={m1}")
hata_bekle(rpc, B, "borsa_sat", m2, 10, 5000, icerir="halka açık")
hata_bekle(rpc, A, "borsa_sat", m1, 10, 50, icerir="en az 100")
rpc(A, "borsa_sat", m1, 30, 4000)
hata_bekle(rpc, A, "borsa_sat", m1, 75, 4000, icerir="Satabileceğin pay")
l = rpc(C, "borsa_liste")
x = next(s for s in l["sirketler"] if s["id"] == m1)
assert float(x["en_ucuz"]) == 4000 and float(x["satista"]) == 30
b = rpc(C, "borsa_sirket", m1); emir = b["emirler"][0]["id"]
hata_bekle(rpc, A, "borsa_al", emir, 5, icerir="Kendi emrini")
hata_bekle(rpc, C, "borsa_al", emir, 31, icerir="arasında")
hz0 = float(q("select hazine from oyun.ulke where id=1")); pa0, pc0 = para(A), para(C)
rpc(C, "borsa_al", emir, 12.5)
assert pay(m1, C) == 12.5 and pay(m1, A) == 87.5
assert para(C) == pc0 - 50000 - 250 and para(A) == pa0 + 50000
assert float(q("select hazine from oyun.ulke where id=1")) > hz0
assert float(q(f"select kalan from oyun.borsa_emir where id={emir}")) == 17.5
b = rpc(C, "borsa_sirket", m1)
assert float(b["son"]) == 4000 and len(b["islemler"]) == 1 and float(b["benim_pay"]) == 12.5
rpc(C, "borsa_sat", m1, 12.5, 4500)
rpc(A, "borsa_iptal", emir)
assert q(f"select durum from oyun.borsa_emir where id={emir}") == "iptal"
# alıcı payının tamamını geri satar → ortaklıktan çıkar
e2 = rpc(A, "borsa_sirket", m1)["emirler"][0]
rpc(A, "borsa_al", e2["id"], 12.5)
assert pay(m1, C) == 0 and pay(m1, A) == 100
ok("Borsa: %30 satış emri, %12,5 kısmi alım (50.000 ₺ + 250 ₺ komisyon hazineye), fazla satış engeli, iptal, tam çıkış")

# ---------------- Rekabet Kurumu
q(f"insert into oyun.makamlar(tur,user_id,bakanlik,bas) values ('bakan','{TIC}','ticaret',now())")
hata_bekle(rpc, A, "rekabet_ac", ADANA, "market", icerir="Ticaret Bakanı")
q(f"update oyun.pazar_sirket set otopilot=false, fiyat=3 where sirket_id in ({m1},{m2})")   # iki farklı sahip, ikisi de premium: kartel
re = rpc(TIC, "rekabet_ekrani")
assert re["yetkili"] and any(z["il_id"] == ADANA and z["hepsi_premium"] for z in re["riskli"])
k0a, k0b = kasa(m1), kasa(m2)
rpc(TIC, "rekabet_ac", ADANA, "market")
assert float(q("select kasa from oyun.bakanlik_kasa where kod='ticaret'")) == 29.5
hata_bekle(rpc, TIC, "rekabet_ac", ADANA, "market", icerir="zaten")
rpc(TIC, "rekabet_ac", IZMIR, "market")         # İzmir'de tek market, orta fiyat → temiz
zaman("2030-03-11 10:10"); q("select oyun.pazar_tick()")
s1 = qj(f"select row_to_json(r) from oyun.rekabet_sorusturma r where il_id={ADANA}")
s2 = qj(f"select row_to_json(r) from oyun.rekabet_sorusturma r where il_id={IZMIR}")
assert s1["durum"] == "ihlal" and "kartel" in s1["karar"], s1
assert abs(kasa(m1) - (k0a - round(k0a * 0.08))) < 2 and abs(kasa(m2) - (k0b - round(k0b * 0.08))) < 2
assert q(f"select fiyat from oyun.pazar_sirket where sirket_id={m1}") == "2"
assert s2["durum"] == "temiz"
ok(f"Rekabet Kurumu: Adana marketlerinde kartel → toplam {float(s1['ceza']):,.0f} ₺ ceza, fiyat ortaya; İzmir temiz")

# ---------------- şirket bağışı
parti = int(q("select id from oyun.partiler where not kapali order by id limit 1"))
pk0 = float(q(f"select kasa from oyun.partiler where id={parti}"))
hata_bekle(rpc, C, "sirket_parti_bagis", m1, parti, 5000, icerir="en büyük ortak")
hata_bekle(rpc, A, "sirket_parti_bagis", m1, parti, 90000, icerir="7 günde en fazla")
k1 = kasa(m1)
rpc(A, "sirket_parti_bagis", m1, parti, 50000)
assert float(q(f"select kasa from oyun.partiler where id={parti}")) == pk0 + 50000 and kasa(m1) == k1 - 50000
hata_bekle(rpc, A, "sirket_parti_bagis", m1, parti, 40000, icerir="kalan 30.000")
sb = rpc(B, "siyasi_bagislar")
assert sb["son"][0]["tutar"] == 50000 and sb["parti_toplam"][0]["tutar"] == 50000
assert "bağış" in q("select metin from oyun.olaylar order by id desc limit 1")
ok("Şirket bağışı: 7 günde sermayenin %20'si sınırı, parti kasası arttı, herkese açık liste ve olay akışı")

# ---------------- yerel fiyat → geçim ve enflasyon
q(f"update oyun.pazar_sirket set fiyat=1 where sirket_id in ({m1},{m2})")     # Adana: iki ucuz market
q(f"update oyun.pazar_sirket set fiyat=3 where sirket_id={m_iz}")              # İzmir: tek premium market
q("update oyun.pazar_ayar set son_endeks_gun=null")
enf0 = float(q("select enflasyon from oyun.ulke where id=1"))
q("select oyun.piyasa_endeks_tick()")
ga = float(q(f"select deger from oyun.etkiler where kaynak_tur='piyasa' and il_id={ADANA}"))
gi = float(q(f"select deger from oyun.etkiler where kaynak_tur='piyasa' and il_id={IZMIR}"))
assert ga == 5 and gi == -7.5, (ga, gi)
assert abs(float(q("select oyun.bonus(%d::smallint,'gecim',oyun.simdi())" % ADANA)) - 5) < 1e-9
q("select oyun.piyasa_endeks_tick()")       # aynı gün ikinci kez çalışmaz
assert int(q("select count(*) from oyun.etkiler where kaynak_tur='piyasa'")) == 2
assert float(q("select enflasyon from oyun.ulke where id=1")) != enf0
ok(f"Yerel fiyatlar: Adana (iki ucuz market) geçim %{ga:+.1f}, İzmir (premium tekel) %{gi:+.1f}; enflasyon {enf0:.2f} → {float(q('select enflasyon from oyun.ulke where id=1')):.2f}")
# market kapanınca etki biter
q(f"update oyun.sirketler set aktif=false where id={m_iz}")
q("update oyun.pazar_ayar set son_endeks_gun=null"); q("select oyun.piyasa_endeks_tick()")
assert float(q(f"select oyun.bonus({IZMIR}::smallint,'gecim',oyun.simdi())")) == 0
ok("İlde market kalmayınca geçim etkisi kalkıyor")

# ---------------- piyasa raporu ve şirket rehberi
pr = rpc(A, "piyasa_raporu")
assert len(pr["sektorler"]) == 5 and pr["borsa"]["sirket"] == 1 and pr["rekabet"] and pr["bagislar"]
assert pr["ucuz_iller"][0]["il"] == "Adana"
v = rpc(A, "sirket_vitrini")
vm = next(s for s in v["sirketler"] if s["id"] == m1)
assert vm["il"] == "Adana" and vm["halka_acik"] and float(vm["vergi"]) >= 0
ok("Piyasa raporu (sektör liderleri, borsa, ihale, kararlar, bağışlar, ucuz/pahalı iller) ve şirket rehberi")
print("TAMAM: borsa + rekabet + bağış + otopilot + fiyat endeksi")
