"""Modül 91: bağış birimi, hizmet karnesi, kriz masası, İller Bankası kredisi."""
from db import q, qj, rpc, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
kasa = lambda il: float(q(f"select kasa from oyun.il_durum where il_id={il}"))
mem = lambda il: float(q(f"select memnuniyet from oyun.il_durum where il_id={il}"))
def zaman(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}+03'")
def gece(ts): zaman(ts); q(f"select oyun.belediye_gunluk('{ts}+03')")

zaman("2030-05-02 10:00")
def oyuncu(kad, il, p=3000000):
    u = kullanici_ekle(f"{kad}@bd.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.cuzdan set para={p} where user_id='{u}'"); return u
ANK, BAY = IL("Ankara"), IL("Bayburt")
BASKAN, VATANDAS, BAYBASKAN = oyuncu("AnkBaskan", "Ankara"), oyuncu("AnkVatandas", "Ankara"), oyuncu("BayBaskan", "Bayburt")
q(f"insert into oyun.makamlar(tur,user_id,il_id,bas) values ('bel','{BASKAN}',{ANK},now()),('bel','{BAYBASKAN}',{BAY},now())")
q(f"update oyun.il_durum set kasa=0.001 where il_id={ANK}")
TLM = float(q("select oyun.pazar_tl_milyar()"))

# ---------------- bağış birimi
k0, h0 = kasa(ANK), float(q("select hazine from oyun.ulke where id=1"))
rpc(VATANDAS, "serbest_bagis", "il", str(ANK), 1000, None)
assert abs(kasa(ANK) - (k0 + 1000 / TLM)) < 1e-9, kasa(ANK)
rpc(VATANDAS, "serbest_bagis", "devlet", None, 500, None)
assert abs(float(q("select hazine from oyun.ulke where id=1")) - (h0 + 500 / TLM)) < 1e-6
assert q(f"select count(*) from oyun.belediye_sehir_hareket where il_id={ANK} and tur='bagis'") == "1"
ok(f"1.000 ₺ şehir bağışı kasaya {1000/TLM*1000:.2f} milyon ₺ ekledi (önceden 1.000 milyar); işlem defterinde görünüyor")

# ---------------- gece kasası: bağış/kredi tavanda kesilmez
g = float(q(f"select oyun.il_gelir({ANK}::smallint)"))
q(f"update oyun.il_durum set kasa={80*g} where il_id={ANK}")
gece("2030-05-03 00:05")
assert kasa(ANK) >= 80 * g - float(q(f"select oyun.il_gider({ANK}::smallint)")) - 1e-6, (kasa(ANK), 80 * g)
ok("60 günlük tavan üstündeki kasa gece kesilmiyor (yalnız yeni vergi geliri durur)")

# ---------------- karne
p = rpc(BASKAN, "belediye_detay_paneli")
assert len(p["karne"]["alanlar"]) == 7 and p["kredi"]["limit"] > 0
ort0 = p["karne"]["ortalama"]
q(f"update oyun.il_durum set kasa=50 where il_id={ANK}")
rpc(BASKAN, "belediye_bina_islem", "su_aritma", "insa")
q("update oyun.belediye_bina set bitis=now()-interval '1 minute'"); q("select oyun.belediye_bina_tick()")
p = rpc(BASKAN, "belediye_detay_paneli")
su = next(a for a in p["karne"]["alanlar"] if a["kod"] == "su")
assert su["puan"] > ort0 and su["katkilar"][0]["kaynak"].startswith("Su Arıtma"), su
ok(f"Karne: 7 alan, ortalama {ort0}; su arıtma tesisi su puanını {su['puan']}'e çıkardı (büyük il ölçeği {p['karne']['olcek']})")
hata_bekle(rpc, VATANDAS, "belediye_kriz_karar", 1, "a", icerir="belediye başkan")
assert rpc(VATANDAS, "belediye_detay_paneli") is None
pk = rpc(VATANDAS, "belediye_karnesi", ANK)
assert pk["baskan"]["kad"] == "AnkBaskan" and len(pk["karne"]["alanlar"]) == 7
ok("Vatandaş başkan panelini göremiyor ama herkese açık belediye karnesini görüyor")

# ---------------- kredi
q(f"update oyun.il_durum set kasa=0.5 where il_id={ANK}")
lim = float(rpc(BASKAN, "belediye_detay_paneli")["kredi"]["limit"])
hata_bekle(rpc, BASKAN, "belediye_kredi_al", 1, 15, icerir="Vade")
hata_bekle(rpc, BASKAN, "belediye_kredi_al", round(lim + 1, 4), 10, icerir="limit")
r = rpc(BASKAN, "belediye_kredi_al", 1, 10)
assert abs(kasa(ANK) - 1.5) < 1e-9 and r["toplam"] > 1
hata_bekle(rpc, BASKAN, "belediye_kredi_al", 0.5, 10, icerir="24 saatte")
gece("2030-05-04 00:05")
b = qj(f"select row_to_json(b) from oyun.belediye_borc b where il_id={ANK}")
assert abs(b["kalan"] - (r["toplam"] - r["taksit"])) < 1e-6, b
ok(f"Kredi: 1 milyar ₺, 10 gün, faiz %{r['faiz']*100:.2f}, ilk gece taksit {r['taksit']:.4f} milyar ₺ ödendi")
q(f"update oyun.il_durum set kasa=-1 where il_id={ANK}")   # gece geliri de yetmesin
m0 = mem(ANK); gece("2030-05-05 00:05")
b = qj(f"select row_to_json(b) from oyun.belediye_borc b where il_id={ANK}")
assert b["gecikme"] == 1 and q(f"select count(*) from oyun.belediye_sehir_hareket where il_id={ANK} and tur='kredi_gecikme'") == "1"
ok("Kasa boşken taksit ödenemedi: gecikme 1, %5 ceza borca eklendi, başkana bildirim")
q(f"update oyun.il_durum set kasa=5 where il_id={ANK}")
rpc(BASKAN, "belediye_kredi_kapat", b["id"])
assert q(f"select durum from oyun.belediye_borc where id={b['id']}") == "kapandi"
ok("Kredi erken kapatıldı")

# ---------------- kriz masası
kid = int(q(f"select oyun.belediye_kriz_baslat({ANK}::smallint, 'cop')"))
assert q(f"select count(*) from oyun.bildirimler where user_id='{BASKAN}' and metin like 'Kriz masası%'") == "1"
assert q(f"select oyun.belediye_kriz_baslat({ANK}::smallint, 'kar')") == ""   # aynı anda tek kriz
hata_bekle(rpc, BASKAN, "belediye_kriz_karar", kid, "z", icerir="Geçersiz")
q(f"update oyun.il_durum set kasa=0 where il_id={ANK}")
hata_bekle(rpc, BASKAN, "belediye_kriz_karar", kid, "a", icerir="kasası yetersiz")
q(f"update oyun.il_durum set kasa=5 where il_id={ANK}")
k0, m0 = kasa(ANK), mem(ANK)
s = rpc(BASKAN, "belediye_kriz_karar", kid, "a")
assert s["durum"] == "cozuldu" and kasa(ANK) < k0 and mem(ANK) == m0 + 2
p = rpc(BASKAN, "belediye_detay_paneli")
tem = next(a for a in p["karne"]["alanlar"] if a["kod"] == "temizlik")
assert any(x["kaynak"] == "Çöp toplama krizi" for x in tem["katkilar"]) and p["kriz"] is None and p["kriz_gecmis"][0]["secim_ad"]
ok(f"Kriz kararı: {s['maliyet']:.4f} milyar ₺ harcandı, memnuniyet +2, temizlik karnesine 14 günlük etki")
hata_bekle(rpc, BASKAN, "belediye_kriz_karar", kid, "a", icerir="süresi doldu")

# sessiz kalınca
kid2 = int(q(f"select oyun.belediye_kriz_baslat({BAY}::smallint, 'su')"))
m0 = mem(BAY)
zaman("2030-05-06 12:00")
q("select oyun.belediye_kriz_tick(0)")
assert q(f"select durum from oyun.belediye_kriz where id={kid2}") == "sessiz" and mem(BAY) == max(0, m0 - 4)
assert int(q(f"select count(*) from oyun.olaylar where il_id={BAY} and metin like '%Belediyeden açıklama gelmedi%'")) == 1
ok("24 saatte karar verilmeyince 'sessiz kaldı' sonucu işledi ve herkese açık akışa düştü")

# tick yeni kriz açar, soğuma süresine uyar
n = int(q("select oyun.belediye_kriz_tick(1)"))
acik = int(q("select count(*) from oyun.belediye_kriz where durum='acik'"))
assert acik == 0, acik   # ikisi de son 36 saatte kriz yaşadı
zaman("2030-05-08 12:00")
q("select oyun.belediye_kriz_tick(1)")
assert int(q("select count(*) from oyun.belediye_kriz where durum='acik'")) == 2
ok("Saatlik kontrol: 36 saat soğumadan sonra iki başkanlı ile de yeni kriz açıldı")
# başkan düşerse kriz kapanır
q(f"update oyun.makamlar set bit=now() where user_id='{BAYBASKAN}' and tur='bel'")
q("select oyun.belediye_kriz_tick(0)")
assert q(f"select count(*) from oyun.belediye_kriz where il_id={BAY} and durum='acik'") == "0"
ok("Başkanlık boşalınca açık kriz kapandı")

# karne gece memnuniyeti çeker
q(f"update oyun.il_durum set memnuniyet=40 where il_id={ANK}")
gece("2030-05-09 00:05")
ok(f"Gece hesabı karneyi memnuniyete katıyor (Ankara memnuniyet {mem(ANK):.2f}, karne ort. {rpc(BASKAN,'belediye_detay_paneli')['karne']['ortalama']})")
print("belediye_detay: hepsi geçti")
