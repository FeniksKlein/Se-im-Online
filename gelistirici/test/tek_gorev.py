"""Tek görev kuralı: kimse aynı anda iki görev taşıyamaz.
İstisnalar: milletvekili + genel başkan yardımcısı; genel başkan + cumhurbaşkanı.
Çalıştır: ../kur_yerel.sh && python3 tek_gorev.py"""
from db import q, rpc, saat, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, baslangic_para=10000000;")
saat("2026-10-02 12:00")

def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    return u
def roller(u): return q(f"select array_to_string(oyun.roller('{u}'), ',') ")
def makam(tur, u, il=None, parti=1, bakanlik=None):
    q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bakanlik,bas) values ('{tur}','{u}',{il or 'null'},{parti},{('$$'+bakanlik+'$$') if bakanlik else 'null'},'2026-10-02 12:00+03')")
def secim_kazan(tur, kazananlar, donem, parti=1):
    sid = q(f"""insert into oyun.secimler(tur,donem,oy_bas,oy_bit,sonuc_at,goreve_bas,durum,sonuc)
                values ('{tur}','{donem}','2026-10-02 08:00+03','2026-10-02 09:00+03','2026-10-02 10:00+03','2026-10-02 12:30+03','sonuclandi','{{"ikinci_tur":false}}') returning id""").split("\n")[0]
    for u, il in kazananlar: q(f"insert into oyun.kazananlar values ({sid}, '{u}', {il or 'null'}, {parti})")
    q(f"select oyun.goreve_baslat({sid})")

gb  = oyuncu("Genel", 35, 1); q(f"update oyun.partiler set gb='{gb}' where id=1")
vek = oyuncu("Vekil", 35, 1); makam("mv", vek, 35)
bak = oyuncu("Bakan", 35, 1); makam("bakan", bak, bakanlik="adalet")
bel = oyuncu("Baskan", 35, 1); makam("bel", bel, 35)
yrd = oyuncu("Yardimci", 35, 1)
cb  = oyuncu("Cumhur", 6, 1); makam("cb", cb)

# ---- genel başkan yardımcısı yalnızca vekil olabilir
rpc(gb, "gby_ata", 1, "Vekil")
assert roller(vek) in ("mv,gby", "gby,mv")
ok("Milletvekili aynı anda genel başkan yardımcısı olabilir")
hata_bekle(rpc, gb, "gby_ata", 2, "Bakan", icerir="milletvekili olabilir")
hata_bekle(rpc, gb, "gby_ata", 2, "Baskan", icerir="milletvekili olabilir")
hata_bekle(rpc, gb, "gby_ata", 2, "Cumhur", icerir="milletvekili olabilir")
rpc(gb, "gby_ata", 2, "Yardimci")
rpc(gb, "gby_ata", 3, "Yardimci")        # aynı kişinin sırası değişebilir
assert q("select count(*) from oyun.parti_gby where parti_id=1") == "2"
ok("Bakan, belediye başkanı ve cumhurbaşkanı genel başkan yardımcısı atanamaz; yardımcının sırası değişebilir")

# ---- bakanı yalnızca cumhurbaşkanı atar; başka görevi olan atanamaz
hata_bekle(rpc, cb, "bakan_ata", "saglik", "Vekil", icerir="önce")
hata_bekle(rpc, cb, "bakan_ata", "saglik", "Baskan", icerir="önce")
hata_bekle(rpc, cb, "bakan_ata", "saglik", "Bakan", icerir="önce")
hata_bekle(rpc, cb, "bakan_ata", "saglik", "Genel", icerir="önce")
hata_bekle(rpc, cb, "bakan_ata", "saglik", "Yardimci", icerir="önce")      # genel başkan yardımcısı
hata_bekle(rpc, gb, "bakan_ata", "saglik", "Yardimci", icerir="yalnızca cumhurbaşkanında")
rpc(bel, "istifa", "bel")
assert q(f"select count(*) from oyun.makamlar where user_id='{bel}' and bit is null") == "0"
rpc(cb, "bakan_ata", "saglik", "Baskan")
assert roller(bel) == "bakan"
ok("Vekil, belediye başkanı, bakan, genel başkan ve yardımcı bakan atanamaz; belediye başkanı istifa edince atanabilir")
hata_bekle(rpc, vek, "istifa", "bel", icerir="değilsin")
rpc(vek, "istifa", "mv")
assert roller(vek) == "gby"
ok("Milletvekili istifa edebilir")

# ---- genel başkan vekil/belediye adayı olamaz
saat("2026-10-26 10:00")
hata_bekle(rpc, gb, "aday_ol", "mv_on", icerir="Genel başkan")
ok("Genel başkan milletvekili adayı olamaz")

# ---- seçim kazanınca eski görev düşer
v2 = oyuncu("Vekil2", 35, 1); makam("mv", v2, 35)
secim_kazan("bel", [(v2, 35)], "2098-01")
assert roller(v2) == "bel"
ok("Belediye seçimini kazanan vekilin vekilliği düşer")
y2 = oyuncu("Yrd2", 35, 1); rpc(gb, "gby_ata", 4, "Yrd2")
secim_kazan("bel", [(y2, 35)], "2098-02")
assert roller(y2) == "bel"
ok("Belediye seçimini kazanan genel başkan yardımcısı yardımcılıktan düşer")
v3 = oyuncu("Vekil3", 35, 1); makam("mv", v3, 35); rpc(gb, "gby_ata", 5, "Vekil3")
secim_kazan("mv", [(v3, 35)], "2098-03")
assert roller(v3) in ("mv,gby", "gby,mv")
ok("Vekil seçilen genel başkan yardımcısı, yardımcılığı korur")

# kurultayı kazanan: vekillik/bakanlık düşer, yardımcılık düşer
v4 = oyuncu("Vekil4", 35, 1); makam("mv", v4, 35)
secim_kazan("kurultay", [(v4, None)], "2098-04")
assert q("select gb from oyun.partiler where id=1") == v4 and roller(v4) == "gb"
ok("Kurultayı kazanan vekil genel başkan olur, vekilliği düşer")

# genel başkan cumhurbaşkanı seçilirse ikisini birden taşır
secim_kazan("cb", [(v4, None)], "2098-05")
assert sorted(roller(v4).split(",")) == ["cb", "gb"]
ok("Genel başkan cumhurbaşkanı seçilince ikisi birlikte sürer")
# cumhurbaşkanı kurultayı kazanırsa cumhurbaşkanlığı düşmez
c2 = oyuncu("Cumhur2", 6, 2); makam("cb", c2, parti=2)
secim_kazan("kurultay", [(c2, None)], "2098-06", parti=2)
assert sorted(roller(c2).split(",")) == ["cb", "gb"]
ok("Cumhurbaşkanı kendi partisinin genel başkanı da olabilir")

# genel başkan vekil seçilirse (olmaması gerekir) görevi üstlenemez
g2 = oyuncu("Genel2", 35, 3); q(f"update oyun.partiler set gb='{g2}' where id=3")
secim_kazan("mv", [(g2, 35)], "2098-07", parti=3)
assert q(f"select count(*) from oyun.makamlar where user_id='{g2}' and tur='mv' and bit is null") == "0"
ok("Genel başkan sandalyeyi üstlenemez (güvence)")
print("\nTEK GÖREV KONTROLLERİ GEÇTİ")
