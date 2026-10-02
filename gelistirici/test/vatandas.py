"""4. aşama: vatandaş ekonomisi ve vaatler.
Maaş kumbarası, giriş serisi, statü, reklam ödülü, makam maaşları, vergiler, geçim; politikalar (yürütme),
belediye ayarları, aday ücreti, taşınma, bağış, ek yayın, satın alma; ölçülebilir vaatler, mali alan ve vaat karnesi.
Çalıştır: ../kur_yerel.sh && python3 vatandas.py"""
import json
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle, SqlHata

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def k(sql): return q(sql)
def f(sql): return float(q(sql))
def hy(u): return rpc(u, "hayat")
def j(x): return json.dumps(x, ensure_ascii=False)

q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0;")
saat("2026-10-02 12:00")

def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    rpc(u, "durum")
    return u

# Eylül dönemi (geçmiş): seçim kayıtları ve son genel seçimin oyları (hazine yardımı için)
q("""insert into oyun.secimler(tur, donem, oy_bas, oy_bit, sonuc_at, durum) values
     ('mv',  '2026-09','2026-09-02 08:00+03','2026-09-02 17:00+03','2026-09-02 18:00+03','tamam'),
     ('bel', '2026-09','2026-09-04 08:00+03','2026-09-04 17:00+03','2026-09-04 18:00+03','tamam'),
     ('cb',  '2026-09','2026-09-02 08:00+03','2026-09-02 17:00+03','2026-09-02 18:00+03','tamam'),
     ('kurultay','2026-09','2026-09-18 08:00+03','2026-09-18 17:00+03','2026-09-18 18:00+03','tamam')""")
S = {t: int(k(f"select id from oyun.secimler where donem='2026-09' and tur='{t}'")) for t in ("mv", "bel", "cb", "kurultay")}
q(f"""insert into oyun.oylar(secim_id, secmen, il_id, parti_id)
      select {S['mv']}, gen_random_uuid(), 6, case when g <= 60 then 1 when g <= 98 then 2 else 3 end from generate_series(1,100) g""")
def makam(u, tur, il=None, parti=None, bakanlik=None, secim=None):
    return int(k(f"""insert into oyun.makamlar(tur,user_id,il_id,parti_id,bakanlik,secim_id,bas)
          values ('{tur}','{u}',{il or 'null'},{parti or 'null'},{"'" + bakanlik + "'" if bakanlik else 'null'},{secim or 'null'},'2026-10-02 12:00+03') returning id""").split()[0])
def vaat_ekle(kapsam, kod, hedef, u=None, parti=None, il=None, yon=None):
    q(f"""insert into oyun.vaatler(kapsam, donem, user_id, parti_id, il_id, kod, hedef, yon, olusturma)
          values ('{kapsam}','2026-09',{"'" + u + "'" if u else 'null'},{parti or 'null'},{il or 'null'},'{kod}',{hedef if hedef is not None else 'null'},
                  {"'" + yon + "'" if yon else 'null'},'2026-09-01 10:00+03')""")

ali   = oyuncu("Ali", 34, 1)
ayse  = oyuncu("Ayse", 34, 1)
veli  = oyuncu("Veli", 6, 2)
reis  = oyuncu("Reis", 6, 1);      makam(reis, "cb", parti=1, secim=S["cb"])
bas34 = oyuncu("Baskan34", 34, 1); bel34 = makam(bas34, "bel", il=34, parti=1, secim=S["bel"])
vek   = [oyuncu(f"Vekil{i}", 6, 1) for i in range(3)]
for u in vek: makam(u, "mv", il=6, parti=1, secim=S["mv"])
bakan = {b: oyuncu(f"Bakan{b.capitalize()}", 35, 1) for b in ("calisma", "maliye", "ulastirma", "saglik")}
for b, u in bakan.items(): makam(u, "bakan", parti=1, bakanlik=b)

# ---------------- MAAŞ KUMBARASI ----------------
h = hy(ali)
kb = h["kumbara"]
asg_saat = 28075 / 720
assert h["para"] == 10000 and h["statu"]["ad"] == "Yeni Gelen" and kb["dolu"] and kb["saat"] == 8
s_ = kb["saatlik"]
assert abs(s_["maas"] - asg_saat) < 0.01 and s_["vergi"] == 0                    # asgari ücret vergiden muaf
assert abs(s_["kent"] - asg_saat * 0.02) < 0.01 and abs(s_["gecim"] - 350 / 24) < 0.01
net8 = round((asg_saat * 0.98 - 350 / 24) * 8)
assert kb["birikmis"] == net8, (kb["birikmis"], net8)
r = rpc(ali, "topla")
assert r["para"] == 10000 + net8 and r["sonuc"]["ilk"] and r["sonuc"]["seri"] == 1 and r["statu"]["puan"] == 1
hata_bekle(rpc, ali, "topla", icerir="henüz boş")
saat("2026-10-02 15:00")
assert abs(hy(ali)["kumbara"]["birikmis"] - (asg_saat * 0.98 - 350 / 24) * 3) <= 1
saat("2026-10-03 06:00")                                                         # 18 saat geçti ama kumbara 8 saatte durur
kb = hy(ali)["kumbara"]
assert kb["saat"] == 8 and kb["dolu"] and kb["seri"] == 2 and kb["seri_bonus"] == 5
p0 = hy(ali)["para"]
r = rpc(ali, "topla")
assert r["sonuc"]["seri"] == 2 and r["para"] - p0 == kb["birikmis"] and "seri +%5" in r["hareketler"][0]["aciklama"]
ok(f"Kumbara: yeni oyuncu dolu kumbarayla başlar ({net8} ₺/8 saat), 8 saatte dolup durur, toplanınca boşalır; ikinci gün seri +%5")

saat("2026-10-05 09:00")                                                         # bir gün atladı → seri sıfırlanır
assert hy(ali)["kumbara"]["seri"] == 1
q(f"update oyun.cuzdan set kidem = 9 where user_id = '{ali}'")
r = rpc(ali, "topla")
assert r["statu"]["ad"] == "Vatandaş" and r["statu"]["carpan"] == 1.1 and r["sonuc"]["statu_atladi"]
assert "Statün yükseldi: Vatandaş" in k(f"select metin from oyun.bildirimler where user_id='{ali}' order by id desc limit 1")
s_ = hy(ali)["kumbara"]["saatlik"]
assert abs(s_["maas"] - asg_saat * 1.1) < 0.01 and abs(s_["vergi"] - asg_saat * 0.1 * 0.20) < 0.01   # yalnız asgari ücretin üstü vergilenir
ok("Seri: bir gün atlanınca sıfırlanır. Statü: 10 kıdem puanında Vatandaş (×1,1); asgari ücretin üstündeki kısım vergileniyor")

# ---------------- MAKAM MAAŞI, REKLAM ÖDÜLÜ ----------------
end = f("select endeks from oyun.ulke")
s_ = hy(vek[0])["kumbara"]["saatlik"]
assert abs(s_["makam"] - 310332 * end / 720) < 0.05, s_
assert hy(reis)["makamlar"][0]["aylik"] == round(354497 * end)
assert round(f("select oyun.makam_maasi('bel', 34::smallint)") / end) == 317800 and round(f("select oyun.makam_maasi('bel', 69::smallint)") / end) == 171400
p0 = hy(ayse)["para"]
r = rpc(ayse, "reklam_odul")
assert r["sonuc"]["odul"] == round(asg_saat * 2) and r["para"] == p0 + r["sonuc"]["odul"] and r["reklam"]["kalan"] == 4
hata_bekle(rpc, ayse, "reklam_odul", icerir="biraz bekle")
for i in range(4):
    saat(f"2026-10-05 09:{2 + 2 * i:02d}"); rpc(ayse, "reklam_odul")
saat("2026-10-05 09:30")
hata_bekle(rpc, ayse, "reklam_odul", icerir="Yarın")
ok(f"Makam maaşları gerçek oranlarda (vekil {round(310332 * end):,} ₺/ay, büyükşehir başkanı 317.800, küçük il 171.400); reklam ödülü 2 saatlik maaş, günde 5")

# ---------------- POLİTİKALAR (YÜRÜTME) ----------------
hata_bekle(rpc, ali, "politika_ayarla", "asgari", 30000, icerir="ilgili bakan")
hata_bekle(rpc, bakan["maliye"], "politika_ayarla", "asgari", 30000, icerir="ilgili bakan")
hata_bekle(rpc, bakan["calisma"], "politika_ayarla", "asgari", 40000, icerir="arasında")      # +%30'dan fazla
hata_bekle(rpc, bakan["calisma"], "politika_ayarla", "asgari", 27000, icerir="arasında")      # düşürülemez
on = rpc(bakan["calisma"], "politika_onizle", "asgari", 30000)
assert on["gunluk"] < 0 and on["enflasyon"] > 0                                  # vergi geliri artar ama enflasyon baskısı
rpc(bakan["calisma"], "politika_ayarla", "asgari", 30000)
assert abs(hy(ali)["kumbara"]["saatlik"]["maas"] - 30000 / 720 * 1.1) < 0.01
hata_bekle(rpc, reis, "politika_ayarla", "asgari", 31000, icerir="en erken")              # 7 günde bir (CB de bekler)
rpc(bakan["calisma"], "politika_ayarla", "destek", 150)
rpc(reis, "politika_ayarla", "kidem_primi", 15)
assert hy(ali)["statu"]["carpan"] == 1.15
hata_bekle(rpc, bakan["maliye"], "politika_ayarla", "vergi", 40, icerir="arasında")
rpc(bakan["maliye"], "politika_ayarla", "vergi", 15)
end = f("select endeks from oyun.ulke")
assert hy(ali)["fiyat"]["tasinma"] == round(5000 * end)
rpc(bakan["ulastirma"], "politika_ayarla", "tasinma_destek", 40)
assert abs(hy(ali)["fiyat"]["tasinma"] - 5000 * end * 0.6) <= 1
pan = rpc(bakan["calisma"], "bakanlik_paneli")
assert {p_["kod"] for p_ in pan["politikalar"]} == {"asgari", "kidem_primi", "destek"} and all(p_["hazir"] for p_ in pan["politikalar"])
assert "Asgari ücret: 28.075 ₺/ay → 30.000 ₺/ay" in k("select string_agg(baslik, '|') from oyun.gazete")
ok("Politikalar: asgari ücreti Çalışma Bakanı (en fazla +%30, düşürülemez, 7 günde bir), vergiyi Maliye (Meclis bandında), taşınma desteğini Ulaştırma; CB hepsini ayarlar; Resmî Gazete'de")

saat("2026-10-06 09:00")
r = rpc(veli, "topla")
assert r["sonuc"]["destek"] == 150 and any(x["tur"] == "destek" and x["tutar"] == 150 for x in r["hareketler"])
ok("Sosyal destek: yeni oyuncular günün ilk toplamasında 150 ₺ aldı")

# ---------------- BELEDİYE AYARLARI ----------------
hata_bekle(rpc, ali, "belediye_ayar", 0, 100, icerir="belediye başkanlarındadır")
q("update oyun.il_durum set kasa = 5 where il_id = 34")
pan = rpc(bas34, "belediye_ayar", 0, 100)
assert pan["kent_vergisi"] == 0 and pan["hemsehri"] == 100
hata_bekle(rpc, bas34, "belediye_ayar", 1, 100, icerir="24 saatte bir")
rpc(bas34, "belediye_hizmet", "lokanta", True)
kb = hy(ali)["kumbara"]
assert kb["saatlik"]["kent"] == 0 and kb["gecim_indirim"] == 15 and kb["gunluk_destek"]["belediye"] == 100
r = rpc(ayse, "topla")
assert any(x["tur"] == "hemsehri" and x["tutar"] == 100 for x in r["hareketler"]) and any(x["tur"] == "destek" for x in r["hareketler"])
assert any("Kent lokantası" in e["kaynak"] for e in r["etkiler"])
assert hy(veli)["kumbara"]["gecim_indirim"] == 0
ok("Belediye: kent vergisi %0, günlük 100 ₺ hemşehri desteği, kent lokantası (geçim −%15) yalnız İstanbullulara işliyor")

# ---------------- ADAY ÜCRETİ ----------------
q("update oyun.profiller set parti_at = '2026-10-01 00:00+03'")
q(f"update oyun.cuzdan set para = 5000 where user_id = '{ayse}'")
ucret = round(9000 * f("select endeks from oyun.ulke"))                          # İstanbul: 3.000 × 3
assert rpc(ayse, "parti_kasa", 1)["ucretler"]["bel_on"] == ucret
hata_bekle(rpc, ayse, "aday_ol", "bel_on", icerir="yeterli para")
assert k(f"select count(*) from oyun.adaylar where user_id='{ayse}'") == "0"                  # başvuru geri alındı
q(f"update oyun.partiler set gb = '{ali}' where id = 1")
hata_bekle(rpc, ayse, "parti_ucret_ayarla", '{"bel_on":0.5}', icerir="genel başkan")
pk = rpc(ali, "parti_ucret_ayarla", '{"bel_on":0.5}')
assert pk["ucretler"]["bel_on"] == round(ucret / 2)
k0 = rpc(ali, "parti_kasa", 1)["kasa"]
rpc(ayse, "aday_ol", "bel_on")
assert hy(ayse)["para"] == 5000 - round(ucret / 2) and rpc(ali, "parti_kasa", 1)["kasa"] == k0 + round(ucret / 2)
ok(f"Aday ücreti: İstanbul belediye ön seçimi {ucret:,} ₺, para yetmeyince başvuru alınmadı; GB çarpanı ×0,5 yaptı; ücret parti kasasına girdi")

# ---------------- VAATLER: KAYIT VE MALİ ALAN ----------------
sec = rpc(ayse, "vaat_secenekleri", "bel")
assert len(sec["turler"]) == 8 and sec["en_fazla"] == 4 and sec["alan"] > 0
bo = int(k("select id from oyun.secimler where tur='bel_on' and donem='2026-10'"))
asiri = j([{"kod": "hemsehri", "hedef": 1000}, {"kod": "kira"}, {"kod": "istihdam"}, {"kod": "rayli"}])
assert rpc(ayse, "vaat_hesapla", "bel", asiri)["karar"] == "karsiliksiz"
hata_bekle(rpc, ayse, "vaat_yaz", bo, "Vaatlerim", asiri, icerir="karşılığı yok")
hata_bekle(rpc, ayse, "vaat_yaz", bo, "Vaatlerim", j([{"kod": "asgari", "hedef": 40000}]), icerir="Geçersiz vaat")
hata_bekle(rpc, ayse, "vaat_yaz", bo, "Vaatlerim", j([{"kod": "kira"}, {"kod": "kira"}]), icerir="iki kez")
r = rpc(ayse, "vaat_yaz", bo, "İstanbul'a kira yardımı ve hemşehri desteği!", j([{"kod": "kira"}, {"kod": "hemsehri", "hedef": 150}]))
assert r["hesap"]["karar"] in ("karsilanabilir", "zorlayici")
d = rpc(veli, "il_detay", 34)
a = next(x for x in d["adaylar"] if x["kad"] == "Ayse")
assert [v["kod"] for v in a["vaatler"]] == ["kira", "hemsehri"] and a["vaatler"][1]["hedef_yazi"] == "150 ₺/gün", a
rpc(ayse, "adaylik_geri_cek", bo)
ok(f"Belediye adayı vaatleri: kira yardımı + günlük 150 ₺ ({r['hesap']['karar']}); bütçeyi aşan liste 'karşılıksız' diye reddedildi; vaatler aday listesinde")

# ---------------- TAŞINMA, BAĞIŞ, EK YAYIN ----------------
hata_bekle(rpc, ali, "il_degistir", 35, icerir="Belediye seçim dönemi")
saat("2026-10-12 10:00")
q(f"update oyun.cuzdan set para = 100 where user_id = '{veli}'")
hata_bekle(rpc, veli, "il_degistir", 34, icerir="yeterli para")
fiyat = hy(ali)["fiyat"]["tasinma"]
p0 = hy(ali)["para"]
rpc(ali, "il_degistir", 35)
assert hy(ali)["para"] == p0 - fiyat and hy(ali)["il_ad"] == "İzmir"
ok(f"Taşınma: {fiyat:,} ₺ (devletin %40 taşınma desteği düşülmüş); parası yetmeyen taşınamıyor")

tavan = f("select asgari from oyun.ulke")
hy(vek[1]); q(f"update oyun.cuzdan set para = 100000 where user_id = '{vek[1]}'")
rpc(vek[1], "bagis_yap", 20000)
hata_bekle(rpc, vek[1], "bagis_yap", 15000, icerir="Bağış sınırı")
hata_bekle(rpc, veli, "reklam_al", icerir="Yayın yetkin")
rpc(vek[1], "yayin_gonder", "vekil", "Ankara'ya yeni hastane!", None)
hata_bekle(rpc, vek[1], "yayin_gonder", "vekil", "İkinci", None, icerir="ek yayın hakkı")
rpc(vek[1], "reklam_al")
rpc(vek[1], "yayin_gonder", "vekil", "İkinci mesaj", None)
ok(f"Bağış sınırı günde {round(tavan):,} ₺; ek propaganda hakkı satın alınıp kullanıldı")

# ---------------- SATIN ALMA ----------------
def odeme(olay): return qj(f"set role service_role; select public.odeme_isle('{json.dumps(olay)}'::jsonb);")
p0 = hy(veli)["para"]
assert odeme({"event": {"type": "TEST"}})["durum"] == "test"
satis = {"event": {"type": "NON_RENEWING_PURCHASE", "app_user_id": veli, "product_id": "tl_35000", "transaction_id": "GPA.1"}}
assert odeme(satis)["durum"] == "eklendi" and odeme(satis)["durum"] == "zaten_islendi"
assert odeme({"event": {"type": "NON_RENEWING_PURCHASE", "app_user_id": veli, "product_id": "bilinmeyen", "transaction_id": "GPA.2"}})["durum"] == "urun_yok"
assert hy(veli)["para"] == p0 + 35000
assert odeme({"event": {"type": "CANCELLATION", "app_user_id": veli, "product_id": "tl_35000", "transaction_id": "GPA.1"}})["dusulen"] == 35000
assert hy(veli)["para"] == p0
ok("Satın alma: yalnız sunucu (service_role) para ekleyebilir; aynı işlem iki kez eklenmez; iade düşülür")

# ---------------- SEÇİM BEYANNAMESİ ----------------
hata_bekle(rpc, ayse, "beyanname_kaydet", "Beyanname", j([]), icerir="genel başkan")
hata_bekle(rpc, ali, "beyanname_kaydet", "Beyanname", j([{"kod": "vergi", "hedef": 0}, {"kod": "destek", "hedef": 1000}]), icerir="karşılığı yok")
asg = f("select asgari from oyun.ulke")
hata_bekle(rpc, ali, "beyanname_kaydet", "Beyanname", j([{"kod": "asgari", "hedef": round(asg * 1.6)}]), icerir="karşılığı yok")   # enflasyon patlar
r = rpc(ali, "beyanname_kaydet", "Üreten Türkiye: istihdam, destek ve dengeli bütçe.",
        j([{"kod": "destek", "hedef": 400}, {"kod": "vergi", "hedef": 22}, {"kod": "cal_istihdam"}]))
assert r["hesap"]["karar"] != "karsiliksiz" and len(r["beyanname"]["vaatler"]) == 3
assert r["hesap"]["vaatler"][1]["gunluk"] < 0                                   # vergi artışı gelir getiriyor, desteği finanse ediyor
assert rpc(veli, "parti_kasa", 1)["beyanname"]["metin"].startswith("Üreten Türkiye")
ok(f"Seçim beyannamesi: sıfır vergi + 1.000 ₺ destek ve %60 asgari ücret artışı reddedildi; vergi artışıyla finanse edilen destek kabul edildi ({r['hesap']['karar']})")

# Vekil adayı yalnız Meclis yetkilerini vaat eder
saat("2026-10-26 10:00")
q(f"update oyun.cuzdan set para = 50000 where user_id = '{veli}'")
rpc(veli, "aday_ol", "mv_on")
mo = int(k("select id from oyun.secimler where tur='mv_on' and durum='bekliyor' order by oy_bas limit 1"))
hata_bekle(rpc, veli, "vaat_yaz", mo, "x", j([{"kod": "asgari", "hedef": 35000}]), icerir="Geçersiz vaat")
r = rpc(veli, "vaat_yaz", mo, "Ankara'ya daha çok belediye payı!", j([{"kod": "belediye_payi", "hedef": 15}, {"kod": "baraj", "hedef": 5}]))
assert len(r["hesap"]["vaatler"]) == 2
assert k(f"select string_agg(distinct durum, ',') from oyun.vaatler where user_id='{ayse}'") == "secilmedi"
ok("Vekil adayı yalnız Meclis'in yetkisindekini vaat edebiliyor; adaylıktan çekilenin vaatleri 'seçilmedi' olarak kapandı")

# ---------------- VAAT TAKİBİ VE KARNE ----------------
q(f"update oyun.partiler set gb = '{ali}' where id = 1")
q(f"update oyun.makamlar set bit = null, bitis_neden = null where id = {bel34}")
vaat_ekle("bel", "lokanta", None, u=bas34, parti=1, il=34)
vaat_ekle("bel", "kent_vergisi", 1, u=bas34, parti=1, il=34)
vaat_ekle("bel", "rayli", None, u=bas34, parti=1, il=34)
vaat_ekle("beyanname", "asgari", 30000, parti=1, yon=">=")
vaat_ekle("beyanname", "ikramiye", 1000, parti=1, yon=">=")
vaat_ekle("mv", "belediye_payi", 15, u=vek[0], parti=1, il=6, yon=">=")
vaat_ekle("gb", "aday_ucret", 0.5, u=ali, parti=1, yon="<=")
vaat_ekle("mv", "baraj", 3, u=vek[2], parti=1, il=6, yon="<=")
saat("2026-10-27 00:05")                                                         # gece: vaatler etkinleşir ve ilk gün değerlendirilir
assert k("select string_agg(durum, ',' order by id) from oyun.vaatler where donem='2026-09'") == ",".join(["aktif"] * 8)
assert k("select gun_tutuldu || '/' || gun_toplam from oyun.vaatler where donem='2026-09' and kod='kent_vergisi'") == "1/1"
pan = rpc(bas34, "belediye_paneli")
assert [v["tutuldu"] for v in pan["vaatler"]] == [True, True, False]           # lokanta açık, kent vergisi %0 ≤ %1, raylı yapılmadı
rpc(reis, "kararname_cikar", "ikramiye", None, None, '{"miktar":1000}')
pay = {"adalet":7,"disisleri":5,"icisleri":9,"maliye":6,"savunma":12,"egitim":14,"saglik":13,"sanayi":7,"ticaret":5,"tarim":7,"ulastirma":9,"calisma":6}
kid = rpc(vek[0], "kanun_teklif", "butce", "Yerel Yönetimleri Güçlendirme Bütçesi", "Belediyelerin payı %15'e çıkarılır.", j({"belediye_payi": 15, "paylar": pay}))["id"]
saat("2026-10-28 00:10")
for u in vek[:2]: rpc(u, "kanun_oy", kid, "kabul")
rpc(vek[2], "kanun_oy", kid, "ret")
saat("2026-10-29 00:11")
rpc(reis, "kanun_cb_karar", kid, "onay", None)
rpc(ali, "parti_ucret_ayarla", '{"mv_on":0.5,"bel_on":0.5,"kurultay":0.5,"cb_on":0.5}')
saat("2026-10-30 00:12")
v = {r_["kod"]: r_ for r_ in qj("select jsonb_agg(oyun.vaat_json(v)) from oyun.vaatler v where donem='2026-09'")}
assert v["asgari"]["tutuldu"] and v["ikramiye"]["tutuldu"] and v["belediye_payi"]["tutuldu"] and v["aday_ucret"]["gun_tutuldu"] >= 1, v
assert not v["baraj"]["tutuldu"] and not v["rayli"]["tutuldu"]
kart = rpc(veli, "oyuncu_kart", "Reis")["karneler"]
assert kart and kart[0]["beyanname"] and kart[0]["tutulan"] == 2 and kart[0]["toplam"] == 2, kart
assert rpc(veli, "parti_kasa", 1)["iktidar"]["tutulan"] == 2
assert rpc(veli, "oyuncu_kart", "Vekil0")["karneler"][0]["tutulan"] == 1
assert rpc(veli, "il_detay", 34)["bel_vaatler"][0]["tutuldu"]
ok("Vaat takibi: seçilince etkinleşir; sürekli vaatler gün gün (kent vergisi 1/1), tek seferlikler yapılınca (ikramiye, bütçede kabul oyu) tutulur; karne oyuncu kartında, partide, il sayfasında")

q(f"update oyun.makamlar set bit = '2026-10-30 12:00+03' where id = {bel34}")
saat("2026-10-31 00:13")
assert k(f"select string_agg(distinct durum, ',') from oyun.vaatler where user_id='{bas34}'") == "bitti"
ok("Görev bitince vaatler 'bitti' olarak kapanıyor, karne kalıcı")

# ---------------- KUMBARA BİLDİRİMİ ----------------
q("update oyun.ayarlar set push_aktif = true")
q(f"insert into oyun.cihazlar(token, user_id, platform) values ('{'k' * 40}', '{ayse}', 'ios')")
rpc(ayse, "topla")
q("delete from oyun.push_kuyruk")
saat("2026-10-31 08:30")
assert k("select count(*) from oyun.push_kuyruk where baslik like 'Kumbaran doldu%'") == "1"
saat("2026-10-31 09:30")
assert k("select count(*) from oyun.push_kuyruk where baslik like 'Kumbaran doldu%'") == "1"   # bir kez
q("update oyun.ayarlar set push_aktif = false")
ok("Kumbara dolunca telefona bir kez 'Kumbaran doldu' bildirimi gidiyor")

# ---------------- GÜVENLİK ----------------
for sql in ["set role anon; select public.hayat();", "set role anon; select public.topla();",
            "set role authenticated; select * from oyun.cuzdan;", "set role authenticated; select oyun.para_islem(gen_random_uuid(), 1000, 'x', 'x', now());",
            "set role authenticated; select public.odeme_isle('{}'::jsonb);"]:
    try: q(sql); raise AssertionError(sql)
    except SqlHata as e: assert "permission denied" in str(e), e
ok("Güvenlik: cüzdan, para ve satın alma fonksiyonları dışarıya kapalı")

print(f"\nTÜM VATANDAŞ EKONOMİSİ KONTROLLERİ GEÇTİ ({len(TAMAM)})")
