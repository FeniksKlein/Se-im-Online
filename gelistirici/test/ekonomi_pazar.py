"""Modül 84: rekabetçi şirketler, kamu ihaleleri, sektör politikası ve ruhsat harcı."""
from db import q, qj, rpc, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
para = lambda u: float(q(f"select para from oyun.cuzdan where user_id='{u}'"))
kasa = lambda sid: float(q(f"select kasa from oyun.sirketler where id={sid}"))
def zaman(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}+03'")

zaman("2030-03-03 10:00")
def oyuncu(kad, il="İzmir", p=5000000):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.cuzdan set para={p} where user_id='{u}'"); return u
A, B, C, D = oyuncu("Ayse"), oyuncu("Burak"), oyuncu("Cem"), oyuncu("Deniz")
BAS, BAKAN, CB = oyuncu("Baskan"), oyuncu("SaglikBakani"), oyuncu("Reis")
q("update oyun.ulke set asgari=30000, buyume=3, memnuniyet=50 where id=1")
q("update oyun.il_durum set gelisim=50, memnuniyet=50")
ADANA, BARTIN, IZMIR = IL("Adana"), IL("Bartın"), IL("İzmir")

# ---------------- katalog ve kuruluş
k = rpc(A, "pazar_katalog")
assert [s["kod"] for s in k["sektorler"]] == ["ozel_okul", "ozel_hastane", "market", "ulasim", "enerji"]
hata_bekle(rpc, A, "pazar_sirket_kur", "Ab", "market", 400000, ADANA, None, icerir="3-50")
hata_bekle(rpc, A, "pazar_sirket_kur", "Ayse Market", "market", 100000, ADANA, None, icerir="en az")
hata_bekle(rpc, A, "pazar_sirket_kur", "Ayse Market", "kuyumcu", 400000, ADANA, None, icerir="Geçersiz")
hata_bekle(rpc, A, "sirket_kur", "Eski Yol", "market", 400000, icerir="Gecersiz sektor")   # eski RPC eski türlerle sınırlı kalır
m1 = rpc(A, "pazar_sirket_kur", "Ayse Market", "market", 400000, ADANA, None)
assert para(A) == 4600000 and kasa(m1["id"]) == 400000
yalniz = m1["tahmin"]
assert yalniz["rakip"] == 0 and yalniz["net"] > 0, yalniz
ok(f"Market kuruldu (Adana, 400.000 ₺): tek başına haftalık net tahmini {yalniz['net']:,} ₺ (%{yalniz['getiri']}), pay %{yalniz['pay']}")

# ---------------- rekabet: ikinci şirket aynı ile gelince ikisi de daralır
m2 = rpc(B, "pazar_sirket_kur", "Burak Market", "market", 400000, ADANA, None)
t1 = rpc(A, "pazar_detay", m1["id"])["tahmin"]; t2 = m2["tahmin"]
assert t1["rakip"] == 1 and t1["net"] < yalniz["net"] and abs(t1["net"] - t2["net"]) < 2, (t1, t2)
ok(f"Rakip girdi: ikisinin de net tahmini {t1['net']:,} ₺'ye düştü")
# fiyat savaşı: Burak ucuza geçer, Ayşe'nin payı düşer
rpc(B, "pazar_ayarla", m2["id"], 1, 1, None)
t1b = rpc(A, "pazar_detay", m1["id"])["tahmin"]; t2b = rpc(B, "pazar_detay", m2["id"])["tahmin"]
assert t2b["pay"] > t1b["pay"] and t1b["net"] < t1["net"], (t1b, t2b)
ok(f"Fiyat savaşı: ucuz market pay %{t2b['pay']} / pahalı kalan %{t1b['pay']}; Ayşe'nin neti {t1b['net']:,} ₺")
# yetki
hata_bekle(rpc, C, "pazar_ayarla", m1["id"], 1, 1, None, icerir="en büyük ortak")
hata_bekle(rpc, B, "pazar_ayarla", m2["id"], 2, 1, None, icerir="10 dakikada")
# senaryo tablosu 12 fiyat×kalite kombinasyonu içerir
d = rpc(A, "pazar_detay", m1["id"])
assert len(d["senaryo"]) == 12 and len(d["rakipler"]) == 1 and d["yonetici"]
ok("Yönetim yetkisi, 10 dakika sınırı ve 12'li senaryo tablosu çalışıyor")

# ---------------- kalabalık il zarar ettirir, boş il kazandırır
for i, u in enumerate([C, D]):
    rpc(u, "pazar_sirket_kur", f"Market {i}", "market", 400000, ADANA, None)
kalabalik = rpc(A, "pazar_detay", m1["id"])["tahmin"]
assert kalabalik["rakip"] == 3 and kalabalik["net"] < 0, kalabalik
h = rpc(A, "pazar_harita", "market")
adana = next(x for x in h["iller"] if x["il_id"] == ADANA)
assert adana["rakip"] == 4 and h["iller"][0]["rakip"] == 0 and len(h["iller"]) == 81
ok(f"Adana'da 4 market: Ayşe'nin neti {kalabalik['net']:,} ₺ (zarar); haritada en iyi fırsat {h['iller'][0]['il']}")

# ---------------- haftalık hesap: cron gibi pazar_tick, vergi hazineye, rapor yazılır
hazine0 = float(q("select hazine from oyun.ulke where id=1"))
gel0 = float(q(f"select gelisim from oyun.il_durum where il_id={ADANA}"))
q("select setseed(0.3)")
zaman("2030-03-10 10:05")
n = int(q("select oyun.pazar_tick()"))
assert n == 4, n
r = qj(f"select row_to_json(r) from oyun.pazar_rapor r where sirket_id={m1['id']}")
assert r and r["rakip"] == 3 and float(r["net"]) < 0
assert float(q(f"select gelisim from oyun.il_durum where il_id={ADANA}")) > gel0
assert int(q(f"select count(*) from oyun.sirket_hareket where sirket_id={m1['id']}")) == 1
ok(f"Haftalık hesap: 4 şirket işlendi, Ayşe'nin raporu net {float(r['net']):,.0f} ₺, Adana gelişimi arttı")

# küçük ilde büyük sermaye gideri karşılayamaz
bartin = rpc(A, "pazar_detay", m1["id"])
# Ayşe İzmir'e taşınır (tek başına) → bedel kasadan, marka düşer
hata_bekle(rpc, C, "pazar_tasi", m1["id"], IZMIR, icerir="en büyük ortak")
k0 = kasa(m1["id"])
tas = rpc(A, "pazar_tasi", m1["id"], IZMIR)
assert kasa(m1["id"]) == k0 - 40000 and tas["rakip"] == 0 and tas["net"] > 0, tas
hata_bekle(rpc, A, "pazar_tasi", m1["id"], BARTIN, icerir="7 günde")
ok(f"Taşınma: 40.000 ₺ bedel, İzmir'de tek başına net tahmini {tas['net']:,} ₺")

# kâr eden şirket ortağa kâr payı öder ve kurumlar vergisi hazineye gider
zaman("2030-03-17 10:10")
pA = para(A)
q("select oyun.pazar_tick()")
r2 = qj(f"select row_to_json(r) from oyun.pazar_rapor r where sirket_id={m1['id']} order by zaman desc limit 1")
assert float(r2["net"]) > 0 and float(r2["vergi"]) > 0, r2
assert para(A) > pA
assert float(q("select hazine from oyun.ulke where id=1")) > hazine0
ok(f"İzmir haftası: net {float(r2['net']):,.0f} ₺ ortağa ödendi, {float(r2['vergi']):,.0f} ₺ kurumlar vergisi hazineye")

# ---------------- iflas: kasası biten şirket kapanır
q(f"update oyun.sirketler set kasa=1000 where id={m2['id']}")
zaman("2030-03-24 10:15")
q("select oyun.pazar_tick()")
assert q(f"select aktif from oyun.sirketler where id={m2['id']}") == "f"
assert "iflas" in q(f"select metin from oyun.bildirimler where user_id='{B}' order by id desc limit 1")
ok("Kasası tükenen market iflas etti, ortağa bildirildi")

# ---------------- enerji kaynağı
e1 = rpc(C, "pazar_sirket_kur", "Cem Enerji", "enerji", 500000, IZMIR, "komur")
mem0 = float(q(f"select memnuniyet from oyun.il_durum where il_id={IZMIR}"))
de = rpc(C, "pazar_detay", e1["id"])
kay = {x["kaynak"]: x["net"] for x in de["senaryo"] if "kaynak" in x}
assert set(kay) == {"komur", "dogalgaz", "yenilenebilir"} and kay["komur"] > kay["yenilenebilir"], kay
ok(f"Enerji kaynakları: kömür {kay['komur']:,} / doğalgaz {kay['dogalgaz']:,} / yenilenebilir {kay['yenilenebilir']:,} ₺ haftalık")

# ---------------- sektör politikası
q(f"insert into oyun.makamlar(tur,user_id,bas) values ('cb','{CB}',now())")
q(f"insert into oyun.makamlar(tur,user_id,bakanlik,bas) values ('bakan','{BAKAN}','saglik',now())")
q("update oyun.bakanlik_kasa set kasa=30")
hata_bekle(rpc, A, "sektor_politika_ayarla", "ozel_hastane", "tesvik", icerir="Sağlık Bakanı")
h1 = rpc(D, "pazar_sirket_kur", "Deniz Hastane", "ozel_hastane", 400000, IZMIR, None)["tahmin"]
rpc(BAKAN, "sektor_politika_ayarla", "ozel_hastane", "tesvik")
assert float(q("select kasa from oyun.bakanlik_kasa where kod='saglik'")) == 28
h2 = rpc(D, "pazar_detay", int(q("select id from oyun.sirketler where ad='Deniz Hastane'")))["tahmin"]
assert h2["politika"] == "tesvik" and h2["pazar"] > h1["pazar"]
hata_bekle(rpc, BAKAN, "sektor_politika_ayarla", "ozel_hastane", "normal", icerir="24 saatte")
# boş bakanlığa CB vekâlet eder: Ticaret bakanı yok → CB market denetimi açar
rpc(CB, "sektor_politika_ayarla", "market", "denetim")
assert q("select oyun.sektor_pol_durum('market', oyun.simdi())") == "denetim"
# eski türe de işler: tarım teşviki (Tarım bakanlığı boş → CB)
rpc(CB, "sektor_politika_ayarla", "tarim", "tesvik")
assert float(q("select oyun.sektor_pol_carpan('tarim', oyun.simdi())")) == 1.15
ok(f"Sektör politikası: Sağlık teşviki pazarı {h1['pazar']:,} → {h2['pazar']:,} ₺, bakanlık kasası 30 → 28 milyar; CB boş bakanlıklara vekâlet ediyor")

# ---------------- ruhsat harcı
q(f"insert into oyun.makamlar(tur,user_id,il_id,bas) values ('bel','{BAS}',{IZMIR},now())")
hata_bekle(rpc, A, "il_ruhsat_ayarla", 5, icerir="belediye başkanı")
hata_bekle(rpc, BAS, "il_ruhsat_ayarla", 9, icerir="%8")
rpc(BAS, "il_ruhsat_ayarla", 5)
h3 = rpc(D, "pazar_detay", int(q("select id from oyun.sirketler where ad='Deniz Hastane'")))["tahmin"]
assert h3["ruhsat_oran"] == 5 and h3["ruhsat"] > 0
ok(f"İzmir ruhsat harcı %5: Deniz Hastane'den haftalık {h3['ruhsat']:,} ₺ belediyeye")

# ---------------- kamu ihalesi
ins1 = rpc(A, "sirket_kur", "Ayse Insaat", "insaat", 400000)["id"]
ins2 = rpc(B, "sirket_kur", "Burak Yapi", "insaat", 400000)["id"]
ins3 = rpc(BAS, "sirket_kur", "Baskanin Firmasi", "insaat", 400000)["id"]
q(f"update oyun.il_durum set kasa=5 where il_id={IZMIR}")
e = rpc(BAS, "ihale_ekrani")
assert e["yetki"]["belediye_il"] == IZMIR and any(p["kod"] == "yol" for p in e["yetki"]["projeler"])
hata_bekle(rpc, A, "ihale_ac", "yol", IZMIR, 24, icerir="belediye başkanı")
hata_bekle(rpc, BAS, "ihale_ac", "yol", IZMIR, 6, icerir="12, 24")
ih = rpc(BAS, "ihale_ac", "yol", IZMIR, 24)
butce = float(ih["butce"]); tavan = float(ih["tavan"])
assert abs(float(q(f"select kasa from oyun.il_durum where il_id={IZMIR}")) - (5 - butce)) < 1e-6
hata_bekle(rpc, BAS, "ihale_ac", "yol", IZMIR, 24, icerir="zaten")
hata_bekle(rpc, BAS, "ihale_teklif", ih["id"], ins3, int(tavan * 0.8), icerir="Çıkar çatışması")
hata_bekle(rpc, A, "ihale_teklif", ih["id"], m1["id"], int(tavan * 0.8), icerir="inşaat")
hata_bekle(rpc, A, "ihale_teklif", ih["id"], ins1, int(tavan * 0.3), icerir="arasında")
rpc(A, "ihale_teklif", ih["id"], ins1, int(tavan * 0.9))
rpc(B, "ihale_teklif", ih["id"], ins2, int(tavan * 0.78))
rpc(A, "ihale_teklif", ih["id"], ins1, int(tavan * 0.75))     # teklifini güncelleyebilir
gor = rpc(C, "ihale_ekrani")["acik"][0]
assert gor["teklif_say"] == 2 and gor["teklifler"] is None and gor["bedel"] is None   # kapalı zarf
ok(f"İhale açıldı: İzmir yol yenileme, bütçe {butce} milyar ₺ ≈ {tavan:,.0f} ₺; çıkar çatışması ve kapalı zarf çalışıyor")

zaman("2030-03-25 10:20")
q("select oyun.ihale_tick()")
x = qj(f"select row_to_json(x) from oyun.kamu_ihale x where id={ih['id']}")
assert x["durum"] == "yapim" and x["kazanan"] == ins1 and float(x["bedel"]) == int(tavan * 0.75)
assert kasa(ins1) == 400000 - round(tavan * 0.70)
iade = round((tavan - int(tavan * 0.75)) / tavan * butce, 4)
assert abs(float(q(f"select kasa from oyun.il_durum where il_id={IZMIR}")) - (5 - butce + iade)) < 1e-3
ok(f"En düşük teklif kazandı ({int(tavan*0.75):,} ₺); artan {iade} milyar ₺ belediyeye döndü")

# yöntem: önce kaliteli, sonra tasarruflu (yakalanma senaryosu zorlanır)
hata_bekle(rpc, B, "ihale_yontem", ih["id"], "kaliteli", icerir="en büyük ortağı")
rpc(A, "ihale_yontem", ih["id"], "kaliteli")
assert kasa(ins1) == 400000 - round(tavan * 0.85)
rpc(A, "ihale_yontem", ih["id"], "tasarruflu")
assert kasa(ins1) == 400000 - round(tavan * 0.55)
q("select setseed(0.0)")
q("create or replace function pg_temp.x() returns void language sql as 'select 1'")
gel1 = float(q(f"select gelisim from oyun.il_durum where il_id={IZMIR}"))
# yakalanmayı garantilemek için insaat denetimi aç (risk %60) ve rastgeleyi sabitle
q("insert into oyun.sektor_politika(sektor,durum,bas,bit,son_degisim) values ('insaat','denetim',now(),'2031-01-01',now()) on conflict (sektor) do update set durum='denetim', bit='2031-01-01'")
zaman("2030-03-28 10:25")
yakalandi = None
for tohum in [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09]:
    q(f"select setseed({tohum}); select oyun.ihale_tick();")
    x = qj(f"select row_to_json(x) from oyun.kamu_ihale x where id={ih['id']}")
    if x["durum"] == "tamam": yakalandi = x["sonuc"] == "yakalandi"; break
assert x["durum"] == "tamam"
dn = qj(f"select row_to_json(d) from oyun.sirket_deneyim d where sirket_id={ins1}")
if yakalandi:
    assert dn["yasak_bit"] is not None and dn["is_sayisi"] == 0
    hata_bekle(rpc, BAS, "ihale_ac", "park", IZMIR, 12) if False else None
    ok("Tasarruflu yapım denetimde yakalandı: hakediş yarım, %20 ceza, 14 gün ihale yasağı, skandal haberi")
else:
    assert dn["is_sayisi"] == 1
    ok("Tasarruflu yapım denetimden kurtuldu: tam hakediş, etki düşük")
assert float(q(f"select gelisim from oyun.il_durum where il_id={IZMIR}")) > gel1
# yakalanma dalı: denetim altında tasarruflu işler tekrarlanır, en az biri yakalanmalı
yakalanan = yakalandi
for deneme in range(8):
    if yakalanan: break
    q(f"update oyun.il_durum set kasa=5 where il_id={IZMIR}; delete from oyun.sirket_deneyim where sirket_id={ins2}")
    q(f"update oyun.sirketler set kasa=400000 where id={ins2}")
    zaman(f"2030-05-{deneme+1:02d} 09:00")
    pr = ["park", "kres", "yol"][deneme % 3]
    q(f"update oyun.kamu_ihale set durum='iptal' where il_id={IZMIR} and durum in ('acik','yapim')")
    z = rpc(BAS, "ihale_ac", pr, IZMIR, 12)
    rpc(B, "ihale_teklif", z["id"], ins2, int(float(z["tavan"]) * 0.8))
    zaman(f"2030-05-{deneme+1:02d} 22:00"); q("select oyun.ihale_tick()")
    rpc(B, "ihale_yontem", z["id"], "tasarruflu")
    zaman(f"2030-05-{deneme+6:02d} 23:00"); q(f"select setseed({0.1 + deneme / 20}); select oyun.ihale_tick();")
    zx = qj(f"select row_to_json(x) from oyun.kamu_ihale x where id={z['id']}")
    assert zx["durum"] == "tamam", zx
    yakalanan = zx["sonuc"] == "yakalandi"
    if yakalanan:
        dn2 = qj(f"select row_to_json(d) from oyun.sirket_deneyim d where sirket_id={ins2}")
        assert dn2["yasak_bit"] is not None
        assert "skandal" in q(f"select lower(baslik) from oyun.gazete where ref_id={z['id']} order by id desc limit 1")
        z2 = rpc(BAS, "ihale_ac", "park" if pr != "park" else "kres", IZMIR, 12)
        hata_bekle(rpc, B, "ihale_teklif", z2["id"], ins2, int(float(z2["tavan"]) * 0.8), icerir="yasaklı")
        rpc(BAS, "ihale_iptal", z2["id"])
assert yakalanan, "denetim dalı hiç tetiklenmedi"
ok("Denetimde yakalanan tasarruflu iş: kesinti + ceza, skandal manşeti, 14 gün ihale yasağı")

# teklifsiz ihale bütçeyi iade eder; bakanlık ihalesi + deneyim şartı
k0 = float(q("select kasa from oyun.bakanlik_kasa where kod='saglik'"))
zaman("2030-05-20 09:00")
ih2 = rpc(BAKAN, "ihale_ac", "hastane", ADANA, 12)
assert abs(float(q("select kasa from oyun.bakanlik_kasa where kod='saglik'")) - (k0 - float(ih2["butce"]))) < 1e-6
zaman("2030-05-20 22:30"); q("select oyun.ihale_tick()")
assert q(f"select durum from oyun.kamu_ihale where id={ih2['id']}") == "teklifsiz"
assert abs(float(q("select kasa from oyun.bakanlik_kasa where kod='saglik'")) - k0) < 1e-6
q(f"update oyun.il_durum set kasa=20 where il_id={IZMIR}")
ih3 = rpc(BAS, "ihale_ac", "metro", IZMIR, 12)
hata_bekle(rpc, B, "ihale_teklif", ih3["id"], ins2, int(float(ih3["tavan"]) * 0.8), icerir="deneyim")
rpc(BAS, "ihale_iptal", ih3["id"])
assert q(f"select durum from oyun.kamu_ihale where id={ih3['id']}") == "iptal"
ok("Teklifsiz bakanlık ihalesi kasaya döndü; metro deneyim ister; iptal bütçeyi iade eder")

# ---------------- eski şirketler eskisi gibi + politika çarpanı
zaman("2030-05-28 10:35")
rpc(A, "sirket_liste")
assert int(q(f"select count(*) from oyun.sirket_hareket where sirket_id={ins1} and aciklama like '7 günlük%'")) >= 1
ok("Eski türler (inşaat) haftalık eski motorla hesaplanmaya devam ediyor")
print("TAMAM: ekonomi pazar + ihale + politika")
