"""Ekonomi 3: parti kuruluş ücreti, il teşkilatları, oyuncudan oyuncuya para gönderme, banka (mevduat, vadeli, kredi,
gecikme ve yasal takip), servet vergisine banka mevduatının girmesi ve moderatör ekibi.
Çalıştır: ../kur_yerel.sh && python3 ekonomi3.py"""
import json, math, os, subprocess
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
q("""update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, baslangic_para=10000,
     parti_kur_ucret=25000, teskilat_ucret=2000, teskilat_zorunlu=true, parti_kurucu_sayi=2, parti_kurucu_kidem=0, havale_sinir=1,
     banka_acik=true, banka_reel_faiz=5, banka_tavan=2000000""")
saat("2026-10-02 12:00")

def oyuncu(kad, il, parti=None, para=None):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    if para is not None: setpara(u, para)
    return u
def setpara(u, x): q(f"select oyun.cuzdanim('{u}'); update oyun.cuzdan set para={x} where user_id='{u}'")
def para(u): return int(float(q(f"select para from oyun.cuzdan where user_id='{u}'")))
def kasa(pid): return int(float(q(f"select kasa from oyun.partiler where id={pid}")))
def bildirim(u): return q(f"select metin from oyun.bildirimler where user_id='{u}' order by id desc limit 1")
def hareket(u, tur): return q(f"select tutar from oyun.hesap_hareket where user_id='{u}' and tur='{tur}' order by id desc limit 1")
def kredi(u): return qj(f"select row_to_json(k) from oyun.krediler k where user_id='{u}' order by id desc limit 1")
def notu(u): return int(q(f"select kredi_notu from oyun.banka_musteri where user_id='{u}'"))
def oran(k): return float(qj("select oyun.banka_oranlar()")[k])

# =====================================================================
# 1) PARTİ KURULUŞ ÜCRETİ
# =====================================================================
fakir = oyuncu("Fakir", 35, para=10000)
hata_bekle(rpc, fakir, "parti_kur", "Yoksul Halk Partisi", "YHP", "#225588", "a_gul", icerir="25.000 ₺")
assert q("select count(*) from oyun.partiler where kisa='YHP'") == "0" and para(fakir) == 10000
v = rpc(fakir, "vatandaslik")
assert v["parti_kurma"]["ucret"] == 25000 and v["parti_kurma"]["para"] == 10000
ok("Parasi yetmeyen parti kuramaz; ücret seçmen kartında görünür (25.000 ₺)")

kurucu1 = oyuncu("Kurucu", 35, para=100000)
rpc(kurucu1, "parti_kur", "Deneme Yolu Partisi", "DYO", "#225588", "a_gul")
p1 = int(q("select id from oyun.partiler where kisa='DYO'"))
assert para(kurucu1) == 75000 and int(hareket(kurucu1, "parti_kur")) == -25000
assert q(f"select il_id||'/'||genel_merkez from oyun.parti_teskilat where parti_id={p1}") == "35/true"
assert int(float(q(f"select kurulus_ucret from oyun.partiler where id={p1}"))) == 25000
ok("Parti kurulunca 25.000 ₺ cüzdandan düşer; genel merkez kurucunun ilinde ilk il teşkilatı olarak açılır")

kurucu2 = oyuncu("Kurucu2", 35, para=100000)
rpc(kurucu2, "parti_kur", "Yarin Umut Partisi", "YUP", "#aa3355", "a_gul")
p2 = int(q("select id from oyun.partiler where kisa='YUP'"))
uye_ank = oyuncu("UyeAnkara", 6, p2, para=50000)
uye_bay = oyuncu("UyeBayburt", 69, p2, para=50000)
saat("2026-10-02 12:01")
assert q(f"select kurulus_bit is null from oyun.partiler where id={p2}") == "t"
assert q("select count(*) from oyun.parti_teskilat where parti_id=1") == "81"
ok("Oyunla gelen partiler 81 ilde teşkilatlı; yeni parti kurucu sayısını tamamlayınca kuruluşu biter")

# =====================================================================
# 2) İL TEŞKİLATLARI
# =====================================================================
hata_bekle(rpc, uye_ank, "teskilat_ac", 6, icerir="yalnızca genel başkan")
hata_bekle(rpc, kurucu2, "teskilat_ac", 6, icerir="6.000 ₺ olmalı")
rpc(uye_ank, "bagis_yap", 7000)
t = rpc(kurucu2, "teskilat_ac", 6)
assert kasa(p2) == 1000 and t["sayi"] == 2 and t["yetkili"]
assert "il teşkilatı açıldı" in q(f"select aciklama from oyun.parti_hareket where parti_id={p2} and tur='teskilat'")
assert "Ankara" in bildirim(uye_ank) and "teşkilatlı" in bildirim(uye_ank)
hata_bekle(rpc, kurucu2, "teskilat_ac", 6, icerir="zaten teşkilatı var")
ok("İl teşkilatını GB açar; bedeli il büyüklüğüne göre (Ankara 6.000 ₺) parti kasasından düşer, o ildeki üyelere haber gider")

q(f"insert into oyun.parti_gby(parti_id, user_id, sira) values ({p2}, '{uye_bay}', 1)")
rpc(uye_ank, "bagis_yap", 2000)
t = rpc(uye_bay, "teskilat_ac", 69)
assert kasa(p2) == 1000 and t["sayi"] == 3
ok("Genel başkan yardımcısı da teşkilat açabilir; küçük ilde (Bayburt) bedel 2.000 ₺")

# Belediye aday adaylığında kullanılacak üyeler (başvurudan önce üye olmalı)
uye_izm = oyuncu("UyeIzmir", 35, p2)
uye_ist = oyuncu("UyeIstanbul", 34, p2)

# Bir kerelik geçiş: güncellemeden önce kurulmuş partiler, üyelerinin olduğu illerde teşkilatlı sayılır
eski = int(q("insert into oyun.partiler(ad, kisa, renk, amblem, kurulus) values ('Eski Donem Partisi','EDP','#123456','a_gul','2026-09-01') returning id").split("\n")[0])
eu = oyuncu("EskiUye", 16, eski)
q("update oyun.ayarlar set teskilat_gecis=false")
SQL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../sql/15_ekonomi3.sql")
for _ in range(2):
    subprocess.run(["psql", "-h", "/tmp", "-U", "postgres", "-d", "oyun_test", "-q", "-v", "ON_ERROR_STOP=1", "-f", SQL], check=True, capture_output=True)
assert q(f"select string_agg(il_id::text, ',') from oyun.parti_teskilat where parti_id={eski}") == "16"
assert q("select teskilat_gecis from oyun.ayarlar") == "t"
assert q(f"select count(*) from oyun.parti_teskilat where parti_id={p2}") == "3"
ok("Geçiş: eski partiler üyelerinin ilinde teşkilatlı sayılır; dosya iki kez çalışınca hiçbir şey değişmez")

# =====================================================================
# 3) PARA GÖNDERME
# =====================================================================
ali = oyuncu("Ali", 34, para=100000); veli = oyuncu("Veli", 6, para=1000)
r = rpc(ali, "para_gonder", "Veli", 5000, "Kampanya için")
assert para(ali) == 95000 and para(veli) == 6000 and r["bugun"] == 5000 and r["tavan"] == 28075
assert int(hareket(veli, "havale")) == 5000 and "Kampanya için" in q(f"select aciklama from oyun.hesap_hareket where user_id='{veli}' and tur='havale'")
assert "Ali sana 5.000 ₺ gönderdi" in bildirim(veli)
hata_bekle(rpc, ali, "para_gonder", "Ali", 500, icerir="Kendine")
hata_bekle(rpc, ali, "para_gonder", "Veli", 50, icerir="En az 100")
hata_bekle(rpc, ali, "para_gonder", "Veli", 24000, icerir="Günlük gönderim sınırı 28.075")
hata_bekle(rpc, ali, "para_gonder", "Veli", 500, "gerizekalı", icerir="uygunsuz")
q("update oyun.ayarlar set oy_min_kidem=10"); hata_bekle(rpc, veli, "para_gonder", "Ali", 500, icerir="seçmen kartın"); q("update oyun.ayarlar set oy_min_kidem=0")
rpc(veli, "engelle", "Ali"); hata_bekle(rpc, ali, "para_gonder", "Veli", 500, icerir="engellediği"); rpc(veli, "engel_kaldir", "Ali")
ok("Para gönderme: alıcıya geçer ve bildirim gider; kendine, 100 ₺ altı, günlük sınır üstü, küfürlü not, seçmen kartı eksik ve engelleyen oyuncuya gönderilemez")

q("update oyun.ayarlar set coklu_kontrol=true")
c1 = oyuncu("CihazBir", 34, para=10000)
q(f"select set_config('request.jwt.claim.sub', '{c1}', false); select public.oturum_kaydet('ortak-cihaz', 'iz1')")
c2 = kullanici_ekle("cihaziki@t.com")
q(f"select set_config('request.jwt.claim.sub', '{c2}', false); select public.oturum_kaydet('ortak-cihaz', 'iz2')")
q("update oyun.ayarlar set test_simdi='2026-10-02 12:05+03'"); rpc(c2, "profil_olustur", "CihazIki", 34)
q(f"insert into oyun.hesap_onay(user_id, zaman) values ('{c2}', now())")      # onaylı olsa bile aynı cihaz kuralı geçerli
hata_bekle(rpc, c1, "para_gonder", "CihazIki", 1000, icerir="Aynı cihazda")
q("update oyun.ayarlar set coklu_kontrol=false")
ok("Aynı cihazda açılmış hesaplar arasında para gönderilemez (çoklu hesapla para toplama engeli)")

# =====================================================================
# 4) BANKA: vadesiz, vadeli, tavan, servet vergisi
# =====================================================================
o = qj("select oyun.banka_oranlar()")
assert o["politika"] == 40 and o["vadesiz"] == 1.67 and o["vadeli7"] == 2.67 and o["vadeli30"] == 3.17 and o["kredi"] == 5.33
ok("Faizler enflasyona bağlı: politika %40 (yıllık) → vadesiz %1,67, vadeli 7 gün %2,67, 30 gün %3,17, kredi %5,33 (aylık)")

zengin = oyuncu("Zengin", 34, para=500000)
b = rpc(zengin, "banka_yatir", 100000)
assert para(zengin) == 400000 and b["vadesiz"]["bakiye"] == 100000
hata_bekle(rpc, zengin, "banka_yatir", 50, icerir="En az 100")
q("update oyun.ayarlar set banka_tavan=150000"); hata_bekle(rpc, zengin, "banka_yatir", 60000, icerir="en fazla 150.000"); q("update oyun.ayarlar set banka_tavan=2000000")
b = rpc(zengin, "vadeli_ac", 30000, 7)
assert para(zengin) == 370000 and len([x for x in b["vadeliler"] if x["durum"] == "acik"]) == 1
hata_bekle(rpc, zengin, "vadeli_ac", 500, 7, icerir="en az 1.000")
hata_bekle(rpc, zengin, "vadeli_ac", 5000, 10, icerir="7 ya da 30")
vb = rpc(zengin, "vadeli_ac", 10000, 30)
boz_id = [x["id"] for x in vb["vadeliler"] if x["anapara"] == 10000][0]
rpc(zengin, "vadeli_ac", 1000, 30)
hata_bekle(rpc, zengin, "vadeli_ac", 1000, 30, icerir="en fazla 3")
ok("Vadesiz hesaba yatırma, kişi başı mevduat tavanı, vadeli hesap (7/30 gün, en az 1.000 ₺, en fazla 3)")

# Servet vergisi bankadaki mevduatı da sayar
q("insert into oyun.duzenlemeler(kod, deger, kaynak, zaman) values ('servet_vergisi', 2, 'kararname', now()) on conflict (kod) do update set deger = 2")
once = para(zengin); mevduat = 100000 + 30000 + 10000 + 1000
q(f"select oyun.gunluk_kesinti('{zengin}', '2026-10-02 12:00+03')")
assert once - para(zengin) == math.floor((once + mevduat - 250000) * 2 / 1000), (once, para(zengin))
assert "banka mevduatı dahil" in q(f"select aciklama from oyun.hesap_hareket where user_id='{zengin}' and tur='servet'")
q("delete from oyun.duzenlemeler where kod='servet_vergisi'")
ok("Servet vergisi bankadaki parayı da sayar (para bankaya saklanarak vergiden kaçılamaz)")

# =====================================================================
# 5) KREDİ
# =====================================================================
iyi = oyuncu("Iyi", 35, para=5000)
b = rpc(iyi, "banka")
assert b["kredi_limit"] == 14000 and b["kredi_notu"] == 1100 and b["not_ad"] == "Az riskli"
q(f"select oyun.cuzdanim('{iyi}'); update oyun.cuzdan set kidem=30 where user_id='{iyi}'")
assert rpc(iyi, "banka")["kredi_limit"] == 42100
hata_bekle(rpc, iyi, "kredi_cek", 50000, 7, icerir="Kredi limitin 42.100")
hata_bekle(rpc, iyi, "kredi_cek", 500, 7, icerir="En az 1.000")
hata_bekle(rpc, iyi, "kredi_cek", 5000, 10, icerir="7, 15 ya da 30")
b = rpc(iyi, "kredi_cek", 20000, 7)
k = b["kredi"]
assert k["toplam"] == 20249 and k["taksit"] == 2893 and k["kalan"] == 20249 and para(iyi) == 25000
assert "Kredin hesabına geçti" in bildirim(iyi)
hata_bekle(rpc, iyi, "kredi_cek", 1000, 7, icerir="Ödenmemiş bir kredin")
ok("Kredi limiti statüye göre (Yeni Gelen 14.000, Saygın Vatandaş 42.100 ₺); 20.000 ₺ 7 gün: geri ödeme 20.249, günlük taksit 2.893 ₺")

# Gecikecek borçlu: vadeli hesabı var, cüzdanı boş
borclu = oyuncu("Borclu", 35, 1, para=20000)
q(f"select oyun.cuzdanim('{borclu}'); update oyun.cuzdan set kidem=20 where user_id='{borclu}'")
rpc(borclu, "vadeli_ac", 5000, 7)
rpc(borclu, "kredi_cek", 10000, 15)
kb = kredi(borclu)
assert kb["toplam"] == 10267 and kb["taksit"] == 685
setpara(borclu, 0)
ok("Borçlu oyuncu: 10.000 ₺ 15 gün kredi (10.267 ₺, günde 685 ₺), cüzdanı boşaltıldı")

# ---- 1. gün (3 Ekim)
saat("2026-10-03 12:00")
z = rpc(zengin, "banka")
gecen = (24 * 60 - 5) / (24 * 60)          # 2 Ekim 12:05'te yatırıldı, 3 Ekim 12:00'de işlendi
assert z["vadesiz"]["faiz_toplam"] == math.floor(100000 * oran("vadesiz") / 100 / 30 * gecen), (z["vadesiz"], oran("vadesiz"))
assert z["vadesiz"]["bakiye"] == 100000 + z["vadesiz"]["faiz_toplam"]
ok(f"Vadesiz faiz her gece hesaba eklenir: 100.000 ₺ için 1 günde {z['vadesiz']['faiz_toplam']} ₺")

assert para(iyi) == 25000 - 2893 and kredi(iyi)["kalan"] == 20249 - 2893 and kredi(iyi)["gecikme_gun"] == 0
kb = kredi(borclu)
assert kb["gecikmis"] == 685 + 7 and kb["kalan"] == 10267 + 7 and kb["gecikme_gun"] == 1 and notu(borclu) == 1060
assert "taksitin ödenemedi" in bildirim(borclu)
d = rpc(borclu, "durum")
assert "1 gündür ödenmedi" in d["profil"]["kredi_uyari"]
hata_bekle(rpc, borclu, "banka_cek", None, icerir="bloke")
hata_bekle(rpc, borclu, "para_gonder", "Ali", 100, icerir="Gecikmiş kredi borcun")
hata_bekle(rpc, borclu, "bagis_yap", 100, icerir="Gecikmiş kredi borcun")
hata_bekle(rpc, borclu, "il_bagis", 100, icerir="Gecikmiş kredi borcun")
hata_bekle(rpc, borclu, "vadeli_ac", 1000, 7, icerir="Gecikmiş kredi borcun")
ok("Taksit gece cüzdandan otomatik ödenir; ödenemezse: %1 gecikme faizi, kredi notu −40, uyarı; para gönderme, bağış, çekme ve vadeli açma kapanır")

# Erken kapama: kalan günlerin faizi alınmaz
ki = kredi(iyi); faiz_payi = (ki["toplam"] - ki["anapara"]) / ki["gun"]
beklenen = ki["kalan"] - round(faiz_payi * math.floor(ki["kalan"] / ki["taksit"]))
once = para(iyi)
assert rpc(iyi, "banka")["kredi"]["erken_kapama"] == beklenen
rpc(iyi, "kredi_ode", None)
assert once - para(iyi) == beklenen and kredi(iyi)["durum"] == "kapandi" and notu(iyi) == 1160
ok(f"Erken kapama: {beklenen} ₺ (kalan günlerin faizi düşüldü); zamanında kapatılan kredi notu +60")

# ---- 2. ve 3. gün: yasal takip
saat("2026-10-04 12:00")
kb = kredi(borclu); assert kb["gecikme_gun"] == 2 and kb["gecikmis"] == 692 + 685 + 14 and notu(borclu) == 1020
saat("2026-10-05 12:00")
kb = kredi(borclu)
assert kb["durum"] == "takip" and notu(borclu) == 1020 - 40 - 250
assert q(f"select durum from oyun.vadeli where user_id='{borclu}'") == "haciz"
assert kb["gecikmis"] == 0 and kb["kalan"] == 10267 + 7 + 14 + 21 - 2097, kb
assert int(float(q(f"select kidem from oyun.cuzdan where user_id='{borclu}'"))) == 15
assert para(borclu) > 2900                                       # vadeli hesaptan borç sonrası kalan cüzdana döndü
assert "yasal takibe düştü" in bildirim(borclu)
assert rpc(ali, "oyuncu_kart", "Borclu")["borclu"] is True
assert "yasal takipte" in rpc(borclu, "durum")["profil"]["kredi_uyari"]
ok("3 gün üst üste ödenmeyen kredi yasal takibe düşer: vadeli hesap bozulup borca sayılır, kredi notu −250, kıdem −5, oyuncu kartında 'takipteki borçlu'")

saat("2026-10-06 10:00")
kb = kredi(borclu); assert kb["kalan"] == 8212 - 685 and kb["durum"] == "takip"

# Aday gösterme şartı: belediye aday adaylığı (6 Ekim)
rpc(uye_ank, "aday_ol", "bel_on")
hata_bekle(rpc, uye_ist, "aday_ol", "bel_on", icerir="İstanbul il teşkilatı yok")
rpc(uye_izm, "aday_ol", "bel_on")                # genel merkez İzmir'de
q("update oyun.ayarlar set teskilat_zorunlu=false"); rpc(uye_ist, "aday_ol", "bel_on"); q("update oyun.ayarlar set teskilat_zorunlu=true")
ok("Teşkilatı olmayan ilde aday gösterilemez; teşkilatlı ilde ve genel merkezde olur (yönetici şartı kapatabilir)")


q(f"update oyun.cuzdan set son_toplama='2026-10-06 02:00+03' where user_id='{borclu}'")
once_kalan = kb["kalan"]
r = rpc(borclu, "topla")
maas = r["sonuc"]["maas"]; haciz = -int(hareket(borclu, "haciz"))
assert haciz == min(once_kalan, maas // 2) and kredi(borclu)["kalan"] == once_kalan - haciz
ok(f"Takipte maaş haczi: toplanan {maas} ₺ maaşın {haciz} ₺'si borca kesildi")

hata_bekle(rpc, borclu, "kredi_cek", 1000, 7, icerir="Ödenmemiş bir kredin")
setpara(borclu, 50000)
kapama = rpc(borclu, "banka")["kredi"]["erken_kapama"]
rpc(borclu, "kredi_ode", None)
assert kredi(borclu)["durum"] == "kapandi" and para(borclu) == 50000 - kapama
assert "30 gün boyunca yeni kredi" in bildirim(borclu)
hata_bekle(rpc, borclu, "kredi_cek", 1000, 7, icerir="Takibe düşen kredin")
assert rpc(ali, "oyuncu_kart", "Borclu")["borclu"] is False
rpc(borclu, "para_gonder", "Ali", 100)
ok("Borç kapanınca haciz kalkar ve para gönderme açılır; 30 gün kara liste (yeni kredi yok)")

# Vadeli: vadesinde anapara + faiz; erken bozmada durduğu kadar vadesiz faizi
bozma = [x for x in rpc(zengin, "banka")["vadeliler"] if x["id"] == boz_id][0]["bozma"]
once = para(zengin)
b = rpc(zengin, "vadeli_boz", boz_id)
getiri = para(zengin) - once - 10000
assert getiri == bozma and 0 < getiri < round(10000 * 3.17 / 100 * 4 / 30), getiri
hata_bekle(rpc, zengin, "vadeli_boz", boz_id, icerir="bulunamadı")
ok(f"Vadeli hesap erken bozulunca durduğu süre kadar vadesiz faizi işler ({getiri} ₺)")
once = para(zengin)
saat("2026-10-09 12:10")
assert para(zengin) - once >= 30000 + round(30000 * 2.67 / 100 * 7 / 30) - 1
assert q(f"select durum from oyun.vadeli where user_id='{zengin}' and anapara=30000") == "vade"
assert "vadesi doldu" in bildirim(zengin)
ok("Vadesi dolan vadeli hesap: anapara + sabit faiz (30.000 ₺ 7 günde 187 ₺) cüzdana yatar")

# Kuruluşu düşen parti: ücretin yarısı iade
assert q(f"select kapali from oyun.partiler where id={p1}") == "t"
assert int(hareket(kurucu1, "parti_kur_iade")) == 12500 and "iade" in bildirim(kurucu1)
ok("Kuruluşu düşen partinin kurucusuna ücretin yarısı (12.500 ₺) iade edilir")

# =====================================================================
# 6) MODERATÖR EKİBİ
# =====================================================================
ercan = oyuncu("Ercan", 35); q(f"update oyun.profiller set yonetici=true where id='{ercan}'")
mod = oyuncu("Mod1", 34); mod2 = oyuncu("Mod2", 34); kotu = oyuncu("Kotu", 34)
hata_bekle(rpc, mod, "admin_ozet", icerir="yalnızca oyun yöneticileri ve moderatörler")
hata_bekle(rpc, mod, "admin_moderator_ayarla", "Mod2", "{ozet}", icerir="yöneticileri")
r = rpc(ercan, "admin_moderator_ayarla", "Mod1", "{sikayet,oyuncu_ara}")
assert r["liste"][0]["kad"] == "Mod1" and r["liste"][0]["yetkiler"] == ["oyuncu_ara", "sikayet"] and len(r["tanim"]) == 9
assert "seni moderatör yaptı" in bildirim(mod) and "Şikâyetler" in bildirim(mod)
y = rpc(mod, "durum")["profil"]["yetkiler"]
assert y["moderator"] and not y["yonetici"] and sorted(y["liste"]) == ["oyuncu_ara", "sikayet"]
assert len(rpc(ercan, "durum")["profil"]["yetkiler"]["liste"]) == 9
hata_bekle(rpc, ercan, "admin_moderator_ayarla", "Mod1", "{ucmak}", icerir="Geçersiz yetki")
hata_bekle(rpc, ercan, "admin_moderator_ayarla", "Ercan", "{ozet}", icerir="Kendi yetkilerini")
ok("Yönetici bir oyuncuyu moderatör yapar ve yetkilerini seçer; moderatöre bildirim gider")

rpc(kotu, "sohbet_yaz", "genel", "Bu bir spam mesajı")
mid = int(q("select id from oyun.mesajlar where metin='Bu bir spam mesajı'"))
rpc(ali, "sikayet_et", "mesaj", mid, "Kotu", "spam")
assert len(rpc(mod, "admin_sikayetler", "yeni")) == 1
hata_bekle(rpc, mod, "admin_ozet", icerir="yetkin yok")
hata_bekle(rpc, mod, "admin_duyuru", "Merhaba", icerir="yetkin yok")
hata_bekle(rpc, mod, "admin_kurallar", None, icerir="yetkin yok")
hata_bekle(rpc, mod, "admin_islem", "Kotu", "sustur1", icerir="yetkin yok")
hata_bekle(rpc, mod, "admin_sikayet_karar", "mesaj", mid, "Kotu", "gizle_sustur1", icerir="Susturma yetkin yok")
hata_bekle(rpc, mod, "admin_sikayet_karar", "mesaj", mid, "Kotu", "kapat", icerir="Hesap kapatma yetkin yok")
rpc(mod, "admin_sikayet_karar", "mesaj", mid, "Kotu", "gizle")
assert q(f"select gizli from oyun.mesajlar where id={mid}") == "t"
o = rpc(mod, "admin_oyuncu", "Kotu")
assert o["eposta"] is None and o["kad"] == "Kotu"
assert rpc(ercan, "admin_oyuncu", "Kotu")["eposta"] == "Kotu@t.com"
ok("Moderatör yalnızca verilen yetkiyi kullanır: şikâyeti gizler ama susturamaz, hesap kapatamaz, duyuru atamaz; e-postayı göremez")

rpc(ercan, "admin_moderator_ayarla", "Mod1", "{sikayet,oyuncu_ara,sustur}")
rpc(ercan, "admin_moderator_ayarla", "Mod2", "{ozet}")
rpc(mod, "admin_islem", "Kotu", "sustur1")
assert q(f"select susturma_bitis > test_simdi from oyun.profiller, oyun.ayarlar where profiller.id='{kotu}'") == "t"
hata_bekle(rpc, mod, "admin_islem", "Ercan", "sustur1", icerir="Yöneticiye ya da başka bir moderatöre")
hata_bekle(rpc, mod, "admin_islem", "Mod2", "sustur7", icerir="Yöneticiye ya da başka bir moderatöre")
hata_bekle(rpc, mod, "admin_islem", "Kotu", "kapat", icerir="yetkin yok")
rpc(ercan, "admin_islem", "Mod2", "sustur1")          # yönetici herkese işlem yapabilir
ok("Susturma yetkisi verilince susturur; yöneticiye ve diğer moderatörlere işlem yapamaz")

kayit = rpc(ercan, "admin_mod_kayit", 50)
islemler = [(k["kad"], k["islem"]) for k in kayit]
assert ("Mod1", "sustur1") in islemler and ("Mod1", "sikayet_gizle") in islemler and ("Ercan", "moderator_ata") in islemler
assert [k for k in kayit if k["islem"] == "sikayet_gizle"][0]["ayrinti"] == "Bu bir spam mesajı"
hata_bekle(rpc, mod, "admin_mod_kayit", 10, icerir="yöneticileri")
ok("Moderasyon günlüğü: kim, ne zaman, kime, ne yaptı (yalnız yönetici görür)")

rpc(ercan, "admin_moderator_ayarla", "Mod1", "{}")
assert "sona erdi" in bildirim(mod)
hata_bekle(rpc, mod, "admin_sikayetler", "yeni", icerir="yalnızca oyun yöneticileri")
assert not rpc(mod, "durum")["profil"]["yetkiler"]["moderator"]
ok("Yetkiler boş bırakılınca moderatörlük sona erer")

# Kurallar ekranından yeni ayarlar
r = rpc(ercan, "admin_kurallar", json.dumps({"parti_kur_ucret": 40000, "teskilat_zorunlu": False, "banka_reel_faiz": 8, "havale_sinir": 2}))
assert r["parti_kur_ucret"] == 40000 and r["teskilat_zorunlu"] is False and r["banka_reel_faiz"] == 8 and r["havale_sinir"] == 2
rpc(ercan, "admin_kurallar", json.dumps({"banka_acik": False}))
hata_bekle(rpc, zengin, "banka_yatir", 1000, icerir="Banka şu an kapalı")
ok("Yönetici paneli: parti ücreti, teşkilat şartı, faiz, havale sınırı ve bankayı açıp kapama ayarları")

print(f"\nTÜM EKONOMİ 3 KONTROLLERİ GEÇTİ ({len(TAMAM)})")
