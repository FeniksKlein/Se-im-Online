"""Vekil oy kaydı + Meclis araştırması (99_meclis_oy_kaydi_arastirma.sql).
Çalıştır: ../kur_yerel.sh && python3 meclis_arastirma.py"""
from db import q, rpc, saat, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, baslangic_para=1000000;")
saat("2026-10-02 12:00")

def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    return u
def mv(u, il, parti):
    q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas) values ('mv','{u}',{il},{parti},'2026-10-02 11:00+03')")

A = [oyuncu(f"Aa{i}", 35, 1) for i in range(1, 6)]
B = [oyuncu(f"Bb{i}", 6, 2) for i in range(1, 4)]
C1 = oyuncu("Cc1", 34, 3)
uye = oyuncu("Uye", 35, 1)
for u in A: mv(u, 35, 1)
for u in B: mv(u, 6, 2)
mv(C1, 34, 3)
q("select oyun.meclis_donem_baslat(null, oyun.simdi())")

GER = "Son bir yılda illerde yaşanan su kesintilerinin nedenlerinin, sorumlularının ve alınacak önlemlerin araştırılması gerekmektedir."
KONU = "Su kesintilerinin nedenleri ve sorumluları"

# ---------- ÖNERGE + İMZA ----------
l = rpc(uye, "meclis_arastirmalar")
assert l["vekilim"] is False and l["imza_yeter"] == 2 and l["uye_sayisi"] == 5, l
hata_bekle(rpc, uye, "meclis_arastirma_ver", KONU, GER, icerir="milletvekilleri")
hata_bekle(rpc, A[1], "meclis_arastirma_ver", "Kısa", GER, icerir="10–150")
hata_bekle(rpc, A[1], "meclis_arastirma_ver", KONU, "kısa gerekçe", icerir="50–3000")
d = rpc(A[1], "meclis_arastirma_ver", KONU, GER)
aid = d["id"]
assert d["durum"] == "imza" and d["imzalar"] == ["Aa2"] and d["no"] == 1
hata_bekle(rpc, A[1], "meclis_arastirma_ver", KONU + " ikinci", GER, icerir="zaten")
hata_bekle(rpc, uye, "meclis_arastirma_imza", aid, True, icerir="milletvekilleri")
d = rpc(B[0], "meclis_arastirma_imza", aid, True)
assert d["durum"] == "oylamada" and d["imzalar"] == ["Aa2", "Bb1"], d["durum"]
ok("Önerge: yalnız vekiller verir; dolu sandalyenin 1/30'u (en az 2) imzayla öngörüşme oylaması hemen açılıyor")

# ---------- ÖNGÖRÜŞME ----------
saat("2026-10-02 13:00")
for u in A[:4]: rpc(u, "meclis_arastirma_oy", aid, "kabul")
rpc(B[0], "meclis_arastirma_oy", aid, "ret")
hata_bekle(rpc, uye, "meclis_arastirma_oy", aid, "kabul", icerir="milletvekilleri")
d = rpc(uye, "meclis_arastirma_detay", aid)
assert d["ongorusme"]["kabul"] == 4 and d["ongorusme"]["ret"] == 1 and len(d["ongorusme"]["liste"]) == 5
saat("2026-10-03 12:30")
d = rpc(uye, "meclis_arastirma_detay", aid)
assert d["durum"] == "kurulus" and d["uye_sayisi"] == 5, d["durum"]
kont = {x["parti"]["id"]: x["koltuk"] for x in d["kontenjan"]}
assert kont == {1: 3, 2: 2}, kont
ok("Öngörüşme açık oyla kabul (oylar herkese açık); 5 üyelik komisyon D'Hondt ile 3 + 2 dağıtıldı")

# ---------- KURULUŞ ----------
hata_bekle(rpc, C1, "meclis_arastirma_uye_ol", aid, True, icerir="kontenjan")
for u in A[:3]: rpc(u, "meclis_arastirma_uye_ol", aid, True)
hata_bekle(rpc, A[3], "meclis_arastirma_uye_ol", aid, True, icerir="kontenjanı (3) doldu")
rpc(B[0], "meclis_arastirma_uye_ol", aid, True)
saat("2026-10-04 01:00")     # son 12 saat: boş yerler herkese açık
rpc(C1, "meclis_arastirma_uye_ol", aid, True)
hata_bekle(rpc, B[1], "meclis_arastirma_uye_ol", aid, True, icerir="doldu")
hata_bekle(rpc, A[4], "meclis_arastirma_baskan_oy", aid, "Aa2", icerir="komisyon üyeleri")
hata_bekle(rpc, A[0], "meclis_arastirma_baskan_oy", aid, "Aa5", icerir="komisyon üyesi")
rpc(A[0], "meclis_arastirma_baskan_oy", aid, "Aa2"); rpc(A[1], "meclis_arastirma_baskan_oy", aid, "Aa2")
for u in (B[0], C1, A[2]): rpc(u, "meclis_arastirma_baskan_oy", aid, "Bb1")
saat("2026-10-04 13:00")
d = rpc(uye, "meclis_arastirma_detay", aid)
assert d["durum"] == "calisma" and d["baskan"] == "Bb1" and d["uye"] == 5, (d["durum"], d["baskan"])
ok("Kuruluş: parti kontenjanı korunuyor, son 12 saatte boş yer bağımsız/küçük partiye açılıyor; üyeler başkanı seçti")

# ---------- ÇALIŞMA: davet / cevap ----------
SORU = "Bakanlığınız su kesintileri konusunda belediyelerle hangi koordinasyonu yaptı?"
hata_bekle(rpc, A[3], "meclis_arastirma_davet", aid, "Uye", SORU, icerir="komisyon üyelerince")
hata_bekle(rpc, A[0], "meclis_arastirma_davet", aid, "Yokki", SORU, icerir="oyuncu yok")
rpc(A[0], "meclis_arastirma_davet", aid, "Uye", SORU)
hata_bekle(rpc, A[1], "meclis_arastirma_davet", aid, "Uye", SORU, icerir="zaten")
rpc(B[0], "meclis_arastirma_davet", aid, "Aa5", SORU)
l = rpc(uye, "meclis_arastirmalar")
assert len(l["davetlerim"]) == 1 and l["davetlerim"][0]["soran"] == "Aa1"
assert "Meclis araştırma komisyonu seni dinlemek" in q(f"select metin from oyun.bildirimler where user_id='{uye}' order by id desc limit 1")
did = l["davetlerim"][0]["id"]
hata_bekle(rpc, A[4], "meclis_arastirma_cevap", did, "Benim cevabım olmaz bu, sana sorulmadı.", icerir="sana yapılmadı")
rpc(uye, "meclis_arastirma_cevap", did, "Belediyelerle her hafta toplantı yaptık ve altyapı bütçesini artırdık.")
hata_bekle(rpc, uye, "meclis_arastirma_cevap", did, "İkinci kez cevap vermek istiyorum burada.", icerir="cevapladın")
ok("Çalışma: üyeler herhangi bir oyuncuyu davet ediyor, davetli bildirim alıp yazılı cevap veriyor")

# ---------- RAPOR ----------
RAPOR = "Komisyon, su kesintilerinin temel nedeninin eskimiş altyapı ve bakanlık ile belediyeler arasındaki koordinasyon eksikliği olduğunu tespit etmiştir."
hata_bekle(rpc, A[0], "meclis_arastirma_rapor", aid, RAPOR, None, icerir="Komisyon Başkanı")
hata_bekle(rpc, B[0], "meclis_arastirma_rapor", aid, "kısa", None, icerir="100–6000")
d = rpc(B[0], "meclis_arastirma_rapor", aid, RAPOR, "Altyapı yenileme fonu kurulsun.")
assert d["durum"] == "rapor_oylama"
dl = {x["davetli"]: x["durum"] for x in d["dinlemeler"]}
assert dl == {"Uye": "cevaplandi", "Aa5": "gelmedi"}, dl
hata_bekle(rpc, A[4], "meclis_arastirma_oy", aid, "kabul", icerir="komisyon üyeleri")
rpc(A[0], "meclis_arastirma_oy", aid, "kabul"); rpc(A[1], "meclis_arastirma_oy", aid, "kabul")
rpc(C1, "meclis_arastirma_oy", aid, "ret"); rpc(A[2], "meclis_arastirma_oy", aid, "cekimser")
hata_bekle(rpc, B[0], "meclis_arastirma_serh", aid, "Başkan olarak şerh yazmak istiyorum.", icerir="şerh düşemez")
rpc(C1, "meclis_arastirma_serh", aid, "Rapor bakanlığın sorumluluğunu yeterince ortaya koymuyor; katılmıyorum.")
saat("2026-10-05 13:00")
d = rpc(uye, "meclis_arastirma_detay", aid)
assert d["durum"] == "tamamlandi" and d["rapor_sonuc"] == "kabul" and len(d["serhler"]) == 1, (d["durum"], d["rapor_sonuc"])
assert d["rapor_oy"]["kabul"] == 2 and d["rapor_oy"]["ret"] == 1
ok("Rapor: yalnız başkan sunar, cevapsız davetler 'gelmedi' olur, üyeler oylar, muhalefet şerhi yayımlanır")

# ---------- OY KAYDI ----------
k = q("insert into oyun.kanunlar(no,tur,baslik,metin,teklif_eden,teklif_parti,durum,teklif_at,oy_bas,oy_bit,sonuc_at) "
      f"values (1,'serbest','Kent Ormanları Kanunu','Her ilde kent ormanı.','{B[0]}',2,'yururlukte','2026-10-02 12:00+03','2026-10-02 18:00+03','2026-10-03 18:00+03','2026-10-03 18:00+03') returning id")
q(f"insert into oyun.grup_kararlari values ({k},1,'kabul',null,'2026-10-02 18:00+03')")
q(f"insert into oyun.kanun_oylari values ({k},'ilk','{A[1]}',1,'ret','2026-10-02 19:00+03'),({k},'ilk','{A[0]}',1,'kabul','2026-10-02 19:00+03')")
a2 = rpc(uye, "vekil_oy_kaydi", "aa2", 40)
assert a2["vekil"] and a2["gorevde"] and a2["kad"] == "Aa2"
turler = sorted((x["tur"], x["asama"], x["oy"]) for x in a2["kayit"])
assert turler == [("arastirma", "Komisyon raporu", "kabul"), ("arastirma", "Öngörüşme", "kabul"), ("kanun", "Genel Kurul", "ret")], turler
kn = next(x for x in a2["kayit"] if x["tur"] == "kanun")
assert kn["aykiri"] is True and a2["ozet"]["aykiri"] == 1 and a2["ozet"]["toplam"] == 3
assert a2["ozet"]["oturum"] == 2 and a2["ozet"]["katildi"] == 2, a2["ozet"]
a5 = rpc(uye, "vekil_oy_kaydi", "Aa5")
assert a5["ozet"]["oturum"] == 2 and a5["ozet"]["katildi"] == 0 and a5["kayit"] == []
assert rpc(uye, "vekil_oy_kaydi", "Uye") == {"vekil": False}
hata_bekle(rpc, uye, "vekil_oy_kaydi", "Yokki", icerir="oyuncu yok")
# Anayasa oylaması gizli: kayda girmez
k2 = q("insert into oyun.kanunlar(no,tur,baslik,metin,teklif_eden,teklif_parti,durum,teklif_at,oy_bas,oy_bit) "
       f"values (2,'anayasa','Gizli','Gizli oy.','{B[0]}',2,'ret','2026-10-02 12:00+03','2026-10-02 18:00+03','2026-10-03 18:00+03') returning id")
q(f"insert into oyun.kanun_oylari values ({k2},'ilk','{A[1]}',1,'kabul','2026-10-02 19:00+03')")
assert all(x["baslik"] != "2 sayılı Gizli" for x in rpc(uye, "vekil_oy_kaydi", "Aa2")["kayit"])
ok("Oy kaydı: kanun/araştırma oyları, grup kararına aykırılık ve katılım herkese açık; anayasa (gizli oy) hariç")

# ---------- SÜRE / KADÜK ----------
d2 = rpc(A[2], "meclis_arastirma_ver", "Orman yangınlarının nedenleri araştırılsın", GER)
saat("2026-10-06 14:00")
assert rpc(uye, "meclis_arastirma_detay", d2["id"])["durum"] == "dustu"
d3 = rpc(A[3], "meclis_arastirma_ver", "Deprem hazırlığı eksiklikleri araştırılsın", GER)
saat("2026-10-06 15:00")
q("select oyun.meclis_donem_baslat(null, oyun.simdi())")
saat("2026-10-06 15:05")
assert rpc(uye, "meclis_arastirma_detay", d3["id"])["durum"] == "kaduk"
l = rpc(uye, "meclis_arastirmalar")
assert l["aktif"] == [] and [x["durum"] for x in l["biten"]] == ["kaduk", "dustu", "tamamlandi"]
ok("İmza süresi dolan önerge düşüyor; yeni yasama döneminde sonuçlanmamış araştırma kadük oluyor")
print("meclis_arastirma: hepsi geçti")
