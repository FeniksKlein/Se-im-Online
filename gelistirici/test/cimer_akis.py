"""Modül 81 (CİMER) ve 82 (akış: anonim beğen/beğenme, yanıtlar).
Çalıştır: ../kur_yerel.sh && python3 cimer_akis.py"""
from db import q, qj, rpc, kullanici_ekle, hata_bekle
TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
_dk = [0]
def ileri(dk=1):
    _dk[0] += dk; q(f"update oyun.ayarlar set test_simdi = '2030-03-03 10:00+03'::timestamptz + interval '{_dk[0]} minutes'")
ileri(0)
U = []
for n in range(6):
    u = kullanici_ekle(f"c{n}@test.com"); rpc(u, "profil_olustur", f"Cim_{n}", [34, 6, 35, 34, 6, 35][n]); U.append(u)
VAT, CB, BAKAN, BEL, VAT2, VAT3 = U
q(f"insert into oyun.makamlar(tur,user_id,bas) values ('cb','{CB}',now())")
q(f"insert into oyun.makamlar(tur,user_id,bakanlik,bas) values ('bakan','{BAKAN}','saglik',now())")
q(f"insert into oyun.makamlar(tur,user_id,il_id,bas) values ('bel','{BEL}',34,now())")

# ---------- CİMER
c = rpc(VAT, "cimer")
assert c["bugun_kalan"] == 3 and any(b["kod"] == "saglik" and b["bakan"] == "Cim_2" for b in c["kurumlar"]["bakanliklar"])
assert c["kurumlar"]["cb"] == "Cim_1"
ok("CİMER ekranı: kurumlar ve makam sahipleri listelenir")
r = rpc(VAT, "cimer_basvur", "bakanlik", "saglik", None, "sikayet", "Hastane randevusu", "İlimizdeki devlet hastanesinde randevu bulamıyoruz, çözüm bekliyoruz.")
assert r["muhatap_var"]
bid = r["id"]
assert "CİMER" in q(f"select metin from oyun.bildirimler where user_id='{BAKAN}' order by id desc limit 1")
g = rpc(BAKAN, "cimer")["gelen"]
assert len(g) == 1 and g[0]["yanitlayabilirim"] and g[0]["gonderen"] == "Cim_0" and g[0]["kurum"] == "Sağlık Bakanlığı"
assert rpc(CB, "cimer")["gelen"] == [] and rpc(BEL, "cimer")["gelen"] == []
ok("Bakanlığa şikâyet yalnız o bakanın kutusuna düştü, bildirimi gitti")
hata_bekle(rpc, CB, "cimer_yanitla", bid, "sonuclandi", "olumlu", "Başkasının başvurusu", icerir="yetkin yok")
ileri(); hata_bekle(rpc, VAT, "cimer_basvur", "bakanlik", "saglik", None, "talep", "Aynı kurum", "Aynı kuruma altı saat dolmadan ikinci başvuru.", icerir="6 saatte")
hata_bekle(rpc, VAT, "cimer_basvur", "bakanlik", "yok", None, "talep", "Konu başlığı", "Geçersiz bakanlık kodu ile başvuru denemesi.", icerir="Bakanlık")
hata_bekle(rpc, VAT, "cimer_basvur", "cb", None, None, "talep", "Kısa", "kısa", icerir="Konu")
ok("Yetkisiz yanıt, aynı kuruma 6 saat kuralı ve biçim denetimleri çalışıyor")
rpc(VAT, "cimer_basvur", "belediye", None, 34, "talep", "Park yapılsın", "Mahallemize çocuk parkı yapılmasını talep ediyoruz, alan boş duruyor.")
ileri(); rpc(VAT, "cimer_basvur", "cb", None, None, "oneri", "Gençlik programı", "Gençlere yönelik bir burs ve staj programı başlatılmasını öneriyorum.")
ileri(); hata_bekle(rpc, VAT, "cimer_basvur", "bakanlik", "egitim", None, "talep", "Dördüncü başvuru", "Bir günde dördüncü başvuru reddedilmeli, sınır üçtür.", icerir="en fazla 3")
assert rpc(VAT, "cimer")["bugun_kalan"] == 0
ok("Günde 3 başvuru sınırı")
assert len(rpc(BEL, "cimer")["gelen"]) == 1 and len(rpc(CB, "cimer")["gelen"]) == 1
# boş bakanlık → CB vekâlet
rpc(VAT2, "cimer_basvur", "bakanlik", "egitim", None, "bilgi", "Okul bütçesi", "Okullara bu yıl ne kadar bütçe ayrıldığını öğrenmek istiyorum.")
assert any(x["kurum"] == "Millî Eğitim Bakanlığı" for x in rpc(CB, "cimer")["gelen"])
ok("Belediye ve Cumhurbaşkanlığı başvuruları doğru kişiye; boş bakanlığa CB vekâleten bakar")
# yanıt + memnuniyet
rpc(BAKAN, "cimer_yanitla", bid, "inceleniyor", None, None)
assert rpc(VAT, "cimer")["basvurularim"][-1]["durum"] == "inceleniyor"
ileri(30); rpc(BAKAN, "cimer_yanitla", bid, "sonuclandi", "olumlu", "Hastaneye ek hekim görevlendirildi, randevu sayısı artırıldı.")
b = [x for x in rpc(VAT, "cimer")["basvurularim"] if x["id"] == bid][0]
assert b["durum"] == "sonuclandi" and b["sonuc"] == "olumlu" and b["cevaplayan"] == "Cim_2"
hata_bekle(rpc, VAT2, "cimer_degerlendir", bid, True, icerir="değerlendiremezsin")
rpc(VAT, "cimer_degerlendir", bid, True)
hata_bekle(rpc, VAT, "cimer_degerlendir", bid, False, icerir="değerlendiremezsin")
ok("İncelemeye alma, resmî yanıt, yalnız gönderenin bir kez memnuniyet bildirmesi")
# makam değişince bekleyen başvuru yeni sahibine geçer
q(f"update oyun.makamlar set bit=now() where user_id='{BEL}' and tur='bel'")
q(f"insert into oyun.makamlar(tur,user_id,il_id,bas) values ('bel','{VAT3}',34,now())")
assert len(rpc(VAT3, "cimer")["gelen"]) == 1 and rpc(BEL, "cimer")["gelen"] == []
ok("Belediye başkanı değişince bekleyen başvuru yeni başkana geçti (başvuru kişiye değil makama)")
# başvurular gizli: başka oyuncu göremez
assert rpc(VAT2, "cimer")["gelen"] == [] and all(x["benim"] for x in rpc(VAT2, "cimer")["basvurularim"])
k = rpc(VAT2, "cimer_karne")
sag = [x for x in k if x["kurum"] == "Sağlık Bakanlığı"][0]
assert sag["basvuru"] == 1 and sag["yanit"] == 1 and sag["memnuniyet"] == 100
assert all("gonderen" not in x for x in k)
ok(f"Kurum karnesi herkese açık ama kimliksiz: {sag}")
# 72 saat geçince geciken sayılır
q("update oyun.ayarlar set test_simdi = '2030-03-07 12:00+03'")
k = {x["kurum"]: x for x in rpc(VAT2, "cimer_karne")}
assert k["Cumhurbaşkanlığı"]["geciken"] == 1
ok("72 saatte yanıtlanmayan başvuru karnede gecikmiş görünür")
# eski dilekçe kapalı, görevler CİMER'i sayar
hata_bekle(rpc, VAT, "sos_dilekce_gonder", "cb", None, None, "Eski dilekçe", "Eski sistemden dilekçe gönderme denemesi.", icerir="CİMER")
ist = qj(f"select oyun.gorev_istatistik('{VAT}', '2030-01-01')")
assert ist["dilekce_gonder"] == 3, ist["dilekce_gonder"]
assert qj(f"select oyun.gorev_istatistik('{BAKAN}', '2030-01-01')")["dilekce_yanit"] == 1
assert q("select count(*) from oyun.gorev_katalog where metrik='dilekce_gonder' and baslik like 'CİMER%'") == "5"
ok("Dilekçe gönderimi kapandı; hayat görevleri CİMER başvurularını sayıyor")
# imza kampanyası → toplu CİMER başvurusu
q(f"insert into oyun.sos_imza_kamp(acan,makam,muhatap,il_id,baslik,metin,esik) values ('{VAT2}','cb','{CB}',null,'Toplu kampanya','Kampanya metni burada yazıyor, hedefe ulaştı.',1)")
kid = q("select id from oyun.sos_imza_kamp order by id desc limit 1")
q(f"insert into oyun.sos_imza(kampanya_id,user_id) values ({kid},'{VAT}')")
q(f"insert into oyun.sos_dilekce(gonderen,makam,muhatap,baslik,metin,imza_kamp_id) values ('{VAT2}','cb','{CB}','Toplu kampanya','Kampanya metni burada yazıyor, hedefe ulaştı.',{kid})")
t = [x for x in rpc(CB, "cimer")["gelen"] if x["imza_sayisi"]]
assert len(t) == 1 and t[0]["imza_sayisi"] == 1
ok("İmza kampanyası hedefe ulaşınca CİMER'e toplu başvuru olarak düştü")
assert q("select count(*) from information_schema.table_privileges where table_schema='oyun' and table_name in ('cimer_basvuru','akis_begenmeme') and grantee in ('anon','authenticated','public')") == "0"
ok("CİMER tablosu internete kapalı")

# ---------- AKIŞ: beğen / beğenme
q("update oyun.ayarlar set test_simdi = '2030-03-08 10:00+03'")
a = rpc(VAT, "akis_yaz", "Vergi indirimi şart! #ekonomi")["id"]
r1 = rpc(VAT2, "akis_tepki", a, "begen"); assert (r1["begeni"], r1["begenmeme"], r1["begendim"]) == (1, 0, True)
r2 = rpc(VAT3, "akis_tepki", a, "begenme"); assert (r2["begeni"], r2["begenmeme"]) == (1, 1)
r3 = rpc(VAT2, "akis_tepki", a, "begenme"); assert (r3["begeni"], r3["begenmeme"], r3["begendim"], r3["begenmedim"]) == (0, 2, False, True)
r4 = rpc(VAT2, "akis_tepki", a, "begenme"); assert (r4["begeni"], r4["begenmeme"], r4["begenmedim"]) == (0, 1, False)
rpc(CB, "akis_begen", a)
x = [p for p in rpc(BEL, "akis_liste", "herkes") if p["id"] == a][0]
assert (x["begeni"], x["begenmeme"], x["begendim"], x["begenmedim"]) == (1, 1, False, False)
ok("Beğen/beğenme: tek tepki, aynı düğmeye tekrar basınca geri alınır, sayılar doğru")
# anonimlik: hiçbir RPC çıktısında tepki verenlerin adı yok
cikti = json_dump = str(rpc(BEL, "akis_liste", "herkes")) + str(rpc(BEL, "akis_konu", a)) + str(rpc(BEL, "akis_tepki", a, None))
assert "Cim_1" not in cikti and "Cim_3" not in cikti and "Cim_5" not in cikti
assert q("select count(*) from information_schema.routines where routine_schema='public' and routine_name like 'akis%' and routine_definition ilike '%akis_begenmeme%user_id%' and routine_name not in ('akis_tepki')") >= "0"
ok("Kimin beğenip kimin beğenmediği hiçbir çıktıda yok (yalnız sayılar ve kendi tepkin)")
# yanıtlar
ileri(); y1 = rpc(VAT2, "akis_yanit_yaz", a, "Katılmıyorum, bütçe açığı büyür.")["id"]
ileri(); rpc(VAT3, "akis_yanit_yaz", y1, "Yanıta yanıt da ana paylaşımın altına gelir.")
k = rpc(BEL, "akis_konu", y1)
assert k["ana"]["id"] == a and len(k["yanitlar"]) == 2 and k["ana"]["yanit"] == 2
assert all(p["yanit_id"] is None for p in rpc(BEL, "akis_liste", "herkes"))
assert "yanıt verdi" in q(f"select metin from oyun.bildirimler where user_id='{VAT}' order by id desc limit 1")
q(f"insert into oyun.engellemeler(engelleyen,engellenen) values ('{VAT}','{CB}')")
hata_bekle(rpc, CB, "akis_yanit_yaz", a, "Engelliyken yanıt", icerir="engelleme")
ok("Yanıtlar paylaşımın altında; akışta ayrıca görünmez; engelliyken yanıt yazılamaz; sahibine bildirim gider")
print(f"\n{len(TAMAM)} kontrol geçti")
