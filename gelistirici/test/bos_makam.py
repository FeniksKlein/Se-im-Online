"""Boş makam kuralı: bakanlık vekâleti, seçimde kazanan çıkmazsa görevdeki kalır, genel başkansız parti kalmaz, pano.
Çalıştır: ../kur_yerel.sh && python3 bos_makam.py"""
import json
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, baslangic_para=10000000;")
saat("2026-10-02 12:00")

def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    return u
def makam(tur, u, il=None, parti=1, bakanlik=None):
    return q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bakanlik,bas) values ('{tur}','{u}',{il or 'null'},{parti},{('$$'+bakanlik+'$$') if bakanlik else 'null'},'2026-10-02 12:00+03') returning id").split("\n")[0]
_n = [0]
def secim(tur, kazananlar, parti=1):
    _n[0] += 1; donem = f"2026-{_n[0]:02d}x"
    sid = q(f"""insert into oyun.secimler(tur,donem,oy_bas,oy_bit,sonuc_at,goreve_bas,durum,sonuc)
                values ('{tur}','{donem}','2026-10-02 08:00+03','2026-10-02 09:00+03','2026-10-02 10:00+03','2026-10-02 12:30+03','sonuclandi','{{"ikinci_tur":false}}') returning id""").split("\n")[0]
    for u, il in kazananlar: q(f"insert into oyun.kazananlar values ({sid}, '{u}', {il or 'null'}, {parti})")
    q(f"select oyun.goreve_baslat({sid})")
def aktif(tur, il=None):
    return q(f"select coalesce(string_agg(p.kad, ',' order by p.kad), '') from oyun.makamlar m join oyun.profiller p on p.id=m.user_id where m.tur='{tur}' and m.bit is null" + (f" and m.il_id={il}" if il else ""))

cb  = oyuncu("Cumhur", 6, 1); makam("cb", cb)
bak = oyuncu("Bakan", 35, 1)
sade = oyuncu("Sade", 35, 1)

# ---------------- 1) BAKANLIK VEKÂLETİ ----------------
vp = rpc(cb, "vekalet_paneli")
assert len(vp) == 12 and vp[0]["icraatlar"], len(vp)
assert rpc(sade, "vekalet_paneli") == []
saat("2026-10-02 12:05")
rpc(cb, "icraat_yap", "adl_harc")
assert q("select count(*) from oyun.icraat_kayit where kod='adl_harc'") == "1"
g = q("select string_agg(metin, ' | ') from oyun.gazete where baslik like 'Harç muafiyeti%'")
assert "vekâleten Cumhurbaşkanı Cumhur" in g, g
hata_bekle(rpc, sade, "icraat_yap", "adl_ifade", icerir="yalnızca ilgili bakan")
ok("Bakanı olmayan bakanlığın icraatını cumhurbaşkanı vekâleten yapıyor (Resmî Gazete'de 'vekâleten' yazıyor); başkası yapamıyor")

makam("bakan", bak, il=None, bakanlik="adalet")
assert len(rpc(cb, "vekalet_paneli")) == 11 and "adalet" not in [x["kod"] for x in rpc(cb, "vekalet_paneli")]
saat("2026-10-09 12:05")
hata_bekle(rpc, cb, "icraat_yap", "adl_ifade", icerir="yalnızca ilgili bakan")     # bakan atanınca vekâlet biter
rpc(bak, "icraat_yap", "adl_ifade")
ok("Bakan atanınca vekâlet sona eriyor; icraatı bakan yapıyor")

# ---------------- 2) KAZANAN ÇIKMAZSA GÖREVDEKİ KALIR ----------------
bel_a = oyuncu("BelA", 34, 1); makam("bel", bel_a, 34)
bel_b = oyuncu("BelB", 6, 1);  makam("bel", bel_b, 6)
yeni  = oyuncu("YeniB", 6, 1)
secim("bel", [(yeni, 6)])                       # yalnız Ankara'da aday çıktı
assert aktif("bel", 34) == "BelA", "İstanbul'da aday çıkmadı: görevdeki kalmalı"
assert aktif("bel", 6) == "YeniB"
assert q(f"select bitis_neden from oyun.makamlar where user_id='{bel_b}'") == "donem_bitti"
secim("bel", [])                                 # hiç kazanan yok
assert aktif("bel", 34) == "BelA" and aktif("bel", 6) == "YeniB"
ok("Belediye seçiminde aday çıkmayan ilde görevdeki başkan devam ediyor; aday çıkan ilde görev devrediliyor")

assert aktif("cb") == "Cumhur" and q("select count(*) from oyun.makamlar where tur='bakan' and bit is null") == "1"
secim("cb", [])
assert aktif("cb") == "Cumhur" and q("select count(*) from oyun.makamlar where tur='bakan' and bit is null") == "1"
assert q(f"select count(*) from oyun.bildirimler where user_id='{cb}' and metin like '%görevine devam ediyorsun%'") == "1"
yeni_cb = oyuncu("YeniCB", 16, 2)
secim("cb", [(yeni_cb, None)], parti=2)
assert aktif("cb") == "YeniCB" and q("select count(*) from oyun.makamlar where tur='bakan' and bit is null") == "0"
ok("Cumhurbaşkanlığı seçiminde kimse çıkmazsa cumhurbaşkanı ve kabinesi yerinde kalıyor; yeni cumhurbaşkanı gelince kabine yenileniyor")

# milletvekilleri liste usulüyle topluca yenilenir (yedek listeleri doldurur)
mv1 = oyuncu("Vekil1", 35, 1); makam("mv", mv1, 35)
secim("mv", [])
assert aktif("mv") == "", "Meclis topluca yenilenir"
ok("Meclis (liste usulü) eskisi gibi topluca yenileniyor")

# ---------------- 3) GENEL BAŞKANSIZ PARTİ KALMAZ ----------------
q("update oyun.partiler set gb = null where id = 3")
h1 = oyuncu("Halef1", 35, 3); h2 = oyuncu("Halef2", 35, 3); h3 = oyuncu("Halef3", 35, 3)
for u, k_ in [(h1, 50), (h2, 99), (h3, 10)]:
    q(f"select oyun.cuzdanim('{u}'); update oyun.cuzdan set kidem = {k_} where user_id = '{u}'")
makam("mv", h2, 35, parti=3)                      # en kıdemli ama milletvekili: görevi düşmesin diye seçilmez
q(f"insert into oyun.parti_gby(parti_id,user_id,sira) values (3,'{h1}',1)")
# tick genel başkanı atamaz (kurultaysız): yalnız gönüllü üstlenme ve kurultay sonrası halef
saat("2026-10-02 13:00")
assert q("select gb is null from oyun.partiler where id=3") == "t"
secim("kurultay", [])                               # kimse aday olmadı
assert q("select gb from oyun.partiler where id=3") == h1, q("select gb from oyun.partiler where id=3")
assert q("select count(*) from oyun.parti_gby where user_id='%s'" % h1) == "0"
assert q(f"select count(*) from oyun.makamlar where user_id='{h2}' and bit is null") == "1"
assert q(f"select count(*) from oyun.bildirimler where user_id='{h1}' and metin like '%genel başkan oldun%'") == "1"
q("select oyun.gb_halef(oyun.simdi())")
assert q("select gb from oyun.partiler where id=3") == h1
ok("Kurultay adaysız kaldı: en kıdemli uygun üye genel başkan oldu (milletvekili atlandı, yardımcılıktan çıktı), bildirim gitti, ikinci kez değişmedi")

q("update oyun.partiler set gb = null where id = 4")
secim("kurultay", [])
assert q("select gb is null from oyun.partiler where id=4") == "t"
ok("Üyesi olmayan parti boş kalıyor (zorla kimse atanmıyor)")

q("update oyun.partiler set gb = null where id = 3")
u1 = oyuncu("Aday1", 35, 3)
try:
    rpc(sade, "genel_baskanlik_uslen"); raise AssertionError("girissiz")
except AssertionError: raise
except Exception: pass
rpc(u1, "genel_baskanlik_uslen")
assert q("select gb from oyun.partiler where id=3") == u1
try:
    rpc(u1, "genel_baskanlik_uslen"); raise AssertionError("gb dolu")
except AssertionError: raise
except Exception: pass
ok("Gönüllü üstlenme çalışıyor; dolu partide reddediliyor")

# ---------------- 4) BOŞ MAKAMLAR PANOSU ----------------
b = rpc(sade, "bos_makamlar")
assert b["cb"] == "YeniCB" and len(b["bakanliklar"]) == 12 and len(b["belediyeler"]) == 81 - 2
assert b["vekil"] == {"dolu": 1, "bos": 599}, b["vekil"]
assert all(p["id"] != 3 for p in b["partiler"])      # parti 3 artık genel başkanlı
assert {x["tur"] for x in b["sonraki"]} <= {"bel", "mv", "cb", "kurultay"}
ok("Boş Makamlar panosu: boş bakanlıklar, belediyeler, Meclis sandalyeleri, genel başkansız partiler ve sonraki seçimler")

# ---------------- GÜVENLİK ----------------
for fn in ["bos_makamlar()", "vekalet_paneli()"]:
    try:
        q(f"set role anon; select public.{fn};"); raise AssertionError(fn)
    except Exception as e_:
        assert "permission denied" in str(e_) or "Giriş" in str(e_) or "yetkin" in str(e_), (fn, e_)
ok("Güvenlik: yeni fonksiyonlar girişsiz kapalı")
print("\nTÜM BOŞ MAKAM KONTROLLERİ GEÇTİ")
