"""Modül 87: ilişkili hesap kuralı, fiyat bantları, MASAK, anket ödül tavanı, şeffaflık."""
from db import q, qj, rpc, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
para = lambda u: float(q(f"select para from oyun.cuzdan where user_id='{u}'"))
kasa = lambda sid: float(q(f"select kasa from oyun.sirketler where id={sid}"))
def zaman(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}+03'")
def cihaz(u, c): q(f"insert into oyun.oturumlar(user_id, cihaz, iz, ip, ilk, son) values ('{u}', '{c}', 'iz', 'ip', now(), now())")

zaman("2030-01-01 10:00"); q("update oyun.ayarlar set coklu_kontrol=true")
def oyuncu(kad, il="İzmir", p=5000000):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.cuzdan set para={p} where user_id='{u}'"); return u
ANA, ALT, DIGER, UCUNCU, MOD, BAS = oyuncu("Ana"), oyuncu("AltHesap"), oyuncu("Diger"), oyuncu("Ucuncu"), oyuncu("Denetci"), oyuncu("Baskan")
cihaz(ANA, "cihaz-1"); cihaz(ALT, "cihaz-1"); cihaz(DIGER, "cihaz-2"); cihaz(UCUNCU, "cihaz-3")
assert q(f"select oyun.iliskili('{ANA}','{ALT}')") == "t" and q(f"select oyun.iliskili('{ANA}','{DIGER}')") == "f"
q("update oyun.ulke set asgari=30000 where id=1; update oyun.il_durum set gelisim=50, memnuniyet=50")
zaman("2030-01-20 10:00")
IZMIR = IL("İzmir")

# ---------------- borsa: ilişkili alım ve fiyat bandı
m = rpc(ANA, "pazar_sirket_kur", "Ana Market", "market", 400000, IZMIR, None)["id"]
q(f"update oyun.sirketler set halka_acik=true where id={m}")
hata_bekle(rpc, ANA, "borsa_sat", m, 10, 50000, icerir="Fiyat bandı")        # referans 4.000 → 2.000-8.000
rpc(ANA, "borsa_sat", m, 20, 4000)
e = rpc(DIGER, "borsa_sirket", m)["emirler"][0]["id"]
hata_bekle(rpc, ALT, "borsa_al", e, 5, icerir="ilişkili")
rpc(DIGER, "borsa_al", e, 2)
hata_bekle(rpc, ANA, "borsa_sat", m, 5, 5000, icerir="Fiyat bandı")          # son işlem 4.000 → 3.200-4.800
rpc(ANA, "borsa_sat", m, 5, 4800)
ok("Borsa: ilişkili hesap alamıyor; fiyat bandı ilk işlemde referansın 0,5-2 katı, sonra son fiyatın ±%20'si")

# ---------------- şirket satışı ve ortaklık teklifi
s2 = rpc(ANA, "sirket_kur", "Ana Holding", "teknoloji", 500000)["id"]
hata_bekle(rpc, ANA, "sirket_satiliga_cikar", s2, 1000, icerir="Fiyat bandı")            # 1 ₺'ye satıp para taşıma yok
hata_bekle(rpc, ANA, "sirket_satiliga_cikar", s2, 50000000, icerir="Fiyat bandı")        # şişirme yok
rpc(ANA, "sirket_satiliga_cikar", s2, 600000)
hata_bekle(rpc, ALT, "sirket_satilik_al", s2, icerir="ilişkili")
hata_bekle(rpc, ANA, "sirket_pay_teklif", s2, ALT, 10, 50000, icerir="ilişkili")
hata_bekle(rpc, ANA, "sirket_pay_teklif", s2, DIGER, 10, 1000, icerir="Fiyat bandı")
rpc(ANA, "sirket_pay_teklif", s2, DIGER, 10, 50000)
ok("Şirket ve pay satışı: 1 ₺'ye ya da 100 katına satılamıyor, ilişkili hesaba satılamıyor")

# ---------------- emlak
mk = rpc(ANA, "mulk_il_satin_al", "daire", IZMIR)
mulk = int(q(f"select id from oyun.yatirim_mulkleri where user_id='{ANA}' order by id desc limit 1"))
bedel = float(q(f"select oyun.mulk_il_bedel({IZMIR}::smallint,'daire')"))
hata_bekle(rpc, ANA, "mulk_ilan_ver", mulk, round(bedel * 5), icerir="Fiyat bandı")
rpc(ANA, "mulk_ilan_ver", mulk, round(bedel * 1.2))
ilan = int(q(f"select id from oyun.mulk_ilan where mulk_id={mulk} and durum='acik'"))
hata_bekle(rpc, ALT, "mulk_ilan_satin_al", ilan, icerir="ilişkili")
ok(f"Emlak: rayiç bedelin 2,5 katından pahalı ilan verilemiyor, ilişkili hesap satın alamıyor (rayiç {bedel:,.0f} ₺)")

# ---------------- ihale
q(f"insert into oyun.makamlar(tur,user_id,il_id,bas) values ('bel','{ANA}',{IZMIR},now())")
q(f"update oyun.il_durum set kasa=5 where il_id={IZMIR}")
ins_alt = rpc(ALT, "sirket_kur", "Alt Insaat", "insaat", 400000)["id"]
ins_dg = rpc(DIGER, "sirket_kur", "Diger Insaat", "insaat", 400000)["id"]
ih = rpc(ANA, "ihale_ac", "park", IZMIR, 12)
hata_bekle(rpc, ALT, "ihale_teklif", ih["id"], ins_alt, int(float(ih["tavan"]) * 0.8), icerir="Çıkar çatışması")
rpc(DIGER, "ihale_teklif", ih["id"], ins_dg, int(float(ih["tavan"]) * 0.8))
ok("İhale: belediye başkanının ikinci hesabının şirketi teklif veremiyor")

# ---------------- ajans: sipariş, anket ve ödül tavanı
aj = rpc(ALT, "ajans_kur", "Alt Ajans", 300000)["id"]
hata_bekle(rpc, ANA, "ajans_siparis", aj, "anket", IZMIR, "kisi", None, icerir="aynı cihazı")
an = rpc(DIGER, "ajans_siparis", aj, "anket", IZMIR, "kisi", None)
hata_bekle(rpc, ANA, "ajans_anket_cevap", an["id"], None, icerir="aynı cihazı")      # ajans sahibiyle ilişkili
yeni = oyuncu("YeniUye")
r = rpc(yeni, "ajans_anket_cevap", an["id"], None)
assert r["odul"] == 0 and "günden eski" in r["odulsuz_neden"]
r = rpc(UCUNCU, "ajans_anket_cevap", an["id"], None); assert r["odul"] > 0
# günlük sınır: 3 ödülden sonra ödül yok
q(f"update oyun.guvenlik_ayar set gunluk_odul_sinir=1")
aj2 = rpc(DIGER, "ajans_kur", "Diger Ajans", 300000)["id"]
zaman("2030-01-20 12:00")
an2 = rpc(BAS, "ajans_siparis", aj2, "anket", None, "kisi", None)
r = rpc(UCUNCU, "ajans_anket_cevap", an2["id"], None)
assert r["odul"] == 0 and "Günde en fazla" in r["odulsuz_neden"], r
q(f"update oyun.guvenlik_ayar set gunluk_odul_sinir=3")
ok("Ajans: ilişkili sipariş ve katılım engelli; yeni hesaba ve günlük sınırı aşana ödül yok")

# ---------------- MASAK
# 1) ani servet
q(f"select oyun.para_islem('{DIGER}', 1500000, 'sirket', 'Test kârı', oyun.simdi())")
x = qj("select row_to_json(m) from oyun.masak m where tur='ani_servet' order by id desc limit 1")
assert x and x["user_id"] == DIGER
q(f"select oyun.para_islem('{DIGER}', 1500000, 'yonetici', 'Hediye', oyun.simdi())")   # yönetici hediyesi sayılmaz, tekrar bildirim yok
assert int(q("select count(*) from oyun.masak where tur='ani_servet'")) == 1
# 2) tekrarlayan ticaret: Diğer ile Üçüncü 3 kez alıp satıyor
rpc(DIGER, "borsa_sat", m, 2, 4000)
e2 = rpc(UCUNCU, "borsa_sirket", m)["emirler"]
e2 = [z for z in e2 if z["satici"] == "Diger"][0]["id"]
rpc(UCUNCU, "borsa_al", e2, 1); rpc(UCUNCU, "borsa_sat", m, 1, 4000)
e3 = [z for z in rpc(DIGER, "borsa_sirket", m)["emirler"] if z["satici"] == "Ucuncu"][0]["id"]
rpc(DIGER, "borsa_al", e3, 1)
rpc(UCUNCU, "borsa_al", e2, 1)
assert int(q("select count(*) from oyun.masak where tur='tekrarlayan_ticaret'")) == 1
# 3) parti harcaması: GBY'ye bildirim + büyük harcamada MASAK
parti = int(q("select id from oyun.partiler where not kapali order by id limit 1"))
q(f"update oyun.partiler set gb='{BAS}', kasa=250000 where id={parti}; delete from oyun.parti_gby where parti_id={parti} or user_id='{UCUNCU}'")
q(f"insert into oyun.parti_gby(parti_id, sira, user_id) values ({parti}, 1, '{UCUNCU}')")
zaman("2030-01-20 14:00")
rpc(BAS, "ajans_siparis", aj2, "reklam", None, "parti", "Türkiye için büyük değişim başlıyor, bize katıl!")
assert "kasasından" in q(f"select metin from oyun.bildirimler where user_id='{UCUNCU}' order by id desc limit 1")
assert int(q("select count(*) from oyun.masak where tur='parti_harcama'")) == 1
# 4) ihale aynı partiden birine giderse
q(f"update oyun.profiller set parti_id={parti} where id in ('{ANA}','{DIGER}')")
zaman("2030-01-21 00:00"); q("select oyun.ihale_tick()")
assert int(q("select count(*) from oyun.masak where tur='ihale_kayirma'")) == 1
ok("MASAK: ani servet (yönetici hediyesi hariç), tekrarlayan ticaret, büyük parti harcaması (GBY'ye bildirim), aynı partiye ihale kayıtları oluştu")

# ---------------- MASAK paneli ve kararlar
hata_bekle(rpc, MOD, "admin_masak", "yeni", icerir="yalnızca oyun yöneticileri")
q(f"insert into oyun.moderatorler(user_id, yetkiler, atayan, zaman) values ('{MOD}', '{{ekonomi}}', '{ANA}', now())")
p = rpc(MOD, "admin_masak", "yeni")
assert len(p["kayitlar"]) == 4 and p["kayitlar"][0]["son_gelirler"] is not None
ani = [k for k in p["kayitlar"] if k["tur"] == "ani_servet"][0]
hata_bekle(rpc, MOD, "admin_masak_karar", ani["id"], "el_koy", 1000000, "kısa", icerir="10 karakter")
d0, h0 = para(DIGER), float(q("select hazine from oyun.ulke where id=1"))
rpc(MOD, "admin_masak_karar", ani["id"], "el_koy", 1000000, "Haksız kazanç tespit edildi (test).")
assert para(DIGER) == d0 - 1000000 and float(q("select hazine from oyun.ulke where id=1")) > h0
assert "el konuldu" in q(f"select metin from oyun.bildirimler where user_id='{DIGER}' order by id desc limit 1")
hata_bekle(rpc, MOD, "admin_masak_karar", ani["id"], "temiz", None, None, icerir="zaten")
diger = [k for k in p["kayitlar"] if k["tur"] == "tekrarlayan_ticaret"][0]
rpc(MOD, "admin_masak_karar", diger["id"], "ihtar", None, "Karşılıklı al-sat yapmayın, uyarı.")
uid_ihtar = q(f"select id from oyun.profiller where kad='{diger['kad']}'")
assert "MASAK ihtarı" in q(f"select metin from oyun.bildirimler where user_id='{uid_ihtar}' order by id desc limit 1")
assert q("select count(*) from oyun.mod_kayit where islem like 'masak_%'") == "2"
ok("MASAK paneli: yalnız 'ekonomi' yetkisiyle; el koyma parayı hazineye aktardı ve bildirdi; ihtar; aynı kayda ikinci karar yok")

# ---------------- şeffaflık
dft = rpc(DIGER, "parti_kasa_defteri", parti)
assert dft["cikis_30g"] > 0 and any("reklam" in h["aciklama"] for h in dft["hareketler"])
yh = rpc(DIGER, "yonetim_hediyeleri")
assert yh["toplam"] >= 1500000 and yh["el_koyma"][0]["tutar"] == 1000000
ok("Şeffaflık: parti kasa defteri herkese açık, yönetim hediyeleri ve el koymalar listede")
print("TAMAM: ekonomi güvenliği")
