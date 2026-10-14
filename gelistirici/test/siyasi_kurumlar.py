"""Modül 97: davet kodu, ulusal kriz masası, Meclis komisyonları, parti kapatma davası, gençlik ve kadın kolları.
Çalıştırma: SK_DB=sk_test python3 test/siyasi_kurumlar.py  (varsayılan oyun_test)"""
import os, db
db.DB[db.DB.index("oyun_test")] = os.environ.get("SK_DB", "oyun_test")
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
para = lambda u: float(q(f"select para from oyun.cuzdan where user_id='{u}'"))
num = lambda s: float(q(s))

q("update oyun.ayarlar set min_hesap_gun=0, oy_min_kidem=0, eposta_zorunlu=false, cihaz_zorunlu=false, coklu_kontrol=false where id=1")
saat("2026-10-14 10:00")

def oyuncu(kad, il="İzmir", p=1000000):
    u = kullanici_ekle(f"{kad.lower()}@t.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.cuzdan set para={p} where user_id='{u}'"); return u
def makam(u, tur, il=None, bakanlik=None, parti=None):
    return q(f"insert into oyun.makamlar(tur,user_id,il_id,bakanlik,parti_id,kaynak,bas) values('{tur}','{u}',{il or 'null'},"
             f"{repr(bakanlik) if bakanlik else 'null'},{parti or 'null'},'atama',now()) returning id")
def parti(ad, kisa, gb):
    pid = int(q(f"insert into oyun.partiler(ad,kisa,renk,gb,kurulus,kasa) values('{ad}','{kisa}','#335599','{gb}',now(),500000) returning id"))
    q(f"update oyun.profiller set parti_id={pid}, parti_at=oyun.simdi() where id='{gb}'"); return pid
def uye(u, pid): q(f"update oyun.profiller set parti_id={pid}, parti_at=oyun.simdi() where id='{u}'")

# ===================================================================== 1) DAVET
print("Davet kodu")
ahmet, burak, cem, deniz = oyuncu("Ahmet"), oyuncu("Burak"), oyuncu("Cem"), oyuncu("Deniz")
q(f"update oyun.profiller set olusturma = now() - interval '1 day' where id='{ahmet}'")
d = rpc(ahmet, "davet_bilgim"); kod = d["kod"]
assert len(kod) == 6 and rpc(ahmet, "davet_bilgim")["kod"] == kod
hata_bekle(rpc, ahmet, "davet_kodu_gir", kod, icerir="Kendi")
hata_bekle(rpc, burak, "davet_kodu_gir", "ZZZZZZ", icerir="bulunamadı")
pa, pb = para(ahmet), para(burak)
r = rpc(burak, "davet_kodu_gir", kod.lower()); assert r["durum"] == "odendi", r
assert para(ahmet) - pa == 20000 and para(burak) - pb == 10000
hata_bekle(rpc, burak, "davet_kodu_gir", kod, icerir="Zaten")
ok(f"Kod {kod} üretildi; Burak girdi, oy hakkı olduğu için ikisine anında 20.000/10.000 ₺ yattı")

q(f"insert into oyun.oturumlar(user_id, ilk, son, cihaz) values ('{ahmet}', now(), now(), 'cihaz-1'), ('{cem}', now(), now(), 'cihaz-1')")
hata_bekle(rpc, cem, "davet_kodu_gir", kod, icerir="Aynı cihaz")
ok("Aynı cihazdan açılmış hesap davet kodu kullanamıyor")

q("update oyun.ayarlar set min_hesap_gun=3 where id=1")
r = rpc(deniz, "davet_kodu_gir", kod); assert r["durum"] == "bekliyor"
d = rpc(ahmet, "davet_bilgim"); assert d["sayilar"]["bekliyor"] == 1 and "günlük" in d["davetlerim"][0]["eksik"]
saat("2026-10-18 10:00"); q("select oyun.siyasi_kurumlar_tick()")
assert q(f"select durum from oyun.davet where davet_edilen='{deniz}'") == "odendi"
assert rpc(ahmet, "davet_bilgim")["liderler"][0]["kad"] == "Ahmet"
q("update oyun.ayarlar set min_hesap_gun=0 where id=1")
ok("Hesabı 3 günlük olmayan davetli bekledi, oy hakkı kazanınca zamanlayıcı ödülü verdi; liderlik tablosu çalışıyor")
saat("2026-10-19 10:00")

# ===================================================================== 2) ULUSAL KRİZ
print("Ulusal kriz masası")
yon, reis, icisleri, hatayb = oyuncu("Oyunsahibi"), oyuncu("Reis"), oyuncu("Icisleri"), oyuncu("HatayBaskan", "Hatay")
vat = [oyuncu(f"Hatayli{i}", "Hatay") for i in range(4)]
q(f"update oyun.profiller set yonetici=true where id='{yon}'")
makam(reis, "cb"); makam(icisleri, "bakan", bakanlik="icisleri"); makam(hatayb, "bel", IL("Hatay"))
hata_bekle(rpc, reis, "ulusal_kriz_baslat", "deprem", "Hatay", icerir="yönetici")
mem0 = num(f"select memnuniyet from oyun.il_durum where il_id={IL('Hatay')}")
k = rpc(yon, "ulusal_kriz_baslat", "deprem", "Hatay")["aktif"]
assert k["il_ad"] == "Hatay" and k["asama"] == 1
assert num(f"select memnuniyet from oyun.il_durum where il_id={IL('Hatay')}") < mem0
hata_bekle(rpc, yon, "ulusal_kriz_baslat", "sel", None, icerir="Zaten")
kb = rpc(icisleri, "ulusal_kriz")["aktif"]; assert kb["yetki_ilk"] and not kb["yetki_kalici"] and kb["ilk"]["secenekler"]
assert "puan" not in kb["ilk"]["secenekler"][0]
hata_bekle(rpc, vat[0], "ulusal_kriz_karar", k["id"], "ilk", "afad", icerir="yalnız")
hz0, pv = num("select hazine from oyun.ulke where id=1"), para(vat[0])
rpc(icisleri, "ulusal_kriz_karar", k["id"], "ilk", "afad")
assert para(vat[0]) - pv == 8000 and num("select hazine from oyun.ulke where id=1") < hz0
kb = rpc(reis, "ulusal_kriz")["aktif"]; assert kb["asama"] == 2 and kb["yetki_kalici"]
hata_bekle(rpc, icisleri, "ulusal_kriz_karar", k["id"], "kalici", "kentsel", icerir="yürütmenin")
rpc(reis, "ulusal_kriz_karar", k["id"], "kalici", "kentsel")
kasa0 = num(f"select kasa from oyun.il_durum where il_id={IL('Hatay')}")
rpc(hatayb, "ulusal_kriz_karar", k["id"], "yerel", "cadir")
assert num(f"select kasa from oyun.il_durum where il_id={IL('Hatay')}") < kasa0
hata_bekle(rpc, reis, "ulusal_kriz_puanla", k["id"], 5, None, icerir="sorumlu")
for i, v in enumerate(vat): rpc(v, "ulusal_kriz_puanla", k["id"], 4 + (i % 2), 3)
hata_bekle(rpc, burak, "ulusal_kriz_puanla", k["id"], 4, 4, icerir="o ilde")
kd0 = num(f"select oyun.kidem_puani('{icisleri}')")
saat("2026-10-20 12:00"); q("select oyun.siyasi_kurumlar_tick()")
a = rpc(burak, "ulusal_kriz"); assert a["aktif"] is None and a["arsiv"][0]["karne"] is not None
ar = a["arsiv"][0]; assert ar["karne"] >= 60 and ar["bel_karne"] >= 60, ar
assert num(f"select oyun.kidem_puani('{icisleri}')") > kd0
ok(f"Deprem (Hatay): bakan ilk müdahale, CB kalıcı çözüm, belediye yerel karar; AFAD 8.000 ₺; karne {ar['karne']}/100, belediye {ar['bel_karne']}/100")

q("update oyun.uk_ayar set son_kriz = now() - interval '30 days'")
rpc(yon, "ulusal_kriz_baslat", "salgin", None)
saat("2026-10-20 19:00"); q("select oyun.siyasi_kurumlar_tick()")
saat("2026-10-21 20:00"); q("select oyun.siyasi_kurumlar_tick()")
saat("2026-10-22 21:00"); q("select oyun.siyasi_kurumlar_tick()")
ar = rpc(burak, "ulusal_kriz")["arsiv"][0]; assert ar["kod"] == "salgin" and ar["karne"] == 0 and ar["ilk"]["karar"] == "yok"
ok("Karar verilmeyen salgın krizi otomatik kapandı; karne 0, sorumlulara kıdem cezası")

q("update oyun.uk_ayar set son_kriz = now() - interval '30 days', haftalik_ihtimal = 100, son_cekilis = null")
saat("2026-10-28 18:30"); q("select oyun.siyasi_kurumlar_tick()")
assert rpc(burak, "ulusal_kriz")["aktif"] is not None
saat("2026-10-28 18:40"); q("select oyun.siyasi_kurumlar_tick()")
ok("Çarşamba 18.00 çekilişi yeni kriz başlattı")
q("update oyun.uk_olay set durum='bitti' where durum='aktif'")

# ===================================================================== 3) KOMİSYONLAR
print("Meclis komisyonları")
saat("2026-10-29 10:00")
a1, a2, a3, a4, b1, b2 = (oyuncu(k) for k in ["Avekil1", "Avekil2", "Avekil3", "Avekil4", "Bvekil1", "Bvekil2"])
gbA, gbB = oyuncu("GenelA"), oyuncu("GenelB")
PA, PB = parti("A Partisi", "AP", gbA), parti("B Partisi", "BP", gbB)
for u in (a1, a2, a3, a4): uye(u, PA); makam(u, "mv", IL("İzmir"), parti=PA)
for u in (b1, b2): uye(u, PB); makam(u, "mv", IL("İzmir"), parti=PB)
mv_say = int(q("select oyun.dolu_sandalye()"))
k = rpc(a1, "komisyonlar"); boyut = k["boyut"]
kont = {x["parti"]: x["kontenjan"] for x in k["kontenjan"]}
assert sum(kont.values()) == boyut
q("delete from oyun.kom_uye")
for u in [a1, a2, a3, a4][:kont["AP"]]: rpc(u, "komisyon_katil", "plan_butce")
if kont["AP"] < 4:
    hata_bekle(rpc, [a1, a2, a3, a4][kont["AP"]], "komisyon_katil", "plan_butce", icerir="kontenjan")
rpc(b1, "komisyon_katil", "plan_butce")
hata_bekle(rpc, gbA, "komisyon_katil", "plan_butce", icerir="milletvekilleri")
rpc(a1, "komisyon_baskan_oy", "plan_butce", "Avekil1"); rpc(b1, "komisyon_baskan_oy", "plan_butce", "Avekil1")
kj = [x for x in rpc(a1, "komisyonlar")["komisyonlar"] if x["kod"] == "plan_butce"][0]
assert kj["baskan"] == "Avekil1"
ok(f"{mv_say} vekil, komisyon büyüklüğü {boyut}; kontenjan {kont}; Avekil1 Plan ve Bütçe başkanı")

kid = rpc(a1, "kanun_teklif", "serbest", "Vergi indirimi kanunu", "Dar gelirliye vergi indirimi getirilsin.", None)["id"]
kk = rpc(b1, "komisyon_kanun", kid); assert kk["kom_kod"] == "plan_butce" and kk["oy_verebilirim"]
rpc(a1, "komisyon_rapor", kid, "Komisyon teklifin bütçe dengesini bozacağını değerlendirmiştir.")
hata_bekle(rpc, b1, "komisyon_rapor", kid, "Rapor denemesi yirmi karakterden uzun", icerir="başkan")
uyeler = [u for u in [a1, a2, a3, a4][:kont["AP"]]] + [b1]
for u in uyeler[1:]: rpc(u, "komisyon_oy", kid, "ret", "Bütçe açığı büyür")
rpc(a1, "komisyon_oy", kid, "kabul", None)
kid2 = rpc(b1, "kanun_teklif", "serbest", "Okul sütü kanunu", "İlkokullarda ücretsiz süt dağıtılsın.", None)["id"]
assert rpc(a2, "komisyon_kanun", kid2)["kom_kod"] == "egitim"
saat("2026-10-30 11:00"); q("select oyun.tick()")
k1 = qj(f"select row_to_json(k) from oyun.kanunlar k where id={kid}")
k2 = qj(f"select row_to_json(k) from oyun.kanunlar k where id={kid2}")
assert k1["durum"] == "ret" and "Komisyonu" in k1["sonuc_metin"], k1
assert k2["durum"] == "oylamada" and q(f"select karar from oyun.kom_kanun where kanun_id={kid2}") == "raporsuz"
ok("Vergi teklifi Plan ve Bütçe'de reddedildi, Genel Kurul'a gelmedi; oy kullanılmayan okul sütü teklifi raporsuz oylamaya geçti")

tb = a4; makam(tb, "tbmm", parti=PA)
kid3 = rpc(a2, "kanun_teklif", "serbest", "Yeni teklif başlığı", "Gerekçe metni burada yazıyor.", None)["id"]
assert rpc(tb, "komisyon_kanun", kid3)["havale_edebilirim"]
assert rpc(tb, "komisyon_havale", kid3, "icisleri")["kom_kod"] == "icisleri"
hata_bekle(rpc, a1, "komisyon_havale", kid3, "adalet", icerir="Meclis Başkanı")
ok("Meclis Başkanı havaleyi değiştirebiliyor, başkası değiştiremiyor")

# ===================================================================== 4) PARTİ KAPATMA
print("Parti kapatma davası")
adalet = oyuncu("AdaletBakani"); makam(adalet, "bakan", bakanlik="adalet")
h1, h2, h3 = oyuncu("Hakim1"), oyuncu("Hakim2"), oyuncu("Hakim3")
for i, h in enumerate([h1, h2, h3], 1): q(f"update oyun.mahkeme_uye set user_id='{h}', bas=now(), gorev_bit=now()+interval '60 days' where sira={i}")
gbC = oyuncu("GenelC"); PC = parti("C Partisi", "CP", gbC); cv = oyuncu("Cvekil"); uye(cv, PC); makam(cv, "mv", IL("İzmir"), parti=PC)
hata_bekle(rpc, b2, "parti_kapatma_ac", PC, "odak", "kısa", icerir="50")
hata_bekle(rpc, gbC, "parti_kapatma_ac", PC, "odak", "x" * 60, icerir="Kendi")
rpc(adalet, "parti_kapatma_ac", PC, "odak", "Parti yöneticilerinin açıklamaları demokratik cumhuriyet ilkelerine aykırı eylemlerin odağı olduğunu gösteriyor.")
d = rpc(gbC, "parti_kapatma_davalari", PC)["davalar"][0]; assert d["durum"] == "savunma" and d["savunabilirim"]
rpc(gbC, "parti_kapatma_savunma", d["id"], "İddialar soyuttur; partimiz demokratik ilkelere bağlıdır ve hiçbir yasa dışı eylemin odağı değildir.")
assert rpc(h1, "parti_kapatma_davalari", PC)["davalar"][0]["oy_verebilirim"]
kasaC, hz0 = num(f"select kasa from oyun.partiler where id={PC}"), num("select hazine from oyun.ulke where id=1")
rpc(h1, "parti_kapatma_oy", d["id"], "kapatma", "Deliller partinin odak hâline geldiğini gösteriyor.")
assert q(f"select kapali from oyun.partiler where id={PC}") == "f"
rpc(h2, "parti_kapatma_oy", d["id"], "kapatma", "Üçte iki çoğunluk için oyumu kapatma yönünde kullanıyorum.")
assert q(f"select kapali from oyun.partiler where id={PC}") == "t"
assert q(f"select parti_id from oyun.profiller where id='{cv}'") == "" and q(f"select parti_id from oyun.makamlar where user_id='{cv}' and tur='mv' and bit is null") == ""
assert num("select hazine from oyun.ulke where id=1") > hz0 and kasaC > 0
assert q(f"select adaylik_yasagi_bitis > now() + interval '29 days' from oyun.profiller where id='{gbC}'") == "t"
ok("Adalet Bakanı davası → savunma → 3 üyeden 2 kapatma oyu: parti kapandı, vekil bağımsız kaldı, kasa hazineye, GB'ye 30 gün adaylık yasağı")

saat("2026-11-01 10:00")
rpc(a1, "parti_kapatma_ac", PB, "mali", "Parti hesaplarında açıklanamayan bağışlar ve mali denetime sunulmayan harcamalar tespit edilmiştir.")
d = rpc(a2, "parti_kapatma_davalari", PB)["davalar"][0]; assert d["durum"] == "imza" and d["imzalayabilirim"]
hata_bekle(rpc, b2, "parti_kapatma_imza", d["id"], icerir="Kendi")
for u in (a2, a3, cv):
    if rpc(u, "parti_kapatma_davalari", PB)["davalar"][0]["durum"] == "imza": rpc(u, "parti_kapatma_imza", d["id"])
assert rpc(gbB, "parti_kapatma_davalari", PB)["davalar"][0]["durum"] == "savunma"
saat("2026-11-02 11:00"); q("select oyun.siyasi_kurumlar_tick()")
assert rpc(gbB, "parti_kapatma_davalari", PB)["davalar"][0]["durum"] == "yargilama"
rpc(h1, "parti_kapatma_oy", d["id"], "kapatma", "Mali usulsüzlük ağır ve süreklidir.")
rpc(h2, "parti_kapatma_oy", d["id"], "yardim", "Kapatma ağır; yardımdan yoksunluk yeterli.")
assert rpc(gbB, "parti_kapatma_davalari", PB)["davalar"][0]["durum"] == "yargilama"
rpc(h3, "parti_kapatma_oy", d["id"], "ret", "Deliller yetersizdir; dava reddedilmelidir.")
d = rpc(gbB, "parti_kapatma_davalari", PB); assert d["davalar"][0]["durum"] == "yardim" and d["yardim_yasaklari"]
sid = q("select id from oyun.secimler where tur='mv' and durum <> 'bekliyor' order by oy_bit desc limit 1")
if not sid:
    sid = q("insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,durum) values ('mv','2026-test',now()-interval '9 day',now()-interval '8 day',now()-interval '7 day',now()-interval '6 day',now()-interval '6 day',now()-interval '5 day','tamam') returning id")
q(f"insert into oyun.oylar(secim_id,secmen,parti_id,il_id,zaman) select {sid}, id, parti_id, il_id, now() from oyun.profiller where parti_id in ({PA},{PB}) on conflict do nothing")
paylar = qj("select json_agg(parti_id) from oyun.parti_yardim_paylari()")
assert PA in paylar and PB not in paylar, paylar
ok("Vekil imzasıyla açılan davada 1 kapatma + 1 yoksunluk + 1 ret: B Partisi 30 gün hazine yardımından yoksun, A'nın payı ödeniyor")

# ===================================================================== 5) KOLLAR
print("Gençlik ve kadın kolları")
genc, kadin, disari = oyuncu("GencUye"), oyuncu("KadinUye"), oyuncu("Ziyaretci", "Ankara")
uye(genc, PA); uye(kadin, PA)
hata_bekle(rpc, genc, "kol_baskan_ata", PA, "genclik", "GencUye", icerir="genel başkan")
hata_bekle(rpc, gbA, "kol_baskan_ata", PA, "genclik", "Ziyaretci", icerir="üyesi")
gby = oyuncu("Gby"); uye(gby, PA); q(f"insert into oyun.parti_gby(parti_id,sira,user_id,gorev) values ({PA},1,'{gby}','Teşkilattan Sorumlu')")
hata_bekle(rpc, gbA, "kol_baskan_ata", PA, "genclik", "Gby", icerir="Tek görev")
rpc(gby, "kol_baskan_ata", PA, "genclik", "GencUye")
rpc(kadin, "kol_katil", PA, "kadin")
k = rpc(genc, "parti_kollari", PA); assert k["kollar"][0]["baskanim"] and k["kollar"][1]["uye_sayisi"] == 1
hata_bekle(rpc, genc, "kol_etkinlik_duzenle", PA, "genclik", "bulusma", IL("Ankara"), "Gençlik buluşması", "Ankara'da gençlerle buluşuyoruz.", icerir="teşkilat")
q(f"insert into oyun.parti_teskilat(parti_id,il_id,kurulus) values ({PA},{IL('Ankara')},now()) on conflict do nothing")
hata_bekle(rpc, genc, "kol_etkinlik_duzenle", PA, "genclik", "bulusma", IL("Ankara"), "Gençlik buluşması", "Ankara'da gençlerle buluşuyoruz.", icerir="kasasında")
hata_bekle(rpc, genc, "kol_butce_aktar", PA, "genclik", 20000, icerir="mali")
rpc(gbA, "kol_butce_aktar", PA, "genclik", 20000)
pg = para(genc); rpc(genc, "kol_bagis", PA, "genclik", 1000); assert pg - para(genc) == 1000
rpc(genc, "kol_etkinlik_duzenle", PA, "genclik", "bulusma", IL("Ankara"), "Gençlik buluşması", "Ankara'da gençlerle buluşuyoruz.")
hata_bekle(rpc, genc, "kol_etkinlik_duzenle", PA, "genclik", "egitim", IL("Ankara"), "İkinci etkinlik", "Aynı anda ikinci etkinlik olmaz.", icerir="süren")
e = rpc(disari, "parti_kollari", PA)["kollar"][0]["etkinlikler"][0]; assert e["katilabilirim"] and rpc(disari, "parti_kollari", PA)["kollar"][0]["kasa"] is None
rpc(disari, "kol_etkinlik_katil", e["id"])
hata_bekle(rpc, kadin, "kol_etkinlik_katil", e["id"], icerir="yalnız o ilde")
rpc(genc, "kol_duyuru_yap", PA, "genclik", "Hafta sonu", "Hafta sonu bütün illerde stant açıyoruz.")
hata_bekle(rpc, genc, "kol_duyuru_yap", PA, "genclik", "Yine", "Altı saat dolmadan ikinci duyuru.", icerir="6 saatte")
uye(disari, PA)
saat("2026-11-03 12:00"); q("select oyun.siyasi_kurumlar_tick()")
k = rpc(genc, "parti_kollari", PA)["kollar"][0]
assert k["kasa"] == 21000 - 5000 and k["istatistik"]["katilim"] == 1 and k["istatistik"]["kazanilan_uye"] == 1 and k["etkinlikler"][0]["sonuc"]
makam(genc, "bel", IL("İzmir"), parti=PA)
assert rpc(genc, "parti_kollari", PA)["kollar"][0]["baskan"] is None
uye(kadin, PB); assert rpc(gbA, "parti_kollari", PA)["kollar"][1]["uye_sayisi"] == 0
ok("Kol başkanı atandı (tek görev kontrolü), bütçe + bağış, Ankara buluşması, parti dışı katılımcı üye oldu; belediye başkanı olunca kol başkanlığı bitti, partiden ayrılan koldan çıktı")
print("TAMAM")
