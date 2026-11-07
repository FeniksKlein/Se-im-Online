"""Süper yönetici portalı · Aşama 2 (168): oyuncu yönetimi + toplu işlem kabul testleri.
Çalıştır: ../kur_yerel.sh && python3 yonetim_oyuncu.py
S4 para tutarlılığı · S6 il düzeltme (teşkilat, adaylık, seçmenlik) · S7 aynı işlem iki kez uygulanmaz ·
parti / görev kuru çalıştırma · engel / susturma geri alma · yetki."""
import json
from db import q, qj, rpc, kullanici_ekle, hata_bekle

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def J(o): return json.dumps(o, ensure_ascii=False)

q("update oyun.ayarlar set test_simdi = '2031-03-01 12:00+03'")

Y = kullanici_ekle("sahip@test.com"); rpc(Y, "profil_olustur", "Sahip", 34)
q(f"update oyun.profiller set yonetici = true where id = '{Y}'")
U = {}
for ad, il in (("Ali", 34), ("Berk", 34), ("Cem", 35), ("Duru", 6), ("Ece", 6), ("Fatih", 35)):
    u = kullanici_ekle(f"{ad}@test.com"); rpc(u, "profil_olustur", ad, il); U[ad] = u
for ad in ("Ali", "Berk", "Duru", "Ece"):
    q(f"update oyun.profiller set parti_id = 1, parti_at = '2030-01-01' where id = '{U[ad]}'")
q(f"update oyun.profiller set parti_id = 2, parti_at = '2030-01-01' where id = '{U['Cem']}'")
q("update oyun.profiller set son_il_degis = '2030-01-01', il_at = '2030-01-01'")

def onizle(islem, p): return rpc(Y, "yp_onizle", islem, J(p))
def uygula(o, onay="ONAYLIYORUM"): return rpc(Y, "yp_uygula", o["anahtar"], onay)
def para(ad): return float(q(f"select para from oyun.cuzdan where user_id = '{U[ad]}'"))

# ---------------------------------------------------------------- yetki
hata_bekle(rpc, U["Ali"], "yp_onizle", "oyuncu_para", J({"user_id": U["Ali"], "tutar": 1, "aciklama": "x"}), icerir="YP_YETKI")
hata_bekle(rpc, U["Ali"], "yp_oyuncular", "{}", icerir="YP_YETKI")
ok("Oyuncu portal işlemlerini çağıramaz")

# ---------------------------------------------------------------- S4 para
a0, b0 = para("Ali"), para("Berk")
hh0 = int(q("select count(*) from oyun.hesap_hareket where tur = 'yonetici'"))
o = onizle("oyuncu_para", {"kullanicilar": [U["Ali"], U["Berk"]], "tutar": 5000, "aciklama": "Seçim ödülü"})
assert o.get("engel") is None and o["sayi"] == 2, o
hata_bekle(rpc, Y, "yp_uygula", o["anahtar"], "evet", icerir="YP_ONAY")
s = uygula(o)
assert s["basarili"] and len(s["eklenen"]) == 2 and s["dogrulama"]["tutarli"], s
assert para("Ali") - a0 == 5000 and para("Berk") - b0 == 5000
assert int(q("select count(*) from oyun.hesap_hareket where tur = 'yonetici'")) == hh0 + 2
ok("S4: 2 oyuncuya +5000 ₺; cüzdan farkı ve hesap hareketi tutarlı")

# S7 aynı anahtar ikinci kez uygulanmaz
s2 = uygula(o)
assert s2["basarili"] and s2.get("tekrar"), s2
assert para("Ali") - a0 == 5000 and int(q("select count(*) from oyun.hesap_hareket where tur = 'yonetici'")) == hh0 + 2
ok("S7: aynı işlem anahtarı ikinci kez çalışmadı, yeni kayıt yok")

# Mükerrer uyarısı
o2 = onizle("oyuncu_para", {"kullanicilar": [U["Ali"], U["Berk"]], "tutar": 5000, "aciklama": "Seçim ödülü"})
assert o2.get("mukerrer") and any("zaten uygulandı" in u for u in o2["uyarilar"]), o2
ok("Aynı değerlerle yeni ön izleme mükerrer uyarısı veriyor")

# Yetersiz bakiye hariç tutulur, diğerine uygulanır
q(f"update oyun.cuzdan set para = 100 where user_id = '{U['Berk']}'")
o3 = onizle("oyuncu_para", {"kullanicilar": [U["Ali"], U["Berk"]], "tutar": -1000, "aciklama": "Ceza"})
assert o3["sayi"] == 1 and o3["haric"][0]["kad"] == "Berk", o3
s3 = uygula(o3)
assert len(s3["eklenen"]) == 1 and len(s3["eklenemeyen"]) == 1 and s3["dogrulama"]["tutarli"], s3
ok("Toplu para: yetersiz bakiyeli oyuncu hariç; başarılı/başarısız ayrı listelendi")

# Ön izlemeden sonra veri değişirse uygulanmaz
o4 = onizle("oyuncu_para", {"filtre": {"parti_id": "1"}, "tutar": 10, "aciklama": "Parti ödülü"})
n4 = o4["sayi"]
q(f"update oyun.profiller set parti_id = 1 where id = '{U['Fatih']}'")
s4 = uygula(o4)
assert not s4["basarili"] and s4.get("degisti"), s4
q(f"update oyun.profiller set parti_id = null where id = '{U['Fatih']}'")
ok(f"Filtreye yeni oyuncu girince ({n4} → {n4 + 1}) işlem durdu, hiçbir şey uygulanmadı")

# Geri al (para)
a1 = para("Ali")
g = onizle("geri_al", {"islem_id": s["islem_id"]})
assert g.get("engel") is None, g
gs = uygula(g)
assert gs["basarili"] and para("Ali") == a1 - 5000, (gs, para("Ali"), a1)
ok("Para işlemi geri alındı (ters hesap hareketiyle)")

# Filtre yöneticiyi içermez
o5 = onizle("oyuncu_bildirim", {"filtre": {}, "metin": "Merhaba vatandaşlar"})
assert all(e["user_id"] != Y for e in o5["etkilenen"]) and o5["sayi"] == 6, o5
ok("Filtreli toplu işlem yönetici hesabını içermiyor")

# ---------------------------------------------------------------- kıdem
k0 = float(q(f"select kidem from oyun.cuzdan where user_id = '{U['Cem']}'"))
o = onizle("oyuncu_kidem", {"user_id": U["Cem"], "miktar": 7})
s = uygula(o, None)
assert s["basarili"] and float(q(f"select kidem from oyun.cuzdan where user_id = '{U['Cem']}'")) == k0 + 7, s
gs = uygula(onizle("geri_al", {"islem_id": s["islem_id"]}))
assert float(q(f"select kidem from oyun.cuzdan where user_id = '{U['Cem']}'")) == k0
ok("Kıdem +7 ve geri alma")

# ---------------------------------------------------------------- S6 il düzeltme
q("""insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,durum) values
 ('mv_on','2031-04','2031-02-25 00:00+03','2031-03-05 00:00+03','2031-03-10 08:00+03','2031-03-10 22:00+03','2031-03-10 22:30+03','2031-03-11 00:00+03','bekliyor'),
 ('mv','2031-04',null,null,'2031-04-01 08:00+03','2031-04-01 22:00+03','2031-04-01 22:30+03','2031-04-02 00:00+03','bekliyor')""")
ON = int(q("select id from oyun.secimler where tur='mv_on' and donem='2031-04'"))
q(f"insert into oyun.adaylar(secim_id,user_id,parti_id,il_id,sira) values ({ON},'{U['Ali']}',1,34,1),({ON},'{U['Duru']}',1,6,1),({ON},'{U['Ece']}',1,6,2)")
q(f"insert into oyun.parti_teskilat_gorev(parti_id,il_id,user_id,atayan,atama,aktif) values (1,34,'{U['Ali']}','{Y}',now(),true) on conflict (parti_id,il_id) do update set user_id = excluded.user_id, aktif = true")
il_at0 = q(f"select il_at from oyun.profiller where id = '{U['Ali']}'")
o = onizle("oyuncu_il", {"user_id": U["Ali"], "il_id": 6})
assert o.get("engel") is None, o
assert o["adayliklar"][0]["islem"] == "tasi" and o["adayliklar"][0]["yeni_sira"] == 3, o["adayliklar"]
assert len(o["teskilat"]) == 1, o
s = uygula(o, None)
assert s["basarili"] and s["dogrulama"]["tutarli"] and s["dogrulama"]["eski_ilde_bekleyen_adaylik_yok"], s
r = qj(f"select row_to_json(x) from (select il_id, il_at from oyun.profiller where id = '{U['Ali']}') x")
assert r["il_id"] == 6 and q(f"select il_at from oyun.profiller where id = '{U['Ali']}'") == il_at0
assert q(f"select il_id || '/' || sira from oyun.adaylar where secim_id = {ON} and user_id = '{U['Ali']}'") == "6/3"
assert q(f"select aktif from oyun.parti_teskilat_gorev where parti_id = 1 and il_id = 34") == "f"
mv = qj(f"select row_to_json(s) from oyun.secimler s where tur='mv' and donem='2031-04'")
pr = f"(select p from oyun.profiller p where id = '{U['Ali']}')"
assert q(f"select oyun.oy_engeli({pr}, s) is null from oyun.secimler s where id = {mv['id']}") == "t"
ok("S6: İstanbul → Ankara düzeltme: il, il başkanlığı kapandı, ön seçim adaylığı Ankara listesine 3. sıradan taşındı, seçmenlik sürüyor")

gs = uygula(onizle("geri_al", {"islem_id": s["islem_id"]}))
assert gs["basarili"], gs
assert q(f"select il_id from oyun.profiller where id = '{U['Ali']}'") == "34"
assert q(f"select il_id || '/' || sira from oyun.adaylar where secim_id = {ON} and user_id = '{U['Ali']}'") == "34/1"
assert q("select aktif from oyun.parti_teskilat_gorev where parti_id = 1 and il_id = 34") == "t"
ok("İl düzeltmesi geri alındı: il, adaylık sırası ve il başkanlığı eski halinde")

# taşınma kipi seçmen kütüğü beklemesini başlatır
q("update oyun.ayarlar set oy_il_gun = 60")
o = onizle("oyuncu_il", {"user_id": U["Berk"], "il_id": 35, "mod": "tasinma"})
assert any("Seçmen kütüğü" in (x["sonra"] or "") for x in o["oy_hakki"]), o["oy_hakki"]
o = onizle("oyuncu_il", {"user_id": U["Berk"], "il_id": 35})
assert not any("Seçmen kütüğü" in (x["sonra"] or "") for x in o["oy_hakki"]), o["oy_hakki"]
q("update oyun.ayarlar set oy_il_gun = 0")
ok("Taşınma kipi seçmen kütüğü beklemesini gösteriyor, düzeltme kipi göstermiyor")

# ---------------------------------------------------------------- parti (kuru çalıştırma)
o = onizle("oyuncu_parti", {"user_id": U["Ali"], "parti_id": 2})
assert o.get("engel") is None, o
biten = [x["ad"] for x in o["biten"]]
assert any("adaylığı" in b for b in biten) and any("İl Başkanı" in b for b in biten), biten
assert q(f"select parti_id from oyun.profiller where id = '{U['Ali']}'") == "1", "kuru çalıştırma veriyi değiştirdi"
assert q(f"select count(*) from oyun.adaylar where secim_id = {ON} and user_id = '{U['Ali']}'") == "1"
s = uygula(o)
assert s["basarili"] and s["dogrulama"]["tutarli"], s
assert q(f"select parti_id from oyun.profiller where id = '{U['Ali']}'") == "2"
assert q(f"select count(*) from oyun.adaylar where secim_id = {ON} and user_id = '{U['Ali']}'") == "0"
ok("Parti değişikliği: ön izleme kaybedilecek adaylık + il başkanlığını gösterdi, veriye dokunmadı; uygulama aynısını yaptı")
g = onizle("geri_al", {"islem_id": s["islem_id"]})
assert g.get("engel"), g
ok("Parti değişikliği geri alınamaz olarak işaretli")

# ---------------------------------------------------------------- görev ver / al
o = onizle("makam_ver", {"user_id": U["Cem"], "tur": "bel", "il_id": 35})
assert o.get("engel") is None and any("Belediye" in x["ad"] or "35" in x["ad"] or "İzmir" in x["ad"] for x in o["baslayan"]), o
assert q(f"select count(*) from oyun.makamlar where user_id = '{U['Cem']}' and bit is null") == "0"
s = uygula(o)
mid = q(f"select id from oyun.makamlar where user_id = '{U['Cem']}' and bit is null and tur = 'bel'")
assert s["basarili"] and mid, s
# aynı koltuğa başkası: önceki sahibi "biten"de
o = onizle("makam_ver", {"user_id": U["Fatih"], "tur": "bel", "il_id": 35})
assert any(x["kad"] == "Cem" for x in o["biten"]), o["biten"]
ok("Görev ver: belediye başkanlığı atandı; koltuğa başkası atanırken önceki sahibi 'bitecek' listesinde")
o = onizle("makam_al", {"makam_id": int(mid), "neden": "Test"})
assert any(x["kad"] == "Cem" for x in o["biten"]), o
s = uygula(o)
assert s["basarili"] and q(f"select bit is not null from oyun.makamlar where id = {mid}") == "t"
ok("Görevden al: makam sona erdi")
assert "Geçersiz" in (onizle("makam_ver", {"user_id": U["Cem"], "tur": "yok"}).get("engel") or "")
ok("Geçersiz görev türü engel olarak dönüyor")

# ---------------------------------------------------------------- engel / sustur
o = onizle("hesap_engelle", {"kullanicilar": [U["Fatih"], Y], "gun": 3, "neden": "Hakaret"})
assert o["sayi"] == 1 and o["haric"][0]["kad"] == "Sahip", o
s = uygula(o)
assert s["basarili"] and q(f"select yasakli from oyun.profiller where id = '{U['Fatih']}'") == "t"
gs = uygula(onizle("geri_al", {"islem_id": s["islem_id"]}))
assert gs["basarili"] and q(f"select yasakli from oyun.profiller where id = '{U['Fatih']}'") == "f", gs
ok("Hesap engelle (yönetici hariç) ve geri alma")
o = onizle("sustur", {"user_id": U["Ece"], "saat": 24, "neden": "Spam"})
s = uygula(o, None)
assert q(f"select susturma_bitis is not null from oyun.profiller where id = '{U['Ece']}'") == "t"
gs = uygula(onizle("geri_al", {"islem_id": s["islem_id"]}))
assert gs["basarili"] and q(f"select susturma_bitis is null from oyun.profiller where id = '{U['Ece']}'") == "t", gs
ok("Susturma ve geri alma")

# ---------------------------------------------------------------- bildirim
b0 = int(q("select count(*) from oyun.bildirimler where metin = 'Oyun yönetimi: Merhaba vatandaşlar'"))
s = uygula(o5, None)
assert s["basarili"] and int(q("select count(*) from oyun.bildirimler where metin = 'Oyun yönetimi: Merhaba vatandaşlar'")) == b0 + 6
ok("Toplu bildirim 6 oyuncuya gitti")

# ---------------------------------------------------------------- okuma
L = rpc(Y, "yp_oyuncular", J({"il_id": "34"}), 50, 0, "para")
assert L["toplam"] == 3 and len(L["kayitlar"]) == 3, L
D = rpc(Y, "yp_oyuncu", U["Ali"])
for k in ("para", "makamlar", "sirketler", "mulk", "krediler", "mevduat", "davalar", "adayliklar", "oy_hakki", "portal_islemleri"):
    assert k in D, k
assert len(D["portal_islemleri"]) >= 3, D["portal_islemleri"]
assert all("tercih" not in json.dumps(x) and "aday_id" not in x for x in D["oy_hakki"])
ok("Oyuncu listesi (filtre + sıralama) ve oyuncu dosyası; oy hakkında tercih bilgisi yok")

# Denetim kaydı
n = int(q("select count(*) from oyun.yp_islem where durum in ('uygulandi','geri_alindi') and once is not null"))
assert n >= 12, n
ok(f"{n} işlem önceki/yeni değerleriyle kayıtlı")

print(f"{len(TAMAM)} kontrol geçti")
